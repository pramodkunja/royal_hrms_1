import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/widgets/leave_carry_forward_tab.dart';

import '../../core/permissions/p0_permission_parity_test.dart' as h;

// Task 88 / HO-37: Carry Forward safety guard. Run writes leave balances on
// production and the preview/run POSTs are unverified there, so Run must be
// unreachable until a successful Preview for exactly the selected years.
// A stand-in server with synthetic data; nothing is sent anywhere.

ResponseBody _json(Object body, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> _ok(Object data) => {'status': 'success', 'message': 'ok', 'data': data};

class _CfServer extends h.Server {
  bool failPreview = false;
  bool previewEchoesYears = true;
  final log = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    log.add('${o.method} ${o.path}');
    switch ('${o.method} ${o.path}') {
      case 'GET ${ApiConstants.carryForwardYears}':
        return _json(_ok({
          'years': [
            {'from_year': 2024, 'to_year': 2025},
            {'from_year': 2025, 'to_year': 2026},
          ],
          'default_from': 2025,
          'default_to': 2026,
        }));
      case 'GET ${ApiConstants.carryForwardHistory}':
        return _json(_ok({'count': 0, 'page': 1, 'total_pages': 1, 'results': []}));
      case 'POST ${ApiConstants.carryForwardPreview}':
        if (failPreview) return _json({'status': 'error', 'message': 'Not found.'}, 404);
        final body = o.data as Map;
        return _json(_ok({
          if (previewEchoesYears) 'from_year': body['from_year'],
          if (previewEchoesYears) 'to_year': body['to_year'],
          'total_rows': 1,
          'pending_count': 1,
          'already_processed_count': 0,
          'preview_rows': [
            {
              'employee_id': 'E-T1',
              'employee_name': 'Test Employee',
              'leave_type': 'cl',
              'leave_type_display': 'Casual Leave',
              'unused_days': 2,
              'carry_forward_amount': 2,
              'already_processed': false,
            }
          ],
        }));
    }
    return super.fetch(o, s, c);
  }
}

late _CfServer _cf;

final _run = find.byKey(const Key('carry-forward-run'));
final _preview = find.byKey(const Key('carry-forward-preview'));
final _hint = find.byKey(const Key('carry-forward-preview-required'));
bool _enabled(WidgetTester t, Finder f) => t.widget<ButtonStyleButton>(f).onPressed != null;

Future<void> _pump(WidgetTester tester, {void Function(_CfServer)? configure}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  _cf = _CfServer();
  configure?.call(_cf);
  h.server = _cf;
  await tester.pumpWidget(ProviderScope(
    overrides: h.overrides(h.user(['settings.view', 'leave.edit', 'leave.approve'], role: 'branch_admin')),
    child: const MaterialApp(
      home: Scaffold(body: LeaveCarryForwardTab()),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _pickYear(WidgetTester tester, String label, int year) async {
  final dd = find.byType(DropdownButtonFormField<int>);
  await tester.tap(label == 'From Year' ? dd.first : dd.last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('$year').last);
  await tester.pumpAndSettle();
}

Iterable<String> _writes() => _cf.log.where((l) => !l.startsWith('GET '));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('GETs load years; Run is disabled before any preview, with an explanation', (tester) async {
    await _pump(tester);
    expect(_cf.log, contains('GET ${ApiConstants.carryForwardYears}'));
    expect(_enabled(tester, _preview), isTrue);
    expect(_enabled(tester, _run), isFalse);
    expect(_hint, findsOneWidget);
    expect(find.textContaining('Run is enabled only after a successful preview'), findsOneWidget);
    expect(_writes(), isEmpty);
  });

  testWidgets('a successful preview for the selected years enables Run', (tester) async {
    await _pump(tester);
    await tester.tap(_preview);
    await tester.pumpAndSettle();
    expect(_writes(), ['POST ${ApiConstants.carryForwardPreview}']);
    expect(_enabled(tester, _run), isTrue);
    expect(_hint, findsNothing);
    expect(_cf.log.where((l) => l.contains(ApiConstants.carryForwardRun)), isEmpty);
  });

  testWidgets('guard does not depend on the preview response echoing the years', (tester) async {
    await _pump(tester, configure: (s) => s.previewEchoesYears = false);
    await tester.tap(_preview);
    await tester.pumpAndSettle();
    expect(_enabled(tester, _run), isTrue);
  });

  testWidgets('a failed preview (e.g. 404) keeps Run disabled and shows the error', (tester) async {
    await _pump(tester, configure: (s) => s.failPreview = true);
    await tester.tap(_preview);
    await tester.pumpAndSettle();
    expect(find.textContaining('Not found'), findsWidgets);
    expect(_enabled(tester, _run), isFalse);
    expect(_hint, findsOneWidget);
    expect(_cf.log.where((l) => l.contains(ApiConstants.carryForwardRun)), isEmpty);
  });

  testWidgets('changing a year after preview disables Run again', (tester) async {
    await _pump(tester);
    await tester.tap(_preview);
    await tester.pumpAndSettle();
    expect(_enabled(tester, _run), isTrue);
    await _pickYear(tester, 'From Year', 2024);
    expect(_enabled(tester, _run), isFalse);
    expect(_hint, findsOneWidget);
  });

  testWidgets('Run opens the irreversible-action confirmation; Cancel sends no run request', (tester) async {
    await _pump(tester);
    await tester.tap(_preview);
    await tester.pumpAndSettle();
    await tester.tap(_run);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.textContaining('This cannot be undone'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(_cf.log.where((l) => l.contains(ApiConstants.carryForwardRun)), isEmpty);
    expect(_writes(), ['POST ${ApiConstants.carryForwardPreview}']);
  });

  testWidgets('tapping disabled Run before preview opens nothing and sends nothing', (tester) async {
    await _pump(tester);
    await tester.tap(_run, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(_writes(), isEmpty);
  });
}

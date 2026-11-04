import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/profile/data/models/my_profile_model.dart';
import 'package:mobile_app/features/separation/data/models/separation_models.dart';
import 'package:mobile_app/features/separation/presentation/notice_period.dart';
import 'package:mobile_app/features/separation/presentation/providers/separation_providers.dart';
import 'package:mobile_app/features/separation/presentation/screens/separation_detail_screen.dart';
import 'package:mobile_app/features/separation/presentation/widgets/separation_form_sheet.dart';
import 'package:mobile_app/shared/widgets/app_text_field.dart';

// Phase 1 D: the employee's assigned notice period and the expected last
// working day, as web's SeparationFormModal / SeparationDetailsSection and
// the backend's _apply_assigned_notice + notice_info do it.

ResponseBody _ok(Object data) => ResponseBody.fromString(
        jsonEncode({'status': 'success', 'message': 'ok', 'data': data}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });

class _Backend implements HttpClientAdapter {
  _Backend({this.myNotice, this.employees = const []});
  final int? myNotice;
  final List<Map<String, dynamic>> employees;

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    switch (o.path) {
      case ApiConstants.myProfile:
        return _ok({
          'id': 'u1',
          'full_name': 'Pat Person',
          'notice_period_days': myNotice,
          'profile': {}
        });
      case ApiConstants.separationTypes:
        return _ok([
          {'value': 'resignation', 'label': 'Resignation'}
        ]);
      case ApiConstants.separationReasons:
        return _ok([
          {'value': 'career', 'label': 'Career growth'}
        ]);
      case ApiConstants.employees:
        return _ok({'count': employees.length, 'results': employees});
    }
    return _ok({});
  }

  @override
  void close({bool force = false}) {}
}

class _NullSecureStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('helpers (web lib/noticePeriod.ts)', () {
    test(
        'expected last working day = request date + notice days, across months and years',
        () {
      expect(expectedLastWorkingDay(DateTime(2026, 11, 4), 30),
          DateTime(2026, 12, 4));
      expect(expectedLastWorkingDay(DateTime(2026, 12, 20), 15),
          DateTime(2027, 1, 4));
      expect(expectedLastWorkingDay(DateTime(2026, 2, 27), 1),
          DateTime(2026, 2, 28));
      expect(expectedLastWorkingDay(DateTime(2026, 11, 4), 0),
          DateTime(2026, 11, 4));
      expect(expectedLastWorkingDay(null, 30), isNull);
      expect(expectedLastWorkingDay(DateTime(2026, 11, 4), null), isNull);
    });

    test('formatting', () {
      expect(formatNoticePeriod(null), 'Not assigned');
      expect(formatNoticePeriod(1), '1 day');
      expect(formatNoticePeriod(60), '60 days');
      expect(formatNoticeDate('2026-12-04'), '4 Dec 2026');
      expect(formatNoticeDate(null), '—');
      expect(formatNoticeDate('garbage'), '—');
    });
  });

  group('parsing', () {
    test(
        'separation request: assigned notice and expected last working day; absent = null',
        () {
      Map<String, dynamic> j([Map<String, dynamic> extra = const {}]) => {
            'id': 's1',
            'request_date': '2026-11-04',
            'notice_period_days': 45,
            ...extra
          };
      final r = SeparationRequestModel.fromJson(j({
        'assigned_notice_period_days': 45,
        'expected_last_working_day': '2026-12-19'
      }));
      expect(r.assignedNoticePeriodDays, 45);
      expect(r.expectedLastWorkingDay, '2026-12-19');
      final none = SeparationRequestModel.fromJson(j({
        'assigned_notice_period_days': null,
        'expected_last_working_day': ''
      }));
      expect(none.assignedNoticePeriodDays, isNull);
      expect(none.expectedLastWorkingDay, isNull);
    });

    test('employee picker rows and the profile carry notice_period_days', () {
      expect(
          EmployeePickerOptionModel.fromJson(
              {'employee_id': 'E1', 'notice_period_days': 60}).noticePeriodDays,
          60);
      expect(
          EmployeePickerOptionModel.fromJson({'employee_id': 'E1'})
              .noticePeriodDays,
          isNull);
      expect(
          MyProfileModel.fromJson({
            'id': 'u',
            'notice_period_days': 90,
            'profile': <String, dynamic>{}
          }).noticePeriodDays,
          90);
      expect(
          MyProfileModel.fromJson({'id': 'u', 'profile': <String, dynamic>{}})
              .noticePeriodDays,
          isNull);
    });
  });

  group('separation form', () {
    Future<void> pumpForm(WidgetTester tester, _Backend backend,
        {bool canPickEmployee = false}) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(
              Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
                ..httpClientAdapter = backend),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullSecureStorage()),
        ],
        child: MaterialApp(
            home: Scaffold(
                body: SeparationFormSheet(canPickEmployee: canPickEmployee))),
      ));
      await tester.pumpAndSettle();
    }

    AppTextField noticeField(WidgetTester tester) =>
        tester.widget<AppTextField>(
            find.widgetWithText(AppTextField, 'Notice Period (days) *'));
    String noticeText(WidgetTester tester) =>
        noticeField(tester).controller!.text;
    String ddmmyyyy(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    testWidgets(
        'self-service with an assigned period: pre-filled, read-only, last day = today + period',
        (tester) async {
      await pumpForm(tester, _Backend(myNotice: 60));
      expect(noticeText(tester), '60');
      expect(noticeField(tester).enabled, isFalse);
      expect(find.byKey(const Key('separation-notice-hint')), findsOneWidget);
      expect(find.text('60 days from request date'), findsOneWidget);
      expect(find.text(ddmmyyyy(expectedLastWorkingDay(_today(), 60)!)),
          findsOneWidget);
    });

    testWidgets(
        'no assigned period: 30-day default, editable, last day follows it',
        (tester) async {
      await pumpForm(tester, _Backend());
      expect(noticeText(tester), '30');
      expect(noticeField(tester).enabled, isTrue);
      expect(find.byKey(const Key('separation-notice-hint')), findsNothing);
      expect(find.text('30 days from request date'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(AppTextField, 'Notice Period (days) *'), '45');
      await tester.pumpAndSettle();
      expect(find.text('45 days from request date'), findsOneWidget);
    });

    testWidgets(
        'a manually chosen last working day is kept when the notice period changes',
        (tester) async {
      await pumpForm(tester, _Backend());
      // The second date field is the Proposed Last Working Day; pick a day
      // other than today + 30 so it is a real manual choice.
      await tester.tap(find.byIcon(Icons.calendar_today_outlined).at(1));
      await tester.pumpAndSettle();
      final auto = expectedLastWorkingDay(_today(), 30)!;
      final pickDay = auto.day == 28 ? '27' : '28';
      await tester.tap(find.text(pickDay).last);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      final chosen = DateTime(auto.year, auto.month, int.parse(pickDay));
      expect(find.text(ddmmyyyy(chosen)), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(AppTextField, 'Notice Period (days) *'), '90');
      await tester.pumpAndSettle();
      expect(find.text(ddmmyyyy(chosen)), findsOneWidget);
      expect(find.text(ddmmyyyy(expectedLastWorkingDay(_today(), 90)!)),
          findsNothing);
    });

    testWidgets(
        'HR filing for an employee: their period is pre-filled and stays editable',
        (tester) async {
      await pumpForm(
        tester,
        _Backend(myNotice: 60, employees: [
          {
            'employee_id': 'EMP-9',
            'uuid': 'u9',
            'full_name': 'Sam Staff',
            'notice_period_days': 15
          }
        ]),
        canPickEmployee: true,
      );
      expect(noticeField(tester).enabled,
          isFalse); // still self until someone is picked
      await tester.enterText(find.byType(TextField).first, 'Sam');
      await tester.pumpAndSettle(const Duration(milliseconds: 600));
      await tester.tap(find.text('Sam Staff'));
      await tester.pumpAndSettle();
      expect(noticeText(tester), '15');
      expect(noticeField(tester).enabled, isTrue);
      expect(find.text('Assigned notice period: 15 days'), findsOneWidget);
      expect(find.text('15 days from request date'), findsOneWidget);
      await tester.enterText(
          find.widgetWithText(AppTextField, 'Notice Period (days) *'), '10');
      await tester.pumpAndSettle();
      expect(noticeText(tester), '10');
      expect(find.text(ddmmyyyy(expectedLastWorkingDay(_today(), 10)!)),
          findsOneWidget);
    });
  });

  group('separation details', () {
    Future<void> pumpDetail(
        WidgetTester tester, Map<String, dynamic> json) async {
      tester.view.physicalSize = const Size(1080, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final request = SeparationRequestModel.fromJson(json);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          dioProvider.overrideWithValue(
              Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))
                ..httpClientAdapter = _Backend()),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(_NullSecureStorage()),
          separationDetailProvider('s1').overrideWith((ref) async => request),
        ],
        child: MaterialApp(
            home: SeparationDetailScreen(requestId: 's1', initial: request)),
      ));
      await tester.pumpAndSettle();
    }

    Map<String, dynamic> base(Map<String, dynamic> extra) => {
          'id': 's1',
          'request_ref': 'SEP-1',
          'separation_type': 'resignation',
          'separation_type_display': 'Resignation',
          'reason': 'career',
          'reason_display': 'Career growth',
          'request_date': '2026-11-04',
          'proposed_last_working_day': '2026-12-19',
          'notice_period_days': 45,
          'status': 'pending',
          'status_display': 'Pending',
          'employee_name': 'Pat Person',
          'employee_code': 'EMP-1',
          'created_by_name': 'Pat Person',
          'created_at': '2026-11-04T10:00:00Z',
          ...extra,
        };

    testWidgets(
        'shows the assigned notice period and the expected last working day',
        (tester) async {
      // Expected (from the assigned period) differs from the proposed date.
      await pumpDetail(
          tester,
          base({
            'assigned_notice_period_days': 46,
            'expected_last_working_day': '2026-12-20'
          }));
      expect(find.text('Assigned Notice Period'), findsOneWidget);
      expect(find.text('46 days'), findsOneWidget);
      expect(find.text('Expected Last Working Day'), findsOneWidget);
      expect(find.text('20 Dec 2026'), findsOneWidget);
    });

    testWidgets('no assigned period reads "Not assigned"', (tester) async {
      await pumpDetail(
          tester,
          base({
            'assigned_notice_period_days': null,
            'expected_last_working_day': null
          }));
      expect(find.text('Not assigned'), findsOneWidget);
      expect(find.text('Expected Last Working Day'), findsOneWidget);
    });
  });
}

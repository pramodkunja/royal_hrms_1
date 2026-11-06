import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/data/models/leave_policy_model.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/leave_policy_screen.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/widgets/monthly_credit_settings_section.dart';

// Task 11: Leave Policy → Monthly Credit Settings — web
// MonthlyCreditSettingsSection.tsx inside LeavePoliciesTab.tsx. Fields
// credit_schedule ("annual" | "monthly", anything else = annual) and
// monthly_carry_forward (default true), shown with monthly_rules_from; saved
// with the policy (web: PATCH /leave/policy/<type>/ after the rules PUT; the
// server's PATCH is its PUT, which mobile sends once with all fields). The
// server sets monthly_rules_from when either changes. Stand-in server,
// synthetic policies; nothing is sent anywhere.

Map<String, dynamic> policy(String type, String display, {Map<String, dynamic> extra = const {}}) => {
      'id': type.hashCode & 0xffff,
      'leave_type': type,
      'leave_type_display': display,
      'annual_days': '12.0',
      'can_carry_forward': false,
      'max_carry_forward_days': 0,
      'policy_note': '',
      'is_active': true,
      'updated_at': '2026-11-01T00:00:00Z',
      'minimum_leave_duration': '0.5',
      ...extra,
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> policies = [
    policy('casual', 'Casual Leave',
        extra: {'credit_schedule': 'monthly', 'monthly_carry_forward': false, 'monthly_rules_from': '2026-12-01'}),
    policy('earned', 'Earned Leave'), // older shape: no monthly fields
  ];
  final puts = <({String path, Map<String, dynamic> body})>[];
  Completer<void>? hold;
  ({int status, String message})? refuseNext;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET' && o.path == ApiConstants.leaveTypes) {
      return _json({'status': 'success', 'message': 'ok', 'data': policies});
    }
    if (o.method == 'PUT' && o.path.startsWith(ApiConstants.leaveTypes)) {
      final body = Map<String, dynamic>.from(o.data as Map);
      puts.add((path: o.path, body: body));
      if (hold != null) await hold!.future;
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _json({'status': 'error', 'message': r.message}, r.status);
      }
      final type = o.path.split('/').where((s) => s.isNotEmpty).last;
      final current = policies.firstWhere((p) => p['leave_type'] == type);
      final changed = body['credit_schedule'] != (current['credit_schedule'] ?? 'annual') ||
          body['monthly_carry_forward'] != (current['monthly_carry_forward'] ?? true);
      final saved = {...current, ...body, if (changed) 'monthly_rules_from': '2026-12-01'};
      policies = [for (final p in policies) p['leave_type'] == type ? saved : p];
      return _json({'status': 'success', 'message': 'Policy updated.', 'data': saved});
    }
    return _json({'status': 'success', 'message': 'ok', 'data': []});
  }

  @override
  void close({bool force = false}) {}
}

class _NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user(List<String> perms) => UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

late Server server;

Future<void> pump(WidgetTester tester, {List<String> perms = const ['settings.view', 'leave.approve']}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(user(perms))),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(
          path: '/s',
          builder: (_, __) => Consumer(
            builder: (context, ref, _) =>
                ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : const LeavePolicyScreen(),
          ),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  // The rules ("Leave Policy") tab.
  await tester.tap(find.widgetWithText(Tab, 'Leave Policy'));
  await tester.pumpAndSettle();
}

/// Expands the (collapsed) "Monthly Credit Settings" section if needed.
Future<void> showSection(WidgetTester tester) async {
  if (find.byKey(const Key('monthly-rules-from')).hitTestable().evaluate().isEmpty) {
    final title = find.text('Monthly Credit Settings');
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(const Key('monthly-rules-from')));
  await tester.pumpAndSettle();
}

Future<void> selectType(WidgetTester tester, String label) async {
  final picker = find.byType(DropdownButtonFormField<String>).first;
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

bool selected(WidgetTester tester, String value) => tester
    .widget<Semantics>(
        find.descendant(of: find.byKey(Key('credit-schedule-$value')), matching: find.byType(Semantics)).first)
    .properties
    .checked!;

String rulesFromText(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('monthly-rules-from'))).data!;

Future<void> save(WidgetTester tester) async {
  final b = find.widgetWithText(FilledButton, 'Save Policy');
  await tester.ensureVisible(b);
  await tester.tap(b);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model and payload', () {
    test('parsing and web defaults (extractMonthly)', () {
      final m = LeavePolicyModel.fromJson(policy('a', 'A',
          extra: {'credit_schedule': 'monthly', 'monthly_carry_forward': false, 'monthly_rules_from': '2026-12-01'}));
      expect([m.creditSchedule, m.monthlyCarryForward, m.monthlyRulesFrom], ['monthly', false, '2026-12-01']);
      final old = LeavePolicyModel.fromJson(policy('b', 'B'));
      expect([old.creditSchedule, old.monthlyCarryForward, old.monthlyRulesFrom], ['annual', true, null]);
      final odd = LeavePolicyModel.fromJson(policy('c', 'C',
          extra: {'credit_schedule': 'quarterly', 'monthly_carry_forward': 'no', 'monthly_rules_from': ''}));
      expect([odd.creditSchedule, odd.monthlyCarryForward, odd.monthlyRulesFrom], ['annual', true, null]);
    });

    test('the two fields are sent only when set (the Leave Types form never sends them)', () {
      final form = LeavePolicyFormData.fromModel(LeavePolicyModel.fromJson(policy('a', 'A')));
      expect(form.toJson().containsKey('credit_schedule'), isFalse);
      expect(form.toJson().containsKey('monthly_carry_forward'), isFalse);
      form
        ..creditSchedule = 'monthly'
        ..monthlyCarryForward = false;
      expect(form.toJson(), containsPair('credit_schedule', 'monthly'));
      expect(form.toJson(), containsPair('monthly_carry_forward', false));
    });

    test('rules-from date as web (en-IN): "1 Dec 2026", "1 Sept 2026"', () {
      expect(formatRulesFrom('2026-12-01'), '1 Dec 2026');
      expect(formatRulesFrom('2026-09-01'), '1 Sept 2026');
      expect(formatRulesFrom(null), isNull);
      expect(formatRulesFrom('soon'), isNull);
    });
  });

  group('Leave Policy tab', () {
    testWidgets('loads the selected type: Monthly, carry forward off, rules-from date', (tester) async {
      await pump(tester);
      await showSection(tester);
      expect(find.text('Monthly Credit Settings'), findsOneWidget);
      expect(selected(tester, 'monthly'), isTrue);
      expect(selected(tester, 'annual'), isFalse);
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('monthly-carry-forward'))).value, isFalse);
      expect(rulesFromText(tester), endsWith('Current rules apply from 1 Dec 2026.'));
    });

    testWidgets('a type without monthly fields: Annual, no toggle, no rules-from sentence', (tester) async {
      await pump(tester);
      await selectType(tester, 'Earned Leave');
      await showSection(tester);
      expect(selected(tester, 'annual'), isTrue);
      expect(find.byKey(const Key('monthly-carry-forward')), findsNothing);
      expect(rulesFromText(tester), endsWith('earlier months and existing balances are not recalculated.'));
    });

    testWidgets('switching to Monthly shows the toggle (default on); Save sends both with the policy', (tester) async {
      await pump(tester);
      await selectType(tester, 'Earned Leave');
      await showSection(tester);
      await tester.tap(find.byKey(const Key('credit-schedule-monthly')));
      await tester.pumpAndSettle();
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('monthly-carry-forward'))).value, isTrue);
      expect(server.puts, isEmpty); // nothing until Save
      await save(tester);
      expect(server.puts.single.path, '${ApiConstants.leaveTypes}earned/');
      final body = server.puts.single.body;
      expect(body['credit_schedule'], 'monthly');
      expect(body['monthly_carry_forward'], true);
      expect(body['annual_days'], 12.0); // the rest of the policy goes with it, unchanged
      expect(body.containsKey('monthly_rules_from'), isFalse); // server-set only
      expect(find.text('Leave policy updated.'), findsOneWidget);
      await showSection(tester);
      expect(rulesFromText(tester), endsWith('Current rules apply from 1 Dec 2026.')); // from the saved response
    });

    testWidgets('toggling carry forward off is sent; back to Annual hides it', (tester) async {
      await pump(tester);
      await selectType(tester, 'Earned Leave');
      await showSection(tester);
      await tester.tap(find.byKey(const Key('credit-schedule-monthly')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('monthly-carry-forward')));
      await tester.pumpAndSettle();
      await save(tester);
      expect(server.puts.single.body['monthly_carry_forward'], false);
      await showSection(tester);
      await tester.tap(find.byKey(const Key('credit-schedule-annual')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('monthly-carry-forward')), findsNothing);
    });

    testWidgets('a refusal shows the server message and keeps the chosen values', (tester) async {
      await pump(tester);
      await selectType(tester, 'Earned Leave');
      await showSection(tester);
      await tester.tap(find.byKey(const Key('credit-schedule-monthly')));
      await tester.pumpAndSettle();
      server.refuseNext = (status: 403, message: 'Permission denied.');
      await save(tester);
      expect(find.text('Permission denied.'), findsOneWidget);
      expect(find.text('Leave policy updated.'), findsNothing);
      await showSection(tester);
      expect(selected(tester, 'monthly'), isTrue);
      expect(find.byKey(const Key('monthly-carry-forward')), findsOneWidget);
    });

    testWidgets('Discard restores the saved values', (tester) async {
      await pump(tester);
      await showSection(tester);
      await tester.tap(find.byKey(const Key('credit-schedule-annual')));
      await tester.pumpAndSettle();
      final discard = find.text('Discard');
      await tester.ensureVisible(discard);
      await tester.tap(discard);
      await tester.pumpAndSettle();
      await showSection(tester);
      expect(selected(tester, 'monthly'), isTrue);
    });

    testWidgets('Save can\'t be sent twice; the section is locked while saving', (tester) async {
      await pump(tester);
      await showSection(tester);
      server.hold = Completer();
      final b = find.widgetWithText(FilledButton, 'Save Policy');
      await tester.ensureVisible(b);
      await tester.tap(b);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 50));
      expect(tester.widget<SwitchListTile>(find.byKey(const Key('monthly-carry-forward'))).onChanged, isNull);
      server.hold!.complete();
      await tester.pumpAndSettle();
      expect(server.puts, hasLength(1));
      expect(server.puts.single.body['credit_schedule'], 'monthly');
      expect(server.puts.single.body['monthly_carry_forward'], false);
    });

    testWidgets('a Settings viewer without leave.approve still sees the section, as on web (the server decides)',
        (tester) async {
      await pump(tester, perms: ['settings.view']);
      await showSection(tester);
      expect(find.text('Monthly Credit Settings'), findsOneWidget);
      expect(find.text('Monthly Leave Management'), findsNothing); // Task 10's tab stays gated
    });
  });
}

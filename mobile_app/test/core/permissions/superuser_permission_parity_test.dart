import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/facial_recognition/presentation/screens/face_id_registrations_screen.dart';
import 'package:mobile_app/features/referrals/presentation/providers/referral_providers.dart';
import 'package:mobile_app/features/referrals/presentation/screens/referrals_screen.dart';
import 'package:mobile_app/features/separation/presentation/screens/separation_detail_screen.dart';
import 'package:mobile_app/features/separation/presentation/screens/separation_screen.dart';
import 'package:mobile_app/features/settings/presentation/approval_rules/approval_rules_screen.dart';
import 'package:mobile_app/features/settings/presentation/assessment_config/assessment_config_screen.dart';
import 'package:mobile_app/features/settings/presentation/attendance_rules/attendance_rules_screen.dart';
import 'package:mobile_app/features/settings/presentation/notification_settings/notification_settings_screen.dart';
import 'package:mobile_app/features/settings/presentation/onboarding_fields/onboarding_fields_screen.dart';
import 'package:mobile_app/features/settings/presentation/referral_rules/referral_rules_settings_screen.dart';

// Task 71f (audit findings L3, L4).
// L3 — plain permission-list checks ignored the superuser flag. Web uses
// usePermission / useAnyPermission (superuser flag or the codename) and the
// backend's has_perm / HasSettingsPermission pass a superuser and
// settings.edit, so these now use userHasPermission:
//   Referrals "All" tab (recruitment.view), Assessment Config edit
//   (assessments.edit), Attendance Rules / Approval Rules / Notifications /
//   Onboarding Fields edit (settings.edit), Separation approver checks
//   (separation.approve | settings.edit; employees.view | settings.edit),
//   Face ID Registrations (facial_recognition.approve).
// L4 — Referral Rules: backend GET needs settings.view, POST / PATCH /
// DELETE need settings.edit. settings.view alone is now read-only.
// Synthetic users and data; a stand-in server records every request.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object data) => _json(200, {'status': 'success', 'message': 'ok', 'data': data});
Map<String, dynamic> page(List<Object> rows) =>
    {'count': rows.length, 'page': 1, 'page_size': 20, 'total_pages': 1, 'results': rows};

Map<String, dynamic> rule(int id, String title, {int order = 1}) =>
    {'id': id, 'icon': 'ti-info-circle', 'title': title, 'body': 'Rule body $id', 'order': order, 'is_active': true};

Map<String, dynamic> separation(String id, {bool own = false}) => {
      'id': id,
      'request_ref': 'SEP-$id',
      'separation_type': 'resignation',
      'separation_type_display': 'Resignation',
      'reason': 'better_opportunity',
      'reason_display': 'Better opportunity',
      'request_date': '2026-11-01',
      'proposed_last_working_day': '2026-12-01',
      'notice_period_days': 30,
      'comments': '',
      'status': 'approved',
      'status_display': 'Approved',
      'employee_name': 'Test Leaver',
      'employee_code': 'EMP-T5',
      'employee_department': 'QA',
      'employee_designation': 'Tester',
      'reporting_manager': null,
      'document_url': null,
      'created_by_name': 'Test Leaver',
      'approval_stages': <Object>[],
      'can_approve': false,
      'can_cancel': false,
      'can_edit': false,
      'can_delete': false,
      'is_own': own,
      'created_at': '2026-11-01T09:00:00Z',
      'assigned_notice_period_days': 30,
      'expected_last_working_day': '2026-12-01',
    };

class Server implements HttpClientAdapter {
  final calls = <(String, String, Object?)>[];
  String? refuse;

  Iterable<(String, String, Object?)> get writes => calls.where((c) => c.$1 != 'GET');

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((o.method, o.path, o.data));
    if (o.method != 'GET') {
      if (refuse != null) return _json(403, {'status': 'error', 'message': refuse, 'data': {}});
      if (o.path.startsWith('/recruitment/referral-rules/')) {
        final body = o.data is Map ? Map<String, dynamic>.from(o.data as Map) : <String, dynamic>{};
        final id = int.tryParse(o.path.split('/').where((p) => p.isNotEmpty).last) ?? 9;
        return _ok({...rule(id, 'x'), ...body, 'id': id});
      }
      return _ok(o.data is Map ? o.data as Object : <String, dynamic>{});
    }
    switch (o.path) {
      case '/assessments/settings/':
        return _ok({'default_pass_percentage': 70, 'max_attempts': 3, 'time_limit_mins': 30});
      case '/settings/approval-rules/':
        return _ok([
          {
            'workflow_type': 'leave',
            'workflow_label': 'Leave',
            'l1_approver_role': 1,
            'l1_approver_label': 'Manager',
            'l2_approver_role': null,
            'l2_approver_label': '',
          }
        ]);
      case '/notifications/settings/':
        return _ok(<String, dynamic>{});
      case '/settings/onboarding-fields/':
      case '/settings/document-types/':
        return _ok(<Object>[]);
      case '/recruitment/referral-rules/':
        return _ok([rule(1, 'Eligibility'), rule(2, 'Bonus timing', order: 2)]);
      case '/recruitment/referrals/':
      case '/recruitment/referrals/all/':
      case '/separation/requests/':
        return _ok(page(const []));
      case '/separation/requests/S1/':
        return _ok(separation('S1'));
    }
    if (o.path.startsWith('/separation/requests/S1/')) return _ok(<Object>[]);
    if (o.path.startsWith('/attendance/face-registration/')) return _ok(<Object>[]);
    return _ok(<String, dynamic>{});
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

class TestAuth extends AuthNotifier {
  TestAuth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user(List<String> perms, {bool superuser = false, List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'r',
      roleDisplay: 'Role',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

// The permission patterns the brief lists.
final superuserOnly = user(const [], superuser: true); // 1
final settingsAdmin = user(['settings.view', 'settings.edit'], superuser: true); // 2 (login sets the flag)
final settingsViewOnly = user(['settings.view']); // 4
final employee = user(['leave.view', 'leave.create', 'attendance.view', 'attendance.create']); // 5
final unrelated = user(['expenses.view', 'expenses.approve']); // 6
final olderSettingsAdmin = user(['settings.view', 'settings.edit']); // 7 (no flag)

late Server server;

Future<void> pumpScreen(WidgetTester tester, UserEntity u, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => TestAuth(u)),
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
                ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : screen,
          ),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

/// One screen's permission flag, checked through its visible control.
class Case {
  const Case(this.name, this.screen, this.exact, this.control);
  final String name;
  final Widget Function() screen;
  final UserEntity exact; // holds exactly the required codename(s), no flag
  final Finder Function() control; // present only when the flag is on
}

final cases = <Case>[
  Case('Referrals "All Referrals" tab', () => const ReferralsScreen(), user(['recruitment.view']),
      () => find.text('All Referrals')),
  Case('Assessment Config edit', () => const AssessmentConfigScreen(), user(['assessments.view', 'assessments.edit']),
      () => find.byIcon(Icons.edit_outlined)),
  Case('Attendance Rules save', () => const AttendanceRulesScreen(), olderSettingsAdmin,
      () => find.widgetWithText(TextButton, 'Save')),
  Case('Approval Rules edit', () => const ApprovalRulesScreen(), olderSettingsAdmin,
      () => find.byIcon(Icons.edit_outlined)),
  Case('Notification Settings edit', () => const NotificationSettingsScreen(), olderSettingsAdmin,
      () => find.widgetWithText(FilledButton, 'Save Changes')),
  Case('Onboarding Fields add', () => const OnboardingFieldsScreen(), olderSettingsAdmin,
      () => find.byType(FloatingActionButton)),
  Case('Separation "Team Requests" (approver)', () => const Scaffold(body: SeparationScreen()),
      user(['separation.approve']), () => find.text('Team Requests')),
  Case('Face ID Registrations', () => const Scaffold(body: FaceIdRegistrationsScreen()),
      user(['facial_recognition.approve']), () => find.text("You don't have permission to manage face ID registrations."),
  ),
  Case('Referral Rules add / edit / delete', () => const ReferralRulesSettingsScreen(), olderSettingsAdmin,
      () => find.byType(FloatingActionButton)),
];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('L3/L4 per-screen matrix', () {
    for (final c in cases) {
      final faceLock = c.name.startsWith('Face ID'); // control = the lock message (inverted)
      final allowed = <(String, UserEntity)>[
        ('explicit superuser, no codes', superuserOnly),
        ('settings.edit administrator', settingsAdmin),
        ('older settings.edit session, no flag', olderSettingsAdmin),
        ('exact permission', c.exact),
      ];
      final refused = <(String, UserEntity)>[
        if (!identical(c.exact, olderSettingsAdmin)) ('settings.view only', settingsViewOnly),
        ('ordinary employee', employee),
        ('unrelated permission', unrelated),
      ];
      for (final (label, u) in allowed) {
        testWidgets('${c.name}: $label → available', (tester) async {
          await pumpScreen(tester, u, c.screen());
          expect(c.control(), faceLock ? findsNothing : findsWidgets);
          expect(server.writes, isEmpty);
        });
      }
      for (final (label, u) in refused) {
        testWidgets('${c.name}: $label → not available', (tester) async {
          await pumpScreen(tester, u, c.screen());
          expect(c.control(), faceLock ? findsOneWidget : findsNothing);
          expect(server.writes, isEmpty);
        });
      }
    }

    // Settings-family screens need settings.edit: settings.view alone is
    // read-only (backend HasSettingsPermission / CanManageRoles).
    for (final c in cases.where((c) => identical(c.exact, olderSettingsAdmin))) {
      testWidgets('${c.name}: settings.view only → read-only', (tester) async {
        await pumpScreen(tester, settingsViewOnly, c.screen());
        expect(c.control(), findsNothing);
        expect(server.writes, isEmpty);
      });
    }
  });

  group('Face ID Registrations: data is fetched only when allowed', () {
    testWidgets('employee: no face-registration request', (tester) async {
      await pumpScreen(tester, employee, const Scaffold(body: FaceIdRegistrationsScreen()));
      expect(server.calls.where((c) => c.$2.startsWith('/attendance/face-registration/')), isEmpty);
    });
  });

  group('Separation detail: approver capability (handover tasks)', () {
    Future<void> pumpDetail(WidgetTester tester, UserEntity u) =>
        pumpScreen(tester, u, const SeparationDetailScreen(requestId: 'S1'));
    for (final (label, u) in [('superuser', superuserOnly), ('older settings.edit session', olderSettingsAdmin), ('separation.approve', user(['separation.approve']))]) {
      testWidgets('$label: may add handover tasks on another employee\'s request', (tester) async {
        await pumpDetail(tester, u);
        expect(find.byIcon(Icons.add_circle_outline), findsOneWidget);
      });
    }
    testWidgets('employee: no handover management', (tester) async {
      await pumpDetail(tester, employee);
      expect(find.byIcon(Icons.add_circle_outline), findsNothing);
      expect(server.writes, isEmpty);
    });
  });

  group('authorised requests keep their payloads; refusals are shown', () {
    testWidgets('Notification Settings: superuser saves the same PATCH body', (tester) async {
      await pumpScreen(tester, superuserOnly, const NotificationSettingsScreen());
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
      await tester.pumpAndSettle();
      final w = server.writes.single;
      expect((w.$1, w.$2), ('PATCH', '/notifications/settings/'));
      expect((w.$3 as Map)['is_leave_enabled'], false);
    });

    testWidgets('Referral Rules: superuser adds a rule with the same payload', (tester) async {
      await pumpScreen(tester, superuserOnly, const ReferralRulesSettingsScreen());
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'e.g. Eligibility'), 'Joining bonus');
      await tester.enterText(find.widgetWithText(TextField, 'Explain this rule clearly so employees understand it…'), 'Paid after 90 days.');
      await tester.tap(find.text('Save Rule'));
      await tester.pumpAndSettle();
      final w = server.writes.single;
      expect((w.$1, w.$2), ('POST', '/recruitment/referral-rules/'));
      expect(w.$3, {'icon': 'ti-info-circle', 'title': 'Joining bonus', 'body': 'Paid after 90 days.', 'order': 1, 'is_active': true});
    });

    testWidgets('Referral Rules: settings.edit admin edits and deletes (PATCH / DELETE)', (tester) async {
      await pumpScreen(tester, olderSettingsAdmin, const ReferralRulesSettingsScreen());
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Rule'));
      await tester.pumpAndSettle();
      expect((server.writes.last.$1, server.writes.last.$2), ('PATCH', '/recruitment/referral-rules/1/'));
      expect(server.writes.last.$3, {'icon': 'ti-info-circle', 'title': 'Eligibility', 'body': 'Rule body 1', 'order': 1, 'is_active': true});
      await tester.tap(find.byIcon(Icons.delete_outline).first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect((server.writes.last.$1, server.writes.last.$2), ('DELETE', '/recruitment/referral-rules/1/'));
    });

    testWidgets('Referral Rules: form validation unchanged (nothing sent)', (tester) async {
      await pumpScreen(tester, superuserOnly, const ReferralRulesSettingsScreen());
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Rule'));
      await tester.pumpAndSettle();
      expect(find.text('Title and description are required.'), findsOneWidget);
      expect(server.writes, isEmpty);
    });

    testWidgets('Referral Rules: backend refusal shown in the editor', (tester) async {
      await pumpScreen(tester, olderSettingsAdmin, const ReferralRulesSettingsScreen());
      server.refuse = 'You do not have permission to perform this action.';
      await tester.tap(find.byIcon(Icons.edit_outlined).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Rule'));
      await tester.pumpAndSettle();
      // Existing mapping (friendlyReferralError): a 403 reads as below.
      expect(find.text('You do not have permission to do this.'), findsOneWidget);
      expect(server.writes.single.$1, 'PATCH');
    });

    testWidgets('Referral Rules: settings.view viewer sees the rules read-only', (tester) async {
      await pumpScreen(tester, settingsViewOnly, const ReferralRulesSettingsScreen());
      expect(find.text('Eligibility'), findsOneWidget);
      expect(find.text('Bonus timing'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('Referral Rules: unauthorised create / edit / delete through the notifier send nothing', (tester) async {
      await pumpScreen(tester, settingsViewOnly, const ReferralRulesSettingsScreen());
      final container = ProviderScope.containerOf(tester.element(find.byType(ReferralRulesSettingsScreen)));
      final n = container.read(referralRulesAdminProvider.notifier);
      // Real async, so a missing guard surfaces as a recorded request.
      final results = await tester.runAsync(() async => [
            await n.create(icon: 'ti-info-circle', title: 't', body: 'b', order: 1, isActive: true),
            await n.edit(1, icon: 'ti-info-circle', title: 't', body: 'b', order: 1, isActive: true),
            await n.remove(1),
          ]);
      expect(server.writes, isEmpty);
      expect(results, List.filled(3, kReferralRulesNoPermission));
    });
  });

  group('rules, routes and modules', () {
    test('canManageReferralRules = backend has_perm(settings.edit)', () {
      expect(canManageReferralRules(superuserOnly), isTrue);
      expect(canManageReferralRules(settingsAdmin), isTrue);
      expect(canManageReferralRules(olderSettingsAdmin), isTrue);
      expect(canManageReferralRules(settingsViewOnly), isFalse);
      expect(canManageReferralRules(employee), isFalse);
      expect(canManageReferralRules(null), isFalse);
    });

    test('direct navigation: page routes unchanged (settings.view, recruitment / separation / face rules)', () {
      for (final p in [
        AppRoutes.settingsReferralRules,
        AppRoutes.settingsAssessmentConfig,
        AppRoutes.settingsAttendanceRules,
        AppRoutes.settingsApprovalRules,
        AppRoutes.settingsNotifications,
        AppRoutes.settingsOnboardingFields,
      ]) {
        expect(canAccessPath(settingsViewOnly, p), isTrue, reason: p);
        expect(canAccessPath(superuserOnly, p), isTrue, reason: p);
        expect(resolveAuthRedirect(authState: AuthState(user: employee), path: p), AppRoutes.dashboard, reason: p);
        expect(resolveAuthRedirect(authState: AuthState(user: unrelated), path: p), AppRoutes.dashboard, reason: p);
      }
      expect(canAccessPath(superuserOnly, AppRoutes.faceIdRegistrations), isTrue);
      expect(canAccessPath(employee, AppRoutes.faceIdRegistrations), isFalse);
      expect(canAccessPath(employee, AppRoutes.referrals), isTrue); // self-service, as on web
      expect(canAccessPath(employee, AppRoutes.separation), isTrue); // self-service, as on web
    });

    test('module off: screens refused even for a superuser', () {
      for (final (path, module) in [
        (AppRoutes.settingsReferralRules, 'recruitment'),
        (AppRoutes.referrals, 'recruitment'),
        (AppRoutes.settingsAssessmentConfig, 'assessments'),
        (AppRoutes.settingsAttendanceRules, 'attendance'),
        (AppRoutes.faceIdRegistrations, 'face_attendance'),
        (AppRoutes.separation, 'separation'),
      ]) {
        final off = user(const [], superuser: true, modules: const ['leave']);
        final on = user(const [], superuser: true, modules: [module]);
        expect(canAccessPath(off, path), isFalse, reason: path);
        expect(resolveAuthRedirect(authState: AuthState(user: off), path: path), AppRoutes.dashboard, reason: path);
        expect(canAccessPath(on, path), isTrue, reason: path);
      }
      // Core settings: not module-gated (web lib/modules.ts has no entry).
      final off = user(const [], superuser: true, modules: const []);
      expect(canAccessPath(off, AppRoutes.settingsApprovalRules), isTrue);
      expect(canAccessPath(off, AppRoutes.settingsNotifications), isTrue);
      expect(canAccessPath(off, AppRoutes.settingsOnboardingFields), isTrue);
    });
  });
}

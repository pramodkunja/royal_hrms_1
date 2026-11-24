import 'dart:convert';
import 'dart:typed_data';

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
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/leave_policy_screen.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/monthly_leave/monthly_leave_providers.dart';

import '../features/settings/monthly_leave_management_test.dart' as m;
import 'shot_harness.dart';

// Task 106 — render evidence for Leave Policy → Carry Forward and → Monthly
// Leave Management, through the app's route with the real header. Runs only
// with T1011_SHOTS=1 (T1011_OUT, T1011_PREFIX: `before_t106_` for the code as it
// was, `t106_` after). Real widgets, real Poppins.

ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

/// The monthly-leave stand-in plus the carry-forward endpoints.
class LpServer extends m.Server {
  int previewStatus = 200;
  String previewMessage = 'Server error.';
  int? runStatus;
  String runMessage = 'This period has already been executed.';
  int historyStatus = 200;
  int yearsStatus = 200;
  bool noYears = false;
  bool manyHistory = false;
  bool emptyHistory = false;
  bool emptyPreview = false;
  final cfBodies = <String, Object?>{};

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    final key = '${o.method} ${o.path}';
    if (key == 'GET ${ApiConstants.carryForwardYears}') {
      log.add(key);
      if (yearsStatus != 200) return _json({'status': 'error', 'message': 'Server error.'}, yearsStatus);
      return _json(m.ok({
        'years': noYears
            ? <Object>[]
            : [
                {'from_year': 2024, 'to_year': 2025},
                {'from_year': 2025, 'to_year': 2026},
              ],
        'default_from': 2025,
        'default_to': 2026,
      }));
    }
    if (key == 'GET ${ApiConstants.carryForwardHistory}') {
      log.add(key);
      bodies.putIfAbsent(key, () => []).add(Map.of(o.queryParameters));
      if (historyStatus != 200) return _json({'status': 'error', 'message': 'Server error.'}, historyStatus);
      final page = (o.queryParameters['page'] as int?) ?? 1;
      final rows = emptyHistory
          ? <Map<String, dynamic>>[]
          : [
              for (var i = 0; i < (manyHistory ? 20 : 3); i++)
                {
                  'id': 'h${page}_$i',
                  'from_year': 2025 - i,
                  'to_year': 2026 - i,
                  'executed_by_name': i == 1 ? 'Priyanka Venkataraghavan-Subramaniam' : 'Asha Test',
                  'total_processed': 1204 - i * 7,
                  'total_skipped': i * 3,
                  'total_failed': i == 2 ? 4 : 0,
                  'is_completed': i != 2,
                  'created_at': '2026-01-01T0${i + 1}:15:00+05:30',
                },
            ];
      return _json(m.ok({
        'count': manyHistory ? 45 : rows.length,
        'page': page,
        'page_size': 20,
        'total_pages': manyHistory ? 3 : 1,
        'results': rows,
      }));
    }
    if (key == 'POST ${ApiConstants.carryForwardPreview}') {
      log.add(key);
      cfBodies[key] = o.data;
      if (previewStatus != 200) return _json({'status': 'error', 'message': previewMessage}, previewStatus);
      final body = o.data as Map;
      return _json(m.ok({
        'from_year': body['from_year'],
        'to_year': body['to_year'],
        'total_rows': emptyPreview ? 0 : 4,
        'pending_count': emptyPreview ? 0 : 3,
        'already_processed_count': emptyPreview ? 0 : 1,
        'preview_rows': emptyPreview
            ? <Object>[]
            : [
                {
                  'employee_id': 'EMP-0042',
                  'employee_name': 'Anika Sharma',
                  'leave_type': 'cl',
                  'leave_type_display': 'Casual Leave',
                  'unused_days': 4.5,
                  'carry_forward_amount': 4.5,
                  'expiry_date': null,
                  'already_processed': false,
                },
                {
                  'employee_id': 'EMP-0057',
                  'employee_name': 'Venkatasubramanian Ramachandran Iyer-Krishnamurthy',
                  'leave_type': 'el',
                  'leave_type_display': 'Earned Leave (Privilege Leave, Accumulating)',
                  'unused_days': 18.5,
                  'carry_forward_amount': 10,
                  'expiry_date': '2026-06-30',
                  'already_processed': false,
                },
                {
                  'employee_id': 'EMP-0063',
                  'employee_name': 'Sneha Patel',
                  'leave_type': 'cl',
                  'leave_type_display': 'Casual Leave',
                  'unused_days': 2,
                  'carry_forward_amount': 2,
                  'expiry_date': null,
                  'already_processed': true,
                },
                {
                  'employee_id': 'EMP-0071',
                  'employee_name': 'Rohan Mehta',
                  'leave_type': 'sl',
                  'leave_type_display': 'Sick Leave',
                  'unused_days': 6,
                  'carry_forward_amount': 5,
                  'expiry_date': '2026-03-31',
                  'already_processed': false,
                },
              ],
      }));
    }
    if (key == 'POST ${ApiConstants.carryForwardRun}') {
      log.add(key);
      cfBodies[key] = o.data;
      final gate = holds[key];
      if (gate != null) await gate.future;
      if (runStatus != null) return _json({'status': 'error', 'message': runMessage}, runStatus!);
      return _json(m.ok({
        'id': 'new',
        'from_year': (o.data as Map)['from_year'],
        'to_year': (o.data as Map)['to_year'],
        'executed_by_name': 'Asha Test',
        'total_processed': 3,
        'total_skipped': 1,
        'total_failed': 0,
        'is_completed': true,
        'created_at': '2026-11-06T10:00:00+05:30',
      }));
    }
    return super.fetch(o, s, c);
  }
}

Map<String, dynamic> _richPlan() => m.plan([
      {
        ...m.planRow(1, 'EMP-0042', 'new'),
        'employee_name': 'Anika Sharma',
      },
      {
        ...m.planRow(2, 'EMP-0057', 'update', type: 'earned', previous: 1.0, delta: 0.5, credit: 1.5),
        'employee_name': 'Venkatasubramanian Ramachandran Iyer-Krishnamurthy',
        'leave_type_label': 'Earned Leave (Privilege Leave, Accumulating)',
        'message':
            'Raises the month’s credit from 1 to 1.5 day(s); the difference of 0.5 day(s) is added to the balance.',
      },
      {
        ...m.planRow(3, 'EMP-0063', 'error'),
        'employee_name': 'Sneha Patel',
        'message':
            'This employee’s used plus pending leave is more than the new balance would be, so the credit cannot be reduced.',
      },
      m.planRow(4, 'EMP-0071', 'unchanged', previous: 1.5, delta: 0.0),
    ]);

class _Storage extends SecureStorageService {
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

UserEntity lpUser([List<String> perms = const ['settings.view', 'leave.edit', 'leave.approve']]) => UserEntity(
      id: 'u1',
      email: 'admin@example.test',
      fullName: 'Admin',
      role: 'admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

/// The file the import picker hands back.
PickedFile? nextFile;

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> openLeavePolicy(WidgetTester t,
    {Size size = const Size(393, 2400),
    double scale = 1,
    LpServer? server,
    UserEntity? as,
    bool dark = false,
    double keyboard = 0,
    bool shots = true}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shots && shotsEnabled) await t.runAsync(loadShotFonts);
  m.server = server ?? LpServer();
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? lpUser())),
      dioProvider
          .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = m.server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
      monthlyLeaveClockProvider.overrideWithValue(() => m.today),
      monthlyImportFilePickerProvider.overrideWithValue(() async => nextFile),
    ],
    child: shotFrame(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      routerConfig: GoRouter(initialLocation: '/settings/leave-policy', routes: [
        GoRoute(
          path: '/settings/leave-policy',
          builder: (_, __) => Consumer(
            builder: (context, ref, _) =>
                ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : const LeavePolicyScreen(),
          ),
        ),
      ]),
    )),
  ));
  await _settle(t);
}

Future<void> openTabByLabel(WidgetTester t, String label) async {
  // The label also appears elsewhere on the first tab: target the tab itself.
  final tab = find.descendant(of: find.byType(Tab), matching: find.text(label)).first;
  await t.ensureVisible(tab); // the tab strip scrolls sideways
  await t.pump();
  await t.tap(tab);
  await _settle(t);
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f, warnIfMissed: false);
  await _settle(t);
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

Future<void> _cf(WidgetTester t,
    {Size size = const Size(393, 2200), double scale = 1, LpServer? server, UserEntity? as}) async {
  await openLeavePolicy(t, size: size, scale: scale, server: server, as: as);
  await openTabByLabel(t, 'Carry Forward');
}

Future<void> _ml(WidgetTester t, {Size size = const Size(393, 2400), double scale = 1, LpServer? server}) async {
  await openLeavePolicy(t, size: size, scale: scale, server: server);
  await openTabByLabel(t, 'Monthly Leave Management');
}

Future<void> _card(WidgetTester t, String key) async {
  final f = find.descendant(of: find.byKey(Key('monthly-card-$key')), matching: find.byType(InkWell)).first;
  await t.ensureVisible(f);
  await t.tap(f);
  await _settle(t);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // ── Carry Forward ──────────────────────────────────────────────────────────
  shot('cf_01_initial', (t) => _cf(t, size: const Size(393, 1500)));
  shot('cf_02_previewed', (t) async {
    await _cf(t, size: const Size(393, 3000));
    await tapKey(t, 'carry-forward-preview');
  });
  shot('cf_03_run_confirm', (t) async {
    await _cf(t, size: const Size(393, 1500));
    await tapKey(t, 'carry-forward-preview');
    await tapKey(t, 'carry-forward-run');
  });
  shot('cf_04_duplicate_warning', (t) async {
    await _cf(t, size: const Size(393, 3000), server: LpServer()..runStatus = 409);
    await tapKey(t, 'carry-forward-preview');
    await tapKey(t, 'carry-forward-run');
    await t.tap(find.text('Run Carry Forward').last);
    await _settle(t);
  });
  shot('cf_05_history_paged', (t) => _cf(t, size: const Size(393, 4200), server: LpServer()..manyHistory = true));
  shot('cf_06_history_empty', (t) => _cf(t, size: const Size(393, 1500), server: LpServer()..emptyHistory = true));
  shot('cf_07_preview_error', (t) async {
    await _cf(t, size: const Size(393, 1500), server: LpServer()..previewStatus = 500);
    await tapKey(t, 'carry-forward-preview');
  });
  shot('cf_08_no_years', (t) => _cf(t, size: const Size(393, 1200), server: LpServer()..noYears = true));
  shot('cf_09_years_error', (t) => _cf(t, size: const Size(393, 1200), server: LpServer()..yearsStatus = 500));
  shot('cf_10_320dp_2x', (t) async {
    await _cf(t, size: const Size(320, 6000), scale: 2, server: LpServer());
    await tapKey(t, 'carry-forward-preview');
  });
  shot('cf_11_tablet_1000', (t) async {
    await _cf(t, size: const Size(1000, 2200));
    await tapKey(t, 'carry-forward-preview');
  });
  shot('cf_12_dark', (t) async {
    await openLeavePolicy(t, size: const Size(393, 3000), dark: true);
    await openTabByLabel(t, 'Carry Forward');
    await tapKey(t, 'carry-forward-preview');
  });

  // ── Monthly Leave Management ───────────────────────────────────────────────
  shot('ml_01_initial', (t) => _ml(t, size: const Size(393, 1400)));
  shot('ml_02_import_open', (t) async {
    await _ml(t, size: const Size(393, 2600));
    await _card(t, 'import');
  });
  shot('ml_03_manual_open', (t) async {
    await _ml(t, size: const Size(393, 3600));
    await _card(t, 'manual');
  });
  shot('ml_04_manual_320dp_2x', (t) async {
    await _ml(t, size: const Size(320, 8000), scale: 2);
    await _card(t, 'manual');
  });
  shot('ml_05_import_320dp_2x', (t) async {
    await _ml(t, size: const Size(320, 6000), scale: 2);
    await _card(t, 'import');
  });
  shot('ml_06_assignments_320dp', (t) async {
    await _ml(t, size: const Size(320, 3600));
  });
  Future<void> manualReview(WidgetTester t, {required Size size, double scale = 1}) async {
    final server = LpServer()..nextPlan = _richPlan();
    await _ml(t, size: size, scale: scale, server: server);
    await _card(t, 'manual');
    await tapKey(t, 'manual-employee-EMP-7');
    await tapKey(t, 'manual-employee-EMP-9');
    await tapKey(t, 'manual-leave-type');
    await t.tap(find.text('Casual Leave').last);
    await _settle(t);
    await t.enterText(find.byKey(const Key('manual-credit')), '1.5');
    await _settle(t);
    await tapKey(t, 'manual-review');
  }

  shot('ml_08_manual_review', (t) => manualReview(t, size: const Size(393, 5200)));
  shot('ml_08b_manual_review_360', (t) => manualReview(t, size: const Size(360, 5200)));
  shot('ml_08c_manual_review_320dp_2x', (t) => manualReview(t, size: const Size(320, 12000), scale: 2));

  Future<void> importPreview(WidgetTester t, {required Size size, double scale = 1}) async {
    nextFile =
        (name: 'monthly_credits_november_2026_final_version.csv', bytes: Uint8List.fromList(utf8.encode('x')), size: 1);
    final server = LpServer()..nextPlan = _richPlan();
    await _ml(t, size: size, scale: scale, server: server);
    await _card(t, 'import');
    await tapKey(t, 'import-choose-file');
    await tapKey(t, 'import-preview');
  }

  shot('ml_09_import_preview', (t) => importPreview(t, size: const Size(393, 4200)));
  shot('ml_09b_import_preview_320dp_2x', (t) => importPreview(t, size: const Size(320, 11000), scale: 2));

  shot('ml_10_assignments_open', (t) async {
    await _ml(t, size: const Size(393, 2600));
    await _card(t, 'assignments');
  });
  shot('ml_10b_assignments_320dp_2x', (t) async {
    await _ml(t, size: const Size(320, 7000), scale: 2);
    await _card(t, 'assignments');
  });
  shot('ml_11_edit_sheet', (t) async {
    await _ml(t, size: const Size(393, 1400));
    await _card(t, 'assignments');
    await tapKey(t, 'assignment-edit-EMP-7-casual');
  });
  shot('ml_11b_edit_sheet_320dp_2x', (t) async {
    await _ml(t, size: const Size(320, 3000), scale: 2);
    await _card(t, 'assignments');
    await tapKey(t, 'assignment-edit-EMP-7-casual');
  });

  shot('ml_07_tablet_1000', (t) async {
    await _ml(t, size: const Size(1000, 3000));
    await _card(t, 'manual');
  });
}

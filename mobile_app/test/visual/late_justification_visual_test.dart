// Task 111 — Attendance → Late Justifications tab: render-evidence shots (T1011_SHOTS=1) with a
// stand-in API (synthetic data only; nothing leaves the test).
import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/late_justification_review.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

import 'shot_harness.dart';

const longReason =
    'The suburban train was stopped between two stations for almost forty minutes because of a signal failure, and the '
    'replacement bus I took afterwards was caught in a diversion near the flyover. I messaged my manager at 09:40 and '
    'again at 10:05 — attaching the railway notice for reference.';

Map<String, dynamic> row(String id,
        {String status = 'pending',
        String name = 'Asha Test',
        String reason = 'transport',
        String explanation = 'Bus broke down on the way',
        bool canAction = true,
        bool hasDocument = false,
        bool canViewDocument = false,
        String? l1Status,
        String l1Remarks = '',
        String? l2Status,
        String l2Remarks = '',
        String l2 = 'Hema HR',
        int resubmissions = 0,
        String date = '2026-11-10',
        String branch = 'North Wing'}) =>
    {
      'id': id,
      'kind': 'late_justification',
      'employee_id': 'EMP-0$id',
      'name': name,
      'department': 'Ops',
      'branch': branch,
      'date': date,
      'punch_type': '',
      'original_in': '10:05',
      'original_out': '18:30',
      'reason': reason,
      'reason_label': {'medical': 'Medical', 'transport': 'Transport', 'other': 'Other'}[reason],
      'explanation': explanation,
      'status': status,
      'can_action': canAction,
      'l1_approver_name': 'Kiran Manager',
      'l1_status': l1Status,
      'l1_remarks': l1Remarks,
      'l2_approver_name': l2,
      'l2_status': l2Status,
      'l2_remarks': l2Remarks,
      'created_at': '2026-11-10 11:00',
      'has_document': hasDocument,
      'can_view_document': canViewDocument,
      'document_name': hasDocument && canViewDocument ? 'doctor-note.pdf' : '',
      'proof_required': reason == 'medical',
      'missing_proof': !hasDocument,
      'resubmission_count': resubmissions,
      'attendance_status': 'Late',
    };

List<Map<String, dynamic>> allStatuses() => [
      row('1', explanation: longReason, canAction: true),
      row('2', status: 'l2_pending', name: 'Bina Test', canAction: false, l1Status: 'approved', date: '2026-11-09'),
      row('3',
          status: 'approved',
          name: 'Chetan Done',
          canAction: false,
          l1Status: 'approved',
          l2Status: 'approved',
          reason: 'medical',
          hasDocument: true,
          canViewDocument: true,
          date: '2026-11-06'),
      row('4',
          status: 'rejected',
          name: 'Devi Rejected',
          canAction: false,
          l1Status: 'approved',
          l2Status: 'rejected',
          l2Remarks: 'The railway notice shows a delay of 15 minutes, not 55.',
          date: '2026-11-05'),
      row('5',
          status: 'resubmit',
          name: 'Esha Again',
          canAction: false,
          l1Status: 'resubmit',
          l1Remarks: "Upload the doctor's note, not the pharmacy bill",
          resubmissions: 1,
          reason: 'medical',
          hasDocument: true,
          date: '2026-11-04'),
      row('6', name: 'Farah Medical', reason: 'medical', date: '2026-11-03'),
    ];

class Server implements HttpClientAdapter {
  Server(this.rows);
  List<Map<String, dynamic>> rows;
  int status = 200;
  ResponseBody _json(int s, Object b) => ResponseBody.fromString(jsonEncode(b), s, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (o.path == '/attendance/corrections/' && o.method == 'GET') {
      if (status != 200) return _json(status, {'status': 'error', 'message': 'Server error.'});
      return _json(200, {
        'status': 'success',
        'message': 'ok',
        'data': {'count': rows.length, 'results': rows}
      });
    }
    return _json(200, {'status': 'success', 'message': 'ok', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

class _Storage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
          user: UserEntity(
        id: 'mgr-1',
        email: 'm@example.test',
        fullName: 'Kiran Manager',
        role: 'manager',
        roleDisplay: 'Manager',
        mustChangePassword: false,
        permissions: ['attendance.view', 'attendance.create'],
        onboardingStatus: 'complete',
        assessmentStatus: 'complete',
      ));
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> open(WidgetTester t,
    {Size size = const Size(393, 852),
    double scale = 1,
    bool dark = false,
    Server? server,
    String filter = 'all'}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shotsEnabled) await t.runAsync(loadShotFonts);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth()),
      dioProvider.overrideWithValue(
          Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server ?? Server(allStatuses())),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: Consumer(
          builder: (_, ref, child) {
            ref.watch(authStateProvider);
            return child!;
          },
          child: Scaffold(backgroundColor: AppColors.background, body: const LateJustificationsReviewTab())),
    )),
  ));
  await settle(t);
  if (filter != 'pending') {
    await t.tap(find.byKey(Key('late-filter-$filter')));
    await settle(t);
  }
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f, warnIfMissed: false);
  await settle(t);
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  shot('01_populated_all', (t) => open(t, size: const Size(393, 2300)));
  shot('02_review_approve', (t) async {
    await open(t, size: const Size(393, 852));
    await tapKey(t, 'late-review-open-1');
    await tapKey(t, 'late-review-approve');
  });
  shot('03_review_reject', (t) async {
    await open(t, size: const Size(393, 852));
    await tapKey(t, 'late-review-open-1');
    await tapKey(t, 'late-review-reject');
    await t.enterText(find.byKey(const Key('late-review-remarks')), 'The railway notice shows a shorter delay.');
    await settle(t);
  });
  shot('04_review_decided_trail', (t) async {
    await open(t, size: const Size(393, 852));
    await tapKey(t, 'late-review-open-4');
  });
  shot('05_320_2x', (t) => open(t, size: const Size(320, 3600), scale: 2));
  shot('06_320_1x', (t) => open(t, size: const Size(320, 2600)));
  shot('07_tablet_1000', (t) => open(t, size: const Size(1000, 1500)));
  shot('08_dark', (t) => open(t, size: const Size(393, 2300), dark: true));
  shot('09_dark_review', (t) async {
    await open(t, size: const Size(393, 852), dark: true);
    await tapKey(t, 'late-review-open-4');
  });
  shot('10_empty_all', (t) => open(t, size: const Size(393, 700), server: Server([])));
  shot('11_no_match_rejected', (t) => open(t, size: const Size(393, 700), server: Server([]), filter: 'rejected'));
  shot('12_error', (t) => open(t, size: const Size(393, 700), server: Server([])..status = 500));
  shot('13_pending_default', (t) => open(t, size: const Size(393, 1500), filter: 'pending'));
}

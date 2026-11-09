import 'dart:async';
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
import 'package:mobile_app/features/attendance/data/models/attendance_models.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/record_corrections_section.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// P1-1: HR approves / rejects attendance corrections from the record detail,
// as web AttendanceDetailDrawer → PATCH /attendance/corrections/<id>/review/
// {action: approve|reject} on production HRCorrectionReviewView
// (CorrectionReviewSerializer: action + optional blank remarks; attendance.create;
// stage approver enforced server-side, 403 otherwise). Buttons only on
// `pending` rows for attendance.create. Synthetic data, mocked Dio only.

const empId = 'TST001';
const day = '2026-11-05';
const recordId = '6f1c2a3b-0000-4000-8000-000000000001';
const detailKey = (id: recordId, isEmployeeId: false);

Map<String, dynamic> corr(String id, String status, {String emp = empId, String date = day, String? reviewedBy}) => {
      'id': id,
      'employee_id': emp,
      'name': 'Test Person',
      'department': 'Ops',
      'branch': 'North',
      'date': date,
      'punch_type': 'OUT',
      'requested_in': null,
      'requested_out': '18:30',
      'reason': 'Forgot to punch out',
      'status': status,
      'can_action': true,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedBy == null ? null : '2026-11-06 10:00',
      'created_at': '2026-11-05T19:00:00Z',
    };

class Server implements HttpClientAdapter {
  Server() {
    rows = [
      corr('c1', 'pending'),
      corr('c2', 'approved', reviewedBy: 'Test HR'),
      corr('c3', 'l2_pending'),
      corr('c9', 'pending', emp: 'TST999'), // other employee — filtered out
      corr('c8', 'pending', date: '2026-11-04'), // other day — filtered out
    ];
  }

  late List<Map<String, dynamic>> rows;
  final calls = <({String method, String path, Object? body})>[];
  Completer<void>? holdReview;
  int reviewStatus = 200;
  String reviewError = 'You are not the designated approver for this stage.';
  String approveMessage = 'Correction approved. Attendance record updated.';

  int gets(String path) => calls.where((c) => c.method == 'GET' && c.path == path).length;
  List<({String method, String path, Object? body})> get reviews => calls.where((c) => c.method == 'PATCH').toList();

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    if (o.method == 'PATCH' && o.path.startsWith('/attendance/corrections/') && o.path.endsWith('/review/')) {
      final gate = holdReview;
      if (gate != null) await gate.future;
      if (reviewStatus != 200) return _json({'status': 'error', 'message': reviewError, 'data': {}}, reviewStatus);
      final id = o.path.split('/')[3];
      final action = (o.data as Map)['action'];
      rows = [
        for (final r in rows)
          if (r['id'] == id) {...r, 'status': action == 'approve' ? 'approved' : 'rejected', 'reviewed_by': 'Test HR'} else r
      ];
      return _json({
        'status': 'success',
        'message': action == 'approve' ? approveMessage : 'Correction rejected.',
        'data': {'status': action == 'approve' ? 'approved' : 'rejected'}
      });
    }
    if (o.path == ApiConstants.attendanceHrCorrections) {
      return _json({
        'status': 'success',
        'data': {'count': rows.length, 'results': rows}
      });
    }
    if (o.path == ApiConstants.attendanceRecordDetail(recordId)) {
      return _json({
        'status': 'success',
        'data': {'id': recordId, 'employee_id': empId, 'date': day, 'status': 'present', 'punches': []}
      });
    }
    if (o.path == ApiConstants.attendanceRecordAudit(recordId)) {
      return _json({'status': 'success', 'data': []});
    }
    return _json({
      'status': 'success',
      'data': {'results': [], 'count': 0}
    });
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
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final hr = user(['attendance.view', 'attendance.create']);
final viewer = user(['attendance.view', 'attendance.export']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

/// The section inside a host that also shows the record detail and audit
/// trail, as the detail dialog does — so their reloads are observable.
Future<void> pump(WidgetTester tester, {UserEntity? as}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? hr),
    child: MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: Consumer(builder: (context, ref, _) {
            ref.watch(attendanceRecordDetailProvider(detailKey));
            ref.watch(attendanceRecordAuditProvider(recordId));
            return const RecordCorrectionsSection(
                employeeId: empId, date: day, detailKey: detailKey, recordId: recordId);
          }),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

bool enabled(WidgetTester tester, String key) => tester.widget<OutlinedButton>(byKey(key)).onPressed != null;

String status(WidgetTester tester, String id) => tester.widget<Text>(byKey('record-correction-status-$id')).data!;

String? message(WidgetTester tester) {
  final f = byKey('record-correction-review-message');
  return f.evaluate().isEmpty ? null : tester.widget<Text>(f).data;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('visibility (web: status == pending && attendance.create)', () {
    testWidgets('only this employee/day is listed; only the pending row has actions; reviewed rows say who',
        (tester) async {
      await pump(tester);
      expect(byKey('record-correction-c1'), findsOneWidget);
      expect(byKey('record-correction-c2'), findsOneWidget);
      expect(byKey('record-correction-c3'), findsOneWidget);
      expect(byKey('record-correction-c9'), findsNothing);
      expect(byKey('record-correction-c8'), findsNothing);
      expect(byKey('record-correction-approve-c1'), findsOneWidget);
      expect(byKey('record-correction-reject-c1'), findsOneWidget);
      expect(byKey('record-correction-approve-c2'), findsNothing, reason: 'approved');
      expect(byKey('record-correction-approve-c3'), findsNothing, reason: 'l2_pending: web shows no actions');
      expect(find.text('Reviewed by Test HR on 2026-11-06 10:00'), findsOneWidget);
      expect(find.text('Clock Out'), findsNWidgets(3));
      expect(find.text('Requested In: — · Requested Out: 18:30'), findsNWidgets(3));
    });

    testWidgets('without attendance.create there are no Approve/Reject buttons', (tester) async {
      await pump(tester, as: viewer);
      expect(byKey('record-correction-c1'), findsOneWidget);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    test('the action itself refuses without attendance.create, before any request', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(viewer));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      await expectLater(
        c.read(attendanceCorrectionReviewProvider).review('c1',
            approve: true, correctionsKey: (employeeId: empId, date: day)),
        throwsA(kCorrectionReviewDenied),
      );
      expect(server.calls, isEmpty);
    });

    test('canReviewRecordCorrection: settings.edit (admin) passes, other statuses never do', () {
      final admin = user(['settings.edit']);
      final rows = Server().rows;
      final pending = HrCorrectionRowModel.fromJson(rows[0]);
      final approved = HrCorrectionRowModel.fromJson(rows[1]);
      final l2 = HrCorrectionRowModel.fromJson(rows[2]);
      expect(canReviewRecordCorrection(admin, pending), isTrue);
      expect(canReviewRecordCorrection(hr, pending), isTrue);
      expect(canReviewRecordCorrection(viewer, pending), isFalse);
      expect(canReviewRecordCorrection(null, pending), isFalse);
      expect(canReviewRecordCorrection(hr, approved), isFalse);
      expect(canReviewRecordCorrection(hr, l2), isFalse);
    });
  });

  group('approve / reject', () {
    testWidgets('Approve sends {action: approve} to the review endpoint, shows the server message, '
        'and reloads corrections, the record and its audit trail', (tester) async {
      await pump(tester);
      final before = (
        corrections: server.gets(ApiConstants.attendanceHrCorrections),
        detail: server.gets(ApiConstants.attendanceRecordDetail(recordId)),
        audit: server.gets(ApiConstants.attendanceRecordAudit(recordId)),
      );
      await tester.tap(byKey('record-correction-approve-c1'));
      await tester.pumpAndSettle();
      final r = server.reviews.single;
      expect(r.path, ApiConstants.attendanceHrCorrectionReview('c1'));
      expect(r.path, '/attendance/corrections/c1/review/');
      expect(r.body, {'action': 'approve', 'remarks': ''});
      expect(message(tester), 'Correction approved. Attendance record updated.');
      expect(server.gets(ApiConstants.attendanceHrCorrections), greaterThan(before.corrections));
      expect(server.gets(ApiConstants.attendanceRecordDetail(recordId)), greaterThan(before.detail));
      expect(server.gets(ApiConstants.attendanceRecordAudit(recordId)), greaterThan(before.audit));
      expect(status(tester, 'c1'), 'approved');
      expect(byKey('record-correction-approve-c1'), findsNothing);
      expect(find.text('Reviewed by Test HR'), findsOneWidget);
    });

    testWidgets('an L1 approval that moves to HR shows the server\'s "Awaiting HR review" message', (tester) async {
      await pump(tester);
      server.approveMessage = 'Correction approved. Awaiting HR review.';
      await tester.tap(byKey('record-correction-approve-c1'));
      await tester.pumpAndSettle();
      expect(message(tester), 'Correction approved. Awaiting HR review.');
    });

    testWidgets('Reject sends {action: reject} and the row becomes rejected', (tester) async {
      await pump(tester);
      await tester.tap(byKey('record-correction-reject-c1'));
      await tester.pumpAndSettle();
      final r = server.reviews.single;
      expect(r.path, '/attendance/corrections/c1/review/');
      expect(r.body, {'action': 'reject', 'remarks': ''});
      expect(message(tester), 'Correction rejected.');
      expect(status(tester, 'c1'), 'rejected');
    });
  });

  group('loading, duplicates, failure', () {
    testWidgets('while a review runs both buttons are disabled; repeated taps send one request', (tester) async {
      await pump(tester);
      server.holdReview = Completer();
      await tester.tap(byKey('record-correction-approve-c1'));
      await tester.pump();
      expect(enabled(tester, 'record-correction-approve-c1'), isFalse);
      expect(enabled(tester, 'record-correction-reject-c1'), isFalse);
      expect(find.descendant(of: byKey('record-correction-approve-c1'), matching: find.byType(CircularProgressIndicator)),
          findsOneWidget);
      await tester.tap(byKey('record-correction-approve-c1'), warnIfMissed: false);
      await tester.tap(byKey('record-correction-reject-c1'), warnIfMissed: false);
      await tester.pump();
      server.holdReview!.complete();
      await tester.pumpAndSettle();
      expect(server.reviews, hasLength(1));
      expect(status(tester, 'c1'), 'approved');
    });

    test('the action refuses a second review of the same correction while one is in flight', () async {
      server = Server()..holdReview = Completer();
      final c = ProviderContainer(overrides: overrides(hr));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final action = c.read(attendanceCorrectionReviewProvider);
      const key = (employeeId: empId, date: day);
      final first = action.review('c1', approve: true, correctionsKey: key);
      await Future<void>.delayed(Duration.zero);
      expect(action.isReviewing('c1'), isTrue);
      await expectLater(action.review('c1', approve: false, correctionsKey: key), throwsA(kCorrectionReviewBusy));
      server.holdReview!.complete();
      expect(await first, 'Correction approved. Attendance record updated.');
      expect(action.isReviewing('c1'), isFalse);
      expect(server.reviews, hasLength(1));
    });

    testWidgets('a refused review shows the server error, leaves the row pending, reloads nothing; retry works',
        (tester) async {
      await pump(tester);
      server.reviewStatus = 403;
      final corrections = server.gets(ApiConstants.attendanceHrCorrections);
      final detail = server.gets(ApiConstants.attendanceRecordDetail(recordId));
      await tester.tap(byKey('record-correction-approve-c1'));
      await tester.pumpAndSettle();
      expect(message(tester), 'You are not the designated approver for this stage.');
      expect(status(tester, 'c1'), 'pending');
      expect(enabled(tester, 'record-correction-approve-c1'), isTrue);
      expect(server.gets(ApiConstants.attendanceHrCorrections), corrections);
      expect(server.gets(ApiConstants.attendanceRecordDetail(recordId)), detail);

      server.reviewStatus = 200;
      await tester.tap(byKey('record-correction-approve-c1'));
      await tester.pumpAndSettle();
      expect(server.reviews, hasLength(2));
      expect(status(tester, 'c1'), 'approved');
      expect(message(tester), 'Correction approved. Attendance record updated.');
    });

    testWidgets('a server error (500) is shown and the row keeps its actions', (tester) async {
      await pump(tester);
      server
        ..reviewStatus = 500
        ..reviewError = 'Something went wrong.';
      await tester.tap(byKey('record-correction-reject-c1'));
      await tester.pumpAndSettle();
      expect(message(tester), isNotNull);
      expect(status(tester, 'c1'), 'pending');
      expect(byKey('record-correction-reject-c1'), findsOneWidget);
    });
  });
}

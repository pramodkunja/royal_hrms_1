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
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_list.dart' show openApprovalItem;
import 'package:mobile_app/features/attendance/data/models/attendance_models.dart';
import 'package:mobile_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/hr_correction_card.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/late_justification_review.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/record_corrections_section.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_document_viewer_screen.dart';

import '../employees/employee_documents_view_test.dart' show MemStore, pngBytes;

// Task 65b: late-arrival justification, reviewer side — web attendance
// LateJustificationsTab / LateJustificationReviewModal and TeamApprovalsSection
// over backend attendance services_hr_corrections.py. The stand-in server
// applies the backend's rules: who may act at which stage (can_action), a
// reason required to reject or send back, L1 → L2 when an HR approver is set,
// 404 once decided, proof only for medical-proof viewers. Synthetic data only.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object data, [String message = 'ok']) =>
    _json(200, {'status': 'success', 'message': message, 'data': data});

Map<String, dynamic> late(String id,
        {String status = 'pending',
        String name = 'Asha Test',
        String reason = 'transport',
        bool canAction = true,
        bool hasDocument = false,
        bool canViewDocument = false,
        String? l2 = 'Hema HR',
        String? l1Status,
        String l1Remarks = '',
        int resubmissions = 0,
        String date = '2026-11-10'}) =>
    {
      'id': id,
      'kind': 'late_justification',
      'employee_id': 'EMP-0$id',
      'name': name,
      'department': 'Ops',
      'branch': 'North Wing',
      'date': date,
      'punch_type': '',
      'original_in': '10:05',
      'original_out': '18:30',
      'requested_in': null,
      'requested_out': null,
      'reason': reason,
      'reason_label': {'medical': 'Medical', 'transport': 'Transport', 'other': 'Other'}[reason],
      'explanation': 'Bus broke down on the way',
      'status': status,
      'can_action': canAction,
      'l1_approver_name': 'Kiran Manager',
      'l1_status': l1Status,
      'l1_remarks': l1Remarks,
      'l2_approver_name': l2,
      'l2_status': null,
      'l2_remarks': '',
      'created_at': '2026-11-10 11:00',
      'has_document': hasDocument,
      'can_view_document': canViewDocument,
      'document_name': hasDocument ? 'note.png' : '',
      'proof_required': reason == 'medical',
      'missing_proof': reason == 'medical' && !hasDocument,
      'resubmission_count': resubmissions,
      'attendance_status': 'Late',
    };

Map<String, dynamic> punch(String id, {bool canAction = true}) => {
      'id': id,
      'kind': 'punch',
      'employee_id': 'EMP-09',
      'name': 'Ravi Punch',
      'department': 'Ops',
      'branch': 'North Wing',
      'date': '2026-11-09',
      'punch_type': 'IN',
      'requested_in': '09:00',
      'requested_out': null,
      'reason': 'Forgot to punch',
      'status': 'pending',
      'can_action': canAction,
      'l1_remarks': '',
      'l2_remarks': '',
      'created_at': '2026-11-09 10:00',
    };

class Server implements HttpClientAdapter {
  Server(this.rows);
  final List<Map<String, dynamic>> rows;
  final lists = <Map<String, dynamic>>[];
  final patches = <(String, Map<String, dynamic>)>[];
  final docs = <String>[];
  int listStatus = 200;
  Completer<void>? holdReview;
  ({int status, String message})? refuseNext;

  Map<String, dynamic>? row(String id) => rows.where((r) => r['id'] == id).firstOrNull;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    final path = o.path;
    if (path == ApiConstants.attendanceHrCorrections && o.method == 'GET') {
      lists.add(Map.of(o.queryParameters));
      if (listStatus != 200) return _json(listStatus, {'status': 'error', 'message': 'Server error.'});
      final q = o.queryParameters;
      final shown = rows.where((r) {
        if (q['kind'] != null && r['kind'] != q['kind']) return false;
        if (q['status'] != null && r['status'] != q['status']) return false;
        if (q['missing_proof'] == 'true' && r['missing_proof'] != true) return false;
        if (q['employee_id'] != null && r['employee_id'] != q['employee_id']) return false;
        return true;
      }).toList();
      return _ok({'count': shown.length, 'results': shown});
    }
    final review = RegExp(r'^/attendance/corrections/([^/]+)/review/$').firstMatch(path);
    if (review != null && o.method == 'PATCH') {
      final id = review.group(1)!;
      final body = Map<String, dynamic>.from(o.data as Map);
      patches.add((id, body));
      if (holdReview != null) await holdReview!.future;
      final r0 = refuseNext;
      if (r0 != null) {
        refuseNext = null;
        return _json(r0.status, {'status': 'error', 'message': r0.message, 'data': {}});
      }
      final r = row(id);
      if (r == null || !(r['status'] == 'pending' || r['status'] == 'l2_pending')) {
        return _json(404, {'status': 'error', 'message': 'Correction not found or already reviewed.'});
      }
      if (r['can_action'] != true) {
        return _json(403, {'status': 'error', 'message': 'You are not the approver for this stage.'});
      }
      final action = body['action'];
      final remarks = '${body['remarks'] ?? ''}'.trim();
      if (r['kind'] == 'late_justification' && action != 'approve' && remarks.isEmpty) {
        return _json(400, {
          'status': 'error',
          'message': 'Please give a reason.',
          'data': {'remarks': 'A reason is required.'}
        });
      }
      String msg;
      if (action == 'approve') {
        if (r['status'] == 'pending' && r['l2_approver_name'] != null) {
          r['status'] = 'l2_pending';
          r['l1_status'] = 'approved';
          r['can_action'] = false;
          msg = 'Justification approved. Awaiting HR review.';
        } else {
          r['status'] = 'approved';
          r['can_action'] = false;
          msg = 'Justification approved. The day is now Late (Excused).';
        }
      } else if (action == 'resubmit') {
        r['status'] = 'resubmit';
        r['l1_status'] = 'resubmit';
        r['l1_remarks'] = remarks;
        r['can_action'] = false;
        msg = 'Sent back to the employee for resubmission.';
      } else {
        r['status'] = 'rejected';
        r['l1_status'] = 'rejected';
        r['l1_remarks'] = remarks;
        r['can_action'] = false;
        msg = r['kind'] == 'late_justification' ? 'Justification rejected.' : 'Correction rejected.';
      }
      return _ok(<String, dynamic>{}, msg);
    }
    final doc = RegExp(r'^/api/attendance/corrections/([^/]+)/document/$').firstMatch(o.uri.path);
    if (doc != null) {
      docs.add(doc.group(1)!);
      return ResponseBody.fromBytes(pngBytes, 200, headers: {
        Headers.contentTypeHeader: ['image/png']
      });
    }
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

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

const reviewer = UserEntity(
  id: 'mgr-1',
  email: 'm@example.test',
  fullName: 'Kiran Manager',
  role: 'manager',
  roleDisplay: 'Manager',
  mustChangePassword: false,
  permissions: ['attendance.view', 'attendance.create'],
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

late Server server;
late ProviderContainer container;
Finder byKey(String k) => find.byKey(Key(k));

Future<void> pumpHost(WidgetTester tester, Widget body, {List<Map<String, dynamic>>? rows}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server(rows ?? [late('l1'), late('l2', status: 'l2_pending', name: 'Bina Test'), punch('p1')]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(reviewer)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      profileDocumentTempStoreProvider.overrideWithValue(MemStore()),
    ],
    child: MaterialApp(
      home: Consumer(
          builder: (_, ref, child) {
            ref.watch(authStateProvider); // the signed-in user is loaded, as in the app
            return child!;
          },
          child: Scaffold(body: body)),
    ),
  ));
  await settle(tester);
  container = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await settle(tester);
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

/// The single decision sent: (id, body).
void expectPatch(String id, Map<String, dynamic> body) {
  expect(server.patches, hasLength(1));
  expect(server.patches.single.$1, id);
  expect(server.patches.single.$2, body);
}

/// Awaits [f] while letting the fake clock run (requests go through Dio).
Future<T> run<T>(WidgetTester tester, Future<T> f) async {
  T? out;
  var done = false;
  f.then((v) {
    out = v;
    done = true;
  });
  for (var i = 0; i < 40 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(done, isTrue, reason: 'did not complete');
  return out as T;
}

Finder rich(String t) => find.textContaining(t, findRichText: true);

HrCorrectionRowEntity entity(Map<String, dynamic> j) => HrCorrectionRowModel.fromJson(j);

/// Opens the review sheet straight from a button, as every entry point does.
Widget opener(HrCorrectionRowEntity row) => Builder(
      builder: (context) => Center(
        child: TextButton(
          key: const Key('open'),
          onPressed: () async {
            final msg = await showLateJustificationReview(context, row);
            if (msg != null && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('done: $msg')));
            }
          },
          child: const Text('open'),
        ),
      ),
    );

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('row model', () {
    test('late fields parsed; kind tells a late justification from a punch correction', () {
      final l = entity(late('l1', reason: 'medical', hasDocument: true, canViewDocument: true, resubmissions: 2));
      expect(l.isLateJustification, isTrue);
      expect(l.reasonLabel, 'Medical');
      expect(l.explanation, 'Bus broke down on the way');
      expect(l.originalIn, '10:05');
      expect(l.originalOut, '18:30');
      expect(l.hasDocument, isTrue);
      expect(l.canViewDocument, isTrue);
      expect(l.documentName, 'note.png');
      expect(l.proofRequired, isTrue);
      expect(l.resubmissionCount, 2);
      expect(l.attendanceStatus, 'Late');
      final p = entity(punch('p1'));
      expect(p.isLateJustification, isFalse);
      expect(p.hasDocument, isFalse);
      expect(p.resubmissionCount, 0);
      // An older server without "kind" → treated as a punch correction.
      expect(entity({...punch('p2')}..remove('kind')).isLateJustification, isFalse);
    });

    test('decision trail as web reviewTrail', () {
      final r = entity({
        ...late('l1', status: 'rejected', l1Status: 'approved'),
        'l2_status': 'rejected',
        'l2_remarks': 'No proof',
      });
      expect(lateReviewTrail(r), ['Manager (Kiran Manager) approved', 'HR (Hema HR) rejected: No proof']);
      final s = entity({...late('l3', status: 'resubmit', l1Status: 'resubmit', l1Remarks: 'Upload the note'), 'l1_approver_name': null});
      expect(lateReviewTrail(s), ['Manager asked to resubmit: Upload the note']);
      expect(lateReviewTrail(entity(late('l4'))), isEmpty);
    });
  });

  group('HR Attendance → Late Justifications', () {
    testWidgets('Pending by default (both stages, no status sent); web columns; Review vs View', (tester) async {
      await pumpHost(tester, const LateJustificationsReviewTab(), rows: [
        late('l1'),
        late('l2', status: 'l2_pending', name: 'Bina Test', canAction: false),
        late('l3', status: 'approved', name: 'Chetan Done', canAction: false),
        late('l4', reason: 'medical', name: 'Devi Med', hasDocument: true),
        punch('p1'),
      ]);
      expect(server.lists.single, {'kind': 'late_justification', 'page_size': 100});
      expect(find.text('Asha Test'), findsOneWidget);
      expect(find.text('Bina Test'), findsOneWidget);
      expect(find.text('Devi Med'), findsOneWidget);
      expect(find.text('Chetan Done'), findsNothing); // decided — not "Pending"
      expect(find.text('Ravi Punch'), findsNothing); // punch corrections never listed here
      expect(find.text('EMP-0l1 · North Wing'), findsOneWidget);
      expect(find.text('Proof: Missing'), findsNothing);
      expect(find.text('Proof: Attached (locked)'), findsOneWidget); // has proof, no medical access
      expect(find.text('Proof: None'), findsNWidgets(2));
      expect(tester.widget(byKey('late-review-open-l1')), isA<FilledButton>());
      expect(find.descendant(of: byKey('late-review-open-l1'), matching: find.text('Review')), findsOneWidget);
      expect(find.descendant(of: byKey('late-review-open-l2'), matching: find.text('View')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('filters send web\'s query; Missing Proof; empty text', (tester) async {
      await pumpHost(tester, const LateJustificationsReviewTab(), rows: [
        late('l1'),
        late('l3', status: 'approved', name: 'Chetan Done', canAction: false),
        late('l5', status: 'resubmit', name: 'Esha Again', canAction: false),
        late('l6', reason: 'medical', name: 'Farah Med'),
      ]);
      await tapKey(tester, 'late-filter-approved');
      expect(server.lists.last, {'kind': 'late_justification', 'status': 'approved', 'page_size': 100});
      expect(find.text('Chetan Done'), findsOneWidget);
      expect(find.text('Asha Test'), findsNothing);
      await tapKey(tester, 'late-filter-resubmit');
      expect(server.lists.last['status'], 'resubmit');
      expect(find.text('Esha Again'), findsOneWidget);
      await tapKey(tester, 'late-filter-missing');
      expect(server.lists.last, {'kind': 'late_justification', 'missing_proof': 'true', 'page_size': 100});
      expect(find.text('Farah Med'), findsOneWidget);
      expect(find.text('Proof: Missing'), findsOneWidget);
      await tapKey(tester, 'late-filter-all');
      expect(server.lists.last, {'kind': 'late_justification', 'page_size': 100});
      expect(find.text('Chetan Done'), findsOneWidget);
      await tapKey(tester, 'late-filter-rejected');
      expect(byKey('late-review-empty'), findsOneWidget);
      expect(find.text('No requests'), findsOneWidget);
      expect(find.text('Nothing matches this filter.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('load failure: message + Retry reloads', (tester) async {
      await pumpHost(tester, const LateJustificationsReviewTab());
      server.listStatus = 500;
      container.invalidate(lateJustificationQueueProvider);
      await settle(tester);
      expect(byKey('late-review-load-error'), findsOneWidget);
      expect(find.text('Asha Test'), findsNothing);
      server.listStatus = 200;
      final before = server.lists.length;
      await tapKey(tester, 'late-review-retry');
      expect(server.lists.length, before + 1);
      expect(find.text('Asha Test'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('L1 approve with HR next: note, confirm, web payload, server message as notice, queue reloads',
        (tester) async {
      await pumpHost(tester, const LateJustificationsReviewTab());
      await tapKey(tester, 'late-review-open-l1');
      expect(find.text('Late arrival justification'), findsOneWidget);
      expect(find.text('10:05 → 18:30'), findsOneWidget);
      expect(find.text('Bus broke down on the way'), findsWidgets);
      await tapKey(tester, 'late-review-approve');
      expect(find.text('Your approval sends this to HR. The day is excused only after the final approval.'),
          findsOneWidget);
      expect(server.patches, isEmpty); // a confirm step first
      final before = server.lists.length;
      await tapKey(tester, 'late-review-send');
      expectPatch('l1', {'action': 'approve', 'remarks': ''});
      expect(find.text('Late arrival justification'), findsNothing);
      expect(find.text('Justification approved. Awaiting HR review.'), findsOneWidget);
      expect(server.lists.length, greaterThan(before));
      // Still pending (HR stage) → still listed, now View only.
      expect(find.descendant(of: byKey('late-review-open-l1'), matching: find.text('View')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('final approval (no HR stage / at HR): the Late (Excused) note', (tester) async {
      await pumpHost(tester, opener(entity(late('l1', l2: null))), rows: [late('l1', l2: null)]);
      await tapKey(tester, 'open');
      await tapKey(tester, 'late-review-approve');
      expect(find.text("The day will show as Late (Excused) and won't count as a late mark. Punch times stay as recorded."),
          findsOneWidget);
      await tapKey(tester, 'late-review-send');
      expect(find.text('done: Justification approved. The day is now Late (Excused).'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('reject: a reason is required (nothing sent without it); then sent trimmed', (tester) async {
      await pumpHost(tester, opener(entity(late('l1'))));
      await tapKey(tester, 'open');
      await tapKey(tester, 'late-review-reject');
      expect(rich('Reason for rejecting'), findsOneWidget);
      expect(find.text('This is final; the day stays an ordinary late mark.'), findsOneWidget);
      await tapKey(tester, 'late-review-send');
      expect(find.text('Give a reason — it is shown to the employee.'), findsOneWidget);
      await tester.enterText(byKey('late-review-remarks'), '   ');
      await tapKey(tester, 'late-review-send');
      expect(server.patches, isEmpty);
      await tester.enterText(byKey('late-review-remarks'), '  Bus timings do not match  ');
      await tapKey(tester, 'late-review-send');
      expectPatch('l1', {'action': 'reject', 'remarks': 'Bus timings do not match'});
      expect(find.text('done: Justification rejected.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('ask to resubmit: web texts, reason required, action "resubmit"; Back clears the choice', (tester) async {
      await pumpHost(tester, opener(entity(late('l1'))));
      await tapKey(tester, 'open');
      await tapKey(tester, 'late-review-resubmit');
      expect(rich('What should the employee change?'), findsOneWidget);
      expect(find.text("e.g. Upload the doctor's note, not the pharmacy bill"), findsOneWidget);
      expect(find.text('The employee can update and resubmit within 3 days.'), findsOneWidget);
      await tapKey(tester, 'late-review-back');
      expect(byKey('late-review-remarks'), findsNothing);
      expect(byKey('late-review-approve'), findsOneWidget);
      await tapKey(tester, 'late-review-resubmit');
      await tester.enterText(byKey('late-review-remarks'), 'Upload the doctor note');
      await tapKey(tester, 'late-review-send');
      expectPatch('l1', {'action': 'resubmit', 'remarks': 'Upload the doctor note'});
      expect(find.text('done: Sent back to the employee for resubmission.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('not this user\'s stage / own request / out of scope (can_action false): view only, Close', (tester) async {
      await pumpHost(
          tester,
          opener(entity({
            ...late('l2', status: 'l2_pending', canAction: false, l1Status: 'approved', resubmissions: 1),
          })));
      await tapKey(tester, 'open');
      for (final k in ['late-review-approve', 'late-review-reject', 'late-review-resubmit', 'late-review-send']) {
        expect(byKey(k), findsNothing, reason: k);
      }
      expect(find.text('Manager (Kiran Manager) approved'), findsOneWidget);
      expect(find.text('Resubmissions'), findsOneWidget);
      await tapKey(tester, 'late-review-close');
      expect(find.text('Late arrival justification'), findsNothing);
      expect(server.patches, isEmpty);
      await unmount(tester);
    });

    testWidgets('refused (403 stage / 404 already decided): the server\'s message; the sheet stays', (tester) async {
      await pumpHost(tester, opener(entity(late('l1'))));
      await tapKey(tester, 'open');
      await tapKey(tester, 'late-review-approve');
      server.refuseNext = (status: 403, message: 'You are not the approver for this stage.');
      await tapKey(tester, 'late-review-send');
      expect(find.text('You are not the approver for this stage.'), findsOneWidget);
      expect(find.text('Late arrival justification'), findsOneWidget);
      server.refuseNext = (status: 404, message: 'Correction not found or already reviewed.');
      await tapKey(tester, 'late-review-send');
      expect(find.text('Correction not found or already reviewed.'), findsOneWidget);
      server.refuseNext = (status: 500, message: '');
      await tapKey(tester, 'late-review-send');
      expect(find.text('Could not save the decision.'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('one decision at a time: a second tap while saving sends nothing more', (tester) async {
      await pumpHost(tester, opener(entity(late('l1'))));
      await tapKey(tester, 'open');
      await tapKey(tester, 'late-review-approve');
      server.holdReview = Completer<void>();
      await tester.tap(byKey('late-review-send'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(byKey('late-review-send'), warnIfMissed: false);
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 20));
      }
      expect(server.patches, hasLength(1));
      server.holdReview!.complete();
      await settle(tester);
      expect(server.patches, hasLength(1));
      await unmount(tester);
    });

    testWidgets('medical proof: opens in the app through the API for an authorised viewer', (tester) async {
      await pumpHost(tester, opener(entity(late('l4', reason: 'medical', hasDocument: true, canViewDocument: true))));
      await tapKey(tester, 'open');
      expect(find.text('View note.png'), findsOneWidget);
      await tapKey(tester, 'late-review-proof');
      await settle(tester);
      expect(server.docs, ['l4']);
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('medical proof without access: locked text, nothing fetched; missing proof flagged', (tester) async {
      await pumpHost(tester, opener(entity(late('l4', reason: 'medical', hasDocument: true))));
      await tapKey(tester, 'open');
      expect(byKey('late-review-proof'), findsNothing);
      expect(find.text('Attached — visible to authorised HR only'), findsOneWidget);
      expect(server.docs, isEmpty);
      await unmount(tester);

      await pumpHost(tester, opener(entity(late('l6', reason: 'medical'))));
      await tapKey(tester, 'open');
      expect(find.text('Missing (required for medical)'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('corrections inbox: late rows are not punch corrections', () {
    testWidgets('HR card: late row opens the review (no punch Approve/Reject); punch row unchanged', (tester) async {
      final calls = <(String, bool)>[];
      await pumpHost(
          tester,
          ListView(children: [
            for (final j in [late('l1'), punch('p1')])
              HrCorrectionCard(
                record: entity(j),
                onReview: (approve) async {
                  calls.add((j['id'] as String, approve));
                  return null;
                },
              ),
          ]));
      expect(find.text('Late Arrival Justification'), findsOneWidget);
      expect(find.text('Punch Type'), findsOneWidget); // only the punch row
      expect(find.text('Approve'), findsOneWidget); // only the punch row
      expect(find.text('Reject'), findsOneWidget);
      await tapKey(tester, 'hr-correction-late-open-l1');
      expect(find.text('Late arrival justification'), findsOneWidget);
      await tapKey(tester, 'late-review-reject');
      await tester.enterText(byKey('late-review-remarks'), 'No proof of delay');
      await tapKey(tester, 'late-review-send');
      expectPatch('l1', {'action': 'reject', 'remarks': 'No proof of delay'});
      expect(calls, isEmpty); // the punch path was never used for the late row
      await tester.tap(find.text('Approve'));
      await settle(tester);
      expect(calls, [('p1', true)]);
      await unmount(tester);
    });

    testWidgets('the inbox provider refuses a late row on the punch path (no request)', (tester) async {
      await pumpHost(tester, const SizedBox());
      const f = (status: 'all', branch: null, department: null);
      final sub = container.listen(hrCorrectionsProvider(f), (_, __) {}); // kept alive, as on screen
      addTearDown(sub.close);
      await settle(tester);
      expect(sub.read().valueOrNull, hasLength(3));
      final n = container.read(hrCorrectionsProvider(f).notifier);
      expect(await run(tester, n.reviewCorrection('l1', approve: false)), kLateJustificationNeedsReview);
      expect(server.patches, isEmpty);
      expect(await run(tester, n.reviewCorrection('p1', approve: true)), isNull);
      expect(server.patches.single.$1, 'p1');
      await unmount(tester);
    });

    testWidgets('record detail: a late row says so and opens the review; punch row keeps its buttons', (tester) async {
      await pumpHost(tester, const SingleChildScrollView(child: RecordCorrectionsSection(employeeId: 'EMP-0l1', date: '2026-11-10')),
          rows: [late('l1'), {...punch('p1'), 'employee_id': 'EMP-0l1', 'date': '2026-11-10'}]);
      expect(find.text('Late Arrival Justification'), findsOneWidget);
      expect(byKey('record-correction-approve-l1'), findsNothing);
      expect(byKey('record-correction-approve-p1'), findsOneWidget);
      await tapKey(tester, 'record-correction-late-open-l1');
      await tapKey(tester, 'late-review-approve');
      await tapKey(tester, 'late-review-send');
      expectPatch('l1', {'action': 'approve', 'remarks': ''});
      expect(find.text('Justification approved. Awaiting HR review.'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Team Approvals', () {
    test('late rows: web labels; never bulk-selectable; punch rows unchanged', () {
      final l = UnifiedApprovalItem.fromCorrection(entity(late('l1', hasDocument: true)));
      expect(l.isLateJustification, isTrue);
      expect(l.primaryLine, 'Late Arrival Justification');
      expect(l.secondaryLine, 'Transport · proof attached · clocked in 10:05');
      expect(l.tertiaryLine, '2026-11-10');
      expect(l.selectable, isFalse);
      expect(UnifiedApprovalItem.fromCorrection(entity(late('l2'))).secondaryLine, 'Transport · clocked in 10:05');
      final p = UnifiedApprovalItem.fromCorrection(entity(punch('p1')));
      expect(p.isLateJustification, isFalse);
      expect(p.selectable, isTrue);
      expect(p.primaryLine, 'IN correction');
    });

    testWidgets('quick / bulk approve of a late row is refused without a request', (tester) async {
      await pumpHost(tester, const SizedBox());
      final item = UnifiedApprovalItem.fromCorrection(entity(late('l1')));
      final n = container.read(unifiedTeamApprovalsProvider.notifier);
      expect(await run(tester, n.approve(item)), kLateJustificationNeedsReview);
      expect(await run(tester, n.reject(item, remarks: 'x')), kLateJustificationNeedsReview);
      final bulk = await run(tester, n.bulkAction([item], approve: true));
      expect((bulk.succeeded, bulk.failed), (0, 1));
      expect(server.patches, isEmpty);
      await unmount(tester);
    });

    testWidgets('opening a late row shows the review; a decision is sent and the inbox reloads', (tester) async {
      final item = UnifiedApprovalItem.fromCorrection(entity(late('l1')));
      await pumpHost(
          tester,
          Consumer(
              builder: (context, ref, _) => Center(
                    child: TextButton(
                        key: const Key('open'), onPressed: () => openApprovalItem(context, ref, item), child: const Text('open')),
                  )));
      await tapKey(tester, 'open');
      expect(find.text('Late arrival justification'), findsOneWidget);
      await tapKey(tester, 'late-review-resubmit');
      await tester.enterText(byKey('late-review-remarks'), 'Attach the bus ticket');
      final before = server.lists.length;
      await tapKey(tester, 'late-review-send');
      expectPatch('l1', {'action': 'resubmit', 'remarks': 'Attach the bus ticket'});
      expect(server.lists.length, greaterThan(before)); // team inbox fetched again
      expect(find.text('Sent back to the employee for resubmission.'), findsOneWidget);
      await unmount(tester);
    });
  });
}

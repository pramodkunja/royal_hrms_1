import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/candidate_review/data/models/approval_model.dart';
import 'package:mobile_app/features/candidate_review/presentation/screens/candidate_review_screen.dart';
import 'package:mobile_app/features/candidate_review/presentation/widgets/approval_identity_fields.dart';

// Phase 11.2: Candidate Review — onboarding approval at web parity, against
// a stand-in for the production OnboardingApprovalView (GET returns
// submitted + rejected applications; POST {decision, remarks, department,
// designation, uan_number?, name_as_per_aadhar?, pan_number?,
// assessment_ids?} — department/designation required to approve; PAN format
// checked and a PAN already registered refused). Synthetic data only.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object? data) => _json(200, {'status': 'success', 'message': 'ok', 'data': data});
ResponseBody _fail(int status, String message) => _json(status, {'status': 'error', 'message': message, 'data': {}});

Map<String, dynamic> applicant(String id, String name,
        {String status = 'submitted', int? candidateId = 9, String? uan, String? pan, String? aadharName}) =>
    {
      'id': id,
      'full_name': name,
      'email': '$id@example.test',
      'phone': '9000000000',
      'department': 'Engineering',
      'designation': 'Engineer',
      'branch': 'Test Branch',
      'role_name': '',
      'role_display': '',
      'employee_id': '',
      'date_of_joining': null,
      'onboarding_status': status,
      'date_joined': '2026-11-01T10:00:00Z',
      'candidate_id': candidateId,
      'position_applied': 'Engineer',
      'profile': {
        'date_of_birth': '1995-01-01',
        'uan_number': uan,
        'pan_number': pan,
        'name_as_per_aadhar': aadharName,
        'esi_number': null,
      },
      'documents': [],
    };

class FakeApprovalsServer implements HttpClientAdapter {
  FakeApprovalsServer(this.rows);
  final List<Map<String, dynamic>> rows;
  final posts = <Map<String, dynamic>>[];
  int assessmentCalls = 0;
  bool canViewAssessments = true;
  List<Map<String, dynamic>> assessments = [
    {'id': 'a-11', 'title': 'Code of Conduct'},
    {'id': 'a-22', 'title': 'Safety Basics'},
  ];
  final takenPans = <String>{};
  Completer<void>? holdPost;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    final p = o.path;
    if (p == '/onboarding/approvals/' && o.method == 'GET') {
      return _ok({'count': rows.length, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': rows});
    }
    if (p == '/departments/') {
      return _ok({
        'results': [
          {'id': 1, 'name': 'Engineering'},
          {'id': 2, 'name': 'Operations'},
        ]
      });
    }
    if (p == '/designations/') {
      return _ok({
        'results': [
          {'id': 1, 'name': 'Engineer', 'department_name': 'Engineering'},
          {'id': 2, 'name': 'Analyst', 'department_name': 'Operations'},
        ]
      });
    }
    if (p == '/assessments/') {
      assessmentCalls++;
      if (!canViewAssessments) return _fail(403, 'You do not have permission to view assessments.');
      return _ok({'count': assessments.length, 'results': assessments});
    }
    final post = RegExp(r'^/onboarding/approvals/([^/]+)/$').firstMatch(p);
    if (post != null && o.method == 'POST') {
      final body = (o.data as Map).cast<String, dynamic>();
      posts.add(body);
      final gate = holdPost;
      if (gate != null) {
        holdPost = null;
        await gate.future;
      }
      if (body['decision'] == 'approve') {
        if ('${body['department'] ?? ''}'.isEmpty) return _fail(400, 'Department is required to approve onboarding.');
        final pan = '${body['pan_number'] ?? ''}';
        if (pan.isNotEmpty && !RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(pan)) {
          return _fail(400, 'Enter a valid PAN (e.g. ABCDE1234F) — 5 letters, 4 digits, 1 letter.');
        }
        if (takenPans.contains(pan)) {
          return _fail(400, 'This PAN is already registered to [Employee Name] ([Employee ID]).');
        }
      }
      return _ok({});
    }
    return _fail(404, 'Not found');
  }

  @override
  void close({bool force = false}) {}
}

late FakeApprovalsServer server;

/// An onboarding approver — the Review action needs web's canApprove
/// (employees.approve / onboarding.approve, or superuser).
class _Approver extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
      user: UserEntity(
          id: 'hr1',
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: ['recruitment.view', 'onboarding.approve'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

Future<void> pumpScreen(WidgetTester tester, List<Map<String, dynamic>> rows, {FakeApprovalsServer? s}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = s ?? FakeApprovalsServer(rows);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      authStateProvider.overrideWith(_Approver.new),
    ],
    child: MaterialApp(
      home: Consumer(builder: (_, ref, child) {
        ref.watch(authStateProvider); // loaded, as in the app
        return child!;
      }, child: const Scaffold(body: CandidateReviewScreen())),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> openReview(WidgetTester tester, String name) async {
  await tester.tap(find.text(name).first);
  await tester.pumpAndSettle();
  if (find.textContaining('Review —').evaluate().isEmpty) {
    await tester.tap(find.text('Review').first);
    await tester.pumpAndSettle();
  }
}

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await tester.pumpAndSettle();
}

Future<void> startApprove(WidgetTester tester) => tapText(tester, 'Approve & Activate ✓');
Future<void> confirm(WidgetTester tester) => tapText(tester, 'Confirm & Activate');

Future<void> enter(WidgetTester tester, String key, String text) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.enterText(find.byKey(Key(key)), text);
  await tester.pump();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model and status', () {
    test('parses UAN, PAN and Aadhaar name; missing values are null', () {
      final u = ApprovalUser.fromJson(
          applicant('u1', 'Test One', uan: '100000000012', pan: 'ABCDE1234F', aadharName: 'Test One'));
      expect((u.profile?.uanNumber, u.profile?.panNumber, u.profile?.nameAsPerAadhar),
          ('100000000012', 'ABCDE1234F', 'Test One'));
      final none = ApprovalUser.fromJson(applicant('u2', 'Test Two'));
      expect([none.profile?.uanNumber, none.profile?.panNumber, none.profile?.nameAsPerAadhar], [null, null, null]);
    });

    test('rejected is "Needs Revision"; other statuses keep their labels', () {
      expect(candidateStatusLabel('rejected'), 'Needs Revision');
      expect(candidateStatusLabel('submitted'), 'Submitted');
      expect(candidateStatusLabel('complete'), 'Approved');
      expect(candidateStatusLabel('on_hold'), 'On hold'); // unexpected: readable, not raw
      expect(candidateStatusLabel(''), 'Unknown');
    });

    test('masking and validation rules (web / backend)', () {
      expect(maskIdentifier('100000000012'), '••••0012');
      expect(maskIdentifier('ABCDE1234F'), '••••234F');
      expect(maskIdentifier(''), isNull);
      expect(maskIdentifier(null), isNull);
      expect(validateUan(''), isNull);
      expect(validateUan('100000000012'), isNull);
      expect(validateUan('12345'), 'UAN must be exactly 12 digits, or leave it blank.');
      expect(validateUan('12345678901A'), isNotNull);
      expect(validatePan(''), isNull);
      expect(validatePan('ABCDE1234F'), isNull);
      expect(validatePan('abcde1234f'), isNull); // upper-cased before sending
      expect(validatePan('ABCD1234F'), 'Enter a valid PAN (e.g. ABCDE1234F), or leave it blank.');
    });
  });

  group('list', () {
    testWidgets('rejected applications show as Needs Revision and are counted separately', (tester) async {
      await pumpScreen(tester, [
        applicant('u1', 'Test One'),
        applicant('u2', 'Test Two', status: 'rejected'),
        applicant('u3', 'Test Three', status: 'rejected'),
      ]);
      expect(find.text('Needs Revision'), findsWidgets); // stat label + 2 row chips
      expect(find.text('Submitted'), findsOneWidget);
      // Counts: total 3, pending 1, needs revision 2.
      final revisionCard = find.ancestor(of: find.text('Needs Revision').first, matching: find.byType(Column)).first;
      expect(find.descendant(of: revisionCard, matching: find.text('2')), findsOneWidget);
      final pendingCard = find.ancestor(of: find.text('Pending').first, matching: find.byType(Column)).first;
      expect(find.descendant(of: pendingCard, matching: find.text('1')), findsOneWidget);
    });
  });

  group('review sheet', () {
    testWidgets('identity is shown masked; Aadhaar name in full', (tester) async {
      await pumpScreen(
          tester, [applicant('u1', 'Test One', uan: '100000000012', pan: 'ABCDE1234F', aadharName: 'Test A One')]);
      await openReview(tester, 'Test One');
      expect(find.text('••••0012'), findsOneWidget);
      expect(find.text('••••234F'), findsOneWidget);
      expect(find.text('Test A One'), findsOneWidget);
      expect(find.text('100000000012'), findsNothing); // not in read-only view
      expect(find.text('ABCDE1234F'), findsNothing);
    });

    testWidgets('approve form: inputs prefilled from the profile', (tester) async {
      await pumpScreen(
          tester, [applicant('u1', 'Test One', uan: '100000000012', pan: 'abcde1234f', aadharName: 'Test A One')]);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      expect(tester.widget<TextField>(find.byKey(const Key('approval-uan'))).controller!.text, '100000000012');
      expect(tester.widget<TextField>(find.byKey(const Key('approval-pan'))).controller!.text, 'ABCDE1234F');
      expect(tester.widget<TextField>(find.byKey(const Key('approval-aadhar-name'))).controller!.text, 'Test A One');
    });

    testWidgets('approval sends department, designation, the extras and the assessment', (tester) async {
      await pumpScreen(tester, [applicant('u1', 'Test One')]);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      await enter(tester, 'approval-uan', '100000000012');
      await enter(tester, 'approval-aadhar-name', '  Test A One  ');
      await enter(tester, 'approval-pan', 'abcde1234f');
      await tester.tap(find.byKey(const Key('approval-assessment')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Safety Basics').last);
      await tester.pumpAndSettle();
      await confirm(tester);
      expect(server.posts.single, {
        'decision': 'approve',
        'remarks': '',
        'department': 'Engineering',
        'designation': 'Engineer',
        'uan_number': '100000000012',
        'name_as_per_aadhar': 'Test A One',
        'pan_number': 'ABCDE1234F',
        'assessment_ids': ['a-22'],
      });
      expect(find.text('Test One'), findsNothing); // removed from the list after success
    });

    testWidgets('blank optional fields and no assessment are left out', (tester) async {
      await pumpScreen(tester, [applicant('u1', 'Test One')]);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      await confirm(tester);
      expect(server.posts.single,
          {'decision': 'approve', 'remarks': '', 'department': 'Engineering', 'designation': 'Engineer'});
    });

    testWidgets('invalid UAN / PAN: one message at a time in the Assign Role banner (web order); nothing is sent',
        (tester) async {
      await pumpScreen(tester, [applicant('u1', 'Test One')]);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      await enter(tester, 'approval-uan', '12345');
      await enter(tester, 'approval-pan', 'ABC123');
      await confirm(tester);
      // Task 61 (web OnboardingDrawer handleConfirm): UAN is reported first.
      expect(find.text('UAN must be exactly 12 digits, or leave it blank.'), findsOneWidget);
      expect(find.text('Enter a valid PAN (e.g. ABCDE1234F), or leave it blank.'), findsNothing);
      expect(server.posts, isEmpty);
      await enter(tester, 'approval-uan', '100000000012');
      await confirm(tester);
      expect(find.text('UAN must be exactly 12 digits, or leave it blank.'), findsNothing);
      expect(find.text('Enter a valid PAN (e.g. ABCDE1234F), or leave it blank.'), findsOneWidget);
      expect(server.posts, isEmpty);
      // The UAN input only takes digits.
      await enter(tester, 'approval-uan', '12a34');
      expect(tester.widget<TextField>(find.byKey(const Key('approval-uan'))).controller!.text, '1234');
    });

    testWidgets('department and designation are still required', (tester) async {
      final row = applicant('u1', 'Test One')..['department'] = '';
      await pumpScreen(tester, [row..['designation'] = '']);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      await confirm(tester);
      expect(find.text('Please select both Department and Designation before confirming.'), findsOneWidget);
      expect(server.posts, isEmpty);
    });

    testWidgets('a server refusal is shown and everything entered stays', (tester) async {
      final s = FakeApprovalsServer([applicant('u1', 'Test One')])..takenPans.add('ABCDE1234F');
      await pumpScreen(tester, const [], s: s);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      await enter(tester, 'approval-uan', '100000000012');
      await enter(tester, 'approval-pan', 'ABCDE1234F');
      await tester.tap(find.byKey(const Key('approval-assessment')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Code of Conduct').last);
      await tester.pumpAndSettle();
      await confirm(tester);
      expect(find.text('This PAN is already registered to [Employee Name] ([Employee ID]).'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('approval-uan'))).controller!.text, '100000000012');
      expect(tester.widget<TextField>(find.byKey(const Key('approval-pan'))).controller!.text, 'ABCDE1234F');
      expect(find.text('Code of Conduct'), findsWidgets); // selection kept
      expect(find.text('Test One'), findsWidgets); // still in the list
    });

    testWidgets('repeat taps while approving send once', (tester) async {
      final s = FakeApprovalsServer([applicant('u1', 'Test One')])..holdPost = Completer<void>();
      final gate = s.holdPost!;
      await pumpScreen(tester, const [], s: s);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      await tester.ensureVisible(find.text('Confirm & Activate'));
      await tester.tap(find.text('Confirm & Activate'));
      await tester.pump();
      await tester.tap(find.byType(ElevatedButton).last, warnIfMissed: false);
      await tester.pump();
      gate.complete();
      await tester.pumpAndSettle();
      expect(server.posts, hasLength(1));
    });

    testWidgets('reject keeps its existing payload', (tester) async {
      await pumpScreen(tester, [applicant('u1', 'Test One', uan: '100000000012', pan: 'ABCDE1234F')]);
      await openReview(tester, 'Test One');
      await tester.enterText(find.byType(TextField).first, 'Please re-upload your PAN card');
      await tapText(tester, 'Send Back for\nCorrections');
      expect(server.posts.single, {'decision': 'reject', 'remarks': 'Please re-upload your PAN card'});
    });
  });

  group('assessment selection', () {
    testWidgets('loaded once; "No assessment" by default', (tester) async {
      await pumpScreen(tester, [applicant('u1', 'Test One')]);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      expect(find.text('No assessment'), findsOneWidget);
      await tapText(tester, 'Confirm & Activate'); // proceeds without one
      expect(server.posts.single.containsKey('assessment_ids'), isFalse);
      expect(server.assessmentCalls, 1);
    });

    testWidgets('empty list: approval still possible', (tester) async {
      final s = FakeApprovalsServer([applicant('u1', 'Test One')])..assessments = [];
      await pumpScreen(tester, const [], s: s);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      expect(find.byKey(const Key('approval-assessments-empty')), findsOneWidget);
      await confirm(tester);
      expect(server.posts, hasLength(1));
    });

    testWidgets('no permission to list assessments: approval still possible', (tester) async {
      final s = FakeApprovalsServer([applicant('u1', 'Test One')])..canViewAssessments = false;
      await pumpScreen(tester, const [], s: s);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      expect(find.byKey(const Key('approval-assessments-failed')), findsOneWidget);
      await confirm(tester);
      expect(server.posts.single.containsKey('assessment_ids'), isFalse);
    });

    testWidgets('not offered when the applicant has no linked candidate (as web)', (tester) async {
      await pumpScreen(tester, [applicant('u1', 'Test One', candidateId: null)]);
      await openReview(tester, 'Test One');
      await startApprove(tester);
      expect(find.text('Assign assessment (optional)'), findsNothing);
      expect(server.assessmentCalls, 0);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/attendance/data/models/attendance_models.dart';
import 'package:mobile_app/features/attendance/presentation/screens/my_attendance_screen.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/late_justification.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/my_requests/presentation/providers/my_requests_providers.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/profile/presentation/screens/profile_document_viewer_screen.dart';

import '../employees/employee_documents_view_test.dart' show MemStore, pngBytes;

// Task 65a: late-arrival justification, employee side — web my-attendance
// (LateJustificationModal, MyLateJustifications, calendar / history "Explain",
// Monthly Late Arrivals; lib/lateJustification.ts) over backend attendance
// services_late_justification.py / views/late_justification.py. The stand-in
// server applies the backend's rules (explanation 10–1000, proof required for
// Medical, one open request per day) and only the server's verdicts
// (canExplainLate, can_resubmit, late_limit) are shown. Nothing about the
// attendance record is changed here. Synthetic data only.

final today = DateTime.now();
String ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
final lateIso = ymd(today);
const monthsShort = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String fmtDay(DateTime d, {bool weekday = false}) {
  final base = '${d.day.toString().padLeft(2, '0')} ${monthsShort[d.month - 1]} ${d.year}';
  return weekday ? '${weekdays[d.weekday - 1]}, $base' : base;
}

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object data, [String message = 'ok']) =>
    _json(200, {'status': 'success', 'message': message, 'data': data});

Map<String, dynamic> lateRow(String id,
        {String status = 'pending',
        String reason = 'transport',
        String explanation = 'Bus broke down on the way',
        bool hasDocument = false,
        bool canViewDocument = false,
        String rejection = '',
        String? resubmitBy,
        bool canResubmit = false,
        String date = '2026-11-10'}) =>
    {
      'id': id,
      'kind': 'late_justification',
      'date': date,
      'punch_type': '',
      'original_in': '10:05',
      'original_out': '18:30',
      'requested_in': null,
      'requested_out': null,
      'reason': reason,
      'reason_label': {
        'medical': 'Medical',
        'transport': 'Transport',
        'personal': 'Personal',
        'other': 'Other'
      }[reason],
      'notes': explanation,
      'explanation': explanation,
      'status': status,
      'status_label': status,
      'l1_approver_name': 'Kiran Manager',
      'l1_status': status == 'resubmit' ? 'resubmit' : null,
      'l1_remarks': rejection,
      'l2_approver_name': null,
      'l2_status': null,
      'l2_remarks': '',
      'reviewed_by': null,
      'reviewed_at': null,
      'created_at': '2026-11-10 11:00',
      'has_document': hasDocument,
      'can_view_document': canViewDocument,
      'document_name': hasDocument ? 'note.png' : '',
      'proof_required': reason == 'medical',
      'missing_proof': !hasDocument,
      'rejection_reason': rejection,
      'resubmit_by': resubmitBy,
      'can_resubmit': canResubmit,
    };

Map<String, dynamic> punchRow(String id) => {
      'id': id,
      'kind': 'punch',
      'date': '2026-11-09',
      'punch_type': 'IN',
      'original_in': '09:40',
      'requested_in': '09:00',
      'reason': 'Forgot to punch',
      'status': 'pending',
      'l1_remarks': '',
      'l2_remarks': '',
      'created_at': '2026-11-09 10:00',
    };

class Server implements HttpClientAdapter {
  Map<String, dynamic>? lateLimit = {
    'enabled': true,
    'maximum': 3,
    'late_arrivals': 2,
    'remaining': 1,
    'status': 'within',
    'status_label': 'Within limit',
    'year': today.year,
    'month': today.month,
  };
  bool canExplain = true;
  String? dayStatus;
  List<Map<String, dynamic>> corrections = [punchRow('p1')];
  final submissions = <(String, Map<String, String>, String?)>[]; // path, fields, file name
  final gets = <String, int>{};
  int? submitStatus;
  Map<String, dynamic>? submitData;
  String submitMessage = 'Late arrival justification submitted. You will be notified once it is reviewed.';

  int count(String path) => gets[path] ?? 0;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    final path = o.path;
    if (o.method == 'GET') gets[path] = (gets[path] ?? 0) + 1;
    if (path == ApiConstants.attendanceToday) {
      return _ok(
          {'is_clocked_in': false, 'day_completed': false, 'punches': [], 'total_seconds': 0, 'session_seconds': 0});
    }
    if (path == ApiConstants.attendanceStats) {
      return _ok({
        'days_present': 5,
        'late_arrivals': 2,
        'lop_pending': 0,
        'avg_hours_per_day': 8,
        'attendance_percentage': 90,
        'working_days': 6,
        if (lateLimit != null) 'late_limit': lateLimit,
      });
    }
    if (path == ApiConstants.attendanceSummary) return _ok({'working_days': 6});
    if (path == ApiConstants.attendanceCalendar) {
      return _ok({
        'calendar': {
          'days': {
            '${today.day}': {
              'date': lateIso,
              'status': 'Late',
              'clockIn': '10:05',
              'clockOut': null,
              'hours': null,
              'note': 'Late arrival',
              'canRegularize': false,
              'regularization_required': false,
              'canExplainLate': canExplain,
              'lateJustificationStatus': dayStatus,
            },
          },
        },
        'history': [
          {
            'date': '${today.day} ${monthsShort[today.month - 1]}',
            'day': 'Thu',
            'clockIn': '10:05',
            'clockOut': '—',
            'hours': '—',
            'status': 'Late',
            'canRegularize': false,
            'isoDate': lateIso,
            'canExplainLate': canExplain,
            'lateJustificationStatus': dayStatus,
          },
          {
            'date': '1 ${monthsShort[today.month - 1]}',
            'day': 'Mon',
            'clockIn': '09:00',
            'clockOut': '18:00',
            'hours': '9h',
            'status': 'Present',
            'canRegularize': false,
            'isoDate': ymd(DateTime(today.year, today.month, 1)),
          },
        ],
      });
    }
    if (path == ApiConstants.attendanceMyCorrections) return _ok({'results': corrections});
    if (o.method == 'POST' &&
        (path == ApiConstants.attendanceLateJustification || path.startsWith('/attendance/late-justification/'))) {
      final form = o.data as FormData;
      submissions.add((
        path,
        {for (final f in form.fields) f.key: f.value},
        form.files.isEmpty ? null : form.files.single.value.filename,
      ));
      if (submitStatus != null) {
        return _json(submitStatus!, {'status': 'error', 'message': submitMessage, 'data': submitData ?? {}});
      }
      return _json(201, {'status': 'success', 'message': submitMessage, 'data': {}});
    }
    final doc = RegExp(r'^/api/attendance/corrections/([^/]+)/document/$').firstMatch(o.uri.path);
    if (doc != null) {
      gets['doc:${doc.group(1)}'] = (gets['doc:${doc.group(1)}'] ?? 0) + 1;
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
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'emp-1',
          email: 'e@example.test',
          fullName: 'Esha Test',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: ['attendance.view'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

late Server server;
PlatformFile? nextFile;
Finder byKey(String k) => find.byKey(Key(k));

Future<void> pumpScreen(WidgetTester tester, {void Function(Server)? setup}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  nextFile = null;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      lateProofPickerProvider.overrideWithValue(() async => nextFile),
      profileDocumentTempStoreProvider.overrideWithValue(MemStore()),
    ],
    child: MaterialApp(
      home: Consumer(
          builder: (_, ref, child) {
            ref.watch(authStateProvider); // the signed-in user is loaded, as in the app
            return child!;
          },
          child: const Scaffold(body: MyAttendanceScreen())),
    ),
  ));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await settle(tester);
}

Future<void> openHistory(WidgetTester tester) async {
  await tester.ensureVisible(find.text('History'));
  await tester.tap(find.text('History'));
  await settle(tester);
}

Future<void> openCorrectionsTab(WidgetTester tester) async {
  await tester.tap(find.text('Attendance Corrections'));
  // Let the tab finish sliding in before anything on it is tapped.
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

String? textOf(WidgetTester tester, String key) {
  final f = byKey(key);
  if (f.evaluate().isEmpty) return null;
  final w = tester.widget(f);
  if (w is Text) return w.data ?? w.textSpan?.toPlainText();
  return tester.widgetList<Text>(find.descendant(of: f, matching: find.byType(Text))).map((t) => t.data).join(' ');
}

PlatformFile file(String name, List<int> bytes, {int? size}) =>
    PlatformFile(name: name, size: size ?? bytes.length, bytes: Uint8List.fromList(bytes));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (pure)', () {
    test('web lateFormErrors / proofError', () {
      expect(lateFormErrors('medical', 'short', null), {
        'explanation': 'Explain what happened (at least 10 characters).',
        'document': 'Medical reasons need proof (PDF, JPG or PNG).',
      });
      expect(lateFormErrors('medical', 'Doctor visit early', null, hasExistingProof: true), isEmpty);
      expect(lateFormErrors('transport', 'Bus broke down', null), isEmpty);
      expect(lateFormErrors('transport', 'x' * 1001, null)['explanation'], 'Keep it under 1000 characters.');
      expect(lateFormErrors('bogus', 'Bus broke down', null)['reason'], 'Choose a reason.');
      expect(lateProofError('scan.docx', 10), 'Upload a PDF, JPG or PNG file.');
      expect(lateProofError('scan.PDF', 0), 'The file is empty.');
      expect(lateProofError('scan.jpeg', 5 * 1024 * 1024 + 1), 'The file must be 5 MB or smaller.');
      expect(lateProofError('scan.png', 100), isNull);
      expect(lateStatusHint('l2_pending'), 'Reason pending');
      expect(lateStatusHint('resubmit'), 'Resubmit reason');
      expect(lateStatusHint('approved'), isNull);
    });

    test('models read the late fields; older servers without them read as none', () {
      final day = CalendarDayModel.fromJson(
          const {'status': 'Late', 'canExplainLate': true, 'lateJustificationStatus': 'pending'});
      expect((day.canExplainLate, day.lateJustificationStatus), (true, 'pending'));
      final old = CalendarDayModel.fromJson(const {'status': 'Late'});
      expect((old.canExplainLate, old.lateJustificationStatus), (false, null));
      final stats = AttendanceStatsModel.fromJson({
        'late_limit': {
          'enabled': true,
          'maximum': 3,
          'late_arrivals': 4,
          'remaining': null,
          'status': 'exceeded',
          'status_label': 'Exceeded'
        }
      });
      expect((stats.lateLimit!.remaining, stats.lateLimit!.status), (null, 'exceeded'));
      expect(AttendanceStatsModel.fromJson(const {}).lateLimit, isNull);
      final c =
          MyCorrectionModel.fromJson(lateRow('x', status: 'resubmit', canResubmit: true, rejection: 'Need detail'));
      expect((c.isLateJustification, c.canResubmit, c.rejectionReason), (true, true, 'Need detail'));
      expect(MyCorrectionModel.fromJson(punchRow('p')).isLateJustification, isFalse);
    });

    test('My Requests: late rows titled as web; resubmission counts as pending', () {
      final item = MyRequestItem.fromCorrection(MyCorrectionModel.fromJson(lateRow('abcdef123', status: 'resubmit')));
      expect(item.title, 'Late Arrival Justification — Resubmission Required');
      expect(item.requestCode, 'LJ-ABCDEF');
      expect(item.detailSecondary, '10 Nov 2026 · Transport');
      expect(item.displayStatus, MyRequestDisplayStatus.pending);
      expect(MyRequestItem.fromCorrection(MyCorrectionModel.fromJson(lateRow('a', status: 'approved'))).title,
          'Late Arrival Justification');
      expect(MyRequestItem.fromCorrection(MyCorrectionModel.fromJson(punchRow('p'))).title, 'Check-in Correction');
    });
  });

  group('explain a late day', () {
    testWidgets('1/4. history: "Explain late arrival" only where the server allows; web payload; refresh',
        (tester) async {
      await pumpScreen(tester, setup: (s) => s.lateLimit = null);
      await openHistory(tester);
      expect(byKey('history-explain-late-$lateIso'), findsOneWidget);
      expect(find.text('Explain late arrival'), findsOneWidget, reason: 'not on the on-time day');
      final cal = server.count(ApiConstants.attendanceCalendar), stats = server.count(ApiConstants.attendanceStats);
      await tapKey(tester, 'history-explain-late-$lateIso');
      expect(find.text('Explain late arrival'), findsWidgets);
      expect(find.text('${fmtDay(today, weekday: true)} · clocked in at 10:05', findRichText: true), findsOneWidget);
      await tester.tap(byKey('late-reason'));
      await settle(tester);
      await tester.tap(find.text('Transport').last);
      await settle(tester);
      await tester.enterText(byKey('late-explanation'), '  Bus broke down on the way  ');
      await tapKey(tester, 'late-submit');
      expect(server.submissions.single.$1, ApiConstants.attendanceLateJustification);
      expect(server.submissions.single.$2,
          {'reason': 'transport', 'explanation': 'Bus broke down on the way', 'date': lateIso});
      expect(server.submissions.single.$3, isNull, reason: 'no proof chosen');
      expect(find.text(server.submitMessage), findsOneWidget, reason: 'the server message, as web');
      expect(server.count(ApiConstants.attendanceCalendar), greaterThan(cal));
      expect(server.count(ApiConstants.attendanceStats), greaterThan(stats));
      // The corrections list re-fetches when shown (it was invalidated).
      final corr = server.count(ApiConstants.attendanceMyCorrections);
      await openCorrectionsTab(tester);
      expect(server.count(ApiConstants.attendanceMyCorrections), greaterThan(corr));
      await unmount(tester);
    });

    testWidgets('3. checks before sending: explanation and Medical proof; nothing sent', (tester) async {
      await pumpScreen(tester);
      await openHistory(tester);
      await tapKey(tester, 'history-explain-late-$lateIso');
      expect(find.text('Medical proof *', findRichText: true), findsOneWidget,
          reason: 'Medical is web\'s default reason');
      await tapKey(tester, 'late-submit');
      expect(textOf(tester, 'late-sheet-message'), 'Please correct the highlighted fields.');
      expect(textOf(tester, 'late-error-explanation'), 'Explain what happened (at least 10 characters).');
      expect(textOf(tester, 'late-error-document'), 'Medical reasons need proof (PDF, JPG or PNG).');
      nextFile = file('scan.docx', [1, 2, 3]);
      await tapKey(tester, 'late-proof-pick');
      await tester.enterText(byKey('late-explanation'), 'Visited the doctor early');
      await tapKey(tester, 'late-submit');
      expect(textOf(tester, 'late-error-document'), 'Upload a PDF, JPG or PNG file.');
      nextFile = file('big.pdf', [1], size: 5 * 1024 * 1024 + 1);
      await tapKey(tester, 'late-proof-pick');
      await tapKey(tester, 'late-submit');
      expect(textOf(tester, 'late-error-document'), 'The file must be 5 MB or smaller.');
      expect(server.submissions, isEmpty);
      await tapKey(tester, 'late-cancel');
      expect(server.submissions, isEmpty);
      await unmount(tester);
    });

    testWidgets('4. Medical with proof: the file goes as "document"', (tester) async {
      await pumpScreen(tester);
      await openHistory(tester);
      await tapKey(tester, 'history-explain-late-$lateIso');
      await tester.enterText(byKey('late-explanation'), 'Visited the doctor early');
      nextFile = file('note.png', pngBytes);
      await tapKey(tester, 'late-proof-pick');
      expect(textOf(tester, 'late-proof-name'), 'note.png');
      await tapKey(tester, 'late-submit');
      expect(server.submissions.single.$2,
          {'reason': 'medical', 'explanation': 'Visited the doctor early', 'date': lateIso});
      expect(server.submissions.single.$3, 'note.png');
      await unmount(tester);
    });

    testWidgets('6/9. refused (already open / bad proof): the server message and field error; the form stays',
        (tester) async {
      await pumpScreen(tester, setup: (s) {
        s
          ..submitStatus = 400
          ..submitMessage = 'The file is not a valid PDF, JPG or PNG (its content does not match).'
          ..submitData = {
            'document': ['The file is not a valid PDF, JPG or PNG (its content does not match).']
          };
      });
      await openHistory(tester);
      await tapKey(tester, 'history-explain-late-$lateIso');
      await tester.enterText(byKey('late-explanation'), 'Visited the doctor early');
      nextFile = file('fake.png', [1, 2, 3, 4]);
      await tapKey(tester, 'late-proof-pick');
      await tapKey(tester, 'late-submit');
      expect(textOf(tester, 'late-sheet-message'), server.submitMessage);
      expect(textOf(tester, 'late-error-document'), server.submitMessage);
      expect(byKey('late-submit'), findsOneWidget);
      // A date-level refusal: banner only (web shows no per-field date error).
      server
        ..submitMessage = 'You already have an open justification for this date.'
        ..submitData = {
          'date': ['You already have an open justification for this date.']
        };
      nextFile = file('note.png', pngBytes);
      await tapKey(tester, 'late-proof-pick');
      await tapKey(tester, 'late-submit');
      expect(textOf(tester, 'late-sheet-message'), 'You already have an open justification for this date.');
      expect(byKey('late-error-date'), findsNothing);
      await unmount(tester);
    });

    testWidgets('1/5. calendar day: Explain when allowed; a waiting request shows its hint instead', (tester) async {
      await pumpScreen(tester);
      final cell = find.descendant(of: find.byType(GridView).last, matching: find.text('${today.day}'));
      await tester.ensureVisible(cell);
      await tester.tap(cell);
      await settle(tester);
      expect(byKey('day-explain-late'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await settle(tester);
      await unmount(tester);

      await pumpScreen(tester, setup: (s) {
        s
          ..canExplain = false
          ..dayStatus = 'pending';
      });
      final cell2 = find.descendant(of: find.byType(GridView).last, matching: find.text('${today.day}'));
      await tester.ensureVisible(cell2);
      await tester.tap(cell2);
      await settle(tester);
      expect(byKey('day-explain-late'), findsNothing);
      expect(textOf(tester, 'day-late-hint'), 'Reason pending');
      await tester.tap(find.text('Close'));
      await settle(tester);
      await unmount(tester);
    });
  });

  group('monthly limit', () {
    testWidgets('2. shown with the server\'s numbers and status when enabled', (tester) async {
      await pumpScreen(tester);
      final card = byKey('monthly-late-arrivals');
      expect(card, findsOneWidget);
      for (final t in ['3', '2', '1', 'Within limit', 'Maximum allowed', 'Late arrivals this month', 'Remaining']) {
        expect(find.descendant(of: card, matching: find.text(t)), findsWidgets, reason: t);
      }
      await unmount(tester);
    });

    testWidgets('2. exhausted: the server\'s "Exceeded", remaining "—"', (tester) async {
      await pumpScreen(tester, setup: (s) {
        s.lateLimit = {
          'enabled': true,
          'maximum': 3,
          'late_arrivals': 5,
          'remaining': null,
          'status': 'exceeded',
          'status_label': 'Exceeded',
        };
      });
      final card = byKey('monthly-late-arrivals');
      expect(find.descendant(of: card, matching: find.text('Exceeded')), findsOneWidget);
      expect(find.descendant(of: card, matching: find.text('—')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('2. limit off, or an older server: no card', (tester) async {
      await pumpScreen(tester, setup: (s) => s.lateLimit = {'enabled': false, 'maximum': 3, 'late_arrivals': 0});
      expect(byKey('monthly-late-arrivals'), findsNothing);
      await unmount(tester);
      await pumpScreen(tester, setup: (s) => s.lateLimit = null);
      expect(byKey('monthly-late-arrivals'), findsNothing);
      await unmount(tester);
    });
  });

  group('my justifications', () {
    testWidgets('5. punch corrections and late justifications are listed apart; statuses as web', (tester) async {
      await pumpScreen(tester, setup: (s) {
        s.corrections = [
          punchRow('p1'),
          lateRow('l1', status: 'approved'),
          lateRow('l2', status: 'l2_pending'),
          lateRow('l3', status: 'rejected', rejection: 'Not a valid reason'),
        ];
      });
      await openCorrectionsTab(tester);
      final card = byKey('my-late-justifications');
      expect(textOf(tester, 'my-late-status-l1'), 'Late (Excused)');
      expect(textOf(tester, 'my-late-status-l2'), 'Pending (HR)');
      expect(textOf(tester, 'my-late-status-l3'), 'Rejected');
      expect(find.descendant(of: card, matching: find.text('Reviewer: Not a valid reason')), findsOneWidget);
      expect(byKey('my-late-p1'), findsNothing, reason: 'punch corrections are not in this card');
      // ...and late justifications are not counted with the punch corrections.
      String tile(String label) => tester
          .widgetList<Text>(find.descendant(
              of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
              matching: find.byType(Text)))
          .first
          .data!;
      expect((tile('Pending'), tile('Approved'), tile('Rejected')), ('1', '0', '0'));
      await unmount(tester);
    });

    testWidgets('5. none yet: web empty text', (tester) async {
      await pumpScreen(tester);
      await openCorrectionsTab(tester);
      expect(find.text('No late arrival justifications'), findsOneWidget);
      expect(find.text('Use “Explain” on a late day in your attendance calendar (within 3 days).'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('5. resubmission: reviewer note, prefilled, keeps the proof on file; sent to resubmit', (tester) async {
      await pumpScreen(tester, setup: (s) {
        s
          ..submitMessage = 'Justification resubmitted for review.'
          ..corrections = [
            lateRow('l9',
                status: 'resubmit',
                reason: 'medical',
                explanation: 'Doctor visit before work',
                hasDocument: true,
                canViewDocument: true,
                rejection: 'Add the clinic name',
                resubmitBy: '2026-11-15',
                canResubmit: true),
          ];
      });
      await openCorrectionsTab(tester);
      expect(textOf(tester, 'my-late-status-l9'), 'Resubmission Required');
      await tapKey(tester, 'my-late-resubmit-l9');
      expect(find.text('Resubmit late arrival justification'), findsOneWidget);
      expect(find.text("Reviewer's note: Add the clinic name — resubmit by 15 Nov 2026", findRichText: true),
          findsOneWidget);
      expect(tester.widget<TextField>(byKey('late-explanation')).controller!.text, 'Doctor visit before work');
      await tester.enterText(byKey('late-explanation'), 'Doctor visit at City Clinic before work');
      await tapKey(tester, 'late-submit');
      expect(server.submissions.single.$1, ApiConstants.attendanceLateJustificationResubmit('l9'));
      expect(
          server.submissions.single.$2, {'reason': 'medical', 'explanation': 'Doctor visit at City Clinic before work'},
          reason: 'no date on a resubmission; the proof on file is kept');
      expect(server.submissions.single.$3, isNull);
      expect(textOf(tester, 'late-notice'), 'Justification resubmitted for review.');
      await unmount(tester);
    });

    testWidgets('the employee\'s own proof opens in the app through the API', (tester) async {
      await pumpScreen(tester, setup: (s) {
        s.corrections = [lateRow('l5', reason: 'medical', hasDocument: true, canViewDocument: true)];
      });
      await openCorrectionsTab(tester);
      await tapKey(tester, 'my-late-proof-l5');
      expect(find.byType(ProfileDocumentViewerScreen), findsOneWidget);
      expect(server.count('doc:l5'), 1, reason: 'fetched from the API (with the login)');
      await tester
          .tap(find.descendant(of: find.byType(ProfileDocumentViewerScreen), matching: find.byIcon(Icons.close)));
      await settle(tester);
      await unmount(tester);
    });
  });
}

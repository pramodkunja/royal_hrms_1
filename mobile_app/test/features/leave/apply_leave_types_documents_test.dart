import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/leave/data/models/leave_models.dart';
import 'package:mobile_app/features/leave/domain/entities/leave_entity.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart';
import 'package:mobile_app/features/leave/presentation/widgets/apply_leave_tab.dart';
import 'package:mobile_app/features/leave/presentation/widgets/apply_leave_type_selector.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_type_presentation.dart';

// Task 49 — Apply Leave.
// Issue 1: the document requirement is the server's rule only — the leave
// type's Leave Policy `attachment_required` (backend views/leave.py
// _validate_policy_rules: "An attachment is required for this leave type.",
// for built-in and custom types alike). Nothing hardcodes Casual/Sick.
// Issue 2: active custom Leave Policies (e.g. "Pink Leave") are offered after
// the 6 built-ins, as web buildLeaveTypesList; the backend accepts any active
// policy (LeaveRequestCreateSerializer.validate_leave_type).
// A stand-in server; synthetic data; no real leave is submitted.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> policy(String code, String display, {bool attach = false, bool active = true}) => {
      'id': code.hashCode & 0xffff,
      'leave_type': code,
      'leave_type_display': display,
      'annual_days': '12.0',
      'is_active': active,
      'attachment_required': attach,
      'medical_certificate_required': false,
      'allow_half_day': true,
      'allow_future_leave': true,
      'allow_backdated_leave': true,
      'policy_note': '',
    };

/// 12 days each; for 2027 the server has 3 used — so the year asked for
/// shows on screen (12d left vs 9d left).
Map<String, dynamic> balance(String code, String display, {Object? year}) =>
    {'leave_type': code, 'leave_type_display': display, 'total_days': '12.0', 'used_days': year == 2027 ? '3.0' : '0.0'};

class Server implements HttpClientAdapter {
  /// Production-like config that produced the reported symptom: Casual has
  /// Attachment Required on, Sick off.
  List<Map<String, dynamic>> policies = [
    policy('casual', 'Casual Leave', attach: true),
    policy('earned', 'Earned Leave'),
    policy('sick', 'Sick Leave'),
    policy('lwp', 'Leave Without Pay'),
    policy('maternity', 'Maternity Leave'),
    policy('paternity', 'Paternity Leave'),
    policy('pink_leave', 'Pink Leave'),
    policy('old_custom', 'Retired Leave', active: false),
  ];
  final posts = <FormData>[];
  final gets = <(String, Map<String, dynamic>)>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET') gets.add((o.path, Map.of(o.queryParameters)));
    if (o.path == '/leave/policy/') return _json(200, {'status': 'success', 'data': policies});
    if (o.path == '/leave/balance/') {
      return _json(200, {
        'status': 'success',
        'data': [
          for (final p in policies)
            balance(p['leave_type'] as String, p['leave_type_display'] as String, year: o.queryParameters['year']),
        ]
      });
    }
    if (o.path == '/leave/requests/' && o.method == 'GET') {
      if (o.queryParameters['action'] == 'preview') {
        return _json(200, {
          'status': 'success',
          'data': {
            'leave_type': o.queryParameters['leave_type'],
            'calendar_days': 1,
            'actual_leave_days': 0.5,
            'company_holiday_count': 0,
            'company_holidays': [],
            'week_off_count': 0,
            'week_offs': [],
            'available_balance': 12.0,
            'sufficient_balance': true,
            'lop_enabled': false,
            'lop_days': 0,
            'sandwich_leave_enabled': false,
            'earned_leave_used': 0,
            'warning': '',
          }
        });
      }
      return _json(200, {
        'status': 'success',
        'data': {'count': 0, 'page': 1, 'page_size': 20, 'total_pages': 1, 'results': []}
      });
    }
    if (o.path == '/leave/requests/' && o.method == 'POST') {
      final fd = o.data as FormData;
      posts.add(fd);
      final type = fd.fields.firstWhere((f) => f.key == 'leave_type').value;
      final attach = (policies.firstWhere((p) => p['leave_type'] == type)['attachment_required'] as bool);
      // The backend's own rule.
      if (attach && !fd.files.any((f) => f.key == 'document')) {
        return _json(400, {'status': 'error', 'message': 'An attachment is required for this leave type.', 'data': {}});
      }
      return _json(201, {
        'status': 'success',
        'data': {
          'id': 'req-1',
          'employee_name': 'Test Employee',
          'leave_type': type,
          'leave_type_display': type,
          'start_date': fd.fields.firstWhere((f) => f.key == 'start_date').value,
          'end_date': fd.fields.firstWhere((f) => f.key == 'end_date').value,
          'total_days': 0.5,
          'status': 'pending',
          'reason': 'x',
          'applied_on': '2026-11-12',
        }
      });
    }
    return _json(200, {'status': 'success', 'data': <String, dynamic>{}});
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

UserEntity person(String role, List<String> perms, {bool team = false}) => UserEntity(
      id: 'e1',
      email: '$role@example.test',
      fullName: 'Test Employee',
      role: role,
      roleDisplay: role,
      mustChangePassword: false,
      permissions: perms,
      canManageTeam: team,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final employeeUser = person('employee', ['leave.view', 'leave.apply']);

/// Who is signed in (reset to the employee by pump()).
UserEntity applicant = employeeUser;

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthState(user: applicant);
}

late Server server;
List<Override> overrides() => [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pump(WidgetTester tester, {Server? with_, DateTime? at, UserEntity? as}) async {
  tester.view.physicalSize = const Size(1080, 5200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  applicant = as ?? employeeUser;
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [...overrides(), if (at != null) leaveDashboardClockProvider.overrideWithValue(() => at)],
    child: const MaterialApp(home: Scaffold(body: ApplyLeaveTab())),
  ));
  await tester.pumpAndSettle();
}

Future<void> selectType(WidgetTester tester, String label) async {
  final f = find.text(label).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
}

String docLabel(WidgetTester tester) => find.text('(Required)').evaluate().isNotEmpty
    ? 'Required'
    : (find.text('(Optional)').evaluate().isNotEmpty ? 'Optional' : '?');

/// Half day today, a reason, then Submit.
Future<void> fillAndSubmit(WidgetTester tester) async {
  final half = find.text('Half · AM');
  await tester.ensureVisible(half);
  await tester.tap(half);
  await tester.pumpAndSettle();
  final start = find.text('Select').first;
  await tester.ensureVisible(start);
  await tester.tap(start);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
  final reason = find.widgetWithText(TextFormField, 'Briefly describe the reason for your leave…');
  await tester.ensureVisible(reason);
  await tester.enterText(reason, 'Synthetic reason for testing.');
  await tester.pumpAndSettle();
  final submit = find.text('Submit');
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

LeaveTypeEntity entity(String code, String name, {bool attach = false, bool active = true}) =>
    LeaveTypeModel.fromJson(policy(code, name, attach: attach, active: active));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Issue 1 — document requirement = server attachment_required', () {
    test('parsed per type from the policy; absent → not required (no hardcoded Casual/Sick/Maternity list)', () {
      expect(entity('casual', 'Casual Leave', attach: true).docRequired, isTrue);
      expect(entity('sick', 'Sick Leave').docRequired, isFalse);
      expect(entity('pink_leave', 'Pink Leave', attach: true).docRequired, isTrue);
      final noKey = Map<String, dynamic>.from(policy('maternity', 'Maternity Leave'))..remove('attachment_required');
      expect(LeaveTypeModel.fromJson(noKey).docRequired, isFalse);
    });

    test('options carry each type\'s own rule; a built-in with no policy row is not required', () {
      final opts = LeaveTypeOption.listFromEntities(
          [entity('casual', 'Casual Leave', attach: true), entity('sick', 'Sick Leave')], const []);
      Map<String, bool> req = {for (final o in opts) o.code: o.docRequired};
      expect(req['casual'], isTrue);
      expect(req['sick'], isFalse);
      expect(req['maternity'], isFalse, reason: 'synthesized (no policy) → no backend rule');
    });

    testWidgets('1. labels follow the server per type, and switching updates them', (tester) async {
      await pump(tester);
      await selectType(tester, 'Casual Leave');
      expect(docLabel(tester), 'Required');
      await selectType(tester, 'Sick Leave');
      expect(docLabel(tester), 'Optional');
      final s = Server()
        ..policies = [
          policy('casual', 'Casual Leave'),
          policy('sick', 'Sick Leave', attach: true),
        ];
      await pump(tester, with_: s);
      await selectType(tester, 'Sick Leave');
      expect(docLabel(tester), 'Required', reason: 'nothing hardcoded: the same screen follows the other config');
      await selectType(tester, 'Casual Leave');
      expect(docLabel(tester), 'Optional');
    });

    testWidgets('2. required type without a document: visible error, nothing sent', (tester) async {
      await pump(tester);
      await selectType(tester, 'Casual Leave');
      await fillAndSubmit(tester);
      expect(find.text('Supporting document is required for this leave type.'), findsOneWidget);
      expect(server.posts, isEmpty);
    });

    testWidgets('3. switching to an optional type clears the stale error and submits without a document',
        (tester) async {
      await pump(tester);
      await selectType(tester, 'Casual Leave');
      await fillAndSubmit(tester);
      expect(find.text('Supporting document is required for this leave type.'), findsOneWidget);
      await selectType(tester, 'Sick Leave');
      expect(find.text('Supporting document is required for this leave type.'), findsNothing);
      final submit = find.text('Submit');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final fd = server.posts.single;
      expect(fd.fields.firstWhere((f) => f.key == 'leave_type').value, 'sick');
      expect(fd.files.where((f) => f.key == 'document'), isEmpty);
      expect(fd.fields.firstWhere((f) => f.key == 'duration').value, 'half_morning');
    });

    test('4. with a picked file the multipart request carries it as "document"', () async {
      server = Server();
      final dir = await Directory.systemTemp.createTemp('leave_doc_test');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/proof.pdf')..writeAsBytesSync(utf8.encode('%PDF-1.4 synthetic'));
      final c = ProviderContainer(overrides: overrides());
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final err = await c.read(leaveRequestsProvider.notifier).applyLeave(
            leaveTypeCode: 'casual',
            fromDate: '2026-11-12',
            toDate: '2026-11-12',
            reason: 'Synthetic reason for testing.',
            duration: 'half_morning',
            document: PlatformFile(name: 'proof.pdf', size: file.lengthSync(), path: file.path),
          );
      expect(err, isNull);
      final fd = server.posts.single;
      final doc = fd.files.singleWhere((f) => f.key == 'document');
      expect(doc.value.filename, 'proof.pdf');
      expect(fd.fields.firstWhere((f) => f.key == 'leave_type').value, 'casual');
    });
  });

  group('Issue 2 — active custom leave types (Pink Leave)', () {
    test('options: 6 built-ins, then active custom policies in server order; inactive ones left out', () {
      final opts = LeaveTypeOption.listFromEntities([
        entity('pink_leave', 'Pink Leave'),
        entity('casual', 'Casual Leave'),
        entity('old_custom', 'Retired Leave', active: false),
        entity('comp_off', 'Comp Off', attach: true),
      ], [
        const LeaveBalanceEntity(typeCode: 'pink_leave', typeName: 'Pink Leave', used: 2, total: 6),
      ]);
      expect(opts.map((o) => o.code),
          ['casual', 'earned', 'sick', 'lwp', 'maternity', 'paternity', 'pink_leave', 'comp_off']);
      final pink = opts.firstWhere((o) => o.code == 'pink_leave');
      expect((pink.label, pink.balance, pink.total, pink.docRequired), ('Pink Leave', 4, 6, false));
      expect(pink.color, kCustomLeaveTypeColor);
      expect(pink.icon, kCustomLeaveTypeIcon);
      expect(opts.firstWhere((o) => o.code == 'comp_off').docRequired, isTrue);
    });

    testWidgets('5. Pink Leave is offered, selectable, and applied with its own key', (tester) async {
      await pump(tester);
      expect(find.text('Pink Leave'), findsWidgets);
      expect(find.text('Retired Leave'), findsNothing, reason: 'inactive custom policy');
      await selectType(tester, 'Pink Leave');
      expect(docLabel(tester), 'Optional');
      await fillAndSubmit(tester);
      final fd = server.posts.single;
      expect(fd.fields.firstWhere((f) => f.key == 'leave_type').value, 'pink_leave');
    });

    testWidgets('6. a custom type whose policy requires an attachment is enforced the same way', (tester) async {
      final s = Server()
        ..policies = [
          ...Server().policies.where((p) => p['leave_type'] != 'pink_leave'),
          policy('pink_leave', 'Pink Leave', attach: true),
        ];
      await pump(tester, with_: s);
      await selectType(tester, 'Pink Leave');
      expect(docLabel(tester), 'Required');
      await fillAndSubmit(tester);
      expect(find.text('Supporting document is required for this leave type.'), findsOneWidget);
      expect(s.posts, isEmpty);
    });
  });

  // Task 72.1: a successful application refreshes the Leave Dashboard's own
  // balances and LOP stats (same calendar year as web).
  testWidgets('applying refreshes the dashboard balances and stats for the calendar year', (tester) async {
    tester.view.physicalSize = const Size(1080, 5200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    server = Server();
    await tester.pumpWidget(ProviderScope(
      overrides: [...overrides(), leaveDashboardClockProvider.overrideWithValue(() => DateTime(2027, 2, 10, 9))],
      child: MaterialApp(
        home: Scaffold(
          body: Column(children: [
            // Stands in for the Leave Dashboard tab, alive in the TabBarView.
            Consumer(builder: (context, ref, _) {
              ref.watch(myLeaveBalancesProvider);
              ref.watch(myLeaveStatsProvider);
              return const SizedBox.shrink();
            }),
            const Expanded(child: ApplyLeaveTab()),
          ]),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    List<Map<String, dynamic>> q(String path) => [for (final g in server.gets) if (g.$1 == path) g.$2];
    final balancesBefore = q('/leave/balance/').where((m) => m['year'] == 2027).length;
    final statsBefore = q('/leave/stats/').where((m) => m['scope'] == 'own').length;
    expect(balancesBefore, 1);
    await selectType(tester, 'Sick Leave'); // no attachment required in this fixture
    await fillAndSubmit(tester);
    expect(server.posts, hasLength(1));
    expect(q('/leave/balance/').where((m) => m['year'] == 2027).length, balancesBefore + 1);
    expect(q('/leave/stats/').where((m) => m['scope'] == 'own').length, statsBefore + 1);
    expect(q('/leave/stats/').last, {'year': 2027, 'scope': 'own'});
  });

  // Task 72.2: web ApplyLeaveForm.tsx asks for API.leave.balance?year=
  // getLeaveYear() — the calendar year (new Date().getFullYear()), whatever
  // dates are picked; never the backend's financial-year default.
  group('calendar year (web getLeaveYear)', () {
    List<Map<String, dynamic>> balanceQueries() => [for (final g in server.gets) if (g.$1 == '/leave/balance/') g.$2];

    for (final (label, at, year) in [
      ('1 January', DateTime(2027, 1, 1, 0, 5), 2027),
      ('mid-February (financial year still 2026)', DateTime(2027, 2, 10, 9), 2027),
      ('31 March', DateTime(2027, 3, 31, 23), 2027),
      ('1 April', DateTime(2026, 4, 1, 9), 2026),
      ('31 December', DateTime(2026, 12, 31, 23), 2026),
    ]) {
      testWidgets('$label → year $year', (tester) async {
        await pump(tester, at: at);
        expect(balanceQueries(), [
          {'year': year}
        ]);
      });
    }

    testWidgets('the balance shown is that year\'s (2027: 9d left; never the default year\'s 12d)', (tester) async {
      await pump(tester, at: DateTime(2027, 2, 10, 9));
      expect(find.text('9d left'), findsWidgets);
      expect(find.text('12d left'), findsNothing);
    });

    testWidgets('picked leave dates do not change the year', (tester) async {
      await pump(tester, at: DateTime(2027, 2, 10, 9));
      await selectType(tester, 'Sick Leave');
      await fillAndSubmit(tester); // picks a date in the date picker
      // Load + refresh after submitting, both for 2027. Task 78: the old
      // year-less refresh of the shared leaveBalancesProvider (no screen
      // shows it any more) is gone — no request without a year.
      expect(balanceQueries(), [
        {'year': 2027},
        {'year': 2027}
      ]);
      // Analytics stats still refreshed once — for the calendar year since
      // Task 83 (LV-18), no longer year-less.
      expect(server.gets.where((g) => g.$1 == '/leave/stats/' && g.$2.isEmpty), isEmpty);
      expect(server.gets.where((g) => g.$1 == '/leave/stats/' && g.$2['year'] == 2027), hasLength(1));
    });

    testWidgets('after New Year, a submission reloads the new year\'s balances', (tester) async {
      var now = DateTime(2026, 12, 31, 23, 50);
      tester.view.physicalSize = const Size(1080, 5200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = Server();
      applicant = employeeUser;
      await tester.pumpWidget(ProviderScope(
        overrides: [...overrides(), leaveDashboardClockProvider.overrideWithValue(() => now)],
        child: const MaterialApp(home: Scaffold(body: ApplyLeaveTab())),
      ));
      await tester.pumpAndSettle();
      expect(balanceQueries(), [
        {'year': 2026}
      ]);
      now = DateTime(2027, 1, 1, 0, 10);
      await selectType(tester, 'Sick Leave');
      await fillAndSubmit(tester);
      expect(server.posts, hasLength(1));
      expect(balanceQueries().where((q) => q.containsKey('year')).last, {'year': 2027});
    });

    testWidgets('reopening the tab after New Year asks for the new year', (tester) async {
      var now = DateTime(2026, 12, 31, 23, 50);
      final show = ValueNotifier(true);
      tester.view.physicalSize = const Size(1080, 5200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      server = Server();
      applicant = employeeUser;
      await tester.pumpWidget(ProviderScope(
        overrides: [...overrides(), leaveDashboardClockProvider.overrideWithValue(() => now)],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: show,
              builder: (_, on, __) => on ? const ApplyLeaveTab() : const SizedBox(),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      show.value = false; // another Leave tab
      await tester.pumpAndSettle();
      now = DateTime(2027, 1, 1, 9);
      show.value = true;
      await tester.pumpAndSettle();
      expect(balanceQueries(), [
        {'year': 2026},
        {'year': 2027}
      ]);
    });

    for (final u in [
      employeeUser,
      person('hr_admin', ['leave.view', 'leave.apply', 'leave.approve', 'employees.view']),
      person('manager', ['leave.view', 'leave.apply', 'leave.approve'], team: true),
    ]) {
      testWidgets('${u.role}: own balances for the year only — no other balance, stats or team request', (tester) async {
        await pump(tester, as: u, at: DateTime(2026, 11, 16, 10));
        expect(balanceQueries(), [
          {'year': 2026}
        ]);
        final paths = {for (final g in server.gets) g.$1};
        expect(paths, {'/leave/policy/', '/leave/balance/', '/leave/requests/'});
        expect(server.gets.where((g) => g.$2['scope'] == 'team' || g.$2.containsKey('employee_id')), isEmpty);
        expect(server.posts, isEmpty);
        // Leave type selection and its balance unchanged.
        await selectType(tester, 'Earned Leave');
        expect(find.text('12d left'), findsWidgets);
      });
    }

    // Task 83 (LV-18): the shared leaveStatsProvider (Analytics) now sends the
    // calendar year too; the unused shared leaveBalancesProvider stays year-less.
    test('shared balances stay year-less; Analytics stats send the calendar year', () async {
      server = Server();
      final c = ProviderContainer(overrides: [
        ...overrides(),
        leaveDashboardClockProvider.overrideWithValue(() => DateTime(2027, 2, 10, 9)),
      ]);
      addTearDown(c.dispose);
      await c.read(leaveBalancesProvider.future);
      await c.read(leaveStatsProvider.future).then((_) {}, onError: (_) {});
      expect(server.gets.where((g) => g.$1 == '/leave/balance/').single.$2, isEmpty);
      expect(server.gets.where((g) => g.$1 == '/leave/stats/').single.$2, {'year': 2027});
    });
  });
}

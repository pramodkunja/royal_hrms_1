import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
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
import 'package:mobile_app/features/leave/presentation/widgets/apply_leave_tab.dart';
import 'package:mobile_app/features/leave/presentation/widgets/apply_leave_type_selector.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_dashboard_tab.dart' show leaveDays;
import 'package:mobile_app/features/leave/presentation/widgets/leave_number_format.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_preview_panel.dart';

// Task 84.
// LV-08 — balances keep their fractions, printed as web prints a JS number:
//   GET /leave/balance/ sends total_days / used_days as 1-dp decimal strings
//   ("12.0", "9.5") and available_days as a float (2.5); web shows
//   `Number(available_days)` → "2.5d left", "2.5 of 12 days left",
//   "9.5 used", "2.5 remaining". Mobile used to round (2.5 → "3d left").
// LV-11 — the Apply Leave preview, as web: GET /leave/requests/?action=preview
//   &leave_type=&start_date=&end_date=&duration= (half day: end = start);
//   header "{actual_leave_days} working day(s)" (+ "{lop_days}d will be LOP"),
//   Calendar Days / Actual Leave Days / Available Balance / Leave Days Used /
//   LOP Days, Company Holidays (server's "15 Aug" text as-is), Week-Offs
//   ("22 Nov 2026 · Sunday"), the server warning, and web's insufficient-
//   balance notice. All values come from the server.
// Synthetic users, balances and dates; a stand-in server; nothing is sent
// anywhere real.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> policy(String code, String display, {bool lop = false}) => {
      'id': code.hashCode & 0xffff,
      'leave_type': code,
      'leave_type_display': display,
      'annual_days': '12.0',
      'is_active': true,
      'attachment_required': false,
      'medical_certificate_required': false,
      'allow_half_day': true,
      'allow_future_leave': true,
      'allow_backdated_leave': true,
      'convert_to_lop': lop,
      'policy_note': '',
    };

String iso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// A preview response; every figure set by the test.
Map<String, dynamic> previewBody(
  Map<String, dynamic> q, {
  int calendar = 3,
  num actual = 3,
  num available = 2.5,
  num used = 2.5,
  num lop = 0,
  bool lopEnabled = false,
  bool sufficient = true,
  String? warning,
  List<Map<String, String>> holidays = const [],
  List<Map<String, String>> weekOffs = const [],
}) =>
    {
      'leave_type': q['leave_type'],
      'start_date': q['start_date'],
      'end_date': q['end_date'],
      'duration': q['duration'],
      'calendar_days': calendar,
      'company_holidays': holidays,
      'company_holiday_count': holidays.length,
      'week_offs': weekOffs,
      'week_off_count': weekOffs.length,
      'sandwich_leave_enabled': false,
      'actual_leave_days': actual,
      'available_balance': available,
      'leave_days_used': used,
      'lop_days': lop,
      'lop_enabled': lopEnabled,
      'sufficient_balance': sufficient,
      'warning': warning,
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> policies = [
    policy('casual', 'Casual Leave'),
    policy('sick', 'Sick Leave'),
    policy('earned', 'Earned Leave', lop: true),
    policy('lwp', 'Leave Without Pay'),
  ];

  /// Balance rows as the server sends them (decimal strings + float).
  List<Map<String, dynamic>> balances = [
    {'leave_type': 'casual', 'leave_type_display': 'Casual Leave', 'total_days': '12.0', 'used_days': '9.5', 'available_days': 2.5},
    {'leave_type': 'sick', 'leave_type_display': 'Sick Leave', 'total_days': '7.0', 'used_days': '5.5', 'available_days': 1.5},
    {'leave_type': 'earned', 'leave_type_display': 'Earned Leave', 'total_days': '1.5', 'used_days': '1.0', 'available_days': 0.5},
  ];

  /// Builds the preview answer for a query; null → 500.
  Map<String, dynamic>? Function(Map<String, dynamic> q) preview = (q) => previewBody(q);
  int previewStatus = 200;
  String previewError = 'Server error.';

  /// When set, preview answers wait for the completer stored per start/end/type key.
  Map<String, Completer<void>>? holds;

  final gets = <(String, Map<String, dynamic>)>[];
  final posts = <FormData>[];

  List<Map<String, dynamic>> get previewQueries => [
        for (final g in gets)
          if (g.$1 == '/leave/requests/' && g.$2['action'] == 'preview') g.$2
      ];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET') gets.add((o.path, Map.of(o.queryParameters)));
    if (o.path == '/leave/policy/') return _json(200, {'status': 'success', 'data': policies});
    if (o.path == '/leave/balance/') return _json(200, {'status': 'success', 'data': balances});
    if (o.path == '/leave/requests/' && o.method == 'GET') {
      final q = o.queryParameters;
      if (q['action'] == 'preview') {
        final key = '${q['leave_type']}|${q['start_date']}|${q['end_date']}|${q['duration']}';
        final hold = holds?[key];
        if (hold != null) await hold.future;
        if (previewStatus != 200) {
          return _json(previewStatus, {'status': 'error', 'message': previewError, 'data': {}});
        }
        return _json(200, {'status': 'success', 'message': 'Leave preview calculated.', 'data': preview(q)});
      }
      return _json(200, {
        'status': 'success',
        'data': {'count': 0, 'page': 1, 'page_size': 20, 'total_pages': 1, 'results': []}
      });
    }
    if (o.path == '/leave/requests/' && o.method == 'POST') {
      final fd = o.data as FormData;
      posts.add(fd);
      String f(String k) => fd.fields.firstWhere((e) => e.key == k).value;
      return _json(201, {
        'status': 'success',
        'data': {
          'id': 'req-1', 'employee_name': 'Test Employee', 'leave_type': f('leave_type'), //
          'leave_type_display': f('leave_type'), 'start_date': f('start_date'), 'end_date': f('end_date'),
          'total_days': 3, 'status': 'pending', 'reason': 'x', 'applied_on': '2026-11-17',
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

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'e1',
          email: 'employee@example.test',
          fullName: 'Test Employee',
          role: 'employee',
          roleDisplay: 'employee',
          mustChangePassword: false,
          permissions: ['leave.view', 'leave.apply'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

late Server server;

Future<void> pump(WidgetTester tester, {void Function(Server)? setup}) async {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: Scaffold(body: ApplyLeaveTab())),
  ));
  await tester.pumpAndSettle();
}

/// Bounded settle: a pending preview shows a spinner that never settles.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Future<void> tapText(WidgetTester tester, String label) async {
  final f = find.text(label).first;
  await tester.ensureVisible(f);
  await tester.tap(f);
  await settle(tester);
}

/// Picks [d] in the start (0) or end (1) date field via the picker's
/// keyboard-input mode (en-US MM/DD/YYYY).
Future<void> pickDate(WidgetTester tester, int field, DateTime d) async {
  final f = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_DateField').at(field);
  await tester.ensureVisible(f);
  await tester.tap(f);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  final mm = d.month.toString().padLeft(2, '0'), dd = d.day.toString().padLeft(2, '0');
  await tester.enterText(find.descendant(of: find.byType(Dialog), matching: find.byType(TextField)), '$mm/$dd/${d.year}');
  await tester.tap(find.text('OK'));
  await settle(tester);
}

/// The next Monday at least 2 days ahead (inside the picker's window).
DateTime nextMonday() {
  final t = DateTime.now();
  var d = DateTime(t.year, t.month, t.day + 2);
  while (d.weekday != DateTime.monday) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

final mon = nextMonday();
final wed = DateTime(mon.year, mon.month, mon.day + 2);
final fri = DateTime(mon.year, mon.month, mon.day + 4);

/// Casual, Monday → Wednesday, full day.
Future<void> fillRange(WidgetTester tester, {String type = 'Casual Leave', DateTime? to}) async {
  await tapText(tester, type);
  await pickDate(tester, 0, mon);
  await pickDate(tester, 1, to ?? wed);
}

String text(WidgetTester tester, String key) => tester.widget<Text>(find.byKey(Key(key))).data!;

/// The preview grid, label → value.
Map<String, String> grid(WidgetTester tester) => {
      'Calendar Days': text(tester, 'leave-preview-calendar-days'),
      'Actual Leave Days': text(tester, 'leave-preview-actual-days'),
      'Available Balance': text(tester, 'leave-preview-available'),
      'Leave Days Used': text(tester, 'leave-preview-used'),
      'LOP Days': text(tester, 'leave-preview-lop'),
    };

final panel = find.byKey(const Key('leave-preview-panel'));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('LV-08 number formatting', () {
    test('whole, fractional, zero, negative, null and large values, as web prints them', () {
      final cases = <num?, String>{
        12: '12', 12.0: '12', 0: '0', 0.0: '0', -0.0: '0', 0.5: '0.5', 1.5: '1.5', 2.5: '2.5', 2.25: '2.25',
        -1.5: '-1.5', -3: '-3', 365: '365', 1234.5: '1234.5', null: '0',
      };
      cases.forEach((v, s) => expect(formatLeaveDays(v), s, reason: '$v'));
      expect(leaveDays(2.5), '2.5');
      expect(leaveDays(12), '12');
    });

    test('never rounds a half up, and removes floating-point noise', () {
      expect(formatLeaveDays(2.5), isNot('3'));
      expect(formatLeaveDays(0.5), isNot('1'));
      expect(formatLeaveDays(12.0 - 9.7), '2.3'); // 2.3000000000000007
      expect(formatLeaveDays(1.1 - 0.9), '0.2'); // 0.20000000000000007
      expect(formatLeaveDays(2.9999999), '3'); // not "3." or "3.00"
      expect(formatLeaveDays(0.1 + 0.2), '0.3'); // 0.30000000000000004
      expect(formatLeaveDays(2.499999999), '2.5');
      expect(leaveDays(12.0 - 9.7), '2.3');
    });

    test('balance rows: decimal strings and numbers both parse exactly; available_days preferred', () {
      final s = LeaveBalanceModel.fromJson(
          {'leave_type': 'casual', 'total_days': '12.0', 'used_days': '9.5', 'available_days': 2.5});
      expect((s.total, s.used, s.available), (12.0, 9.5, 2.5));
      final n = LeaveBalanceModel.fromJson({'leave_type': 'casual', 'total_days': 12, 'used_days': 9.5});
      expect(n.available, 2.5); // no available_days → total − used
      final str = LeaveBalanceModel.fromJson(
          {'leave_type': 'casual', 'total_days': '12.0', 'used_days': '9.7', 'available_days': '2.3'});
      expect(str.available, 2.3); // the server's figure, not 12.0 − 9.7 = 2.3000000000000007
      final nul = LeaveBalanceModel.fromJson({'leave_type': 'casual', 'total_days': null, 'used_days': null});
      expect((nul.total, nul.used, nul.available), (0.0, 0.0, 0.0));
      final neg = LeaveBalanceModel.fromJson(
          {'leave_type': 'casual', 'total_days': '2.0', 'used_days': '3.5', 'available_days': -1.5});
      expect(neg.available, -1.5);
    });

    test('type options keep fractions (no .round()); no balance row keeps the old fallback', () {
      final types = [LeaveTypeModel.fromJson(policy('casual', 'Casual Leave'))];
      const bal = LeaveBalanceEntity(typeCode: 'casual', typeName: 'Casual Leave', used: 9.5, total: 12, availableDays: 2.5);
      final o = LeaveTypeOption.listFromEntities(types, const [bal]).firstWhere((o) => o.code == 'casual');
      expect((o.balance, o.total, o.used), (2.5, 12.0, 9.5));
      final none = LeaveTypeOption.listFromEntities(types, const []).firstWhere((o) => o.code == 'casual');
      expect((none.balance, none.total, none.used), (0.0, 12.0, 0.0));
    });

    testWidgets('Apply Leave cards and side card show 2.5 / 1.5 / 0.5 exactly', (tester) async {
      await pump(tester);
      expect(find.text('2.5d left'), findsOneWidget);
      expect(find.text('1.5d left'), findsOneWidget);
      expect(find.text('0.5d left'), findsOneWidget);
      expect(find.text('3d left'), findsNothing);
      expect(find.text('Unpaid · Unlimited'), findsOneWidget);
      await tapText(tester, 'Casual Leave');
      expect(find.text('2.5 of 12 days left'), findsOneWidget);
      expect(find.text('9.5 used'), findsOneWidget);
      expect(find.text('2.5 remaining'), findsOneWidget);
      await tapText(tester, 'Sick Leave');
      expect(find.text('1.5 of 7 days left'), findsOneWidget);
      expect(find.text('5.5 used'), findsOneWidget);
    });

    testWidgets('zero, negative and large balances; balances asked for the calendar year (Task 83)', (tester) async {
      await pump(tester, setup: (s) {
        s.balances = [
          {'leave_type': 'casual', 'leave_type_display': 'Casual Leave', 'total_days': '0.0', 'used_days': '0.0', 'available_days': 0.0},
          {'leave_type': 'sick', 'leave_type_display': 'Sick Leave', 'total_days': '2.0', 'used_days': '3.5', 'available_days': -1.5},
          {'leave_type': 'earned', 'leave_type_display': 'Earned Leave', 'total_days': '400.0', 'used_days': '0.5', 'available_days': 399.5},
        ];
      });
      expect(find.text('0d left'), findsWidgets);
      expect(find.text('-1.5d left'), findsOneWidget);
      expect(find.text('399.5d left'), findsOneWidget);
      expect(
          server.gets.where((g) => g.$1 == '/leave/balance/').map((g) => g.$2),
          everyElement({'year': DateTime.now().year}));
    });

    testWidgets('the local balance check uses 2.5, not 3: three days exceed it (preview unavailable)', (tester) async {
      await pump(tester, setup: (s) {
        s.previewStatus = 500;
      });
      await fillRange(tester);
      expect(find.text('3 working days'), findsOneWidget);
      expect(find.textContaining('Exceeds balance by 0.5d. Only 2.5d available.'), findsWidgets);
    });
  });

  group('LV-11 preview', () {
    testWidgets('request: web\'s endpoint and parameters; full day → the end date', (tester) async {
      await pump(tester);
      await fillRange(tester);
      expect(server.previewQueries.last, {
        'action': 'preview',
        'leave_type': 'casual',
        'start_date': iso(mon),
        'end_date': iso(wed),
        'duration': 'full_day',
      });
      expect(server.posts, isEmpty, reason: 'a preview never submits leave');
    });

    testWidgets('full breakdown rendered from the server\'s figures', (tester) async {
      await pump(tester, setup: (s) => s.preview = (q) => previewBody(q, calendar: 3, actual: 3, available: 2.5, used: 2.5));
      await fillRange(tester);
      expect(panel, findsOneWidget);
      expect(text(tester, 'leave-preview-headline'), '3 working days');
      expect(grid(tester), {
        'Calendar Days': '3',
        'Actual Leave Days': '3',
        'Available Balance': '2.5',
        'Leave Days Used': '2.5', // backend leave_days_used (was never parsed before)
        'LOP Days': '0',
      });
      expect(find.byKey(const Key('leave-preview-lop-badge')), findsNothing);
      // The local estimate chip is replaced, as on web.
      expect(find.textContaining('will remain'), findsNothing);
      expect(find.byKey(const Key('leave-preview-loading')), findsNothing);
    });

    testWidgets('half day: end = start, duration sent, 0.5 shown', (tester) async {
      await pump(tester, setup: (s) => s.preview = (q) => previewBody(q, calendar: 1, actual: 0.5, used: 0.5));
      await tapText(tester, 'Casual Leave');
      await tapText(tester, 'Half · PM');
      await pickDate(tester, 0, mon);
      expect(server.previewQueries.last, {
        'action': 'preview',
        'leave_type': 'casual',
        'start_date': iso(mon),
        'end_date': iso(mon),
        'duration': 'half_afternoon',
      });
      expect(text(tester, 'leave-preview-headline'), '0.5 working days');
      expect(grid(tester)['Actual Leave Days'], '0.5');
      expect(grid(tester)['Leave Days Used'], '0.5');
    });

    testWidgets('holidays (server text as-is) and week-offs (web date format + day)', (tester) async {
      final sat = DateTime(mon.year, mon.month, mon.day + 5), sun = DateTime(mon.year, mon.month, mon.day + 6);
      await pump(tester, setup: (s) => s.preview = (q) => previewBody(q, calendar: 7, actual: 4, available: 12, used: 4, holidays: [
            {'date': '15 Aug', 'name': 'Founders Day'},
          ], weekOffs: [
            {'date': iso(sat), 'day': 'Saturday'},
            {'date': iso(sun), 'day': 'Sunday'},
          ]));
      await fillRange(tester, to: DateTime(mon.year, mon.month, mon.day + 6));
      expect(find.text('COMPANY HOLIDAYS'), findsOneWidget);
      expect(find.text('Founders Day'), findsOneWidget);
      expect(find.text('15 Aug'), findsOneWidget);
      expect(find.text('WEEK-OFFS'), findsOneWidget);
      expect(find.text('${leavePreviewDate(iso(sat))} · Saturday'), findsOneWidget);
      expect(find.text('${leavePreviewDate(iso(sun))} · Sunday'), findsOneWidget);
      expect(grid(tester)['Calendar Days'], '7');
      expect(grid(tester)['Actual Leave Days'], '4');
      expect(leavePreviewDate('2026-11-22'), '22 Nov 2026');
      expect(leavePreviewDate('2027-01-05'), '5 Jan 2027');
      expect(leavePreviewDate('15 Aug'), '15 Aug');
    });

    testWidgets('no holidays / week-offs: those sections are absent', (tester) async {
      await pump(tester);
      await fillRange(tester);
      expect(find.text('COMPANY HOLIDAYS'), findsNothing);
      expect(find.text('WEEK-OFFS'), findsNothing);
    });

    testWidgets('monthly-credit policy: the server\'s accrued available balance is shown, not the local one',
        (tester) async {
      // A monthly-credit type's balance row says 2.5 available; the preview
      // (backend: LeaveBalance for the start date's year) answers 1.5 — the
      // panel shows the server's figure and decides sufficiency by it.
      await pump(tester, setup: (s) => s.preview = (q) => previewBody(q, actual: 3, available: 1.5, used: 3, sufficient: false));
      await fillRange(tester);
      expect(grid(tester)['Available Balance'], '1.5');
      expect(find.byKey(const Key('leave-preview-insufficient')), findsOneWidget);
      expect(find.text('Insufficient leave balance for the selected dates. This request cannot be submitted.'),
          findsOneWidget);
    });

    testWidgets('LOP policy: badge and LOP figure; no insufficient notice when lop_enabled', (tester) async {
      await pump(tester, setup: (s) => s.preview = (q) => previewBody(q,
          actual: 3, available: 0.5, used: 0.5, lop: 2.5, lopEnabled: true, sufficient: false));
      await fillRange(tester, type: 'Earned Leave');
      expect(text(tester, 'leave-preview-lop-badge'), '2.5d will be LOP');
      expect(grid(tester)['LOP Days'], '2.5');
      expect(grid(tester)['Leave Days Used'], '0.5');
      expect(find.byKey(const Key('leave-preview-insufficient')), findsNothing);
    });

    testWidgets('server warning shown as web\'s info box', (tester) async {
      const w = 'The selected leave exceeds the maximum consecutive leave limit of 2 day(s).';
      await pump(tester, setup: (s) => s.preview = (q) => previewBody(q, warning: w));
      await fillRange(tester);
      expect(find.descendant(of: find.byKey(const Key('leave-preview-warning')), matching: find.text(w)), findsOneWidget);
    });

    testWidgets('null / empty warning: no box', (tester) async {
      await pump(tester);
      await fillRange(tester);
      expect(find.byKey(const Key('leave-preview-warning')), findsNothing);
    });

    testWidgets('validation failure (400): the server message, the estimate kept, no panel', (tester) async {
      await pump(tester, setup: (s) {
        s.previewStatus = 400;
        s.previewError = 'end_date must be on or after start_date.';
      });
      await fillRange(tester);
      expect(panel, findsNothing);
      expect(find.textContaining('end_date must be on or after start_date.'), findsOneWidget);
      expect(find.text('3 working days'), findsOneWidget); // local estimate
    });

    testWidgets('network failure then Retry: one more request, then the panel', (tester) async {
      await pump(tester, setup: (s) => s.previewStatus = 500);
      await fillRange(tester);
      expect(find.byKey(const Key('leave-preview-error')), findsOneWidget);
      final before = server.previewQueries.length;
      server.previewStatus = 200;
      await tester.tap(find.byKey(const Key('leave-preview-retry')));
      await tester.pumpAndSettle();
      expect(server.previewQueries.length, before + 1);
      expect(panel, findsOneWidget);
      expect(find.byKey(const Key('leave-preview-error')), findsNothing);
    });

    testWidgets('loading: web\'s "Checking balance and holidays…", no stale panel', (tester) async {
      final key = 'casual|${iso(mon)}|${iso(wed)}|full_day';
      final hold = Completer<void>();
      await pump(tester, setup: (s) => s.holds = {key: hold});
      await tapText(tester, 'Casual Leave');
      await pickDate(tester, 0, mon);
      await pickDate(tester, 1, wed);
      expect(find.text('Checking balance and holidays…'), findsOneWidget);
      expect(panel, findsNothing);
      hold.complete();
      await settle(tester);
      expect(find.text('Checking balance and holidays…'), findsNothing);
      expect(panel, findsOneWidget);
    });

    testWidgets('changing type, then dates, then duration: a new request each time, never the old figures',
        (tester) async {
      await pump(tester, setup: (s) => s.preview = (q) => previewBody(q,
          actual: q['end_date'] == q['start_date'] ? (q['duration'] == 'full_day' ? 1 : 0.5) : (q['end_date'] == iso(fri) ? 5 : 3),
          available: q['leave_type'] == 'sick' ? 1.5 : 2.5));
      await fillRange(tester);
      expect(grid(tester)['Available Balance'], '2.5');
      await tapText(tester, 'Sick Leave');
      expect(server.previewQueries.last['leave_type'], 'sick');
      expect(grid(tester)['Available Balance'], '1.5');
      await pickDate(tester, 1, fri);
      expect(server.previewQueries.last['end_date'], iso(fri));
      expect(grid(tester)['Actual Leave Days'], '5');
      await tapText(tester, 'Half · AM');
      expect(server.previewQueries.last, containsPair('duration', 'half_morning'));
      expect(server.previewQueries.last, containsPair('end_date', iso(mon)));
      expect(grid(tester)['Actual Leave Days'], '0.5');
    });

    testWidgets('out-of-order answers: a late answer for old inputs never replaces the current one', (tester) async {
      final oldKey = 'casual|${iso(mon)}|${iso(wed)}|full_day';
      final newKey = 'sick|${iso(mon)}|${iso(wed)}|full_day';
      final oldHold = Completer<void>(), newHold = Completer<void>();
      await pump(tester, setup: (s) {
        s.holds = {oldKey: oldHold, newKey: newHold};
        s.preview = (q) => previewBody(q, available: q['leave_type'] == 'sick' ? 1.5 : 2.5);
      });
      await fillRange(tester); // casual preview pending
      await tapText(tester, 'Sick Leave'); // sick preview pending
      newHold.complete();
      await settle(tester);
      expect(grid(tester)['Available Balance'], '1.5');
      oldHold.complete(); // the stale casual answer arrives last
      await tester.pumpAndSettle();
      expect(grid(tester)['Available Balance'], '1.5');
      expect(find.byKey(const Key('leave-preview-panel')), findsOneWidget);
    });

    testWidgets('submission unchanged: one POST with the form values, after previewing', (tester) async {
      await pump(tester);
      await fillRange(tester, type: 'Sick Leave'); // preview: 3 days, sufficient
      final reason = find.widgetWithText(TextFormField, 'Briefly describe the reason for your leave…');
      await tester.ensureVisible(reason);
      await tester.enterText(reason, 'Synthetic reason for testing.');
      await tester.pumpAndSettle();
      await tapText(tester, 'Submit');
      expect(server.posts, hasLength(1));
      final f = {for (final e in server.posts.single.fields) e.key: e.value};
      expect(f['leave_type'], 'sick');
      expect(f['start_date'], iso(mon));
      expect(f['end_date'], iso(wed));
      expect(f['duration'], 'full_day');
    });

    testWidgets('insufficient (no LOP): submit is refused locally, nothing posted', (tester) async {
      await pump(tester, setup: (s) => s.preview = (q) => previewBody(q, actual: 3, available: 2.5, sufficient: false));
      await fillRange(tester);
      final reason = find.widgetWithText(TextFormField, 'Briefly describe the reason for your leave…');
      await tester.ensureVisible(reason);
      await tester.enterText(reason, 'Synthetic reason for testing.');
      await tester.pumpAndSettle();
      await tapText(tester, 'Submit');
      expect(server.posts, isEmpty);
    });
  });

  test('preview model: leave_days_used parsed; numbers and numeric strings', () {
    final m = LeavePreviewModel.fromJson({
      'calendar_days': 3, 'actual_leave_days': '2.5', 'available_balance': 1.5, 'leave_days_used': 1.5, //
      'lop_days': 1.0, 'lop_enabled': true, 'sufficient_balance': false, 'warning': null,
    });
    expect((m.actualLeaveDays, m.availableBalance, m.leaveDaysUsed, m.lopDays), (2.5, 1.5, 1.5, 1.0));
    expect(m.warning, '');
  });
}

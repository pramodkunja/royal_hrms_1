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
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/data/models/upcoming_holidays.dart';
import 'package:mobile_app/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/dashboard_section.dart';

// Task 5: Employee dashboard "Upcoming Holidays" — web
// components/dashboard/employee/EmpUpcomingHolidays.tsx over GET
// /leave/holidays/ (no parameters; HolidayListCreateView scopes it to
// company-wide + the caller's branch). Active holidays from today on, by
// date, first three; "05" / "NOV" tile, "<day> · <type>", "Today" / "In Nd".
// "Today" is fixed at Thursday 5 November 2026. Synthetic data only.

/// India (+05:30), fixed — tests never depend on the machine's time zone.
const ist = Duration(hours: 5, minutes: 30);
HolidayDayRefs india(DateTime utcInstant) => HolidayDayRefs.withOffset(utcInstant, ist);

/// 09:15 IST on 5 Nov 2026 (03:45 UTC): UTC and local dates agree.
final now = india(DateTime.utc(2026, 11, 5, 3, 45));
final today = DateTime(2026, 11, 5);

Map<String, dynamic> hol(String id, String date, String name,
        {String? day, String type = 'National', bool active = true, String branch = 'All Branches'}) =>
    {
      'id': id,
      'name': name,
      'date': date,
      if (day != null) 'day': day,
      'holiday_type': type.toLowerCase(),
      'holiday_type_display': type,
      'is_optional': false,
      'mandatory_optional': 'Mandatory',
      'description': '',
      'branch': branch == 'All Branches' ? null : 7,
      'branch_name': branch,
      'is_active': active,
      'created_at': '2026-01-01T00:00:00Z',
    };

/// Out of order on purpose; includes past, inactive and a same-day pair.
List<Map<String, dynamic>> sample() => [
      hol('h5', '2026-12-25', 'Test Year End', day: 'Fri'),
      hol('h1', '2026-11-04', 'Test Yesterday', day: 'Wed'),
      hol('h3', '2026-11-14', 'Test Festival A', day: 'Sat', type: 'Regional'),
      hol('h0', '2025-12-25', 'Test Last Year', day: 'Thu'),
      hol('h2', '2026-11-05', 'Test Today', day: 'Thu', type: 'Company'),
      hol('h6', '2026-11-10', 'Test Inactive', day: 'Tue', active: false),
      hol('h4', '2026-11-14', 'Test Festival B', day: 'Sat', branch: 'North Wing'),
    ];

List<DashboardHoliday> parse(List<Object?> raw) => DashboardHoliday.listFrom({'holidays': raw});

class Backend implements HttpClientAdapter {
  Backend(this.holidays);
  List<Object?> holidays;
  int status = 200;
  Completer<void>? hold;
  final holidayQueries = <Map<String, dynamic>>[];
  final paths = <String>[];

  ResponseBody _r(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    paths.add(o.path);
    if (o.path == ApiConstants.holidays) {
      holidayQueries.add(Map.of(o.queryParameters));
      if (hold != null) await hold!.future;
      if (status != 200) return _r(status, {'status': 'error', 'message': 'Server error.', 'data': {}});
      return _r(200, {
        'status': 'success',
        'message': 'Holidays retrieved.',
        'data': {'holidays': holidays, 'total': holidays.length},
      });
    }
    return _r(200, {'status': 'success', 'message': 'ok', 'data': {}});
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

UserEntity employee({String? branch}) => UserEntity(
      id: 'u1',
      email: 'emp@example.test',
      fullName: 'Test Employee',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: const ['leave.view'],
      branch: branch,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

late Backend backend;
late ProviderContainer container;

Future<void> pumpDashboard(WidgetTester tester, List<Object?> holidays,
    {void Function(Backend)? setup, UserEntity? user, HolidayDayRefs? dates}) async {
  tester.view.physicalSize = const Size(1080, 7000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  backend = Backend(holidays);
  setup?.call(backend);
  final router = GoRouter(initialLocation: AppRoutes.dashboard, routes: [
    GoRoute(
      path: AppRoutes.dashboard,
      builder: (_, __) => Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : const Scaffold(body: HomeScreen()),
      ),
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(user ?? employee())),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      upcomingHolidayDatesProvider.overrideWithValue(dates ?? now),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await settle(tester);
  container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

// The dashboard starts periodic timers; unmount before the test ends.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

final card = find.byKey(const Key('emp-upcoming-holidays'));

/// The dashboard's loading state (SectionMessage 'Loading…' draws a skeleton).
final loadingSkeleton = find.byWidgetPredicate((w) => w is SectionMessage && w.label == 'Loading…');

Finder inCard(Finder f) => find.descendant(of: card, matching: f);

/// Holiday names in the card, top to bottom.
List<String> shownNames(WidgetTester tester) {
  final names = <String>[];
  for (final e in inCard(find.byWidgetPredicate((w) => w is Text && (w.data ?? '').startsWith('Test '))).evaluate()) {
    names.add((e.widget as Text).data!);
  }
  return names;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (web EmpUpcomingHolidays)', () {
    test('2–5. active, today onwards, by date, same date in server order, first three', () {
      final up = upcomingHolidays(parse(sample()), now);
      expect(up.map((h) => h.name), ['Test Today', 'Test Festival A', 'Test Festival B']);
      expect(kUpcomingHolidayCount, 3);
      // Past ("Test Yesterday", last year) and inactive are never chosen.
      final all = upcomingHolidays(parse(sample()), india(DateTime.utc(2026, 11, 1, 6)));
      expect(all.map((h) => h.name), isNot(contains('Test Inactive')));
    });

    test('4. today is included at any time of day; yesterday is not', () {
      final h = parse([hol('a', '2026-11-05', 'Test Today'), hol('b', '2026-11-04', 'Test Yesterday')]);
      // 18:00 IST (12:30 UTC): both dates are 5 Nov.
      final evening = india(DateTime.utc(2026, 11, 5, 12, 30));
      expect(upcomingHolidays(h, evening).map((x) => x.name), ['Test Today']);
      expect(upcomingHolidays(h, evening).single.badge(evening.localDate), 'Today');
      expect(upcomingHolidays(h, india(DateTime.utc(2026, 11, 6, 6))), isEmpty);
    });

    test('6. web en-IN formatting: two-digit day, short month upper-case (Sept), badge', () {
      final h = parse([
        hol('a', '2026-11-05', 'Test A', day: 'Thu'),
        hol('b', '2027-09-03', 'Test B', day: 'Fri', type: 'Regional'),
        hol('c', '2027-01-01', 'Test C', day: 'Fri'),
      ]);
      expect([h[0].dayOfMonth, h[0].monthShort], ['05', 'NOV']);
      expect([h[1].dayOfMonth, h[1].monthShort], ['03', 'SEPT']);
      expect(h[1].subtitle, 'Fri · Regional');
      expect(h[0].badge(today), 'Today');
      expect(h[2].badge(today), 'In 57d'); // across the year end
      expect(h[2].badge(DateTime(2026, 12, 31, 22)), 'In 1d');
    });

    test('next year’s holidays count: 30 Dec shows early January (no year filter)', () {
      final h = parse([hol('a', '2027-01-02', 'Test NY'), hol('b', '2026-12-31', 'Test NYE')]);
      expect(upcomingHolidays(h, india(DateTime.utc(2026, 12, 30, 6))).map((x) => x.name), ['Test NYE', 'Test NY']);
    });

    test('11. malformed entries: no/invalid date skipped, inactive unless true, safe fallbacks', () {
      final h = parse([
        null,
        'not a holiday',
        {'id': 'x1', 'name': 'Test No Date', 'is_active': true},
        hol('x2', '05/11/2026', 'Test Wrong Format'),
        hol('x3', '2026-02-30', 'Test Impossible'),
        {...hol('x4', '2026-11-20', 'Test Active Text'), 'is_active': 'true'},
        {'id': 7, 'date': '2026-11-21', 'is_active': true, 'name': 42},
        {...hol('x6', '2026-11-22', 'Test No Day'), 'holiday_type_display': null}..remove('day'),
      ]);
      expect(h.map((x) => x.id), ['x4', '7', 'x6']);
      expect(h[0].isActive, isFalse); // web keeps only is_active === true-ish booleans
      expect(h[1].name, '');
      expect(h[1].subtitle, 'Sat'); // weekday worked out, no dangling "·"
      expect(h[2].subtitle, 'Sun');
      expect(upcomingHolidays(h, now).map((x) => x.id), ['7', 'x6']);
      expect(DashboardHoliday.listFrom(null), isEmpty);
      expect(DashboardHoliday.listFrom({'holidays': 'oops'}), isEmpty);
      expect(DashboardHoliday.listFrom([]), isEmpty);
    });
  });

  group('UTC selection, local badge (web toISOString / daysUntil)', () {
    List<String> pick(List<Map<String, dynamic>> raw, HolidayDayRefs at) =>
        [for (final h in upcomingHolidays(parse(raw), at)) '${h.name} ${h.badge(at.localDate)}'];
    final days = [
      hol('a', '2026-11-05', 'Test Thu'),
      hol('b', '2026-11-06', 'Test Fri'),
      hol('c', '2026-11-07', 'Test Sat'),
    ];

    test('the two dates: same in the day, split in India from 00:00 to 05:29', () {
      final day = india(DateTime.utc(2026, 11, 5, 6)); // 11:30 IST
      expect([day.utcDate, day.localDate], [DateTime(2026, 11, 5), DateTime(2026, 11, 5)]);
      final midnight = india(DateTime.utc(2026, 11, 5, 18, 30)); // 00:00 IST, 6 Nov
      expect([midnight.utcDate, midnight.localDate], [DateTime(2026, 11, 5), DateTime(2026, 11, 6)]);
      final lastMinute = india(DateTime.utc(2026, 11, 5, 23, 59)); // 05:29 IST
      expect([lastMinute.utcDate, lastMinute.localDate], [DateTime(2026, 11, 5), DateTime(2026, 11, 6)]);
      final turn = india(DateTime.utc(2026, 11, 6)); // 05:30 IST
      expect([turn.utcDate, turn.localDate], [DateTime(2026, 11, 6), DateTime(2026, 11, 6)]);
    });

    test('dates agree: the holiday on the UTC date is "Today"', () {
      expect(pick(days, india(DateTime.utc(2026, 11, 5, 6))), ['Test Thu Today', 'Test Fri In 1d', 'Test Sat In 2d']);
    });

    test('India 00:30: UTC is still yesterday, so yesterday’s holiday stays, badged "In -1d" as on web', () {
      expect(pick(days, india(DateTime.utc(2026, 11, 5, 19))), ['Test Thu In -1d', 'Test Fri Today', 'Test Sat In 1d']);
    });

    test('India 05:29 → 05:30: the UTC date turns and yesterday’s holiday drops out', () {
      expect(pick(days, india(DateTime.utc(2026, 11, 5, 23, 59))).first, 'Test Thu In -1d');
      expect(pick(days, india(DateTime.utc(2026, 11, 6))), ['Test Fri Today', 'Test Sat In 1d']);
    });

    test('a holiday on the local date but before the UTC date is excluded (UTC−5 evening)', () {
      // 21:00 on 4 Nov at UTC−5 is 02:00 UTC on 5 Nov.
      final at = HolidayDayRefs.withOffset(DateTime.utc(2026, 11, 5, 2), const Duration(hours: -5));
      expect([at.utcDate, at.localDate], [DateTime(2026, 11, 5), DateTime(2026, 11, 4)]);
      final raw = [hol('w', '2026-11-04', 'Test Wed'), ...days];
      expect(pick(raw, at), ['Test Thu In 1d', 'Test Fri In 2d', 'Test Sat In 3d']);
    });

    test('year end: 00:30 IST on 1 Jan keeps 31 Dec ("In -1d"); from 05:30 it is gone', () {
      final raw = [
        hol('y', '2026-12-31', 'Test NYE'),
        hol('n', '2027-01-01', 'Test NY'),
        hol('m', '2027-01-04', 'Test Mon')
      ];
      expect(pick(raw, india(DateTime.utc(2026, 12, 31, 19))), ['Test NYE In -1d', 'Test NY Today', 'Test Mon In 3d']);
      expect(pick(raw, india(DateTime.utc(2027, 1, 1))), ['Test NY Today', 'Test Mon In 3d']);
    });

    test('same-date server order and the first-three rule hold in the split window', () {
      final raw = [
        hol('z', '2026-11-06', 'Test Second'),
        hol('y', '2026-11-05', 'Test Early'),
        hol('x', '2026-11-06', 'Test Third'),
        hol('w', '2026-11-06', 'Test Fourth'),
      ];
      expect(pick(raw, india(DateTime.utc(2026, 11, 5, 19))),
          ['Test Early In -1d', 'Test Second Today', 'Test Third Today']);
    });

    test('HolidayDayRefs.at: the UTC date of the instant and the device’s local date', () {
      final instant = DateTime.utc(2026, 11, 5, 19);
      final at = HolidayDayRefs.at(instant);
      expect(at.utcDate, DateTime(2026, 11, 5));
      final local = instant.toLocal();
      expect(at.localDate, DateTime(local.year, local.month, local.day));
    });
  });

  group('dashboard card', () {
    testWidgets('1–6. loads once and shows three holidays: tile, name, subtitle, badge', (tester) async {
      await pumpDashboard(tester, sample());
      expect(card, findsOneWidget);
      expect(inCard(find.text('Upcoming Holidays')), findsOneWidget);
      expect(shownNames(tester), ['Test Today', 'Test Festival A', 'Test Festival B']);
      expect(inCard(find.text('05')), findsOneWidget);
      expect(inCard(find.text('NOV')), findsNWidgets(3));
      expect(inCard(find.text('14')), findsNWidgets(2));
      expect(inCard(find.text('Thu · Company')), findsOneWidget);
      expect(inCard(find.text('Sat · Regional')), findsOneWidget);
      expect(inCard(find.text('Today')), findsOneWidget);
      expect(inCard(find.text('In 9d')), findsNWidgets(2));
      for (final gone in ['Test Yesterday', 'Test Last Year', 'Test Inactive', 'Test Year End']) {
        expect(find.text(gone), findsNothing);
      }
      expect(inCard(find.textContaining('View')), findsNothing); // web has no "View all"
      await unmount(tester);
    });

    testWidgets('7. no parameters sent (no branch, no year); the server-scoped list is shown as sent', (tester) async {
      await pumpDashboard(
          tester,
          [
            hol('a', '2026-11-12', 'Test Company Wide'),
            hol('b', '2026-11-13', 'Test North Wing', branch: 'North Wing'),
          ],
          user: employee(branch: 'North Wing'));
      expect(backend.holidayQueries, [<String, dynamic>{}]);
      expect(shownNames(tester), ['Test Company Wide', 'Test North Wing']);
      await unmount(tester);
    });

    testWidgets('India 00:30: the card keeps yesterday’s holiday with "In -1d", as web does', (tester) async {
      await pumpDashboard(tester, sample(), dates: india(DateTime.utc(2026, 11, 5, 19)));
      expect(shownNames(tester), ['Test Today', 'Test Festival A', 'Test Festival B']);
      expect(inCard(find.text('In -1d')), findsOneWidget);
      expect(inCard(find.text('In 8d')), findsNWidgets(2));
      expect(inCard(find.text('Today')), findsNothing);
      await unmount(tester);
    });

    testWidgets('8. nothing upcoming: web’s empty text', (tester) async {
      await pumpDashboard(
          tester, [hol('a', '2026-11-01', 'Test Past'), hol('b', '2026-12-01', 'Test Off', active: false)]);
      expect(inCard(find.text('No upcoming holidays scheduled.')), findsOneWidget);
      expect(shownNames(tester), isEmpty);
      await unmount(tester);
    });

    testWidgets('9. loading shows "Loading…" in the card until the list arrives', (tester) async {
      await pumpDashboard(tester, sample(), setup: (b) => b.hold = Completer());
      expect(inCard(loadingSkeleton), findsOneWidget);
      backend.hold!.complete();
      await settle(tester);
      expect(inCard(loadingSkeleton), findsNothing);
      expect(shownNames(tester), hasLength(3));
      await unmount(tester);
    });

    testWidgets('9–10. a failed load shows the error with Retry; Retry loads the holidays', (tester) async {
      await pumpDashboard(tester, sample(), setup: (b) => b.status = 500);
      expect(inCard(find.text('Server error. Please try again later.')), findsOneWidget);
      expect(shownNames(tester), isEmpty);
      backend.status = 200;
      await tester.tap(inCard(find.text('Retry')));
      await settle(tester);
      expect(shownNames(tester), ['Test Today', 'Test Festival A', 'Test Festival B']);
      expect(backend.holidayQueries, hasLength(2));
      await unmount(tester);
    });

    testWidgets('11. a malformed response shows what is usable and never breaks the dashboard', (tester) async {
      await pumpDashboard(tester, [
        null,
        {'name': 'Test Broken'},
        hol('ok', '2026-11-08', 'Test Good', day: 'Sun'),
      ]);
      expect(shownNames(tester), ['Test Good']);
      expect(find.text('Leave Balances — ${DateTime.now().year}'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('12. existing cards stay, in order: Leave Balances, Upcoming Holidays, then Action Items',
        (tester) async {
      await pumpDashboard(tester, sample());
      final leave = find.text('Leave Balances — ${DateTime.now().year}');
      expect(leave, findsOneWidget);
      final attendance = find.text('Action Items');
      expect(attendance, findsWidgets);
      final yLeave = tester.getTopLeft(leave).dy;
      final yCard = tester.getTopLeft(card).dy;
      final yAttendance = tester.getTopLeft(attendance.last).dy;
      expect(yLeave < yCard && yCard < yAttendance, isTrue);
      await unmount(tester);
    });

    testWidgets('13. one request on load; rebuilds don’t refetch; a refresh fetches exactly once more', (tester) async {
      await pumpDashboard(tester, sample());
      expect(backend.holidayQueries, hasLength(1));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await settle(tester);
      expect(backend.holidayQueries, hasLength(1));
      container.invalidate(employeeHolidaysProvider);
      await settle(tester);
      expect(backend.holidayQueries, hasLength(2));
      await unmount(tester);
    });
  });
}

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
import 'package:mobile_app/features/dashboard/data/models/employee_dashboard_models.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/employee_dashboard_view.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/home_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/emp_celebration_cards.dart';
import 'package:mobile_app/features/employees/presentation/widgets/send_wish_sheet.dart';

// Employee dashboard celebrations, as web EmployeeDashboard.tsx:
//  - TeamBirthdayCard / ManagerBirthdayCard ← GET /dashboard/birthdays/mine/
//    (MyBirthdayWidgetsView: IsAuthenticated + HasCompletedOnboarding; team =
//    same reporting manager, manager = own reporting manager; "today" is the
//    server's local date)
//  - EmpPromotionCelebration ← GET /notifications/?notification_type=promotion
//    &is_read=false&page_size=1; "Got it" → PATCH /notifications/<id>/read/
// Synthetic people only; no real notification or email is sent.

const minePath = ApiConstants.dashboardMyBirthdayWidgets;
const notifPath = ApiConstants.notifications;
const empTodayPath = ApiConstants.dashboardEmployeeBirthdaysToday;

Map<String, dynamic> person(String id, String name, {String message = 'Wish them well!'}) => {
      'employee_id': id,
      'full_name': name,
      'email': '${id.toLowerCase()}@example.test',
      'department': 'Finance',
      'designation': 'Analyst',
      'date_of_birth': '1990-11-09',
      'message': message,
    };

Map<String, dynamic> promotion({String id = 'n-1'}) => {
      'id': id,
      'title': 'Congratulations on your promotion!',
      'message': 'You have been promoted to Senior Analyst.',
      'notification_type': 'promotion',
      'is_read': false,
      'created_at': '2026-11-08T18:45:00Z',
    };

class Backend implements HttpClientAdapter {
  List<Map<String, dynamic>> team = [];
  Map<String, dynamic>? manager;
  List<Map<String, dynamic>> promotions = [];
  int mineStatus = 200;
  int notifStatus = 200;
  Completer<void>? holdMine;
  Completer<void>? holdPatch;
  int patchStatus = 200;
  final calls = <({String method, String path, Map<String, dynamic> query})>[];

  int count(String method, String path) => calls.where((c) => c.method == method && c.path == path).length;

  ResponseBody _r(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters)));
    if (o.path == minePath) {
      if (holdMine != null) await holdMine!.future;
      if (mineStatus != 200) return _r(mineStatus, {'status': 'error', 'message': 'Refused.'});
      return _r(200, {
        'status': 'success',
        'message': 'Birthday widgets retrieved.',
        'data': {'team': team, 'manager': manager},
      });
    }
    if (o.path == notifPath && o.method == 'GET') {
      if (notifStatus != 200) return _r(notifStatus, {'status': 'error', 'message': 'Refused.'});
      return _r(200, {
        'status': 'success',
        'data': {'count': promotions.length, 'results': promotions.take(1).toList(), 'unread_count': promotions.length},
      });
    }
    if (o.method == 'PATCH' && o.path.startsWith(notifPath) && o.path.endsWith('/read/')) {
      if (holdPatch != null) await holdPatch!.future;
      if (patchStatus != 200) return _r(patchStatus, {'status': 'error', 'message': 'Failed.'});
      final id = o.path.split('/').where((p) => p.isNotEmpty).elementAt(1);
      promotions = promotions.where((p) => p['id'] != id).toList();
      return _r(200, {'status': 'success', 'message': 'Notification marked as read.'});
    }
    if (o.path == empTodayPath) {
      return _r(200, {
        'status': 'success',
        'data': {
          'count': 1,
          'birthdays': [person('TST09', 'Company Wide')]
        }
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

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user({bool superuser = false, bool manager = false, List<String> perms = const ['leave.view']}) =>
    UserEntity(
      id: 'u1',
      email: 'emp@example.test',
      fullName: 'Test Employee',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: perms,
      canManageTeam: manager,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

late Backend backend;
late ProviderContainer container;

Future<void> pumpHome(WidgetTester tester, {UserEntity? as, void Function(Backend)? setup}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  backend = Backend();
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
      authStateProvider.overrideWith(() => _Auth(as ?? user())),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = backend),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pump();
  await settleSome(tester);
  container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
}

Future<void> settleSome(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

Finder byKey(String k) => find.byKey(Key(k));
Finder inKey(String k, Finder f) => find.descendant(of: byKey(k), matching: f);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('parsing', () {
    test('team / manager from data; anything else is empty', () {
      final w = MyBirthdayWidgets.fromResponseData({
        'team': [person('T1', 'Asha Rao'), person('T2', 'Ravi Menon')],
        'manager': person('M1', 'Meera Shah', message: 'Your team member is celebrating.'),
      });
      expect(w.team.map((p) => p.fullName), ['Asha Rao', 'Ravi Menon']);
      expect(w.team.first.message, 'Wish them well!');
      expect(w.manager!.fullName, 'Meera Shah');
      expect(MyBirthdayWidgets.fromResponseData({'team': [], 'manager': null}).team, isEmpty);
      expect(MyBirthdayWidgets.fromResponseData({'team': [], 'manager': null}).manager, isNull);
      expect(MyBirthdayWidgets.fromResponseData(null).team, isEmpty);
      expect(MyBirthdayWidgets.fromResponseData({'team': 'x', 'manager': 'y'}).manager, isNull);
    });

    test('promotion = results[0] (id, title, message); none → null', () {
      final p = PromotionCelebration.fromListData({
        'results': [promotion()]
      })!;
      expect([p.id, p.title, p.message],
          ['n-1', 'Congratulations on your promotion!', 'You have been promoted to Senior Analyst.']);
      expect(PromotionCelebration.fromListData({'results': []}), isNull);
      expect(PromotionCelebration.fromListData(null), isNull);
      expect(
          PromotionCelebration.fromListData({
            'results': [
              {'title': 'no id'}
            ]
          }),
          isNull);
    });

    test('Send Wishes needs settings.view and recruitment.edit (or superuser)', () {
      expect(canSendBirthdayWishes(user(perms: ['settings.view', 'recruitment.edit'])), isTrue);
      expect(canSendBirthdayWishes(user(perms: ['settings.view'])), isFalse);
      expect(canSendBirthdayWishes(user(perms: ['recruitment.edit'])), isFalse);
      expect(canSendBirthdayWishes(user(superuser: true, perms: const [])), isTrue);
      expect(canSendBirthdayWishes(null), isFalse);
    });
  });

  group('Employee dashboard', () {
    testWidgets('requests: /dashboard/birthdays/mine/ and unread promotions (page_size 1)', (tester) async {
      await pumpHome(tester);
      expect(find.byType(EmployeeDashboardView), findsOneWidget);
      expect(backend.count('GET', minePath), 1);
      final n = backend.calls.singleWhere((c) => c.method == 'GET' && c.path == notifPath);
      expect(n.query, {'notification_type': 'promotion', 'is_read': 'false', 'page_size': 1});
      await unmount(tester);
    });

    testWidgets('nothing to celebrate: no cards; the existing birthday card is unchanged', (tester) async {
      await pumpHome(tester);
      expect(byKey('team-birthday-card'), findsNothing);
      expect(byKey('manager-birthday-card'), findsNothing);
      expect(byKey('promotion-celebration-card'), findsNothing);
      expect(byKey('emp-birthdays-today'), findsOneWidget); // P1-3 card
      // Nothing rendered at all (not just no card): the layout is unchanged.
      for (final t in [TeamBirthdayCard, ManagerBirthdayCard, PromotionCelebrationCard]) {
        expect(tester.getSize(find.byType(t)), Size.zero, reason: '$t');
      }
      await unmount(tester);
    });

    testWidgets('team: one teammate — web wording and the server message; no email or date of birth', (tester) async {
      await pumpHome(tester, setup: (b) => b.team = [person('T1', 'Asha Rao')]);
      expect(inKey('team-birthday-card', find.text('🎂 TEAM BIRTHDAY TODAY')), findsOneWidget);
      expect(inKey('team-birthday-card', find.text("Today is Asha Rao's birthday.")), findsOneWidget);
      expect(inKey('team-birthday-card', find.text('Wish them well!')), findsOneWidget);
      expect(find.textContaining('t1@example.test'), findsNothing);
      expect(find.textContaining('1990'), findsNothing);
      expect(byKey('team-birthday-dot-0'), findsNothing); // dots only for 2+
      await unmount(tester);
    });

    testWidgets('team: several teammates — dots switch between them', (tester) async {
      await pumpHome(tester, setup: (b) => b.team = [person('T1', 'Asha Rao'), person('T2', 'Ravi Menon')]);
      expect(find.text("Today is Asha Rao's birthday."), findsOneWidget);
      await tester.tap(byKey('team-birthday-dot-1'));
      await tester.pump();
      expect(find.text("Today is Ravi Menon's birthday."), findsOneWidget);
      expect(find.text("Today is Asha Rao's birthday."), findsNothing);
      await unmount(tester);
    });

    testWidgets('manager: web wording and message', (tester) async {
      await pumpHome(tester,
          setup: (b) => b.manager = person('M1', 'Meera Shah', message: 'Your team member is celebrating.'));
      expect(inKey('manager-birthday-card', find.text('🎂 MANAGER BIRTHDAY')), findsOneWidget);
      expect(
          inKey('manager-birthday-card',
              find.text("Today is your manager's birthday. Wish Meera Shah a wonderful birthday.")),
          findsOneWidget);
      expect(inKey('manager-birthday-card', find.text('Your team member is celebrating.')), findsOneWidget);
      expect(byKey('team-birthday-card'), findsNothing);
      await unmount(tester);
    });

    testWidgets('loading hides the cards; a failed request (e.g. 403 onboarding) hides them quietly', (tester) async {
      final gate = Completer<void>();
      await pumpHome(tester, setup: (b) {
        b.team = [person('T1', 'Asha Rao')];
        b.holdMine = gate;
      });
      expect(byKey('team-birthday-card'), findsNothing);
      gate.complete();
      await settleSome(tester);
      expect(byKey('team-birthday-card'), findsOneWidget);
      await unmount(tester);

      await pumpHome(tester, setup: (b) {
        b.team = [person('T1', 'Asha Rao')];
        b.manager = person('M1', 'Meera Shah');
        b.promotions = [promotion()];
        b.mineStatus = 403;
        b.notifStatus = 500;
      });
      expect(byKey('team-birthday-card'), findsNothing);
      expect(byKey('manager-birthday-card'), findsNothing);
      expect(byKey('promotion-celebration-card'), findsNothing);
      expect(find.text('Refused.'), findsNothing);
      expect(find.byType(EmployeeDashboardView), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('promotion: title and message; "Got it" PATCHes it read, refetches, and it stays gone', (tester) async {
      await pumpHome(tester, setup: (b) => b.promotions = [promotion()]);
      expect(inKey('promotion-celebration-card', find.text('Congratulations on your promotion!')), findsOneWidget);
      expect(
          inKey('promotion-celebration-card', find.text('You have been promoted to Senior Analyst.')), findsOneWidget);
      final gets = backend.count('GET', notifPath);
      await tester.tap(byKey('promotion-dismiss'));
      await settleSome(tester);
      expect(backend.count('PATCH', ApiConstants.notificationRead('n-1')), 1);
      expect(backend.count('GET', notifPath), gets + 1);
      expect(byKey('promotion-celebration-card'), findsNothing);
      await unmount(tester);
    });

    testWidgets('promotion: a failed dismiss keeps the card with web\'s message; double tap sends once',
        (tester) async {
      await pumpHome(tester, setup: (b) {
        b.promotions = [promotion()];
        b.patchStatus = 500;
      });
      await tester.tap(byKey('promotion-dismiss'));
      await settleSome(tester);
      expect(find.text("Couldn't dismiss — please try again."), findsOneWidget);
      expect(byKey('promotion-celebration-card'), findsOneWidget);

      backend.patchStatus = 200;
      backend.holdPatch = Completer();
      await tester.tap(byKey('promotion-dismiss'));
      await tester.pump();
      expect(find.text('…'), findsOneWidget);
      await tester.tap(byKey('promotion-dismiss'), warnIfMissed: false);
      backend.holdPatch!.complete();
      await settleSome(tester);
      expect(backend.count('PATCH', ApiConstants.notificationRead('n-1')), 2); // the failed one + one more
      await unmount(tester);
    });

    testWidgets('Send Wishes: hidden without settings.view + recruitment.edit; with them it opens the wish sheet',
        (tester) async {
      await pumpHome(tester, setup: (b) {
        b.team = [person('T1', 'Asha Rao')];
        b.manager = person('M1', 'Meera Shah');
      });
      expect(byKey('team-birthday-wish'), findsNothing);
      expect(byKey('manager-birthday-wish'), findsNothing);
      await unmount(tester);

      await pumpHome(tester, as: user(perms: ['leave.view', 'settings.view', 'recruitment.edit']), setup: (b) {
        b.team = [person('T1', 'Asha Rao')];
        b.manager = person('M1', 'Meera Shah');
      });
      expect(byKey('team-birthday-wish'), findsOneWidget);
      expect(byKey('manager-birthday-wish'), findsOneWidget);
      await tester.tap(byKey('manager-birthday-wish'));
      await settleSome(tester);
      expect(find.byType(SendWishSheet), findsOneWidget);
      expect(backend.calls.where((c) => c.method == 'POST'), isEmpty); // nothing sent by opening it
      await unmount(tester);
    });

    testWidgets('a dashboard revisit refetches birthdays and promotions', (tester) async {
      await pumpHome(tester, setup: (b) => b.team = [person('T1', 'Asha Rao')]);
      container.read(dashboardRevisitProvider.notifier).state++;
      await settleSome(tester);
      expect(backend.count('GET', minePath), 2);
      expect(backend.count('GET', notifPath), 2);
      await unmount(tester);
    });
  });

  group('other dashboards (web: Employee dashboard only)', () {
    for (final entry in {
      'HR (employees.view)': user(perms: ['employees.view', 'leave.view']),
      'Manager (can_manage_team)': user(manager: true),
      'Admin (superuser)': user(superuser: true, perms: const []),
    }.entries) {
      testWidgets('${entry.key}: no celebration requests or cards', (tester) async {
        await pumpHome(tester, as: entry.value, setup: (b) {
          b.team = [person('T1', 'Asha Rao')];
          b.promotions = [promotion()];
        });
        expect(find.byType(EmployeeDashboardView), findsNothing);
        expect(backend.count('GET', minePath), 0);
        expect(backend.calls.where((c) => c.path == notifPath && c.query['notification_type'] == 'promotion'), isEmpty);
        expect(byKey('team-birthday-card'), findsNothing);
        expect(byKey('promotion-celebration-card'), findsNothing);
        await unmount(tester);
      });
    }
  });
}

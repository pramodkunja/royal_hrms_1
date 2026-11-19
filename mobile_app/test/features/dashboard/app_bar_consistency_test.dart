// Task 102: one blue app bar for every shell screen. The real DashboardShell,
// real Approvals / Training / My Learning screens, a stand-in server.
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/screens/dashboard_shell.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/app_top_bar.dart';
import 'package:mobile_app/features/training/presentation/screens/my_learning_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/training_screen.dart';

class _Empty implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async => ResponseBody.fromString(
          jsonEncode({
            'status': 'success',
            'message': 'ok',
            'data': {'results': [], 'count': 0, 'unread_count': 0}
          }),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
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

const _user = UserEntity(
  id: 'u1',
  email: 'user@example.test',
  fullName: 'Test User',
  role: 'hr',
  roleDisplay: 'HR',
  mustChangePassword: false,
  permissions: ['leave.approve', 'training.view'],
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

Future<void> pumpAt(WidgetTester tester, String path) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  Widget page(String t) => Center(child: Text(t));
  final router = GoRouter(initialLocation: path, routes: [
    ShellRoute(
      builder: (_, __, child) => DashboardShell(child: child),
      routes: [
        GoRoute(path: '/dashboard', builder: (_, __) => page('Home')),
        GoRoute(path: '/dashboard/approvals', builder: (_, __) => const ApprovalsScreen()),
        GoRoute(path: '/dashboard/training', builder: (_, __) => const TrainingScreen()),
        GoRoute(path: '/dashboard/my-learning', builder: (_, __) => const MyLearningScreen()),
        GoRoute(path: '/dashboard/leave', builder: (_, __) => page('Leave')),
      ],
    ),
  ]);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(_user)),
      dioProvider
          .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = _Empty()),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(routerConfig: router),
  ));
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

Color? barColor(WidgetTester tester) {
  final box = find.descendant(of: find.byType(AppTopBar), matching: find.byType(Container)).first;
  return (tester.widget<Container>(box).decoration as BoxDecoration?)?.color;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final (path, title) in [
    ('/dashboard/approvals', 'Team Approvals'),
    ('/dashboard/training', 'Training & Learning'),
    ('/dashboard/my-learning', 'My Learning'),
    ('/dashboard/leave', 'Leave Management'),
  ]) {
    testWidgets('$path: the shell’s blue bar (AppColors.primary, white title), exactly one, none inside the screen',
        (tester) async {
      await pumpAt(tester, path);
      expect(find.byType(AppTopBar), findsOneWidget);
      final bar = tester.widget<AppTopBar>(find.byType(AppTopBar));
      expect(bar.isBlueTheme, isTrue);
      expect(bar.title, title);
      expect(barColor(tester), AppColors.primary);
      expect(find.byType(AppBar), findsNothing); // the screen draws no second header
      final text = tester.widget<Text>(find.descendant(of: find.byType(AppTopBar), matching: find.text(title)));
      expect(text.style?.color, Colors.white);
    });
  }

  testWidgets('every blue screen has the same bar geometry; Dashboard home keeps its plain bar', (tester) async {
    final heights = <double>[];
    for (final p in ['/dashboard/approvals', '/dashboard/training', '/dashboard/leave']) {
      await pumpAt(tester, p);
      heights.add(tester.getSize(find.byType(AppTopBar)).height);
    }
    expect(heights.toSet(), hasLength(1));
    await pumpAt(tester, '/dashboard');
    expect(tester.widget<AppTopBar>(find.byType(AppTopBar)).isBlueTheme, isFalse);
  });

  testWidgets('the Approvals body keeps its My Profile-style heading under the bar', (tester) async {
    await pumpAt(tester, '/dashboard/approvals');
    expect(find.text('Approvals'), findsOneWidget);
    expect(find.text('Items waiting on your action'), findsOneWidget);
  });
}

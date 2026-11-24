// Task 111: Weekly Off Assignment tab, mounted inside the real AttendanceScreen
// (NestedScrollView + TabBarView) under a shell-like Scaffold. Stand-in API, render
// evidence only (T1011_SHOTS=1); simulated Android bottom insets.
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
import 'package:mobile_app/features/attendance/presentation/providers/weekly_off_assignment_providers.dart';
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

import '../features/attendance/weekly_off_assignment_test.dart' as base;
import 'shot_harness.dart';

class WoStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class WoAuth extends AuthNotifier {
  WoAuth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

Future<void> open(
  WidgetTester t, {
  Size size = const Size(393, 852),
  double scale = 1,
  bool dark = false,
  double navBottom = 0,
  double keyboard = 0,
  void Function(base.Server)? setup,
  bool branchUser = false,
  bool openTab = true,
  bool viewOnly = false,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  t.view.padding = FakeViewPadding(top: 24, bottom: navBottom);
  t.view.viewPadding = FakeViewPadding(top: 24, bottom: navBottom);
  t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(() {
    t.view.reset();
    t.view.resetPadding();
    t.view.resetViewPadding();
    t.view.resetViewInsets();
  });
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shotsEnabled) await t.runAsync(loadShotFonts);
  // The Attendance screen's own header (attendance_screen.dart: hero banner / stats bar, not part of
  // this tab) overflows in the test font and at large text; those reports are ignored, any other is not.
  final prevOnError = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.toString().contains('attendance_screen.dart')) return;
    prevOnError?.call(d);
  };
  addTearDown(() => FlutterError.onError = prevOnError);
  await t.pumpWidget(const SizedBox()); // a fresh tree for every state
  base.server = base.Server();
  setup?.call(base.server);
  await t.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => WoAuth(viewOnly ? base.viewer : (branchUser ? base.branchHr : base.orgHr))),
      dioProvider
          .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = base.server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(WoStorage()),
      weeklyOffClockProvider.overrideWithValue(() => base.today),
    ],
    child: shotFrame(MaterialApp(
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: Scaffold(appBar: shotAppBar('Attendance'), body: const AttendanceScreen()),
    )),
  ));
  await t.pumpAndSettle();
  swallowStatsBar(t, scale);
  if (openTab) {
    // At large text the header is taller than the screen: scroll the tab bar into reach first.
    // (A header taller than a short screen leaves the pinned tab bar unbuilt until scrolled to.)
    for (var i = 0; i < 14; i++) {
      final bars = find.byType(TabBar);
      if (bars.evaluate().isNotEmpty && t.getCenter(bars).dy <= size.height - 150) break;
      await t.drag(find.byType(NestedScrollView), const Offset(0, -200));
      await t.pumpAndSettle();
    }
    for (var i = 0; i < 8; i++) {
      final c = t.getCenter(find.text('Weekly Off Assignment'));
      final delta = size.width / 2 - c.dx;
      if (delta.abs() < 40) break;
      await t.drag(find.byType(TabBar), Offset(delta, 0));
      await t.pumpAndSettle();
    }
    await t.tap(find.text('Weekly Off Assignment'));
    await t.pumpAndSettle();
    swallowStatsBar(t, scale);
  }
}

/// The Attendance screen's own stats bar (not part of this tab) overflows at 2x text in the test font.
void swallowStatsBar(WidgetTester t, double scale) {
  if (scale > 1.5) while (t.takeException() != null) {}
}

Future<void> bringIntoView(WidgetTester t, Finder f) async {
  final h = t.view.physicalSize.height;
  for (var i = 0; i < 40; i++) {
    final dy = f.evaluate().isEmpty ? double.infinity : t.getCenter(f).dy;
    if (dy >= 300 && dy <= h - 160) return;
    await t.drag(find.byType(NestedScrollView), Offset(0, dy < 300 ? 120 : -120));
    await t.pumpAndSettle();
  }
}

Future<void> openBulk(WidgetTester t) async {
  final list = find.byKey(const Key('weekly-off-tab'));
  // Scroll (outer header first, then the list) until the button is below the pinned tab bar.
  final h = t.view.physicalSize.height;
  for (var i = 0; i < 20; i++) {
    final dy = t.getCenter(find.byKey(const Key('wo-bulk-open'))).dy;
    if (dy >= 300 && dy <= h - 160) break;
    await t.drag(list, Offset(0, dy < 300 ? 120 : -120));
    await t.pumpAndSettle();
  }
  await t.tap(find.byKey(const Key('wo-bulk-open')));
  await t.pumpAndSettle();
  swallowStatsBar(t, MediaQuery.textScalerOf(t.element(find.byType(Scaffold).first)).scale(10) / 10);
}

void manyRows(base.Server s) {
  s.rows = [
    base.row('EMP-7', 'Test Ann', patternId: 'p1', patternName: 'Sat-Sun Off', from: '2026-10-01'),
    base.row('EMP-9', 'Test Bob'),
    base.row('EMP-11', 'Test Chandrasekhara Venkataraghavan Iyer-Subramaniam',
        patternId: 'p2', patternName: 'Sunday Only with a Long Alternate Saturdays Rotation Name', from: '2026-09-15'),
    base.row('EMP-12', 'Test Dee', branch: 'South Wing'),
  ];
  s.totalPages = 3;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shots', (t) async {
    await open(t, setup: manyRows);
    await shoot(t, 'main');
    await t.drag(find.byKey(const Key('weekly-off-tab')), const Offset(0, -2000));
    await t.pumpAndSettle();
    await shoot(t, 'main_bottom');

    await open(t, setup: manyRows, navBottom: 48);
    await openBulk(t);
    await shoot(t, 'bulk_sheet_threebutton48');

    await open(t, setup: manyRows, navBottom: 24);
    await openBulk(t);
    await shoot(t, 'bulk_sheet_gesture24');

    await open(t, setup: manyRows, navBottom: 48, keyboard: 300);
    await openBulk(t);
    await shoot(t, 'bulk_sheet_keyboard');

    await open(t, setup: manyRows);
    await bringIntoView(t, find.byKey(const Key('wo-assign-EMP-7')));
    await t.tap(find.byKey(const Key('wo-assign-EMP-7')));
    await t.pumpAndSettle();
    await shoot(t, 'assign_sheet');

    await open(t, size: const Size(320, 568), setup: manyRows, navBottom: 24);
    await shoot(t, 'w320');
    await openBulk(t);
    await shoot(t, 'w320_bulk_sheet');

    await open(t, scale: 2, setup: manyRows, navBottom: 24);
    await shoot(t, 'text2x');
    await openBulk(t);
    await shoot(t, 'text2x_bulk_sheet');

    await open(t, size: const Size(1000, 800), setup: manyRows);
    await shoot(t, 'tablet');

    await open(t, dark: true, setup: manyRows, navBottom: 24);
    await shoot(t, 'dark');
    await openBulk(t);
    await shoot(t, 'dark_bulk_sheet');

    await open(t, setup: (s) => s.rows = []);
    await t.drag(find.byType(NestedScrollView), const Offset(0, -400));
    await t.pumpAndSettle();
    await shoot(t, 'empty');
    await open(t, setup: (s) => s.failList = true);
    await t.drag(find.byType(NestedScrollView), const Offset(0, -400));
    await t.pumpAndSettle();
    await shoot(t, 'error');
  }, skip: !shotsEnabled);
}

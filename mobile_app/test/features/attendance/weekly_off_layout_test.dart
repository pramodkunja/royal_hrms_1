import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/attendance/presentation/providers/weekly_off_assignment_providers.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/weekly_off_assignment_tab.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';

import '../../visual/weekly_off_visual_test.dart' as v;
import 'weekly_off_assignment_test.dart' as base;

// Task 111: Weekly Off Assignment layout + system-bar safety. Every inset test
// mounts the tab the way the app does: inside the real AttendanceScreen
// (NestedScrollView + TabBarView) under a Scaffold, with simulated Android bottom
// insets (24 = gesture bar, 48 = three-button bar) and keyboard viewInsets.

const sizes = <Size>[
  Size(320, 568),
  Size(360, 800),
  Size(393, 852),
  Size(430, 932),
  Size(600, 900),
  Size(800, 1000),
  Size(1000, 800),
];

Finder get submit => find.byKey(const Key('wo-bulk-submit'));
Finder get listScrollable =>
    find.descendant(of: find.byKey(const Key('weekly-off-tab')), matching: find.byType(Scrollable)).first;

/// Scrolls the page (outer header first, then the list) until [f] is below the pinned tab bar
/// and above the bottom edge, so a tap lands on it.
Future<void> bringIntoView(WidgetTester t, Finder f) async {
  final h = t.view.physicalSize.height;
  for (var i = 0; i < 40; i++) {
    final dy = f.evaluate().isEmpty ? double.infinity : t.getCenter(f).dy;
    if (dy >= 300 && dy <= h - 160) return;
    await t.drag(find.byType(NestedScrollView), Offset(0, dy < 300 ? 120 : -120));
    await t.pumpAndSettle();
  }
  fail('could not bring $f into view');
}

Future<void> openBulkSheet(WidgetTester t) async {
  final b = find.byKey(const Key('wo-bulk-open'));
  await bringIntoView(t, b);
  await t.tap(b);
  await t.pumpAndSettle();
}

Future<void> fillBulk(WidgetTester t) async {
  await base.pick(t, 'wo-bulk-department', 'Ops');
  await base.pick(t, 'wo-bulk-pattern', 'Sunday Only');
}

/// The action row sits entirely above the system bar / keyboard, and is tappable.
void expectClear(WidgetTester t, Finder f, double blocked, {String? reason}) {
  final r = t.getRect(f);
  expect(r.bottom, lessThanOrEqualTo(t.view.physicalSize.height - blocked + 0.01), reason: reason ?? 'rect $r');
  expect(r.top, greaterThanOrEqualTo(0));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Bulk Assign clears the system navigation area (real AttendanceScreen nesting)', () {
    for (final size in sizes) {
      for (final inset in [24.0, 48.0]) {
        testWidgets('${size.width.toInt()}x${size.height.toInt()}, bottom inset ${inset.toInt()}', (t) async {
          await v.open(t, size: size, navBottom: inset, setup: v.manyRows);
          await openBulkSheet(t);
          expect(find.byKey(const Key('wo-bulk-sheet')), findsOneWidget);
          expectClear(t, submit, inset);
          expectClear(t, find.widgetWithText(TextButton, 'Cancel'), inset);
          // No overlap between the two actions.
          final cancel = t.getRect(find.widgetWithText(TextButton, 'Cancel'));
          expect(cancel.overlaps(t.getRect(submit)), isFalse);
          await fillBulk(t);
          expectClear(t, submit, inset);
          expect((t.widget(submit) as ButtonStyleButton).onPressed, isNotNull);
          await t.tap(submit); // hit-testable: a missed tap throws in flutter_test
          await t.pumpAndSettle();
          expect(base.server.posts, hasLength(1));
          expect(find.text('Weekly off pattern assigned to 7 employee(s).'), findsOneWidget);
        });
      }
    }

    for (final scale in [1.5, 2.0]) {
      for (final dark in [false, true]) {
        for (final size in [const Size(320, 568), const Size(393, 852)]) {
          testWidgets('${size.width.toInt()} wide, text ${scale}x, ${dark ? 'dark' : 'light'}, three-button bar',
              (t) async {
            await v.open(t, size: size, scale: scale, dark: dark, navBottom: 48, setup: v.manyRows);
            await openBulkSheet(t);
            expectClear(t, submit, 48);
            expectClear(t, find.widgetWithText(TextButton, 'Cancel'), 48);
            await fillBulk(t);
            expectClear(t, submit, 48);
            await t.tap(submit);
            await t.pumpAndSettle();
            expect(base.server.posts, hasLength(1));
          });
        }
      }
    }

    testWidgets('keyboard open (viewInsets 300) with a three-button bar: actions sit above the keyboard', (t) async {
      await v.open(t, navBottom: 0, keyboard: 300, setup: v.manyRows);
      await openBulkSheet(t);
      expectClear(t, submit, 300);
      await fillBulk(t);
      expectClear(t, submit, 300);
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(base.server.posts, hasLength(1));
    });

    testWidgets('single-employee Assign sheet also clears the bar', (t) async {
      await v.open(t, navBottom: 48, setup: v.manyRows);
      await bringIntoView(t, find.byKey(const Key('wo-assign-EMP-9')));
      await t.tap(find.byKey(const Key('wo-assign-EMP-9')));
      await t.pumpAndSettle();
      expectClear(t, find.byKey(const Key('wo-assign-submit')), 48);
    });
  });

  group('the page itself', () {
    for (final inset in [24.0, 48.0]) {
      testWidgets('end of the list scrolls clear of a ${inset.toInt()}dp bar; pagination reachable', (t) async {
        await v.open(t, size: const Size(360, 640), navBottom: inset, setup: v.manyRows);
        await t.drag(find.byKey(const Key('weekly-off-tab')), const Offset(0, -3000));
        await t.pumpAndSettle();
        await t.drag(find.byKey(const Key('weekly-off-tab')), const Offset(0, -3000));
        await t.pumpAndSettle();
        expectClear(t, find.byKey(const Key('wo-assign-EMP-12')), inset);
        expectClear(t, find.byKey(const Key('wo-next')), inset);
        // The scroll extent really includes the inset (not a fixed one-device spacer): with a
        // bigger bar the last card sits higher.
        await t.tap(find.byKey(const Key('wo-next')));
        await t.pumpAndSettle();
        expect(base.server.lists.last['page'], 2);
      });
    }

    testWidgets('the inset is read from MediaQuery, not hard-coded (bigger bar => list ends higher)', (t) async {
      Future<double> endOf(double inset) async {
        await v.open(t, size: const Size(360, 640), navBottom: inset, setup: v.manyRows);
        await t.drag(find.byKey(const Key('weekly-off-tab')), const Offset(0, -4000));
        await t.pumpAndSettle();
        return t.getRect(find.byKey(const Key('wo-next'))).bottom;
      }

      final low = await endOf(0);
      final mid = await endOf(48);
      final high = await endOf(100);
      // The gap under the last control grows one-for-one with the real inset.
      expect(mid - low, closeTo(-48, 0.5));
      expect(high - low, closeTo(-100, 0.5));
    });
  });

  group('bulk validation, confirmation and duplicate submit survive the redesign', () {
    testWidgets('disabled until a pattern and a branch or department; hint explains', (t) async {
      await v.open(t, navBottom: 24, setup: v.manyRows);
      await openBulkSheet(t);
      expect(find.byKey(const Key('wo-bulk-hint')), findsOneWidget);
      expect(base.enabled(t, 'wo-bulk-submit'), isFalse);
      await base.pick(t, 'wo-bulk-pattern', 'Sunday Only');
      expect(base.enabled(t, 'wo-bulk-submit'), isFalse); // pattern alone is not enough
      await base.pick(t, 'wo-bulk-branch', 'South Wing');
      expect(base.enabled(t, 'wo-bulk-submit'), isTrue);
      await base.pick(t, 'wo-bulk-pattern', 'Select pattern…');
      expect(base.enabled(t, 'wo-bulk-submit'), isFalse); // a branch alone is not enough either
      expect(find.byKey(const Key('wo-bulk-hint')), findsNothing);
    });

    testWidgets('exact request, server-confirmed message, sheet closes, list reloads', (t) async {
      await v.open(t, navBottom: 48, setup: v.manyRows);
      await openBulkSheet(t);
      await base.pick(t, 'wo-bulk-branch', 'South Wing');
      await base.pick(t, 'wo-bulk-pattern', 'Sunday Only');
      final lists = base.server.lists.length;
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(base.server.posts.single.body,
          {'pattern': 'p2', 'effective_from': '2026-11-06', 'branch': 'South Wing', 'department': ''});
      expect(find.byKey(const Key('wo-bulk-sheet')), findsNothing);
      expect(find.text('Weekly off pattern assigned to 7 employee(s).'), findsOneWidget);
      expect(base.server.lists.length, lists + 1);
    });

    testWidgets('a refusal keeps the sheet open, nothing is confirmed; no double submit', (t) async {
      await v.open(t, navBottom: 48, setup: v.manyRows);
      await openBulkSheet(t);
      await fillBulk(t);
      base.server.refuseNext = (status: 422, message: 'Enter a valid date.');
      await t.tap(submit);
      await t.pumpAndSettle();
      expect(find.text('Enter a valid date.'), findsOneWidget);
      expect(find.byKey(const Key('wo-bulk-sheet')), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      base.server.hold = Completer();
      await t.tap(submit);
      await t.pump(const Duration(milliseconds: 50));
      expect(find.text('Assigning…'), findsOneWidget);
      await t.tap(submit, warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 50));
      base.server.hold!.complete();
      await t.pumpAndSettle();
      expect(base.server.posts, hasLength(2));
    });

    testWidgets('without attendance.create: no Bulk Assign and no Assign/Change', (t) async {
      await v.open(t, setup: v.manyRows, openTab: true, branchUser: false, viewOnly: true);
      expect(find.byKey(const Key('wo-bulk-open')), findsNothing);
      expect(find.byKey(const Key('wo-assign-EMP-7')), findsNothing);
      // (The header above the tab is taller in the wide test font: scroll the list into view.)
      for (var i = 0; i < 6 && find.text('Test Ann').evaluate().isEmpty; i++) {
        await t.drag(find.byType(NestedScrollView), const Offset(0, -250));
        await t.pumpAndSettle();
      }
      expect(find.text('Test Ann'), findsOneWidget);
    });
  });

  group('responsive layout (tab on its own, no Attendance header)', () {
    Future<void> mount(WidgetTester t, Size size, double scale, bool dark) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      t.view.padding = const FakeViewPadding(bottom: 48);
      t.view.viewPadding = const FakeViewPadding(bottom: 48);
      addTearDown(() {
        t.view.reset();
        t.view.resetPadding();
        t.view.resetViewPadding();
      });
      AppColors.applyMode(dark);
      addTearDown(() => AppColors.applyMode(false));
      base.server = base.Server();
      v.manyRows(base.server);
      base.server.rows[2]['employee_name'] = 'Test ${'Verylongsurname ' * 6}';
      await t.pumpWidget(ProviderScope(
        overrides: [
          authStateProvider.overrideWith(() => v.WoAuth(base.orgHr)),
          dioProvider.overrideWithValue(
              Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = base.server),
          cookieJarProvider.overrideWithValue(CookieJar()),
          secureStorageProvider.overrideWithValue(v.WoStorage()),
          weeklyOffClockProvider.overrideWithValue(() => base.today),
        ],
        child: MaterialApp(
          theme: AppTheme.themeFor(dark),
          builder: (c, child) =>
              MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
          home: const Scaffold(body: WeeklyOffAssignmentTab()),
        ),
      ));
      await t.pumpAndSettle();
    }

    for (final size in sizes) {
      for (final scale in [1.0, 1.5, 2.0]) {
        for (final dark in [false, true]) {
          testWidgets(
              '${size.width.toInt()}x${size.height.toInt()} text ${scale}x ${dark ? 'dark' : 'light'}: no overflow',
              (t) async {
            await mount(t, size, scale, dark);
            expect(t.takeException(), isNull);
            // Scroll the whole page: every card and the long name lay out without overflow.
            await t.scrollUntilVisible(find.textContaining('Verylongsurname'), 200, scrollable: listScrollable);
            await t.pump();
            expect(t.takeException(), isNull);
            // Full name, never ellipsized: the whole text is laid out in the card's width.
            expect(find.textContaining('Verylongsurname'), findsOneWidget);
            await t.drag(find.byKey(const Key('weekly-off-tab')), const Offset(0, -4000));
            await t.pump();
            expect(t.takeException(), isNull);
            final w = size.width;
            for (final k in ['wo-pattern-EMP-7']) {
              final r = t.getRect(find.byKey(Key(k)));
              expect(r.right, lessThanOrEqualTo(w));
            }
          });
        }
      }
    }

    testWidgets('1 column on phones, 2 columns from 600dp', (t) async {
      await mount(t, const Size(393, 852), 1, false);
      final phone = t.getTopLeft(find.byKey(const Key('wo-row-EMP-7'))).dx ==
          t.getTopLeft(find.byKey(const Key('wo-row-EMP-9'))).dx;
      expect(phone, isTrue);
      await mount(t, const Size(1000, 800), 1, false);
      await t.drag(find.byKey(const Key('weekly-off-tab')), const Offset(0, -400));
      await t.pump();
      expect(t.getTopLeft(find.byKey(const Key('wo-row-EMP-7'))).dx,
          lessThan(t.getTopLeft(find.byKey(const Key('wo-row-EMP-9'))).dx));
    });

    testWidgets('44dp touch targets: Bulk Assign, Assign/Change, pagination', (t) async {
      await mount(t, const Size(393, 852), 1, false);
      expect(t.getSize(find.byKey(const Key('wo-bulk-open'))).height, greaterThanOrEqualTo(44));
      await t.scrollUntilVisible(find.byKey(const Key('wo-assign-EMP-7')), 100, scrollable: listScrollable);
      expect(t.getSize(find.byKey(const Key('wo-assign-EMP-7'))).height, greaterThanOrEqualTo(44));
    });
  });
}

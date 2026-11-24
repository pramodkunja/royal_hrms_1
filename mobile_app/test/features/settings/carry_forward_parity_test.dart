// Task 106 Part A: Leave Policy → Carry Forward, against web CarryForwardTab.tsx /
// CarryForwardPreviewTable / CarryForwardHistoryTable / CarryForwardRunModal.
// A stand-in API (nothing is sent anywhere); the Run guard added by HO-37 (Run only
// after a matching Preview) is kept and pinned here too.
import 'dart:async';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_kit.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/app_top_bar.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/widgets/leave_carry_forward_tab.dart';

import '../../visual/leave_policy_tabs_visual_test.dart' as v;
import 'monthly_leave_management_test.dart' as m;

late v.LpServer server;

class _Storage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

Finder _k(String k) => find.byKey(Key(k));

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

/// The tab alone (responsive matrix: no other tab can interfere).
Future<void> _mount(WidgetTester t,
    {Size size = const Size(393, 3000), double scale = 1, v.LpServer? s, List<String>? perms}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  server = s ?? v.LpServer();
  m.server = server;
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _AuthFor(v.lpUser(perms ?? const ['settings.view', 'leave.edit']))),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: MaterialApp(
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: const Scaffold(body: LeaveCarryForwardTab()),
    ),
  ));
  await _settle(t);
}

class _AuthFor extends AuthNotifier {
  _AuthFor(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

Future<void> _tap(WidgetTester t, String key) async {
  if (_k(key).evaluate().isEmpty) {
    await t.scrollUntilVisible(_k(key), 200,
        scrollable: find.descendant(of: _k('carry-forward-list'), matching: find.byType(Scrollable)).first);
  }
  await t.ensureVisible(_k(key));
  await t.pump();
  await t.tap(_k(key), warnIfMissed: false);
  await _settle(t);
}

int _count(String method, String path) => server.log.where((l) => l == '$method $path').length;
Object? _body(String method, String path) => server.cfBodies['$method $path'];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('who sees it (web: usePermission("leave.edit"))', () {
    testWidgets('without leave.edit: Access Denied, nothing requested', (t) async {
      await _mount(t, perms: ['settings.view']);
      expect(find.byWidgetPredicate((w) => w is ApprovalsEmptyState && w.kind == ApprovalsStateKind.denied),
          findsOneWidget);
      expect(find.text('You do not have permission to view carry-forward operations.'), findsOneWidget);
    });

    testWidgets('on the Leave Policy route: leave.edit shows the tab and the import action, others neither', (t) async {
      await v.openLeavePolicy(t, shots: false);
      expect(find.descendant(of: find.byType(Tab), matching: find.text('Carry Forward')), findsOneWidget);
      expect(_k('leave-import-entry'), findsOneWidget);
      await v.openLeavePolicy(t, shots: false, as: v.lpUser(['settings.view', 'leave.approve']));
      expect(find.descendant(of: find.byType(Tab), matching: find.text('Carry Forward')), findsNothing);
      expect(_k('leave-import-entry'), findsNothing);
    });

    testWidgets('the parent uses the shell’s blue AppTopBar with a back arrow', (t) async {
      await v.openLeavePolicy(t, shots: false);
      expect(find.byType(AppTopBar), findsOneWidget);
      final bar = t.widget<AppTopBar>(find.byType(AppTopBar));
      expect((bar.isBlueTheme, bar.title), (true, 'Leave Policy'));
      expect(_k('app-top-bar-back'), findsOneWidget);
    });
  });

  group('year selection', () {
    testWidgets('years load; the defaults are selected; To Year only offers years after From', (t) async {
      await _mount(t);
      expect(_count('GET', ApiConstants.carryForwardYears), 1);
      expect(find.text('2025'), findsWidgets);
      await t.tap(_k('carry-forward-from-year'));
      await _settle(t);
      await t.tap(find.text('2024').last);
      await _settle(t);
      // From 2024 → To must be after it: 2025 or 2026 are both offered
      await t.tap(_k('carry-forward-to-year'));
      await _settle(t);
      expect(find.text('2025'), findsWidgets);
      expect(find.text('2026'), findsWidgets);
    });

    testWidgets('choosing a From Year that is not before the To Year moves To Year to a valid one', (t) async {
      await _mount(t);
      await t.tap(_k('carry-forward-from-year'));
      await _settle(t);
      await t.tap(find.text('2025').last);
      await _settle(t);
      await _tap(t, 'carry-forward-preview');
      expect(_body('POST', ApiConstants.carryForwardPreview), {'from_year': 2025, 'to_year': 2026});
    });

    testWidgets('no year data: web’s message', (t) async {
      await _mount(t, s: v.LpServer()..noYears = true);
      expect(find.text('No leave year data found'), findsOneWidget);
      expect(find.text('Employees must have leave balances recorded before carry-forward can be run.'), findsOneWidget);
    });

    testWidgets('years failing to load: an error with Retry that reloads', (t) async {
      final s = v.LpServer()..yearsStatus = 500;
      await _mount(t, s: s);
      expect(_k('carry-forward-years-error'), findsOneWidget);
      s.yearsStatus = 200;
      await _tap(t, 'approvals-empty-action');
      expect(_k('carry-forward-controls'), findsOneWidget);
    });
  });

  group('preview', () {
    testWidgets('POSTs {from_year, to_year}; shows web’s counts and every column per record', (t) async {
      await _mount(t);
      await _tap(t, 'carry-forward-preview');
      expect(_body('POST', ApiConstants.carryForwardPreview), {'from_year': 2025, 'to_year': 2026});
      final card = _k('carry-forward-preview-card');
      for (final text in [
        'Total rows',
        'To process',
        'Already done',
        'Anika Sharma',
        'EMP-0042',
        'Casual Leave',
        'Unused days',
        'Carry forward',
        'Expiry date',
        'Never',
        '2026-06-30',
        'Pending',
        'Already Done'
      ]) {
        expect(find.descendant(of: card, matching: find.text(text)), findsWidgets, reason: text);
      }
      expect(find.descendant(of: card, matching: find.text('18.5')), findsOneWidget);
    });

    testWidgets('an empty preview says there is nothing to carry forward', (t) async {
      await _mount(t, s: v.LpServer()..emptyPreview = true);
      await _tap(t, 'carry-forward-preview');
      expect(find.text('Nothing to carry forward'), findsOneWidget);
    });

    testWidgets('a failed preview shows the server message and leaves Run disabled', (t) async {
      await _mount(t, s: v.LpServer()..previewStatus = 500);
      await _tap(t, 'carry-forward-preview');
      expect(find.text('Server error.'), findsOneWidget);
      expect(t.widget<ButtonStyleButton>(_k('carry-forward-run')).onPressed, isNull);
    });

    testWidgets('changing a year discards the preview and disables Run again', (t) async {
      await _mount(t);
      await _tap(t, 'carry-forward-preview');
      expect(t.widget<ButtonStyleButton>(_k('carry-forward-run')).onPressed, isNotNull);
      await t.tap(_k('carry-forward-from-year'));
      await _settle(t);
      await t.tap(find.text('2024').last);
      await _settle(t);
      expect(_k('carry-forward-preview-card'), findsNothing);
      expect(t.widget<ButtonStyleButton>(_k('carry-forward-run')).onPressed, isNull);
    });
  });

  group('run (balance-changing)', () {
    Future<void> toConfirm(WidgetTester t) async {
      await _tap(t, 'carry-forward-preview');
      await _tap(t, 'carry-forward-run');
    }

    testWidgets('the confirmation says the scope, the employee-leave count and that it cannot be undone', (t) async {
      await _mount(t);
      await toConfirm(t);
      expect(
          find.text(
              'This will carry forward unused leave for 3 employee-leave combinations from 2025 to 2026. This cannot be undone. Continue?'),
          findsOneWidget);
      expect(find.text('Already done'), findsWidgets);
    });

    testWidgets('Cancel sends nothing', (t) async {
      await _mount(t);
      await toConfirm(t);
      await t.tap(_k('carry-forward-confirm-cancel'));
      await _settle(t);
      expect(_count('POST', ApiConstants.carryForwardRun), 0);
    });

    testWidgets(
        'confirming POSTs once with {from_year, to_year}; success message; history and years reload; preview cleared',
        (t) async {
      await _mount(t);
      await toConfirm(t);
      final historyBefore = _count('GET', ApiConstants.carryForwardHistory);
      final yearsBefore = _count('GET', ApiConstants.carryForwardYears);
      await t.tap(_k('carry-forward-confirm-run'));
      await _settle(t);
      expect(_count('POST', ApiConstants.carryForwardRun), 1);
      expect(_body('POST', ApiConstants.carryForwardRun), {'from_year': 2025, 'to_year': 2026});
      expect(find.text('Carry forward completed. 3 processed, 1 skipped.'), findsOneWidget);
      expect(_count('GET', ApiConstants.carryForwardHistory), greaterThan(historyBefore));
      expect(_count('GET', ApiConstants.carryForwardYears), greaterThan(yearsBefore));
      expect(_k('carry-forward-preview-card'), findsNothing); // stale numbers are gone
      expect(t.widget<ButtonStyleButton>(_k('carry-forward-run')).onPressed, isNull); // needs a fresh preview
    });

    testWidgets('a second tap while the run is in flight sends nothing more and the dialog cannot be dismissed',
        (t) async {
      final gate = Completer<void>();
      final s = v.LpServer();
      s.holds['POST ${ApiConstants.carryForwardRun}'] = gate;
      await _mount(t, s: s);
      await toConfirm(t);
      await t.tap(_k('carry-forward-confirm-run'));
      await t.pump(const Duration(milliseconds: 100));
      expect(find.text('Running…'), findsOneWidget);
      await t.tap(_k('carry-forward-confirm-run'), warnIfMissed: false);
      await t.pump(const Duration(milliseconds: 100));
      expect(t.widget<ButtonStyleButton>(_k('carry-forward-confirm-run')).onPressed, isNull);
      expect(t.widget<ButtonStyleButton>(_k('carry-forward-confirm-cancel')).onPressed, isNull);
      expect(_count('POST', ApiConstants.carryForwardRun), 1);
      gate.complete();
      await _settle(t);
      expect(_count('POST', ApiConstants.carryForwardRun), 1);
    });

    testWidgets('409 (already executed): a dismissible warning with the server’s message', (t) async {
      await _mount(t, s: v.LpServer()..runStatus = 409);
      await toConfirm(t);
      await t.tap(_k('carry-forward-confirm-run'));
      await _settle(t);
      expect(_k('carry-forward-duplicate'), findsOneWidget);
      expect(find.text('This period has already been executed.'), findsOneWidget);
      await t.tap(find.byTooltip('Dismiss'));
      await _settle(t);
      expect(_k('carry-forward-duplicate'), findsNothing);
    });

    testWidgets('400 (invalid selection): an inline error with the server’s message', (t) async {
      await _mount(t,
          s: v.LpServer()
            ..runStatus = 400
            ..runMessage = 'To year must be after from year.');
      await toConfirm(t);
      await t.tap(_k('carry-forward-confirm-run'));
      await _settle(t);
      expect(find.text('To year must be after from year.'), findsOneWidget);
      expect(_k('carry-forward-duplicate'), findsNothing);
    });

    testWidgets('any other failure: web’s generic message, nothing claimed done', (t) async {
      await _mount(t,
          s: v.LpServer()
            ..runStatus = 500
            ..runMessage = 'boom');
      await toConfirm(t);
      await t.tap(_k('carry-forward-confirm-run'));
      await _settle(t);
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(find.textContaining('completed'), findsNothing);
      expect(_k('carry-forward-preview-card'), findsOneWidget); // the user's context is kept
    });
  });

  group('history (web: Period, Executed By, Processed, Skipped, Failed, Status, Date)', () {
    testWidgets('every column is shown, including Failed when it is 0 and the date', (t) async {
      await _mount(t);
      final first = _k('carry-forward-log-h1_0');
      for (final text in ['2025', '2026', 'Executed by Asha Test', 'Processed', 'Skipped', 'Failed', 'Completed']) {
        expect(find.descendant(of: first, matching: find.text(text)), findsWidgets, reason: text);
      }
      expect(find.descendant(of: first, matching: find.text('0')), findsWidgets); // Failed 0 is still shown
      expect(find.byKey(const Key('carry-forward-log-date-h1_0')), findsOneWidget);
      expect(
          t.widget<Text>(_k('carry-forward-log-date-h1_0')).data, matches(RegExp(r'^\d{1,2} \w+ \d{4}, \d{2}:\d{2}$')));
      expect(find.text('Incomplete'), findsOneWidget);
    });

    testWidgets('paged 20 at a time: Page x of y, Prev/Next request page 2 with page_size 20', (t) async {
      await _mount(t, size: const Size(393, 9000), s: v.LpServer()..manyHistory = true);
      expect(find.text('Page 1 of 3'), findsOneWidget);
      expect(t.widget<ButtonStyleButton>(_k('carry-forward-prev')).onPressed, isNull);
      await _tap(t, 'carry-forward-next');
      expect(find.text('Page 2 of 3'), findsOneWidget);
      expect(server.bodies.entries.where((e) => e.key == 'GET ${ApiConstants.carryForwardHistory}').first.value.last,
          containsPair('page', 2));
      expect(server.bodies['GET ${ApiConstants.carryForwardHistory}']!.last, containsPair('page_size', 20));
    });

    testWidgets('empty history, and a failed history with Retry', (t) async {
      await _mount(t, s: v.LpServer()..emptyHistory = true);
      expect(find.text('No history yet'), findsOneWidget);
      final s = v.LpServer()..historyStatus = 500;
      await _mount(t, s: s);
      expect(_k('carry-forward-history-error'), findsOneWidget);
      s.historyStatus = 200;
      await _tap(t, 'approvals-empty-action');
      expect(_k('carry-forward-log-h1_0'), findsOneWidget);
    });
  });

  group('responsive', () {
    for (final (w, h, s) in [
      (320.0, 568.0, 1.0),
      (360.0, 800.0, 1.0),
      (393.0, 852.0, 1.0),
      (430.0, 932.0, 1.0),
      (700.0, 1000.0, 1.0),
      (1000.0, 800.0, 1.0),
      (320.0, 568.0, 2.0),
      (360.0, 800.0, 1.5),
    ]) {
      testWidgets('${w.toInt()}×${h.toInt()} at $s× text: preview + history scroll end to end, no overflow', (t) async {
        await _mount(t, size: Size(w, h), scale: s, s: v.LpServer()..manyHistory = true);
        await _tap(t, 'carry-forward-preview');
        expect(t.takeException(), isNull);
        for (var i = 0; i < 14; i++) {
          await t.drag(_k('carry-forward-list'), const Offset(0, -350));
          await t.pump();
          expect(t.takeException(), isNull, reason: 'scroll $i');
        }
        await _settle(t);
      });
    }

    testWidgets('on a phone Preview and Run are full-width ≥48dp; at 2× text the confirm dialog stacks', (t) async {
      await _mount(t, size: const Size(320, 2400), scale: 2);
      expect(t.getSize(_k('carry-forward-preview')).height, greaterThanOrEqualTo(48));
      expect(t.getSize(_k('carry-forward-run')).height, greaterThanOrEqualTo(48));
      expect(t.getTopLeft(_k('carry-forward-run')).dy, greaterThan(t.getTopLeft(_k('carry-forward-preview')).dy));
      await _tap(t, 'carry-forward-preview');
      await _tap(t, 'carry-forward-run');
      expect(t.takeException(), isNull);
      expect(t.getRect(_k('carry-forward-confirm-run')).right, lessThanOrEqualTo(320));
      expect(t.getTopLeft(_k('carry-forward-confirm-cancel')).dy,
          greaterThan(t.getTopLeft(_k('carry-forward-confirm-run')).dy));
    });

    testWidgets('tablet: records in two columns, centred content', (t) async {
      await _mount(t, size: const Size(1000, 2400));
      await _tap(t, 'carry-forward-preview');
      expect(t.getTopLeft(_k('carry-forward-row-0')).dy, t.getTopLeft(_k('carry-forward-row-1')).dy);
    });

    testWidgets('dark theme follows the dark tokens', (t) async {
      AppColors.applyMode(true);
      addTearDown(() => AppColors.applyMode(false));
      await _mount(t);
      expect(t.takeException(), isNull);
      final box = t.widget<Container>(_k('carry-forward-controls'));
      expect((box.decoration as BoxDecoration).color, AppColors.surface);
    });
  });
}

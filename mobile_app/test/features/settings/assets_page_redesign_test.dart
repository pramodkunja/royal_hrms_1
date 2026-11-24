// Task 104.1: the whole Assets page — the shell's blue app bar, hero + search,
// status pills, filter sheet and removable chips, status-toned asset cards, the
// distinct empty / error / denied states, paging, and the responsive matrix.
// The real AssetsSettingsScreen with a stand-in API; web behaviour is pinned by
// assets_settings_test.dart (payloads, permissions) and asset_form_redesign_test.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_kit.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/app_top_bar.dart';
import 'package:mobile_app/features/settings/presentation/assets/assets_settings_screen.dart';
import 'package:mobile_app/features/settings/presentation/widgets/settings_app_bar.dart';
import 'package:mobile_app/shared/widgets/blue_hero_banner.dart';

import 'assets_settings_test.dart' as h;

Finder _k(String k) => find.byKey(Key(k));

Future<void> _open(WidgetTester t,
    {Size size = const Size(393, 3000), double scale = 1, void Function(h.Backend)? setup}) async {
  final Widget? child = scale == 1
      ? null
      : MediaQuery(
          data: MediaQueryData(size: size, textScaler: TextScaler.linear(scale)), child: const AssetsSettingsScreen());
  await h.pump(t, setup: setup, child: child);
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  await h.settle(t);
}

Color? _accentOf(WidgetTester t, String id) {
  final card = find.byKey(Key('asset-row-$id'));
  final bar = find.descendant(of: card, matching: find.byType(ColoredBox)).first;
  return t.widget<ColoredBox>(bar).color;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('app bar (the same one Announcements has)', () {
    testWidgets('the shell’s AppTopBar: blue, white title, back arrow, search / theme / bell / sign-out', (t) async {
      await _open(t);
      expect(find.byType(AppTopBar), findsOneWidget);
      expect(find.byType(SettingsAppBar), findsNothing); // no longer the white Settings bar
      final bar = t.widget<AppTopBar>(find.byType(AppTopBar));
      expect(bar.isBlueTheme, isTrue);
      expect(bar.title, 'Asset Management');
      expect(_k('app-top-bar-back'), findsOneWidget);
      expect(find.byTooltip('Menu'), findsNothing); // no drawer outside the shell
      for (final tip in ['Search', 'Switch to dark mode', 'Sign out']) {
        expect(find.byTooltip(tip), findsOneWidget, reason: tip);
      }
      final fill = find.descendant(of: find.byType(AppTopBar), matching: find.byType(Container)).first;
      expect((t.widget<Container>(fill).decoration as BoxDecoration).color, AppColors.primary);
    });

    testWidgets('the hero band sits under the bar, as on Announcements', (t) async {
      await _open(t);
      expect(find.byType(BlueHeroBanner), findsOneWidget);
      expect(t.getTopLeft(find.byType(BlueHeroBanner)).dy, closeTo(t.getBottomLeft(find.byType(AppTopBar)).dy, 1));
      expect(find.descendant(of: find.byType(BlueHeroBanner), matching: _k('asset-search')), findsOneWidget);
    });
  });

  group('status pills and filters (every web filter kept)', () {
    testWidgets('web’s seven statuses + All, as pills; the selected one is shown', (t) async {
      await _open(t);
      final scrollable = find.descendant(of: _k('asset-status-pills'), matching: find.byType(Scrollable)).first;
      for (final v in ['all', 'available', 'assigned', 'under_repair', 'lost', 'damaged', 'retired', 'disposed']) {
        await t.scrollUntilVisible(_k('asset-pill-$v'), 150, scrollable: scrollable);
        expect(_k('asset-pill-$v'), findsOneWidget, reason: v);
      }
      Future<void> pill(String v) async {
        await t.scrollUntilVisible(_k('asset-pill-$v'), -150, scrollable: scrollable);
        // built is not on screen: bring the pill's centre to the middle before tapping
        await t.drag(scrollable, Offset(196 - t.getCenter(_k('asset-pill-$v')).dx, 0));
        await t.pump();
        await t.tap(_k('asset-pill-$v'));
        await h.settle(t);
        await h.settle(t);
      }

      await pill('damaged');
      expect(h.server.lists().last['status'], 'damaged');
      expect(
          t
              .widget<AnimatedContainer>(
                  find.descendant(of: _k('asset-pill-damaged'), matching: find.byType(AnimatedContainer)))
              .decoration,
          isA<BoxDecoration>().having((d) => d.color, 'fill', AppColors.primary));
      await pill('all');
      // back to every status: the full list is shown again (a cached first page needs no new request)
      expect(find.text('Dell Latitude'), findsOneWidget);
      expect(find.text('Pixel'), findsOneWidget);
    });

    testWidgets('branch / category / asset type are in the filter sheet; each shows as a removable chip', (t) async {
      await _open(t);
      expect(_k('asset-filters-count'), findsNothing);
      await h.tapKey(t, 'asset-filters');
      for (final k in ['asset-filter-branch', 'asset-filter-category', 'asset-filter-type']) {
        expect(_k(k), findsOneWidget, reason: k);
      }
      await h.type(t, 'asset-filter-category', 'furniture');
      await t.pump(const Duration(milliseconds: 400));
      await h.settle(t);
      await h.tapKey(t, 'asset-sheet-done');
      expect(_k('asset-chip-category'), findsOneWidget);
      expect(find.descendant(of: _k('asset-filters-count'), matching: find.text('1')), findsOneWidget);
      expect(h.server.lists().last['category'], 'furniture');
      // removing the chip refetches without it, back on page 1
      await t.tap(find.descendant(of: _k('asset-chip-category'), matching: find.byIcon(Icons.close)));
      await h.settle(t);
      expect(_k('asset-chip-category'), findsNothing);
      expect(h.server.lists().last.containsKey('category'), isFalse);
    });

    testWidgets('the filter sheet has the branch options loaded when it opens (regression)', (t) async {
      await _open(t);
      await h.tapKey(t, 'asset-filters');
      await h.tapKey(t, 'asset-filter-branch');
      expect(
          find.descendant(of: find.byType(DropdownMenuItem<String>), matching: find.text('South Wing')), findsWidgets);
    });

    testWidgets('Clear all resets search, status and filters, to page 1', (t) async {
      await _open(t);
      await h.type(t, 'asset-search', 'lap');
      await t.pump(const Duration(milliseconds: 400));
      await h.settle(t);
      await h.tapKey(t, 'asset-pill-available');
      expect(_k('asset-chip-search'), findsOneWidget);
      await h.tapKey(t, 'asset-clear-filters');
      expect(h.server.lists().last, {'page': 1, 'page_size': 20});
      expect(t.widget<TextField>(_k('asset-search')).controller!.text, '');
    });
  });

  group('asset cards', () {
    testWidgets('the web table’s columns, in a card: tag, name, category, type, branch, status, condition', (t) async {
      await _open(t);
      final card = _k('asset-row-a1');
      for (final text in [
        'LAP-001',
        'Dell Latitude',
        'IT Equipment',
        'Laptop',
        'North Wing',
        'Assigned',
        'Condition: Good'
      ]) {
        expect(find.descendant(of: card, matching: find.text(text)), findsOneWidget, reason: text);
      }
      expect(find.descendant(of: _k('asset-row-a2'), matching: find.text('Other (Mobiles)')), findsOneWidget);
    });

    testWidgets('the status colours the card edge and the badge: damaged ≠ available ≠ under repair', (t) async {
      await _open(t);
      final colours = {
        for (final id in ['a1', 'a2', 'a3', 'a4']) id: _accentOf(t, id)
      };
      expect(colours['a2'], AppColors.error); // damaged
      expect(colours['a3'], AppColors.warning); // under repair
      expect(colours['a1'], AppColors.info); // assigned
      expect(colours['a4'], AppColors.success); // available
      expect(colours.values.toSet().length, greaterThan(2));
    });

    testWidgets(
        'row actions follow web: maintenance for damaged only, complete for under repair only, with real labels',
        (t) async {
      await _open(t);
      expect(find.descendant(of: _k('asset-maintenance-a2'), matching: find.text('Maintenance')), findsOneWidget);
      expect(_k('asset-maintenance-a1'), findsNothing);
      expect(find.descendant(of: _k('asset-complete-a3'), matching: find.text('Complete')), findsOneWidget);
      expect(_k('asset-complete-a2'), findsNothing);
      for (final k in ['asset-edit-a1', 'asset-delete-a1', 'asset-maintenance-a2', 'asset-complete-a3']) {
        expect(t.getSize(_k(k)).height, greaterThanOrEqualTo(44), reason: k);
      }
      // the full wording is kept for tooltip and accessibility
      expect(find.byTooltip('Send to Maintenance'), findsOneWidget);
      expect(find.byTooltip('Complete Maintenance'), findsOneWidget);
    });

    testWidgets('a viewer (assets.view only) sees cards and no actions', (t) async {
      await h.pump(t, as: h.viewer);
      expect(_k('asset-row-a1'), findsOneWidget);
      expect(find.text('Edit'), findsNothing);
      expect(find.text('Delete'), findsNothing);
      for (final k in ['asset-edit-a1', 'asset-delete-a1', 'asset-bulk-assign', 'asset-bulk-import', 'asset-add']) {
        expect(_k(k), findsNothing, reason: k);
      }
    });

    testWidgets('the result count comes from the API', (t) async {
      await _open(t);
      expect(find.text('4 assets'), findsOneWidget);
    });

    testWidgets('a very long name and identifier wrap or ellipsize without overflow', (t) async {
      await _open(t, size: const Size(320, 3000), setup: (s) {
        s.assets = [
          h.asset('x1', 'LAP-0099-EXTENDED-IDENTIFIER-2026-NORTH-WING-REGISTER-ENTRY',
              'MacBook Pro 16-inch M3 Max with Extended Warranty and Accessories Bundle for Senior Engineers'),
        ];
      });
      expect(t.takeException(), isNull);
      expect(_k('asset-row-x1'), findsOneWidget);
    });
  });

  group('states', () {
    testWidgets('nothing at all: calm empty, no Clear filters', (t) async {
      await _open(t, setup: (s) => s.assets = []);
      expect(find.byWidgetPredicate((w) => w is ApprovalsEmptyState && w.kind == ApprovalsStateKind.empty),
          findsOneWidget);
      expect(find.text('No assets found.'), findsOneWidget);
      expect(_k('approvals-empty-action'), findsNothing);
    });

    testWidgets('filters matched nothing: its own state with Clear filters, which restores the list', (t) async {
      await _open(t);
      await h.type(t, 'asset-search', 'zzzz');
      await t.pump(const Duration(milliseconds: 400));
      await h.settle(t);
      expect(find.byWidgetPredicate((w) => w is ApprovalsEmptyState && w.kind == ApprovalsStateKind.noMatch),
          findsOneWidget);
      await h.tapKey(t, 'approvals-empty-action');
      expect(find.text('Dell Latitude'), findsOneWidget);
    });

    testWidgets('a failed load is an error with Retry (titled for assets), never the empty look', (t) async {
      await _open(t, setup: (s) => s.listStatus = 500);
      expect(_k('asset-load-error'), findsOneWidget);
      expect(find.text('Couldn’t load assets'), findsOneWidget);
      expect(find.text('No assets yet'), findsNothing);
      h.server.listStatus = 200;
      await h.tapKey(t, 'approvals-empty-action');
      expect(find.text('Dell Latitude'), findsOneWidget);
    });

    testWidgets('no assets.view: denied, no Retry', (t) async {
      await h.pump(t, as: h.user(['settings.view']));
      expect(find.byWidgetPredicate((w) => w is ApprovalsEmptyState && w.kind == ApprovalsStateKind.denied),
          findsOneWidget);
      expect(_k('approvals-empty-action'), findsNothing);
    });

    testWidgets('paging: the pager shows only with more than one page, Prev disabled on page 1', (t) async {
      await _open(t, size: const Size(393, 9000), setup: (s) {
        s.assets = [for (var i = 0; i < 25; i++) h.asset('p$i', 'TAG-$i', 'Item $i')];
      });
      expect(find.text('Page 1 of 2'), findsOneWidget);
      expect(t.widget<OutlinedButton>(_k('asset-prev')).onPressed, isNull);
      await h.tapKey(t, 'asset-next');
      expect(find.text('Page 2 of 2'), findsOneWidget);
      expect(t.widget<OutlinedButton>(_k('asset-next')).onPressed, isNull);
    });
  });

  group('responsive', () {
    double top(WidgetTester t, String id) => t.getTopLeft(_k('asset-row-$id')).dy;

    testWidgets('columns follow the width: 1 on a phone, 2 from 600dp, 3 from 900dp', (t) async {
      await _open(t, size: const Size(393, 3000));
      expect(top(t, 'a1') != top(t, 'a2'), isTrue);
      await _open(t, size: const Size(700, 3000));
      expect(top(t, 'a1'), top(t, 'a2'));
      expect(top(t, 'a3') != top(t, 'a1'), isTrue);
      await _open(t, size: const Size(1000, 3000));
      expect(top(t, 'a1'), top(t, 'a3'));
    });

    for (final (w, hgt, s) in [
      (320.0, 568.0, 1.0),
      (360.0, 800.0, 1.0),
      (393.0, 852.0, 1.0),
      (430.0, 932.0, 1.0),
      (700.0, 1000.0, 1.0),
      (1000.0, 800.0, 1.0),
      (320.0, 568.0, 2.0),
      (360.0, 800.0, 1.5),
    ]) {
      testWidgets('${w.toInt()}×${hgt.toInt()} at $s× text: scrolls end to end, no overflow', (t) async {
        await _open(t, size: Size(w, hgt), scale: s, setup: (b) {
          b.assets = [
            ...b.assets,
            h.asset('long', 'LAP-0099-EXTENDED-IDENTIFIER-2026', 'MacBook Pro 16-inch M3 Max with Extended Warranty'),
          ];
        });
        expect(t.takeException(), isNull);
        for (var i = 0; i < 8; i++) {
          await t.drag(_k('asset-list'), const Offset(0, -300));
          await t.pump();
          expect(t.takeException(), isNull, reason: 'scroll $i');
        }
        expect(_k('asset-add'), findsOneWidget);
      });
    }

    testWidgets('the keyboard open over search keeps the hero usable on a short screen', (t) async {
      await _open(t, size: const Size(320, 568));
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(t.view.resetViewInsets);
      await t.tap(_k('asset-search'));
      await h.settle(t);
      expect(t.takeException(), isNull);
      t.view.resetViewInsets();
    });
  });

  testWidgets('the Add / Edit form opens as a route from the page and returns to it', (t) async {
    await _open(t);
    await h.tapKey(t, 'asset-add');
    expect(find.byType(AssetFormScreen), findsOneWidget);
    await h.tapKey(t, 'asset-cancel');
    expect(find.byType(AssetFormScreen), findsNothing);
    expect(_k('asset-list'), findsOneWidget);
  });
}

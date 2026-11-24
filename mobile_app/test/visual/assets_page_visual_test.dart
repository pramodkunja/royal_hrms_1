import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/announcements/presentation/announcements_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/assets/assets_settings_screen.dart';

import '../features/announcements/announcements_pagination_test.dart' as ann;
import '../features/settings/assets_settings_test.dart' as h;
import 'shot_harness.dart';

// Task 104.1 — render evidence for the whole Assets page (and the Announcements
// app-bar reference). Runs only with T1011_SHOTS=1 (T1011_OUT, T1011_PREFIX:
// `before_t1041_` for the page as it was after Task 104, `t1041_` after).
// Real widgets, real Poppins, the app's real routes and bars.

class _Storage extends SecureStorageService {
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

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 60));
  }
}

Future<void> _tap(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f, warnIfMissed: false);
  await _settle(t);
}

/// A richer list than the unit-test default: every status, long names, Other category.
void _rich(h.Backend s) {
  s.assets = [
    h.asset('a1', 'LAP-001', 'Dell Latitude 5420 Business Laptop', status: 'assigned', assignment: {
      'id': 'as1',
      'status': 'assigned',
      'status_display': 'Assigned',
      'assigned_date': '2026-11-01',
      'expected_return_date': null,
      'employee_hidden': false,
      'employee_name': 'Asha Test',
      'employee_code': 'EMP-2',
    }),
    h.asset('a2', 'PHN-014', 'Pixel 8 Pro',
        category: 'Other', categoryOther: 'Mobiles', type: 'Phone', status: 'damaged', condition: 'damaged'),
    h.asset('a3', 'MON-007', 'Dell UltraSharp 27" Monitor',
        type: 'Monitor',
        status: 'under_repair',
        condition: 'fair',
        maintenance: {'id': 'm1', 'issue': 'Flickering screen', 'maintenance_start_date': '2026-11-02'}),
    h.asset('a4', 'FUR-102', 'Ergonomic Office Chair',
        category: 'Furniture',
        type: 'Chair',
        status: 'available',
        condition: 'new',
        branch: '2',
        branchName: 'South Wing'),
    h.asset('a5', 'LAP-0099-EXTENDED-IDENTIFIER-2026',
        'MacBook Pro 16-inch M3 Max with Extended Warranty and Accessories Bundle',
        status: 'available', condition: 'good'),
    h.asset('a6', 'PRJ-003', 'Epson Projector', type: 'Projector', status: 'retired', condition: 'fair'),
  ];
}

Future<void> _open(WidgetTester t,
    {Size size = const Size(393, 2300),
    double scale = 1,
    void Function(h.Backend)? setup,
    bool rich = true,
    UserEntity? as,
    double keyboard = 0}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  await t.runAsync(loadShotFonts);
  final u = as ?? h.admin;
  h.server = h.Backend({...u.permissions});
  if (rich) _rich(h.server);
  setup?.call(h.server);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider
          .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = h.server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
      assetDatePickerProvider.overrideWithValue((context, initial) async => DateTime(2026, 11, 13)),
    ],
    child: shotFrame(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(false),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(path: '/s', builder: (_, __) => const AssetsSettingsScreen()),
      ]),
    )),
  ));
  await _settle(t);
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // The reference: Announcements under the shell's own AppTopBar.
  shot('00_announcements_reference', (t) async {
    t.view.physicalSize = const Size(393, 852);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.runAsync(loadShotFonts);
    final server = ann.FakeAnnouncementsServer([for (var i = 3; i >= 1; i--) ann.ann(i)]);
    await t.pumpWidget(ProviderScope(
      key: UniqueKey(),
      overrides: [
        authStateProvider.overrideWith(() => _Auth(h.admin)),
        dioProvider
            .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
        cookieJarProvider.overrideWithValue(CookieJar()),
        secureStorageProvider.overrideWithValue(_Storage()),
      ],
      child: shotFrame(MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeFor(false),
        home: Scaffold(appBar: shotAppBar('Announcements'), body: const AnnouncementsScreen()),
      )),
    ));
    await _settle(t);
  });

  shot('01_main_populated', (t) => _open(t));
  shot('02_search_status_filter', (t) async {
    await _open(t, size: const Size(393, 1100));
    await t.enterText(find.byKey(const Key('asset-search')), 'lap');
    await t.pump(const Duration(milliseconds: 500));
    await _settle(t);
  });
  shot('02b_filter_sheet', (t) async {
    await _open(t, size: const Size(393, 852));
    await _tap(t, 'asset-filters');
  });
  shot('02c_status_and_branch_filters', (t) async {
    await _open(t, size: const Size(393, 1100));
    await _tap(t, 'asset-pill-available');
    await _tap(t, 'asset-filters');
    await _tap(t, 'asset-filter-branch');
    await t.tap(find.descendant(of: find.byType(DropdownMenuItem<String>), matching: find.text('South Wing')).last);
    await _settle(t);
    await _tap(t, 'asset-sheet-done');
  });
  shot('03_empty_none', (t) => _open(t, size: const Size(393, 852), setup: (s) => s.assets = []));
  shot('04_empty_no_match', (t) async {
    await _open(t, size: const Size(393, 852));
    await t.enterText(find.byKey(const Key('asset-search')), 'zzzzzz');
    await t.pump(const Duration(milliseconds: 500));
    await _settle(t);
  });
  shot('05_error', (t) => _open(t, size: const Size(393, 852), setup: (s) => s.listStatus = 500));
  shot('06_denied', (t) => _open(t, size: const Size(393, 852), as: h.user(['settings.view'])));
  shot('07_viewer_no_actions', (t) => _open(t, size: const Size(393, 1500), as: h.viewer));
  shot('08_add_form', (t) async {
    await _open(t, size: const Size(393, 2300));
    await _tap(t, 'asset-add');
  });
  shot('09_edit_form', (t) async {
    await _open(t, size: const Size(393, 2300));
    await _tap(t, 'asset-edit-a1');
  });
  shot('10_320dp_2x', (t) => _open(t, size: const Size(320, 4200), scale: 2));
  shot('10b_360dp', (t) => _open(t, size: const Size(360, 2400)));
  shot('10c_430dp', (t) => _open(t, size: const Size(430, 2300)));
  shot('11_tablet_1000', (t) => _open(t, size: const Size(1000, 1500)));
  shot('11b_foldable_700', (t) => _open(t, size: const Size(700, 1500)));
  shot('12_delete_dialog', (t) async {
    await _open(t, size: const Size(393, 852));
    await _tap(t, 'asset-delete-a4');
  });
  shot('13_maintenance_send', (t) async {
    await _open(t, size: const Size(393, 1100));
    await _tap(t, 'asset-maintenance-a2');
  });
  shot(
      '14_paging',
      (t) => _open(t, size: const Size(393, 2600), setup: (s) {
            s.assets = [
              for (var i = 1; i <= 25; i++) h.asset('p$i', 'AST-${i.toString().padLeft(3, '0')}', 'Asset number $i')
            ];
          }));
}

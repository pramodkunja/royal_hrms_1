import 'dart:async';

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
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/assets/assets_settings_screen.dart';

import '../features/settings/assets_settings_test.dart' as h;
import 'shot_harness.dart';

// Task 104 — render evidence for the Add Asset form, reached the way the app
// reaches it: Assets screen → "Add Asset". Runs only with T1011_SHOTS=1
// (T1011_OUT, T1011_PREFIX: `before_t104_` for the old sheet, `t104_` for the
// redesign). Real widgets, real Poppins.

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

Future<void> _type(WidgetTester t, String key, String text) async {
  final f = find.byKey(Key(key));
  await t.ensureVisible(f);
  await t.enterText(f, text);
  await _settle(t);
}

Future<void> _choose(WidgetTester t, String key, String option) async {
  await _tap(t, key);
  await t.tap(find.text(option).last);
  await _settle(t);
}

/// Opens Assets and taps Add Asset (or [edit] a row).
Future<void> _open(WidgetTester t,
    {Size size = const Size(393, 2300),
    double scale = 1,
    bool realDatePicker = false,
    void Function(h.Backend)? setup,
    double keyboard = 0,
    String? edit}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  await t.runAsync(loadShotFonts);
  h.server = h.Backend({...h.admin.permissions});
  setup?.call(h.server);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(h.admin)),
      dioProvider
          .overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = h.server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
      if (!realDatePicker)
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
  await _tap(t, edit == null ? 'asset-add' : 'asset-edit-$edit');
}

Future<void> _partial(WidgetTester t) async {
  await _type(t, 'asset-field-asset_tag', 'LAP-100');
  await _type(t, 'asset-field-asset_name', 'Dell Latitude 5420');
  await _choose(t, 'asset-field-category', 'IT Equipment');
}

Future<void> _full(WidgetTester t) async {
  await _partial(t);
  await _choose(t, 'asset-field-asset_type', 'Laptop');
  await _type(t, 'asset-field-brand', 'Dell');
  await _type(t, 'asset-field-model', 'Latitude 5420');
  await _type(t, 'asset-field-serial_number', 'SN-8841-XK2');
  await _choose(t, 'asset-field-branch', 'North Wing');
  await _tap(t, 'asset-field-purchase_date');
  await _type(t, 'asset-field-purchase_price', '84500.00');
  await _type(t, 'asset-field-vendor', 'Croma Retail Pvt Ltd');
  await _tap(t, 'asset-field-warranty_start_date');
  await _tap(t, 'asset-field-warranty_end_date');
  await _type(t, 'asset-field-description', 'Issued with charger and carry case. Sealed box opened on delivery.');
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  shot('01_empty', (t) => _open(t));
  shot('02_partial', (t) async {
    await _open(t);
    await _partial(t);
  });
  shot('03_full', (t) async {
    await _open(t);
    await _full(t);
  });
  shot('04_dropdown_open', (t) async {
    await _open(t, size: const Size(393, 1100));
    await _tap(t, 'asset-field-category');
  });
  shot('05_date_picker', (t) async {
    await _open(t, size: const Size(393, 2300), realDatePicker: true);
    await _tap(t, 'asset-field-purchase_date');
  });
  shot('06_validation_errors', (t) async {
    await _open(t,
        setup: (s) => s.refuseNext = (
              status: 400,
              message: 'Please correct the highlighted fields.',
              data: {
                'asset_tag': ['Asset Tag "LAP-001" already exists.'],
                'asset_name': ['This field may not be blank.'],
                'category': ['This field is required.'],
                'asset_type': ['This field is required.'],
                'branch': ['Select a valid branch.'],
                'purchase_price': ['Ensure this value is greater than or equal to 0.'],
                'warranty_end_date': ['Warranty end date cannot be before the start date.'],
              },
            ));
    await _tap(t, 'asset-save');
  });
  shot('07_server_error', (t) async {
    await _open(t,
        setup: (s) => s.refuseNext = (status: 500, message: 'Server error. Please try again later.', data: null));
    await _partial(t);
    await _tap(t, 'asset-save');
  });
  shot('08_saving', (t) async {
    final hold = Completer<void>();
    await _open(t, setup: (s) => s.holdWrite = hold);
    await _partial(t);
    await _choose(t, 'asset-field-asset_type', 'Laptop');
    await _choose(t, 'asset-field-branch', 'North Wing');
    await t.tap(find.byKey(const Key('asset-save')), warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 100));
    addTearDown(() => hold.isCompleted ? null : hold.complete());
  });
  shot('09_320dp_2x', (t) => _open(t, size: const Size(320, 4200), scale: 2));
  shot('09b_320dp_2x_keyboard', (t) async {
    await _open(t, size: const Size(320, 568), scale: 2, keyboard: 280);
    await _tap(t, 'asset-field-asset_tag');
  });
  shot('10_tablet_1000', (t) => _open(t, size: const Size(1000, 800)));
  shot('11_edit', (t) => _open(t, size: const Size(393, 2300), edit: 'a1'));
  shot('12_phone_keyboard', (t) async {
    await _open(t, size: const Size(393, 852), keyboard: 300);
    await _tap(t, 'asset-field-asset_tag');
  });
}

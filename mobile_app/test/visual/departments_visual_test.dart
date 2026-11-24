// Task 107 harness: Departments & Designations through the real route, with a
// stand-in API (nothing leaves the test) and render-evidence shots (T1011_SHOTS=1).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/departments/departments_screen.dart';

import 'shot_harness.dart';

const longDeptName =
    'Corporate Strategy, Mergers & Acquisitions and International Regulatory Compliance Affairs Division';

class DeptServer implements HttpClientAdapter {
  int deptStatus = 200;
  int desigStatus = 200;
  int? saveStatus;
  String saveMessage = 'A designation with this name already exists in this department.';
  bool noDepts = false;
  int manyDepts = 0;
  Completer<void>? deptHold;
  final log = <String>[];
  final bodies = <String, List<Object?>>{};

  List<Map<String, dynamic>> depts() {
    if (noDepts) return [];
    final base = <Map<String, dynamic>>[
      {
        'id': 1,
        'name': 'Engineering',
        'description': 'Builds the product',
        'is_active': true,
        'designation_count': 2,
        'employee_count': 12
      },
      {
        'id': 2,
        'name': longDeptName,
        'description': '',
        'is_active': true,
        'designation_count': 1,
        'employee_count': 3
      },
      {
        'id': 3,
        'name': 'Human Resources',
        'description': '',
        'is_active': false,
        'designation_count': 0,
        'employee_count': 0
      },
    ];
    for (var i = 0; i < manyDepts; i++) {
      base.add({
        'id': 10 + i,
        'name': 'Department ${i + 1} of the Operations Group',
        'description': '',
        'is_active': true,
        'designation_count': 0,
        'employee_count': 0
      });
    }
    return base;
  }

  final desigs = <Map<String, dynamic>>[
    {
      'id': 100,
      'name': 'Senior Software Engineer',
      'department': 1,
      'department_name': 'Engineering',
      'is_active': true
    },
    {'id': 101, 'name': 'QA Lead', 'department': 1, 'department_name': 'Engineering', 'is_active': false},
    {
      'id': 102,
      'name': 'Head of Global Strategy and Regulatory Affairs',
      'department': 2,
      'department_name': longDeptName,
      'is_active': true
    },
  ];

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  Object _ok(Object data) => {'status': 'success', 'message': 'ok', 'data': data};

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    final key = '${o.method} ${o.path}';
    log.add(key);
    bodies.putIfAbsent(key, () => []).add(o.data);
    if (key == 'GET /departments/') {
      final hold = deptHold;
      if (hold != null) await hold.future;
      if (deptStatus != 200) return _json({'status': 'error', 'message': 'Server error.'}, deptStatus);
      return _json(_ok(depts()));
    }
    if (key == 'GET /designations/') {
      if (desigStatus != 200) return _json({'status': 'error', 'message': 'Server error.'}, desigStatus);
      return _json(_ok(desigs));
    }
    if (o.method == 'POST' || o.method == 'PUT') {
      if (saveStatus != null) return _json({'status': 'error', 'message': saveMessage}, saveStatus!);
      final d = Map<String, dynamic>.from(o.data as Map);
      if (o.path.startsWith('/designations/')) {
        final id = o.method == 'PUT' ? int.parse(o.path.split('/')[2]) : 500;
        final deptId = d['department'] as int?;
        final name = depts().firstWhere((x) => x['id'] == deptId, orElse: () => {'name': ''})['name'];
        return _json(_ok({'id': id, ...d, 'department_name': name}), o.method == 'POST' ? 201 : 200);
      }
      return _json(_ok({'id': 600, 'designation_count': 0, 'employee_count': 0, ...d}), 201);
    }
    if (o.method == 'DELETE') return _json(_ok({}), 200);
    return _json({'status': 'error', 'message': 'unhandled $key'}, 404);
  }

  @override
  void close({bool force = false}) {}
}

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

UserEntity deptUser([List<String> perms = const ['settings.view', 'settings.edit']]) => UserEntity(
      id: 'u1',
      email: 'admin@example.test',
      fullName: 'Admin',
      role: 'admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> openDepartments(WidgetTester t,
    {Size size = const Size(393, 852),
    double scale = 1,
    DeptServer? server,
    UserEntity? as,
    bool dark = false,
    double keyboard = 0,
    bool shots = true}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shots && shotsEnabled) await t.runAsync(loadShotFonts);
  final s = server ?? DeptServer();
  lastServer = s;
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? deptUser())),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: shotFrame(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      routerConfig: GoRouter(initialLocation: '/settings/departments', routes: [
        GoRoute(
          path: '/settings/departments',
          builder: (_, __) => Consumer(
            builder: (context, ref, _) =>
                ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : const DepartmentsScreen(),
          ),
        ),
      ]),
    )),
  ));
  await settle(t);
}

late DeptServer lastServer;

Future<void> tapText(WidgetTester t, String text, {bool last = false}) async {
  if (find.text(text).evaluate().isEmpty) {
    await t.scrollUntilVisible(find.text(text), 200,
        scrollable: find.descendant(of: find.byKey(const Key("dept-list")), matching: find.byType(Scrollable)).first);
  }
  final f = last ? find.text(text).last : find.text(text).first;
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f, warnIfMissed: false);
  await settle(t);
}

Future<void> tapKey(WidgetTester t, String key) async {
  final f = find.byKey(Key(key));
  if (f.evaluate().isEmpty) {
    // the list is lazy: bring the control into the built range first
    await t.scrollUntilVisible(f, 200,
        scrollable: find.descendant(of: find.byKey(const Key('dept-list')), matching: find.byType(Scrollable)).first);
  }
  await t.ensureVisible(f);
  await t.pump();
  await t.tap(f, warnIfMissed: false);
  await settle(t);
}

/// Expands the department (by name) and opens its Add Designation dialog.
Future<void> openAddDesignation(WidgetTester t, {String dept = 'Engineering'}) async {
  await tapText(t, dept);
  await tapKey(t, 'desig-add');
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const phone = Size(393, 852);
  const narrow = Size(320, 568);

  shot('d_01_list', (t) => openDepartments(t));
  shot('d_02_add_desig_long_dept', (t) async {
    await openDepartments(t, size: phone);
    await openAddDesignation(t, dept: longDeptName);
  });
  shot('d_03_selector_open', (t) async {
    await openDepartments(t, size: phone);
    await openAddDesignation(t, dept: longDeptName);
    await tapKey(t, 'desig-dept-field');
  });
  shot('d_04_320dp_2x_form', (t) async {
    await openDepartments(t, size: narrow, scale: 2);
    await openAddDesignation(t, dept: longDeptName);
  });
  shot('d_05_320dp_2x_selector_open', (t) async {
    await openDepartments(t, size: narrow, scale: 2);
    await openAddDesignation(t, dept: longDeptName);
    await tapKey(t, 'desig-dept-field');
  });

  shot('d_06_list_320dp_2x', (t) async {
    await openDepartments(t, size: const Size(320, 1400), scale: 2);
    await tapText(t, 'Engineering');
  });
  shot('d_07_edit_prefilled', (t) async {
    await openDepartments(t, size: phone);
    await tapText(t, longDeptName);
    await tapKey(t, 'desig-edit-102');
  });
  shot('d_08_server_error', (t) async {
    await openDepartments(t, size: phone, server: DeptServer()..saveStatus = 400);
    await openAddDesignation(t);
    await t.enterText(find.byKey(const Key('desig-name')), 'QA Lead');
    await tapKey(t, 'desig-submit');
  });
  shot('d_09_dark_selector', (t) async {
    await openDepartments(t, size: phone, dark: true);
    await openAddDesignation(t, dept: longDeptName);
    await tapKey(t, 'desig-dept-field');
  });
  shot('d_10_keyboard_selector_320', (t) async {
    await openDepartments(t, size: narrow, keyboard: 260);
    await openAddDesignation(t);
    await tapKey(t, 'desig-dept-field');
  });
}

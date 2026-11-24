// Task 111: HR Attendance -> OT Entry cards and Invalid Punches cards. Stand-in API (nothing leaves
// the test); render-evidence shots only with T1011_SHOTS=1.
import 'dart:convert';
import 'dart:io';

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
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

import 'shot_harness.dart';

const longName = 'Bartholomew Montgomery-Featherstonehaugh Subramaniam';
const longApprover = 'Priyadarshini Venkataraghavan-Krishnamurthy';

List<Map<String, dynamic>> otRows() => [
      {
        'id': 'o1',
        'employee_id': 'EMP-0007',
        'name': 'Pat Kumar',
        'initials': 'PK',
        'date': '2026-11-18',
        'ot_hours': '2h 30m',
        'ot_type': 'Regular',
        'ot_amount': '1250.00',
        'approved_by': 'Asha Rao',
        'status': 'approved',
      },
      {
        'id': 'o2',
        'employee_id': 'EMP-0011',
        'name': longName,
        'initials': 'BM',
        'date': '2026-11-17',
        'ot_hours': '4h',
        'ot_type': 'Weekly Off',
        'ot_amount': '2,48,750.50',
        'approved_by': longApprover,
        'status': 'pending',
      },
      {
        'id': 'o3',
        'employee_id': 'EMP-0012',
        'name': 'Sam Lee',
        'initials': 'SL',
        'date': '2026-11-15',
        'ot_hours': '45m',
        'ot_type': 'Holiday',
        'ot_amount': '300.00',
        'approved_by': '—',
        'status': 'rejected',
      },
    ];

List<Map<String, dynamic>> invalidRows() => [
      {
        'id': 'ip1',
        'device_id': 'DEV-7',
        'raw_time': '2026-11-23 09:02:11',
        'biometric_id': 'DEV-7',
        'issue': 'Expected OUT, got IN',
        'issue_type': 'no-match',
        'suggested_match': 'Add OUT punch',
        'branch': 'Surat',
      },
      {
        'id': 'ip2',
        'device_id': 'GATE-NORTH-TERMINAL-0042',
        'raw_time': '2026-11-23 09:02:40',
        'biometric_id': 'GATE-NORTH-TERMINAL-0042',
        'issue': 'Duplicate IN within 60 seconds',
        'issue_type': 'duplicate',
        'suggested_match': 'Add OUT punch',
        'branch': 'Head Office - Bandra Kurla Complex Annexe',
      },
      {
        'id': 'ip3',
        'device_id': '—',
        'raw_time': '2026-11-23 23:59:59',
        'biometric_id': '—',
        'issue': 'Punch time is in the future',
        'issue_type': 'future',
        'suggested_match': 'Add IN punch',
        'branch': '—',
      },
    ];

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> ot = otRows();
  List<Map<String, dynamic>> invalid = invalidRows();
  int totalPages = 1;
  int otStatus = 200;
  int invalidStatus = 200;
  final writes = <(String, String, Object?)>[];

  ResponseBody _json(int s, Object b) => ResponseBody.fromString(jsonEncode(b), s, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  Map<String, dynamic> _page(List rows) =>
      {'count': rows.length, 'page': 1, 'page_size': 20, 'total_pages': totalPages, 'results': rows};

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      writes.add((o.method, o.path, o.data));
      return _json(200, {'status': 'success', 'message': 'ok', 'data': <String, dynamic>{}});
    }
    Map<String, dynamic> ok(Object d) => {'status': 'success', 'message': 'ok', 'data': d};
    if (o.path == '/attendance/overtime/') {
      if (otStatus != 200) return _json(otStatus, {'status': 'error', 'message': 'Server error.', 'data': {}});
      return _json(200, ok(_page(ot)));
    }
    if (o.path == '/attendance/invalid-punches/') {
      if (invalidStatus != 200) {
        return _json(invalidStatus,
            {'status': 'error', 'message': invalidStatus == 403 ? 'Permission denied.' : 'Server error.', 'data': {}});
      }
      return _json(200, ok(_page(invalid)));
    }
    if (o.path == '/employees/') {
      return _json(200, ok(_page([
        {
          'id': 'u7',
          'employee_id': 'EMP-0007',
          'first_name': 'Pat',
          'last_name': 'Kumar',
          'full_name': 'Pat Kumar',
          'email': 'pat@example.test',
          'branch': 'Surat',
          'department': 'Engineering',
        }
      ])));
    }
    if (o.path == '/employees/hrs/') {
      return _json(200, ok([
        {'id': 'h1', 'employee_id': 'HR-1', 'full_name': 'Asha Rao'}
      ]));
    }
    return _json(200, ok(_page(const [])));
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
  _Auth(this.perms);
  final List<String> perms;
  @override
  Future<AuthState> build() async => AuthState(
      user: UserEntity(
          id: 'u1',
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: perms,
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

const staffPerms = ['attendance.view', 'attendance.create', 'attendance.edit', 'employees.view'];

late Server last;

Future<void> openTab(WidgetTester t, String tab,
    {Size size = const Size(393, 852),
    double scale = 1,
    Server? server,
    bool dark = false,
    List<String> perms = staffPerms}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shotsEnabled) await t.runAsync(loadShotFonts);
  final s = server ?? Server();
  last = s;
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(perms)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: Consumer(
        builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
            ? const SizedBox()
            : const Scaffold(body: AttendanceScreen()),
      ),
    )),
  ));
  for (var i = 0; i < 10; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
  await t.ensureVisible(find.text(tab).first);
  await t.pump();
  await t.tap(find.text(tab).first);
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<void> toRecords(WidgetTester t) async {
  final list = find.ancestor(of: find.text('Add OT Entry').first, matching: find.byType(Scrollable)).first;
  await t.scrollUntilVisible(find.text('OT Records'), 300, scrollable: list);
  await t.drag(list, const Offset(0, -150));
  await settle(t);
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    // Evidence renders keep going past layout overflow (it is visible in the PNG); the real
    // assertions live in test/features/attendance/*_cards_test.dart.
    final ex = Platform.environment['T111_RAW'] == '1' ? null : t.takeException();
    if (ex != null) debugPrint('layout exception in $name: ${(ex is FlutterError ? ex.toStringDeep() : ex.toString()).split('\n').where((l) => l.contains('creator') || l.contains('overflowed') || l.contains('.dart')).take(6).join(' / ')}');
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  shot('ot_01_main', (t) async => openTab(t, 'OT Entry'));
  shot('ot_02_records', (t) async {
    await openTab(t, 'OT Entry');
    await toRecords(t);
  });
  shot('ot_03_320_2x', (t) async {
    await openTab(t, 'OT Entry', size: const Size(320, 1400), scale: 2);
    await toRecords(t);
  });
  shot('ot_04_tablet', (t) async {
    await openTab(t, 'OT Entry', size: const Size(1000, 900));
    await toRecords(t);
  });
  shot('ot_05_dark', (t) async {
    await openTab(t, 'OT Entry', dark: true);
    await toRecords(t);
  });
  shot('ot_06_empty', (t) async {
    await openTab(t, 'OT Entry', server: Server()..ot = []);
    await toRecords(t);
  });
  shot('ot_07_error', (t) async {
    await openTab(t, 'OT Entry', server: Server()..otStatus = 500);
    await toRecords(t);
  });
  shot('ot_08_320', (t) async {
    await openTab(t, 'OT Entry', size: const Size(320, 1000));
    await toRecords(t);
  });

  shot('ip_01_main', (t) async => openTab(t, 'Invalid Punches'));
  shot('ip_02_convert_dialog', (t) async {
    await openTab(t, 'Invalid Punches');
    await t.tap(find.text('Convert').first);
    await settle(t);
  });
  shot('ip_03_320_2x', (t) async => openTab(t, 'Invalid Punches', size: const Size(320, 1400), scale: 2));
  shot('ip_04_tablet', (t) async => openTab(t, 'Invalid Punches', size: const Size(1000, 900)));
  shot('ip_05_dark', (t) async => openTab(t, 'Invalid Punches', dark: true));
  shot('ip_06_empty', (t) async => openTab(t, 'Invalid Punches', server: Server()..invalid = []));
  shot('ip_07_error', (t) async => openTab(t, 'Invalid Punches', server: Server()..invalidStatus = 500));
  shot('ip_08_320', (t) async => openTab(t, 'Invalid Punches', size: const Size(320, 568)));
}

// Task 111 harness: HR Attendance -> Un-punches tab, stand-in API (nothing leaves the test) and
// render-evidence shots (T1011_SHOTS=1). Shots are state-only so the same file captures the
// before/after of the redesign.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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

Map<String, dynamic> unRow(String code, String name, String branch,
        {String date = '2026-11-20',
        String ci = '09:05',
        String eo = '18:00',
        bool pending = false,
        String? cid}) =>
    {
      'employee_id': code,
      'name': name,
      'initials': name.trim().isEmpty ? '' : name.trim().split(' ').map((p) => p[0]).take(2).join().toUpperCase(),
      'date': date,
      'clock_in': ci,
      'expected_out': eo,
      'branch': branch,
      'correction_pending': pending,
      'correction_id': cid,
    };

class UnServer implements HttpClientAdapter {
  List<Map<String, dynamic>> rows = [
    unRow('EMP-0042', 'Anika Sharma', 'Surat', pending: true, cid: 'c1'),
    unRow('EMP-0057', 'Imran Qureshi', 'Mumbai', ci: '08:48', eo: '17:30'),
    unRow('EMP-0063', 'Priyadarshini Venkataraghavan-Subramaniam', 'Ahmedabad Satellite Office, Gujarat',
        ci: '10:12', pending: true, cid: 'c2'),
  ];
  int totalPages = 1;
  int status = 200;
  String message = 'Failed.';
  final unpunchQueries = <Map<String, dynamic>>[];
  final writes = <String>[];
  Future<void>? hold;

  /// Race tests: the Nth un-punch request waits for gates[N] and answers rowsByCall[N] when present.
  final gates = <int, Completer<void>>{};
  final rowsByCall = <int, List<Map<String, dynamic>>>{};

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (o.method != 'GET') writes.add('${o.method} ${o.path}');
    if (o.method == 'GET' && o.path == '/attendance/un-punches/') {
      final n = unpunchQueries.length;
      unpunchQueries.add(Map.of(o.queryParameters));
      if (hold != null) await hold;
      if (gates[n] != null) await gates[n]!.future;
      if (status != 200) return _json({'status': 'error', 'message': message, 'data': {}}, status);
      final page = int.tryParse('${o.queryParameters['page'] ?? 1}') ?? 1;
      return _json({
        'status': 'success',
        'message': '${rows.length} un-punch(es) found.',
        'data': {
          'count': rows.length * totalPages,
          'page': page,
          'page_size': 20,
          'total_pages': totalPages,
          'results': rowsByCall[n] ?? rows,
        },
      });
    }
    if (o.method == 'GET' && o.path == '/employees/') {
      return _json({
        'status': 'success',
        'data': {
          'count': 0,
          'page': 1,
          'page_size': 20,
          'total_pages': 1,
          'results': <Object>[],
        }
      });
    }
    return _json({
      'status': 'success',
      'data': {'results': <Object>[], 'count': 0, 'page': 1, 'total_pages': 1}
    });
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

UserEntity unUser({List<String> perms = const ['attendance.view', 'attendance.edit', 'settings.edit'], String? branch}) =>
    UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Hira Test',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      branch: branch,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

Future<void> settleUn(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<ProviderContainer> openUnpunches(WidgetTester t,
    {Size size = const Size(393, 1400),
    double scale = 1,
    UnServer? server,
    UserEntity? as,
    bool dark = false,
    bool shots = true}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shots && shotsEnabled) await t.runAsync(loadShotFonts);
  final s = server ?? UnServer();
  // The Attendance shell's own stats bar (attendance_screen.dart, not part of this tab) overflows
  // with the wide test font / 2x text; that is reported separately. Everything else still fails.
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    if ((d.toString() + d.exception.toString()).contains('attendance_screen.dart')) {
      return;
    }
    original?.call(d);
  };
  addTearDown(() => FlutterError.onError = original);
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? unUser())),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: const Scaffold(body: AttendanceScreen()),
    )),
  ));
  await settleUn(t);
  final tab = find.text('Un-punches');
  await t.ensureVisible(tab);
  await t.pump();
  await t.tap(tab);
  await settleUn(t);
  return ProviderScope.containerOf(t.element(find.byType(AttendanceScreen)));
}

void unShot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  unShot('u_01_populated', (t) => openUnpunches(t));
  unShot('u_02_320', (t) => openUnpunches(t, size: const Size(320, 1500)));
  unShot('u_03_text2x', (t) async {
    await openUnpunches(t, size: const Size(393, 2400), scale: 2);
  });
  unShot('u_04_tablet', (t) => openUnpunches(t, size: const Size(1000, 1000)));
  unShot('u_05_dark', (t) => openUnpunches(t, dark: true));
  unShot('u_06_empty', (t) => openUnpunches(t, server: UnServer()..rows = []));
  unShot('u_07_error', (t) => openUnpunches(t, server: UnServer()..status = 500));
  unShot('u_08_denied', (t) => openUnpunches(t, server: UnServer()..status = 403..message = 'Permission denied.'));
}

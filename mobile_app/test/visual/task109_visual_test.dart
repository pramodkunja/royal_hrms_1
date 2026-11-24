// Task 109 harness: Leave → Analytics statistics, with a stand-in API (nothing leaves the test)
// and render-evidence shots (T1011_SHOTS=1).
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
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/leave/presentation/providers/leave_providers.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_analytics_tab.dart';

import 'shot_harness.dart';

class T109Server implements HttpClientAdapter {
  /// Default body for GET /leave/stats/ (a well-formed own-scope response with balances).
  Map<String, dynamic> body() => {
        'total': 14,
        'pending': 3,
        'approved': 9,
        'rejected': 2,
        'cancelled': 0,
        'lop_days': 2.5,
        'lop_requests': 2,
        'year': 2026,
        'balances': [
          {
            'leave_type': 'casual',
            'leave_type_display': 'Casual Leave',
            'total_days': 12.0,
            'used_days': 3.0,
            'available': 9.0
          },
          {
            'leave_type': 'earned',
            'leave_type_display': 'Earned Leave (Privilege Leave, Accumulating)',
            'total_days': 18.0,
            'used_days': 10.5,
            'available': 7.5
          },
        ],
      };

  /// Replaces the default body when set (any JSON value — e.g. a string for a malformed reply).
  Object? custom;
  int status = 200;
  String message = 'Server error.';

  /// Queued per-request behaviour for race tests: the Nth GET waits for gates[N] and answers
  /// bodies[N] (when present). Requests beyond the queue answer normally.
  final gates = <Completer<void>>[];
  final bodies = <Object?>[];

  final requests = <Map<String, dynamic>>[];
  int get count => requests.length;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    if (o.method == 'GET' && o.path == '/leave/stats/') {
      final n = requests.length;
      requests.add(Map.of(o.queryParameters));
      if (n < gates.length) await gates[n].future;
      if (status != 200) {
        return _json({'status': 'error', 'message': status == 403 ? 'You do not have permission.' : message}, status);
      }
      final data = n < bodies.length ? bodies[n] : (custom ?? body());
      return _json({'status': 'success', 'message': 'Stats retrieved.', 'data': data});
    }
    return _json({
      'status': 'success',
      'data': {'results': <Object>[]}
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

UserEntity u109(
        {String role = 'employee',
        List<String> perms = const ['leave.view', 'leave.create'],
        bool team = false,
        bool branch = false}) =>
    UserEntity(
      id: 'u1',
      email: 'asha@example.test',
      fullName: 'Asha Test',
      role: role,
      roleDisplay: role,
      mustChangePassword: false,
      permissions: perms,
      canManageTeam: team,
      canManageBranch: branch,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

late T109Server last;
DateTime clock = DateTime(2026, 11, 20, 10);

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Future<ProviderContainer> openAnalytics(WidgetTester t,
    {Size size = const Size(393, 1600),
    double scale = 1,
    T109Server? server,
    UserEntity? as,
    bool dark = false,
    bool shots = true,
    bool settleFirst = true}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shots && shotsEnabled) await t.runAsync(loadShotFonts);
  final s = server ?? T109Server();
  last = s;
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      leaveDashboardClockProvider.overrideWithValue(() => clock),
      authStateProvider.overrideWith(() => _Auth(as ?? u109())),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: const Scaffold(body: LeaveAnalyticsTab()),
    )),
  ));
  if (settleFirst) await settle(t);
  return ProviderScope.containerOf(t.element(find.byType(LeaveAnalyticsTab)));
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  shot('l_01_populated', (t) => openAnalytics(t, size: const Size(393, 1500)));
  shot(
      'l_02_zero',
      (t) => openAnalytics(t,
          size: const Size(393, 900),
          server: T109Server()
            ..custom = {
              'total': 0,
              'pending': 0,
              'approved': 0,
              'rejected': 0,
              'cancelled': 0,
              'lop_days': 0.0,
              'lop_requests': 0,
              'year': 2026,
              'balances': <Object>[],
            }));
  shot('l_03_loading', (t) async {
    final s = T109Server()..gates.add(Completer<void>());
    await openAnalytics(t, size: const Size(393, 900), server: s, settleFirst: false);
    await t.pump(const Duration(milliseconds: 200));
  });
  shot('l_04_error', (t) => openAnalytics(t, size: const Size(393, 900), server: T109Server()..status = 500));
  shot('l_05_denied', (t) => openAnalytics(t, size: const Size(393, 900), server: T109Server()..status = 403));
  shot(
      'l_06_unavailable_fields',
      (t) => openAnalytics(t,
          size: const Size(393, 1000),
          server: T109Server()..custom = {'total': 5, 'pending': 'many', 'approved': 2, 'year': 2026}));
  shot('l_07_320_2x', (t) => openAnalytics(t, size: const Size(320, 2600), scale: 2));
  shot('l_08_tablet_1000', (t) => openAnalytics(t, size: const Size(1000, 900)));
  shot('l_09_dark', (t) => openAnalytics(t, size: const Size(393, 1500), dark: true));
  shot(
      'l_10_approver_team_view',
      (t) => openAnalytics(t,
          size: const Size(393, 1100),
          as: u109(role: 'hr_admin', perms: ['leave.view', 'leave.approve']),
          server: T109Server()
            ..custom = {
              'total': 120,
              'pending': 14,
              'approved': 90,
              'rejected': 10,
              'cancelled': 6,
              'lop_days': 31.5,
              'lop_requests': 12,
              'year': 2026,
              'balances': <Object>[],
            }));
}

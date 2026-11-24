// Shared harness for the Employee Profile → Leave → Leave Requests card tests and renders
// (Task 110). A stand-in API (nothing leaves the test) and synthetic data only.
import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/widgets/employee_leave_tab.dart';

import 'shot_harness.dart';

const empCode = 'EMP-7';
final thisYear = DateTime.now().year;

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

/// One LeaveRequestSerializer row (apps/hrms/serializers.py), synthetic values.
Map<String, dynamic> reqJson(
  String id, {
  String type = 'casual',
  String display = 'Casual Leave',
  String status = 'pending',
  String start = '03-10',
  String end = '03-11',
  String duration = 'full_day',
  String durationDisplay = 'Full Day',
  Object totalDays = '2.0',
  Object lopDays = '0.0',
  String reason = 'Family function out of town.',
  String created = '03-01',
  String l1Name = 'Meera Nair',
  String? l1Status,
  String l1Remarks = '',
  String? l1At,
  String l2Name = '',
  String? l2Status,
  String l2Remarks = '',
  String? l2At,
  String approvedBy = '',
  String? approvedAt,
  String? documentUrl,
  bool canApprove = false,
  bool canCancel = false,
  bool canRequestCancellation = false,
  String cancellationStatus = '',
  int? year,
}) {
  final y = year ?? thisYear;
  return {
    'id': id,
    'leave_type': type,
    'leave_type_display': display,
    'duration': duration,
    'duration_display': durationDisplay,
    'start_date': '$y-$start',
    'end_date': '$y-$end',
    'total_days': totalDays,
    'lop_days': lopDays,
    'reason': reason,
    'status': status,
    'is_lwp': false,
    'employee_name': 'Pat Kumar',
    'employee_code': empCode,
    'employee_dept': 'Operations',
    'employee_branch': 'Pune',
    'l1_approver_name': l1Name,
    'l1_status': l1Status,
    'l1_remarks': l1Remarks,
    'l1_actioned_at': l1At,
    'l2_approver_name': l2Name,
    'l2_status': l2Status,
    'l2_remarks': l2Remarks,
    'l2_actioned_at': l2At,
    'contact_during_leave': '',
    'handover_to': '',
    'handover_notes': '',
    'document_url': documentUrl,
    'created_at': '$y-${created}T09:30:00+05:30',
    'can_approve': canApprove,
    'can_cancel': canCancel,
    'approved_by': approvedBy,
    'approved_at': approvedAt,
    'cancellation_status': cancellationStatus,
    'cancellation_reason': '',
    'cancellation_requested_at': null,
    'cancellation_remarks': '',
    'can_request_cancellation': canRequestCancellation,
    'can_decide_cancellation': false,
  };
}

/// A representative page: one request per status, half day, LOP, two levels.
List<Map<String, dynamic>> samplePage() => [
      reqJson('r1',
          status: 'pending',
          totalDays: '2.0',
          l1Status: 'pending',
          reason: 'Family function out of town, travelling by road on the 10th.'),
      reqJson('r2',
          status: 'l2_pending',
          type: 'earned',
          display: 'Earned Leave',
          start: '04-02',
          end: '04-04',
          totalDays: '3.0',
          l1Status: 'approved',
          l1At: '$thisYear-03-20T10:00:00+05:30',
          l1Remarks: 'Fine with the plan.',
          l2Name: 'Hema Iyer',
          l2Status: 'pending'),
      reqJson('r3',
          status: 'approved',
          type: 'sick',
          display: 'Sick Leave',
          start: '02-05',
          end: '02-05',
          duration: 'half_morning',
          durationDisplay: 'Half Day (Morning)',
          totalDays: '0.5',
          reason: 'Dental appointment.',
          l1Status: 'approved',
          l1At: '$thisYear-02-03T10:00:00+05:30',
          approvedBy: 'Meera Nair',
          approvedAt: '$thisYear-02-03T10:00:00+05:30'),
      reqJson('r4',
          status: 'rejected',
          start: '01-14',
          end: '01-16',
          totalDays: '3.0',
          lopDays: '1.5',
          reason: 'Personal work.',
          l1Status: 'rejected',
          l1Remarks: 'Month-end closing, please reschedule.',
          l1At: '$thisYear-01-10T10:00:00+05:30',
          approvedBy: 'Meera Nair',
          approvedAt: '$thisYear-01-10T10:00:00+05:30'),
      reqJson('r5', status: 'cancelled', start: '01-02', end: '01-02', totalDays: '1.0', l1Status: 'pending'),
    ];

class LeaveCardsServer implements HttpClientAdapter {
  /// Rows per page number; total_pages is the highest key.
  Map<int, List<Map<String, dynamic>>> pages = {1: samplePage()};
  int? requestsStatus;
  String requestsMessage = 'Server exploded.';
  Completer<void>? holdRequests;
  final calls = <({String method, String path, Map<String, dynamic> query})>[];

  List<Map<String, dynamic>> requestCalls() =>
      calls.where((c) => c.path == '/leave/requests/').map((c) => c.query).toList();

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters)));
    if (o.path == '/leave/requests/' && o.method == 'GET') {
      final gate = holdRequests;
      if (gate != null) await gate.future;
      final st = requestsStatus;
      if (st != null) return _json(st, {'status': 'error', 'message': requestsMessage, 'data': {}});
      final page = int.tryParse('${o.queryParameters['page']}') ?? 1;
      final rows = pages[page] ?? const [];
      final total = pages.keys.isEmpty ? 1 : pages.keys.reduce((a, b) => a > b ? a : b);
      return _json(200, {
        'status': 'success',
        'message': 'Leave requests retrieved.',
        'data': {
          'count': pages.values.fold<int>(0, (n, l) => n + l.length),
          'page': page,
          'page_size': 20,
          'total_pages': total,
          'results': rows,
        },
      });
    }
    if (o.path == '/leave/stats/' && o.method == 'GET') {
      return _json(200, {
        'status': 'success',
        'message': 'Stats retrieved.',
        'data': {
          'total': 5,
          'pending': 2,
          'approved': 1,
          'rejected': 1,
          'cancelled': 1,
          'lop_days': 1.5,
          'lop_requests': 1,
          'year': int.tryParse('${o.queryParameters['year']}') ?? thisYear,
          'balances': [
            {
              'leave_type': 'casual',
              'leave_type_display': 'Casual Leave',
              'total_days': 12,
              'used_days': 3,
              'available': 9,
              'credit_schedule': 'annual',
              'statement': null,
            },
          ],
        },
      });
    }
    if (o.path == '/leave/policy/' && o.method == 'GET') {
      return _json(200, {'status': 'success', 'message': 'ok', 'data': []});
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

class _NullStorage extends SecureStorageService {
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

UserEntity hrUser([List<String> perms = const ['employees.view', 'leave.view']]) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Hema Iyer',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: false,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

late LeaveCardsServer lastServer;

/// Mounts the Leave tab at [width] x [height] logical px (1x), [scale] text scale.
Future<void> pumpLeaveRequests(
  WidgetTester t, {
  LeaveCardsServer? server,
  double width = 393,
  double height = 1800,
  double scale = 1,
  bool dark = false,
  bool shots = false,
  bool settle = true,
}) async {
  t.view.physicalSize = Size(width, height);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shots && shotsEnabled) await t.runAsync(loadShotFonts);
  final s = server ?? LeaveCardsServer();
  lastServer = s;
  final emp = EmployeeModel.fromJson(const {
    'id': 'u7',
    'employee_id': empCode,
    'first_name': 'Pat',
    'last_name': 'Kumar',
    'full_name': 'Pat Kumar',
    'email': '',
  });
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(hrUser())),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: Scaffold(body: EmployeeLeaveTab(employee: emp)),
    )),
  ));
  if (settle) await settleFrames(t);
}

Future<void> settleFrames(WidgetTester t) async {
  for (var i = 0; i < 14; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

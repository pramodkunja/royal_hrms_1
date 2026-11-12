// DEBUG-ONLY demo of Employee Profile → Approval Matrix (Task 50) on the real
// screen, without signing in or calling a server:
//
//   flutter run -d <emulator> -t lib/debug/approval_matrix_demo_main.dart
//
// GET /employees/<code>/ and /employees/<code>/approval-matrix/ are answered
// in-process by [_DemoServer] in the production shapes (the matrix rows carry
// integer role ids, as EmployeeApprovalMatrixView sends them). Synthetic
// people; nothing leaves the device. Chips pick the next matrix answer (OK,
// a 500 once, 403, malformed). Not imported by lib/main.dart, so not part of
// the release app; refuses to run outside debug builds.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/presentation/controllers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/states/auth_state.dart';
import '../features/employees/presentation/providers/employee_providers.dart';
import '../features/employees/presentation/screens/employee_profile_screen.dart';

const _code = 'DEMO-50';

class _DemoAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'demo',
          email: 'demo@example.test',
          fullName: 'Demo HR',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: ['employees.view', 'employees.edit'],
          branch: 'North Wing',
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

enum MatrixMode { ok, failOnce, forbidden, malformed }

Map<String, dynamic> _row(String type, String label, {int? l2 = 2, bool override = false}) => {
      'workflow_type': type,
      'workflow_label': label,
      'l1_approver_role': 4,
      'l1_approver_label': 'Reporting Manager',
      'l1_approver_id': 'uuid-m1',
      'l1_approver_name': 'Demo Manager',
      'l1_is_override': override,
      'l2_approver_role': l2,
      'l2_approver_label': l2 == null ? '' : 'HR',
      'l2_approver_id': l2 == null ? null : 'uuid-h1',
      'l2_approver_name': l2 == null ? null : 'Demo HR Lead',
      'l2_is_override': false,
    };

class _DemoServer implements HttpClientAdapter {
  MatrixMode mode = MatrixMode.ok;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (o.path == '/employees/$_code/approval-matrix/' && o.method == 'GET') {
      final m = mode;
      if (m == MatrixMode.failOnce) mode = MatrixMode.ok;
      debugPrint('FAKE_SERVER GET approval-matrix → ${m.name}');
      return switch (m) {
        MatrixMode.ok => _json(200, {
            'status': 'success',
            'message': 'Approval matrix retrieved.',
            'data': [
              _row('leave', 'Leave'),
              _row('expense', 'Expense', l2: null),
              _row('attendance_correction', 'Attendance Correction', override: true),
            ],
          }),
        MatrixMode.failOnce =>
          _json(500, {'status': 'error', 'message': 'Server error. Please try again later.', 'data': {}}),
        MatrixMode.forbidden =>
          _json(403, {'status': 'error', 'message': 'You do not have permission to perform this action.', 'data': {}}),
        MatrixMode.malformed => _json(200, {
            'status': 'success',
            'data': {'unexpected': true}
          }),
      };
    }
    if (o.path == '/employees/$_code/' && o.method == 'GET') {
      return _json(200, {
        'status': 'success',
        'data': {
          'id': _code,
          'uuid': 'uuid-demo',
          'employee_id': _code,
          'first_name': 'Demo',
          'last_name': 'Employee',
          'full_name': 'Demo Employee',
          'email': 'demo.employee@example.test',
          'branch': 'North Wing',
          'department': 'QA',
          'designation': 'Analyst',
          'role': 'employee',
          'is_active': true,
          'status': 'active',
          'onboarding_status': 'complete',
          'reporting_manager': {'id': 'M-1', 'uuid': 'uuid-m1', 'name': 'Demo Manager'},
          'hr': {'id': 'H-1', 'uuid': 'uuid-h1', 'name': 'Demo HR Lead'},
          'documents': <Object>[],
          'profile': <String, dynamic>{},
        },
      });
    }
    return _json(200, {'status': 'success', 'data': <Object>[]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Debug builds only.')))));
    return;
  }
  final server = _DemoServer();
  runApp(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_DemoAuth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://demo.invalid/api'))..httpClientAdapter = server),
    ],
    child: _DemoApp(server: server),
  ));
}

class _DemoApp extends ConsumerStatefulWidget {
  const _DemoApp({required this.server});
  final _DemoServer server;
  @override
  ConsumerState<_DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends ConsumerState<_DemoApp> {
  @override
  Widget build(BuildContext context) {
    final s = widget.server;
    Widget chip(String label, MatrixMode m) => ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          selected: s.mode == m,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(() {
            s.mode = m;
            ref.invalidate(employeeApprovalMatrixProvider(_code));
          }),
        );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Column(children: [
        Material(
          child: SafeArea(
            bottom: false,
            child: Wrap(spacing: 6, children: [
              chip('Matrix OK', MatrixMode.ok),
              chip('500 once', MatrixMode.failOnce),
              chip('403', MatrixMode.forbidden),
              chip('Malformed', MatrixMode.malformed),
            ]),
          ),
        ),
        const Expanded(child: EmployeeProfileScreen(employeeId: _code)),
      ]),
    );
  }
}

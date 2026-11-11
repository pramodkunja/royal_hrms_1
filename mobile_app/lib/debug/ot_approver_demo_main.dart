// DEBUG-ONLY demo of HR Attendance → OT Entry and its "Approved By" picker,
// for checking the real screen on an emulator without signing in or calling a
// server:
//
//   flutter run -d <emulator> -t lib/debug/ot_approver_demo_main.dart
//
// Every request is answered in-process by [_DemoServer] with synthetic data in
// the production response shapes (EmployeeListView, HRListView,
// HROvertimeCreateView). Nothing leaves the device and no overtime is created
// anywhere. Each request is logged on screen and as "FAKE_SERVER ..." lines.
// The chips switch HR-list failure / slowness, drop an approver from a
// branch, and make the next save fail. Not imported by lib/main.dart, so not
// part of the release app; refuses to run outside debug builds.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_client.dart';
import '../features/attendance/presentation/screens/attendance_screen.dart';
import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/presentation/controllers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/states/auth_state.dart';
import '../features/employees/presentation/providers/employee_providers.dart';

const _demoUser = UserEntity(
  id: 'demo',
  email: 'demo@example.test',
  fullName: 'Demo HR',
  role: 'hr',
  roleDisplay: 'HR',
  mustChangePassword: false,
  permissions: ['attendance.view', 'attendance.create', 'employees.view'],
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

class _DemoAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(user: _demoUser);
}

Map<String, dynamic> _emp(String code, String name, String branch) => {
      'id': 'u-$code',
      'employee_id': code,
      'first_name': name.split(' ').first,
      'last_name': name.split(' ').last,
      'full_name': name,
      'email': '',
      'branch': branch,
      'status': 'active',
      'is_active': true,
    };

Map<String, dynamic> _hr(String code, String name, String branch) =>
    {'id': 'uuid-$code', 'employee_id': code, 'full_name': name, 'department': 'HR', 'branch': branch};

class _DemoServer implements HttpClientAdapter {
  _DemoServer(this.onLog);
  final void Function(String) onLog;

  bool hrsFail = false;
  bool hrsSlow = false;
  bool saveFails = false;
  bool dropBilal = false;

  List<Map<String, dynamic>> _hrs(String branch) => switch (branch) {
        'North Wing' => [
            _hr('HR-N1', 'Asha Rao', 'North Wing'),
            if (!dropBilal) _hr('HR-N2', 'Bilal Khan', 'North Wing'),
          ],
        'South Wing' => [_hr('HR-S1', 'Chen Li', 'South Wing')],
        _ => [],
      };

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  void _log(String line) {
    debugPrint('FAKE_SERVER $line');
    onLog(line);
  }

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (o.path == '/employees/' && o.method == 'GET') {
      return _json(200, {
        'status': 'success',
        'data': {
          'results': [
            _emp('EMP-1', 'Pat Kumar', 'North Wing'),
            _emp('EMP-2', 'Sam Iyer', 'South Wing'),
            _emp('EMP-3', 'Lee Das', 'North Wing'),
            _emp('EMP-4', 'Ria Sen', ''),
            _emp('EMP-5', 'Om Nair', 'East Wing'),
          ],
          'total_pages': 1,
        },
      });
    }
    if (o.path == '/employees/hrs/' && o.method == 'GET') {
      _log('GET /employees/hrs/ ${jsonEncode(o.queryParameters)}');
      if (hrsSlow) await Future<void>.delayed(const Duration(seconds: 6));
      if (hrsFail) return _json(500, {'status': 'error', 'message': 'HR list unavailable (demo).', 'data': {}});
      final branch = '${o.queryParameters['branch'] ?? ''}';
      if (branch.isEmpty) {
        return _json(400, {'status': 'error', 'message': 'branch query parameter is required.', 'data': {}});
      }
      return _json(200, {'status': 'success', 'message': 'HR users retrieved.', 'data': _hrs(branch)});
    }
    if (o.path == '/attendance/overtime/create/' && o.method == 'POST') {
      _log('POST /attendance/overtime/create/ ${jsonEncode(o.data)}');
      if (saveFails) {
        return _json(400, {'status': 'error', 'message': 'OT date cannot be in the future. (demo)', 'data': {}});
      }
      return _json(201, {
        'status': 'success',
        'message': 'Overtime entry created.',
        'data': {'id': 'demo-ot'}
      });
    }
    // Everything else on the screen: empty lists / zero counts.
    return _json(200, {
      'status': 'success',
      'message': 'ok',
      'data': {'results': [], 'count': 0, 'summary_chips': <String, int>{}},
    });
  }

  @override
  void close({bool force = false}) {}
}

final _log = ValueNotifier<List<String>>([]);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Debug builds only.')))));
    return;
  }
  final server = _DemoServer((l) => _log.value = [..._log.value, l]);
  runApp(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_DemoAuth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://demo.invalid/api'))..httpClientAdapter = server),
    ],
    child: MaterialApp(debugShowCheckedModeBanner: false, home: _DemoPage(server: server)),
  ));
}

class _DemoPage extends ConsumerStatefulWidget {
  const _DemoPage({required this.server});
  final _DemoServer server;
  @override
  ConsumerState<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends ConsumerState<_DemoPage> {
  @override
  Widget build(BuildContext context) {
    final s = widget.server;
    Widget toggle(String label, bool on, VoidCallback f) => FilterChip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          selected: on,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(f),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Wrap(spacing: 6, children: [
            toggle('HR error', s.hrsFail, () => s.hrsFail = !s.hrsFail),
            toggle('HR slow', s.hrsSlow, () => s.hrsSlow = !s.hrsSlow),
            toggle('Drop Bilal', s.dropBilal, () {
              s.dropBilal = !s.dropBilal;
              // The branch's HR list changed: reload it, as a revisit would.
              ref.invalidate(employeeHrOptionsProvider);
            }),
            toggle('Save fails', s.saveFails, () => s.saveFails = !s.saveFails),
          ]),
          const Expanded(child: AttendanceScreen()),
          Container(
            width: double.infinity,
            color: const Color(0xFF102A43),
            padding: const EdgeInsets.all(6),
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _log,
              builder: (_, lines, __) => Text(
                lines.isEmpty ? 'Fake server log: (no approver/OT requests yet)' : lines.reversed.take(3).join('\n'),
                key: const Key('demo-log'),
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontFamily: 'monospace'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

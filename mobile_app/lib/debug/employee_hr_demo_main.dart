// DEBUG-ONLY demo of Employee Edit → Branch HR (Task 51) on the real edit
// sheet, without signing in or calling a server:
//
//   flutter run -d <emulator> -t lib/debug/employee_hr_demo_main.dart
//
// GET /employees/hrs/?branch=, GET /employees/managers/ and
// PUT /employees/<code>/ are answered in-process by [_DemoServer] in the
// production shapes (HRListView: [{id: <user uuid>, employee_id, full_name,
// department, branch}]). Synthetic people; nothing leaves the device. Every
// request is logged on screen and as "FAKE_SERVER ..." lines (PUT bodies are
// reduced to the keys that matter here). Chips pick the employee and the
// answer of the next HR-list request. Not imported by lib/main.dart, so not
// part of the release app; refuses to run outside debug builds.

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
import '../features/employees/data/models/employee_model.dart';
import '../features/employees/presentation/providers/employee_providers.dart';
import '../features/employees/presentation/widgets/add_employee_sheet.dart';
import '../features/settings/data/models/departments_model.dart';
import '../features/settings/data/models/roles_model.dart';

const _code = 'DEMO-51';
const _hrA = 'aaaaaaaa-0000-4000-8000-00000000000a'; // Asha HR (North)
const _hrB = 'bbbbbbbb-0000-4000-8000-00000000000b'; // Bina HR (North)
const _hrC = 'cccccccc-0000-4000-8000-00000000000c'; // Chetan HR (South)
const _hrS = 'dddddddd-0000-4000-8000-00000000000d'; // Solo HR (East)
const _hrZ = 'eeeeeeee-0000-4000-8000-00000000000e'; // Zed HR (in no list)
const _mgr = 'ffffffff-0000-4000-8000-00000000000f'; // Kiran Manager (North)

String _short(Object? v) => v == null ? 'null' : (v is String && v.length > 8 ? '${v.substring(0, 8)}…' : '$v');

class _DemoAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'demo',
          email: 'demo@example.test',
          fullName: 'Demo HR Admin',
          role: 'hr_admin',
          roleDisplay: 'HR',
          branch: 'North',
          mustChangePassword: false,
          permissions: ['employees.view', 'employees.edit'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

enum Preset { assigned, absentHr, noBranch, soleHr, twoHrs, emptyBranch }

const _presetLabel = {
  Preset.assigned: 'Emp: North, HR Asha',
  Preset.absentHr: 'Emp: HR Zed (not listed)',
  Preset.noBranch: 'Emp: no branch',
  Preset.soleHr: 'Emp: East, no HR',
  Preset.twoHrs: 'Emp: North, no HR',
  Preset.emptyBranch: 'Emp: West (0 HRs)',
};

Map<String, dynamic> _p(String code, String uuid, String name) => {'id': code, 'uuid': uuid, 'name': name};
const _nobody = {'id': null, 'uuid': null, 'name': null};

Map<String, dynamic> _employee(Preset p) {
  final branch = switch (p) {
    Preset.noBranch => '',
    Preset.soleHr => 'East',
    Preset.emptyBranch => 'West',
    _ => 'North',
  };
  final hr = switch (p) {
    Preset.assigned => _p('D-HRA', _hrA, 'Asha HR'),
    Preset.absentHr => _p('D-HRZ', _hrZ, 'Zed HR'),
    _ => _nobody,
  };
  return {
    'id': _code,
    'uuid': '99999999-0000-4000-8000-000000000051',
    'employee_id': _code,
    'first_name': 'Demo',
    'last_name': 'Employee',
    'full_name': 'Demo Employee',
    'email': 'demo.employee@example.test',
    'phone': '9000000051',
    'department': 'Quality',
    'designation': 'QA Analyst',
    'branch': branch,
    'role': 'employee',
    'role_display': 'Employee',
    'date_of_joining': '2026-01-05',
    'is_active': true,
    'status': 'active',
    'hr': hr,
    'reporting_manager': branch == 'North' ? _p('D-M1', _mgr, 'Kiran Manager') : _nobody,
    'reporting_approver': _nobody,
    'profile': {'date_of_birth': '1995-02-01', 'gender': 'female', 'marital_status': 'single'},
    'documents': <Object>[],
  };
}

Map<String, dynamic> _o(String id, String code, String name, String dept, String branch) =>
    {'id': id, 'employee_id': code, 'full_name': name, 'department': dept, 'branch': branch};

final _hrs = {
  'North': [_o(_hrA, 'D-HRA', 'Asha HR', 'HR', 'North'), _o(_hrB, 'D-HRB', 'Bina HR', 'People', 'North')],
  'South': [_o(_hrC, 'D-HRC', 'Chetan HR', 'HR', 'South')],
  'East': [_o(_hrS, 'D-HRS', 'Solo HR', 'HR', 'East')],
  'West': <Map<String, dynamic>>[],
};

final _managers = {
  'North': [_o(_mgr, 'D-M1', 'Kiran Manager', 'Quality', 'North')],
  'South': [_o('12121212-0000-4000-8000-000000000012', 'D-M2', 'Lata Manager', 'Quality', 'South')],
};

enum NextHr { ok, forbidden, error }

final _log = ValueNotifier<List<String>>([]);
void _record(String line) {
  debugPrint('FAKE_SERVER $line');
  _log.value = [..._log.value, line];
}

class _DemoServer implements HttpClientAdapter {
  NextHr nextHr = NextHr.ok;
  bool slowSouth = false;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == '/employees/hrs/' && o.method == 'GET') {
      final branch = '${o.queryParameters['branch'] ?? ''}';
      final mode = nextHr;
      nextHr = NextHr.ok; // one-shot, so Retry succeeds
      _record('GET hrs?branch=$branch (sent)');
      await Future<void>.delayed(Duration(milliseconds: branch == 'South' && slowSouth ? 5000 : 1200));
      if (branch.isEmpty) {
        _record('GET hrs?branch= → 400');
        return _json(400, {'status': 'error', 'message': 'branch query parameter is required.', 'data': {}});
      }
      switch (mode) {
        case NextHr.forbidden:
          _record('GET hrs?branch=$branch → 403');
          return _json(403, {'status': 'error', 'message': 'You do not have permission to perform this action.', 'data': {}});
        case NextHr.error:
          _record('GET hrs?branch=$branch → 500');
          return _json(500, {'status': 'error', 'message': 'Server error. Please try again later.', 'data': {}});
        case NextHr.ok:
          final list = _hrs[branch] ?? const [];
          _record('GET hrs?branch=$branch → 200 [${list.map((h) => h['full_name']).join(', ')}]');
          return _json(200, {'status': 'success', 'data': list});
      }
    }
    if (o.path == '/employees/managers/' && o.method == 'GET') {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final branch = '${o.queryParameters['branch'] ?? ''}';
      final isApprovers = o.queryParameters['manager_approvers'] == '1';
      final list = isApprovers ? const <Object>[] : (_managers[branch] ?? const []);
      return _json(200, {'status': 'success', 'data': list});
    }
    if (o.path == '/employees/$_code/' && o.method == 'PUT') {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final body = Map<String, dynamic>.from(o.data as Map);
      _record('PUT $_code hr_id=${body.containsKey('hr_id') ? _short(body['hr_id']) : '(absent)'} '
          'reporting_manager_id=${body.containsKey('reporting_manager_id') ? _short(body['reporting_manager_id']) : '(absent)'} '
          'branch=${body['branch']} keys=${body.keys.length}');
      return _json(200, {'status': 'success', 'message': 'Employee updated successfully.', 'data': body});
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
      employeeFormRolesProvider.overrideWithValue(AsyncData([
        RoleModel.fromJson(const {'id': 3, 'name': 'employee', 'display_name': 'Employee', 'permissions': []}),
      ])),
      employeeFormDepartmentsProvider.overrideWithValue(AsyncData([
        DepartmentModel.fromJson(const {'id': 1, 'name': 'Quality'}),
      ])),
      employeeBranchesProvider.overrideWith((ref) async => const [
            EmployeeBranch(id: 1, name: 'North'),
            EmployeeBranch(id: 2, name: 'South'),
            EmployeeBranch(id: 3, name: 'East'),
            EmployeeBranch(id: 4, name: 'West'),
          ]),
      employeeDesignationsByDeptProvider.overrideWith((ref, id) async => ['QA Analyst']),
    ],
    child: _DemoApp(server: server),
  ));
}

class _DemoApp extends StatefulWidget {
  const _DemoApp({required this.server});
  final _DemoServer server;
  @override
  State<_DemoApp> createState() => _DemoAppState();
}

class _DemoAppState extends State<_DemoApp> {
  Preset preset = Preset.assigned;
  String result = '';

  @override
  Widget build(BuildContext context) {
    final s = widget.server;
    Widget chip(String label, bool on, VoidCallback f) => ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 10.5)),
          selected: on,
          visualDensity: VisualDensity.compact,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onSelected: (_) => setState(f),
        );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Column(children: [
            Wrap(spacing: 4, runSpacing: 0, children: [
              for (final p in Preset.values) chip(_presetLabel[p]!, preset == p, () => preset = p),
              chip('Next HR GET 403', s.nextHr == NextHr.forbidden, () => s.nextHr = NextHr.forbidden),
              chip('Next HR GET 500', s.nextHr == NextHr.error, () => s.nextHr = NextHr.error),
              chip('South slow 5s', s.slowSouth, () => s.slowSouth = !s.slowSouth),
            ]),
            Expanded(
              child: Center(
                child: Builder(
                  builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
                    FilledButton(
                      key: const Key('open-edit'),
                      onPressed: () async {
                        final r = await AddEmployeeSheet.show(ctx, editing: EmployeeModel.fromJson(_employee(preset)));
                        setState(() => result = 'Sheet closed → $r');
                      },
                      child: const Text('Open Employee Edit'),
                    ),
                    const SizedBox(height: 8),
                    Text(result),
                  ]),
                ),
              ),
            ),
            Material(
              color: const Color(0xFF102A43),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                child: ValueListenableBuilder<List<String>>(
                  valueListenable: _log,
                  builder: (_, lines, __) => Text(
                    lines.isEmpty ? 'Fake server log: (nothing yet)' : lines.reversed.take(4).join('\n'),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// DEBUG-ONLY demo of Employee Profile → Leave (Annual / Monthly views and the
// Monthly Leave Statement), for checking the real widgets on an emulator
// without signing in or calling a server:
//
//   flutter run -d <emulator> -t lib/debug/leave_statement_demo_main.dart
//
// Every request is answered in-process by [_DemoServer] with synthetic data in
// the production response shapes (LeaveStatsView, LeavePolicyView,
// LeaveCreditOverviewView, the requests list). Nothing leaves the device. The
// bar at the top switches employee and simulates a stats failure or a viewer
// the backend withholds statements from. Not imported by lib/main.dart, so not
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
import '../features/employees/presentation/widgets/employee_leave_tab.dart';
import '../features/leave/presentation/providers/leave_providers.dart';

const _demoUser = UserEntity(
  id: 'demo',
  email: 'demo@example.test',
  fullName: 'Demo Viewer',
  role: 'hr',
  roleDisplay: 'HR',
  mustChangePassword: false,
  permissions: ['employees.view', 'leave.view', 'leave.approve'],
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

class _DemoAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(user: _demoUser);
}

final _now = DateTime.now();
final _y = _now.year;
const _short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

Map<String, dynamic> _month(int m, int year,
        {double credit = 1.5,
        double used = 0,
        double pending = 0,
        double carriedIn = 0,
        double expired = 0,
        bool carryOff = true,
        double creditLeft = 0,
        double closing = 0}) =>
    {
      'month': m,
      'label': '${_short[m - 1]} $year',
      'carry_off': carryOff,
      'closed': year < _y || m < _now.month,
      'carried_in': carriedIn,
      'credit': credit,
      'used': used,
      'pending': pending,
      'expired': expired,
      'credit_left': creditLeft,
      'closing': closing,
    };

Map<String, dynamic> _stmt(List<Map<String, dynamic>> months,
        {bool carry = false, double opening = 0, double notItemised = 0, String? rulesFrom, bool reconciled = true}) =>
    {
      'opening': opening,
      'adjustments': 0.0,
      'used_not_itemised': notItemised,
      'months': months,
      'total_credited': months.fold<double>(0, (a, m) => a + (m['credit'] as double)),
      'total_expired': months.fold<double>(0, (a, m) => a + (m['expired'] as double)),
      'total_pending': months.fold<double>(0, (a, m) => a + (m['pending'] as double)),
      'monthly_carry_forward': carry,
      'monthly_rules_from': rulesFrom,
      'reconciled': reconciled,
    };

Map<String, dynamic> _bal(String type, String display, String? schedule, double total, double used,
        [Map<String, dynamic>? statement]) =>
    {
      'leave_type': type,
      'leave_type_display': display,
      'total_days': total,
      'used_days': used,
      'available': total - used,
      'credit_schedule': schedule,
      'statement': statement,
    };

/// Balances per employee code and year.
List<Map<String, dynamic>> _balances(String code, int year) {
  if (code == 'DEMO-B') {
    if (year != _y) return [];
    return [
      _bal('earned', 'Earned Leave', 'annual', 18, 4),
      _bal(
          'monthly_el',
          'Monthly EL',
          'monthly',
          9,
          2,
          _stmt([
            for (var m = 1; m <= _now.month; m++)
              _month(m, year, credit: 1, used: m == 2 ? 2 : 0, carryOff: false, closing: m - (m >= 2 ? 2.0 : 0)),
          ], carry: true)),
    ];
  }
  // DEMO-A
  if (year == _y) {
    return [
      _bal('casual', 'Casual Leave', 'annual', 12, 2),
      _bal('earned', 'Earned Leave', 'annual', 15, 3),
      _bal('maternity', 'Maternity Leave', 'annual', 90, 0),
      _bal('lwp', 'Leave Without Pay', 'annual', 0, 0),
      // Production get_leave_type_display() gives the raw code for custom types.
      _bal('mestrual_leave', 'mestrual_leave', 'annual', 6, 1),
      _bal(
          'monthly_el',
          'Monthly EL',
          'monthly',
          1.5 * _now.month + 2,
          1,
          _stmt([
            for (var m = 1; m <= _now.month; m++)
              _month(m, year,
                  used: m == 1 ? 1 : 0,
                  pending: m == _now.month ? 0.5 : 0,
                  carriedIn: m > 1 ? 0.25 : 0,
                  expired: m == 1 ? 0.5 : 0,
                  creditLeft: m == _now.month ? 1 : 0,
                  closing: 2.0 + m),
          ], opening: 2, notItemised: 0.5, rulesFrom: '$year-03-05', reconciled: false)),
      _bal(
          'comp_off',
          'comp_off',
          'monthly',
          3,
          0,
          _stmt([
            for (var m = 1; m <= _now.month; m++)
              _month(m, year, credit: m.isEven ? 0.5 : 0, carryOff: false, closing: m / 4),
          ], carry: true)),
      _bal('floater', 'floater', null, 1, 0),
    ];
  }
  if (year == _y - 1) {
    return [
      _bal('earned', 'Earned Leave', 'annual', 15, 15),
      _bal(
          'monthly_el',
          'Monthly EL',
          'monthly',
          12,
          0,
          _stmt([
            for (var m = 1; m <= 12; m++) _month(m, year, credit: 1, carryOff: false, closing: m.toDouble()),
          ], carry: true)),
    ];
  }
  if (year == _y + 1) {
    // Nothing recorded yet for next year: a statement with no months.
    return [_bal('monthly_el', 'Monthly EL', 'monthly', 0, 0, _stmt([], carry: true))];
  }
  return [];
}

const _policies = [
  {'id': 1, 'leave_type': 'casual', 'leave_type_display': 'Casual Leave', 'is_active': true},
  {'id': 2, 'leave_type': 'mestrual_leave', 'leave_type_display': 'Pink Leave', 'is_active': true},
  {'id': 3, 'leave_type': 'comp_off', 'leave_type_display': 'Compensatory Off', 'is_active': true},
];

class _DemoServer implements HttpClientAdapter {
  bool statsFail = false;
  bool withhold = false;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    await Future<void>.delayed(const Duration(milliseconds: 700)); // visible loading
    final q = o.queryParameters;
    if (o.path == '/leave/stats/') {
      if (statsFail) return _json(500, {'status': 'error', 'message': 'Leave stats are temporarily unavailable.'});
      final year = int.parse('${q['year']}');
      final rows = _balances('${q['employee_id']}', year).map((b) => withhold ? {...b, 'statement': null} : b).toList();
      return _json(200, {
        'status': 'success',
        'data': {
          'total': 0, 'pending': 1, 'approved': 0, 'rejected': 0, 'cancelled': 0, //
          'lop_days': 0, 'lop_requests': 0, 'year': year, 'balances': rows,
        },
      });
    }
    if (o.path == '/leave/policy/') return _json(200, {'status': 'success', 'data': _policies});
    if (o.path == '/leave/requests/') {
      return _json(200, {
        'status': 'success',
        'data': {'count': 0, 'results': [], 'page': 1, 'page_size': 20, 'total_pages': 1},
      });
    }
    if (o.path.startsWith('/leave/credits/') && o.method == 'GET') {
      final year = int.parse('${q['year'] ?? _y}');
      return _json(200, {
        'status': 'success',
        'data': {
          'employee': {'employee_id': o.path.split('/')[3], 'full_name': 'Demo Employee'},
          'year': year,
          'current_year': _y,
          'summaries': [
            {
              'leave_type': 'earned', 'leave_type_label': 'Earned Leave', 'credit_schedule': 'annual', //
              'opening_or_allocated': 12.0, 'carried_forward': 3.0, 'manual_adjustments': 0.0,
              'total_credits': 15.0, 'used': 3.0, 'pending': 0.0, 'remaining': 12.0,
              'available_after_pending': 12.0,
            },
          ],
          'leave_type': 'earned',
          'monthly': null,
          'transactions': [],
          'assignable_leave_types': [
            {'value': 'earned', 'label': 'Earned Leave', 'credit_schedule': 'annual'},
          ],
        },
      });
    }
    return _json(404, {'status': 'error', 'message': 'Not found'});
  }

  @override
  void close({bool force = false}) {}
}

EmployeeModel _employee(String code, String name) =>
    EmployeeModel.fromJson({'id': 'u-$code', 'employee_id': code, 'first_name': name, 'full_name': name, 'email': ''});

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
  EmployeeModel _emp = _employee('DEMO-A', 'Demo A');

  void _reload() => ref.invalidate(employeeLeaveStatsProvider);

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
      appBar: AppBar(title: Text('Leave demo · ${_emp.employeeId}', style: const TextStyle(fontSize: 15))),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Wrap(spacing: 6, children: [
            toggle('Emp A', _emp.employeeId == 'DEMO-A', () => _emp = _employee('DEMO-A', 'Demo A')),
            toggle('Emp B', _emp.employeeId == 'DEMO-B', () => _emp = _employee('DEMO-B', 'Demo B')),
            toggle('Stats error', s.statsFail, () {
              s.statsFail = !s.statsFail;
              // Turning failures off doesn't reload: the tab's Retry does.
              if (s.statsFail) _reload();
            }),
            toggle('Withheld', s.withhold, () {
              s.withhold = !s.withhold;
              _reload();
            }),
          ]),
        ),
        const Divider(height: 1),
        Expanded(child: EmployeeLeaveTab(employee: _emp)),
      ]),
    );
  }
}

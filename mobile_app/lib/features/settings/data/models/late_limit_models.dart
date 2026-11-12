import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';

// Maximum Late Arrivals Per Month — web lib/lateLimit.ts over backend
// apps/attendance/services_late_limit.py + views/late_limit.py. Tracking
// only: it never adds LOP or changes pay (late-mark LOP stays in Settings →
// Attendance Rules). Counted per calendar month; Late (Excused) days are not
// counted — the server does all counting.

/// Web LATE_LIMIT_MAX (backend MAX_LIMIT).
const kLateLimitMax = 31;

/// Web maximumError — the server repeats it.
String? lateLimitMaximumError(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return 'Enter the maximum.';
  if (!RegExp(r'^\d+$').hasMatch(text)) return 'Enter a whole number.';
  final n = int.parse(text);
  if (n < 1) return 'Enter at least 1.';
  if (n > kLateLimitMax) return 'Enter at most $kLateLimitMax.';
  return null;
}

/// GET /attendance/late-arrival-limit/ — any signed-in user may read it;
/// [canEdit] is the server's settings.edit-or-leave.approve verdict.
class LateLimitSetting {
  const LateLimitSetting({
    required this.enabled,
    required this.maximum,
    required this.configured,
    required this.canEdit,
  });

  final bool enabled;
  final int maximum;

  /// False until Settings → Attendance Rules were saved once; the server
  /// refuses a save (409) until then.
  final bool configured;
  final bool canEdit;

  factory LateLimitSetting.fromJson(Map<String, dynamic> j) => LateLimitSetting(
        enabled: j['enabled'] == true,
        maximum: (j['maximum'] as num?)?.toInt() ?? 5,
        configured: j['configured'] != false,
        canEdit: j['can_edit'] == true,
      );
}

/// One row of GET /attendance/late-arrival-limit/employees/.
class LateLimitEmployee {
  const LateLimitEmployee({
    required this.employee,
    required this.name,
    required this.employeeCode,
    required this.branch,
    required this.department,
    required this.lateArrivals,
    required this.overBy,
    required this.status,
    required this.statusLabel,
  });

  final String employee;
  final String name;
  final String employeeCode;
  final String branch;
  final String department;
  final int lateArrivals;
  final int overBy;
  final String status; // within | reached | exceeded
  final String statusLabel;

  factory LateLimitEmployee.fromJson(Map<String, dynamic> j) => LateLimitEmployee(
        employee: '${j['employee'] ?? ''}',
        name: '${j['name'] ?? ''}',
        employeeCode: '${j['employee_code'] ?? ''}',
        branch: '${j['branch'] ?? ''}',
        department: '${j['department'] ?? ''}',
        lateArrivals: (j['late_arrivals'] as num?)?.toInt() ?? 0,
        overBy: (j['over_by'] as num?)?.toInt() ?? 0,
        status: '${j['status'] ?? ''}',
        statusLabel: '${j['status_label'] ?? ''}',
      );
}

class LateLimitEmployees {
  const LateLimitEmployees({required this.enabled, required this.maximum, required this.results});
  final bool enabled;
  final int maximum;
  final List<LateLimitEmployee> results;

  factory LateLimitEmployees.fromJson(Map<String, dynamic> j) => LateLimitEmployees(
        enabled: j['enabled'] == true,
        maximum: (j['maximum'] as num?)?.toInt() ?? 0,
        results: [
          for (final r in (j['results'] as List? ?? const []))
            if (r is Map) LateLimitEmployee.fromJson(r.cast<String, dynamic>()),
        ],
      );
}

/// "YYYY-MM" for the employees query.
String lateLimitMonthParam(DateTime m) => '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';

class LateLimitApi {
  LateLimitApi(this._dio);
  final Dio _dio;

  static Map<String, dynamic> _data(dynamic body) {
    final d = body is Map && body.containsKey('data') ? body['data'] : body;
    return d is Map ? d.cast<String, dynamic>() : <String, dynamic>{};
  }

  Future<LateLimitSetting> fetch() async =>
      LateLimitSetting.fromJson(_data((await _dio.get(ApiConstants.attendanceLateArrivalLimit)).data));

  /// PUT {enabled, maximum} — web's exact payload. Returns the server message.
  Future<String> save({required bool enabled, required int maximum}) async {
    final res = await _dio.put(ApiConstants.attendanceLateArrivalLimit, data: {'enabled': enabled, 'maximum': maximum});
    final body = res.data;
    final msg = body is Map ? body['message'] : null;
    return msg is String && msg.isNotEmpty ? msg : 'Late arrival limit saved.';
  }

  Future<LateLimitEmployees> employees({required String month, required bool includeReached}) async {
    final res = await _dio.get(ApiConstants.attendanceLateArrivalLimitEmployees, queryParameters: {
      'month': month,
      if (includeReached) 'include_reached': 'true',
    });
    return LateLimitEmployees.fromJson(_data(res.data));
  }
}

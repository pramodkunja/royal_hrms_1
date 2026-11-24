import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';

// Web EmployeeMonthView.tsx data: GET /attendance/employee-calendar/?employee_id=<uuid>&month=YYYY-MM
// (backend HREmployeeMonthView). One FutureProvider per (employee, month) key, so a slow reply
// for one month can never be shown for another.

const _employeeCalendarPath = '/attendance/employee-calendar/';

typedef MonthViewKey = ({String employee, String month});

String monthViewIso(DateTime m) => '${m.year}-${m.month.toString().padLeft(2, '0')}';

class MonthViewDay {
  final String date;
  final String dayShort;
  final int dayNum;
  final String status;
  final String statusLabel;
  final String? clockIn;
  final String? clockOut;
  final num totalHours;
  final bool isFlagged;
  final String? recordId;

  const MonthViewDay({
    required this.date,
    required this.dayShort,
    required this.dayNum,
    required this.status,
    required this.statusLabel,
    required this.clockIn,
    required this.clockOut,
    required this.totalHours,
    required this.isFlagged,
    required this.recordId,
  });

  factory MonthViewDay.fromJson(Map<String, dynamic> j) => MonthViewDay(
        date: '${j['date'] ?? ''}',
        dayShort: '${j['day_short'] ?? ''}',
        dayNum: int.tryParse('${j['day_num'] ?? ''}') ?? 0,
        status: '${j['status'] ?? 'no_record'}',
        statusLabel: '${j['status_label'] ?? 'No Record'}',
        clockIn: _s(j['clock_in']),
        clockOut: _s(j['clock_out']),
        totalHours: num.tryParse('${j['total_hours'] ?? 0}') ?? 0,
        isFlagged: j['is_flagged'] == true,
        recordId: _s(j['record_id']),
      );
}

String? _s(Object? v) => (v == null || '$v'.isEmpty) ? null : '$v';

class MonthViewStats {
  final num present, late, halfDay, absent, onLeave, lopDays, totalHours;
  const MonthViewStats({
    this.present = 0,
    this.late = 0,
    this.halfDay = 0,
    this.absent = 0,
    this.onLeave = 0,
    this.lopDays = 0,
    this.totalHours = 0,
  });

  factory MonthViewStats.fromJson(Map<String, dynamic> j) {
    num n(String k) => num.tryParse('${j[k] ?? 0}') ?? 0;
    return MonthViewStats(
      present: n('present'),
      late: n('late'),
      halfDay: n('half_day'),
      absent: n('absent'),
      onLeave: n('on_leave'),
      lopDays: n('lop_days'),
      totalHours: n('total_hours'),
    );
  }
}

class MonthViewEmployee {
  final String id, employeeId, fullName, department, designation;
  const MonthViewEmployee(
      {required this.id,
      required this.employeeId,
      required this.fullName,
      required this.department,
      required this.designation});
}

class MonthViewData {
  final MonthViewEmployee employee;
  final String month;
  final MonthViewStats stats;
  final List<MonthViewDay> days;
  const MonthViewData({required this.employee, required this.month, required this.stats, required this.days});

  factory MonthViewData.fromJson(Map<String, dynamic> j) {
    final e = (j['employee'] as Map?)?.cast<String, dynamic>() ?? const {};
    return MonthViewData(
      employee: MonthViewEmployee(
        id: '${e['id'] ?? ''}',
        employeeId: '${e['employee_id'] ?? ''}',
        fullName: '${e['full_name'] ?? ''}',
        department: '${e['department'] ?? ''}',
        designation: '${e['designation'] ?? ''}',
      ),
      month: '${j['month'] ?? ''}',
      stats: MonthViewStats.fromJson((j['stats'] as Map?)?.cast<String, dynamic>() ?? const {}),
      days: [
        for (final d in (j['days'] as List? ?? const []))
          if (d is Map) MonthViewDay.fromJson(d.cast<String, dynamic>())
      ],
    );
  }
}

final employeeMonthViewProvider = FutureProvider.autoDispose.family<MonthViewData, MonthViewKey>((ref, key) async {
  final res = await ref
      .watch(dioProvider)
      .get(_employeeCalendarPath, queryParameters: {'employee_id': key.employee, 'month': key.month});
  final body = res.data;
  final data = (body is Map && body['data'] != null) ? body['data'] : body;
  if (data is! Map) throw const FormatException('Unexpected attendance response.');
  return MonthViewData.fromJson(data.cast<String, dynamic>());
});

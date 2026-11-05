// GET /dashboard/employee/notice-period/ — production EmployeeNoticePeriodView
// (apps/dashboard/views/people.py) + notice_info (apps/hrms/services_notice.py).
//
// The signed-in employee's own notice countdown; the server scopes it to
// request.user. Response:
//   {status, message, data: {notice_period: null | {
//     request_id: "<uuid>", request_ref: "SEP-<n>" | "",
//     separation_type: "<display label>",
//     notice_status: "serving" | "completed",
//     days_remaining: <int >= 0>,
//     confirmed_last_working_day: "YYYY-MM-DD",
//     approved_at: "<ISO datetime>" | null }}}
// notice_period is null unless the employee's latest separation request is
// fully approved. Every value is the server's; nothing is computed here.

class EmployeeNoticePeriod {
  final String requestId;
  final String requestRef;
  final String separationType;

  /// 'serving' or 'completed' as sent (anything else is treated as serving,
  /// like web, which only special-cases 'completed').
  final String noticeStatus;
  final int? daysRemaining;
  final String? confirmedLastWorkingDay;
  final String? approvedAt;

  const EmployeeNoticePeriod({
    required this.requestId,
    required this.requestRef,
    required this.separationType,
    required this.noticeStatus,
    this.daysRemaining,
    this.confirmedLastWorkingDay,
    this.approvedAt,
  });

  bool get isCompleted => noticeStatus == 'completed';

  static String _str(Object? v) => v == null ? '' : '$v'.trim();
  static String? _optStr(Object? v) {
    final s = _str(v);
    return s.isEmpty ? null : s;
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  factory EmployeeNoticePeriod.fromJson(Map<String, dynamic> json) => EmployeeNoticePeriod(
        requestId: _str(json['request_id']),
        requestRef: _str(json['request_ref']),
        separationType: _str(json['separation_type']),
        noticeStatus: _str(json['notice_status']).toLowerCase(),
        daysRemaining: _int(json['days_remaining']),
        confirmedLastWorkingDay: _optStr(json['confirmed_last_working_day']),
        approvedAt: _optStr(json['approved_at']),
      );

  /// The unwrapped `data` of the response: `{notice_period: ...}`. Null when
  /// there is no notice period (or the shape is not the expected one).
  static EmployeeNoticePeriod? fromResponseData(Object? data) {
    if (data is! Map) return null;
    final np = data['notice_period'];
    if (np is! Map) return null;
    return EmployeeNoticePeriod.fromJson(Map<String, dynamic>.from(np));
  }
}

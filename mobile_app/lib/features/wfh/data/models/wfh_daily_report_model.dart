import '../../domain/entities/wfh_daily_report_entity.dart';

class WfhDailyReportModel extends WfhDailyReportEntity {
  const WfhDailyReportModel({
    required super.id,
    required super.date,
    required super.completedWork,
    super.pendingWork,
    super.updates,
    super.submittedAt,
    super.submittedLate,
    super.reviewStatus,
    super.reviewedByName,
    super.reviewedAt,
    super.reviewRemarks,
    super.employeeName,
    super.employeeCode,
    super.canReview,
  });

  static String _str(Object? v) => v == null ? '' : v.toString();

  factory WfhDailyReportModel.fromJson(Map<String, dynamic> json) {
    final reviewedAt = json['reviewed_at'];
    return WfhDailyReportModel(
      id: json['id'] is int ? json['id'] as int : int.tryParse(_str(json['id'])) ?? 0,
      date: _str(json['date']),
      completedWork: _str(json['completed_work']),
      pendingWork: _str(json['pending_work']),
      updates: _str(json['updates']),
      submittedAt: _str(json['submitted_at']),
      submittedLate: json['submitted_late'] == true,
      reviewStatus: WfhReportReviewStatus.fromApi(json['review_status'] as String?),
      reviewedByName: _str(json['reviewed_by_name']),
      reviewedAt: reviewedAt?.toString(),
      reviewRemarks: _str(json['review_remarks']),
      employeeName: _str(json['employee_name']),
      employeeCode: _str(json['employee_code']),
      canReview: json['can_review'] == true,
    );
  }
}

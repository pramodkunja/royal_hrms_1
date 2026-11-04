/// One WFH day's end-of-day work report (company policy section 7).
/// Mirrors WFHDailyReportSerializer in apps/hrms/views/wfh_reports.py —
/// every field below comes from that serializer; nothing is derived locally.
enum WfhReportReviewStatus {
  pending('pending', 'Pending review'),
  fullDay('full_day', 'Accepted — Full Day'),
  halfDay('half_day', 'Accepted — Half Day'),
  notAccepted('not_accepted', 'Not accepted');

  const WfhReportReviewStatus(this.apiValue, this.label);

  /// The value the backend sends and accepts (`review_status` / `outcome`).
  final String apiValue;

  /// Same wording as web's REVIEW_LABEL (frontend/lib/wfhReport.ts).
  final String label;

  /// Unknown values fall back to pending, matching the model default.
  static WfhReportReviewStatus fromApi(String? value) =>
      values.firstWhere((s) => s.apiValue == value, orElse: () => pending);
}

class WfhDailyReportEntity {
  final int id;

  /// yyyy-MM-dd, as the backend sends it.
  final String date;
  final String completedWork;
  final String pendingWork;
  final String updates;
  final String submittedAt;
  final bool submittedLate;
  final WfhReportReviewStatus reviewStatus;
  final String reviewedByName;
  final String? reviewedAt;
  final String reviewRemarks;
  final String employeeName;
  final String employeeCode;

  /// Server-computed: still pending and the signed-in user may review it.
  final bool canReview;

  const WfhDailyReportEntity({
    required this.id,
    required this.date,
    required this.completedWork,
    this.pendingWork = '',
    this.updates = '',
    this.submittedAt = '',
    this.submittedLate = false,
    this.reviewStatus = WfhReportReviewStatus.pending,
    this.reviewedByName = '',
    this.reviewedAt,
    this.reviewRemarks = '',
    this.employeeName = '',
    this.employeeCode = '',
    this.canReview = false,
  });
}

/// The server's message plus the saved report ("Report submitted." on create,
/// "Report updated." when the same day's pending report is edited).
typedef WfhReportSaveResult = ({String message, WfhDailyReportEntity report});

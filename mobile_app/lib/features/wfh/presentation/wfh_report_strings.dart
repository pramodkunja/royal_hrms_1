import '../domain/entities/wfh_daily_report_entity.dart';

/// User-facing text for the WFH daily work report, kept in one place.
/// Wording follows web (frontend/app/dashboard/work-from-home/
/// _components/WfhDailyReports.tsx and frontend/lib/wfhReport.ts).
abstract final class WfhReportStrings {
  static const tabLabel = 'Daily Work Report';
  static const formTitle = "Today's Work Report";
  static const formHint =
      'Submit a report for every approved WFH day by end of day. A missing or late report may be marked Absent.';
  static const date = 'Date';
  static const completed = 'Work completed';
  static const pending = 'Pending work';
  static const updates = 'Updates';
  static const submit = 'Submit Report';
  static const submitFailed = 'Could not submit the report.';
  static const myReports = 'My Reports';
  static const toReview = 'Reports to Review';
  static const noReports = 'No reports yet.';
  static const noReportsHint = 'Reports you submit for approved WFH days appear here.';
  static const loadFailed = 'Could not load reports.';
  static const submittedLate = 'Submitted late';
  static const done = 'Done';
  static const reviewer = 'Reviewer';
  static const chooseOutcome = 'Choose outcome';
  static const remarks = 'Remarks';
  static const saveReview = 'Save review';
  static const reviewFailed = 'Could not save the review.';
  static const fullDay = 'Full Day';
  static const halfDay = 'Half Day';
  static const notAccepted = 'Not accepted';

  // Validation — same rules and wording as web's reportFormError/reviewError
  // and the backend serializers.
  static const completedRequired = 'Describe the work you completed today.';
  static const outcomeRequired = 'Choose Full Day, Half Day or Not accepted.';
  static const remarksRequired = 'Give a reason when not accepting a report.';
  static const tooLong = 'Keep this under $kWfhReportMaxLength characters.';
}

/// CharField(max_length=5000) on completed_work, pending_work and updates.
const kWfhReportMaxLength = 5000;

/// The outcomes a reviewer may pick, in web's order.
const kWfhReviewOutcomes = [
  (WfhReportReviewStatus.fullDay, WfhReportStrings.fullDay),
  (WfhReportReviewStatus.halfDay, WfhReportStrings.halfDay),
  (WfhReportReviewStatus.notAccepted, WfhReportStrings.notAccepted),
];

/// Mirrors web's reportFormError plus the backend length limits.
String? wfhReportFormError({required String completed, String pending = '', String updates = ''}) {
  if (completed.trim().isEmpty) return WfhReportStrings.completedRequired;
  if ([completed, pending, updates].any((v) => v.length > kWfhReportMaxLength)) {
    return WfhReportStrings.tooLong;
  }
  return null;
}

/// Mirrors web's reviewError and WFHDailyReportReviewView's checks.
String? wfhReviewError(WfhReportReviewStatus? outcome, String remarks) {
  if (outcome == null || outcome == WfhReportReviewStatus.pending) return WfhReportStrings.outcomeRequired;
  if (outcome == WfhReportReviewStatus.notAccepted && remarks.trim().isEmpty) {
    return WfhReportStrings.remarksRequired;
  }
  return null;
}

/// yyyy-MM-dd for the API, from the device's local date.
String wfhReportIsoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

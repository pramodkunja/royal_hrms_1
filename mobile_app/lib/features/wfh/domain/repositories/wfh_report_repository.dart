import '../entities/wfh_daily_report_entity.dart';

abstract class WfhReportRepository {
  /// The signed-in user's own reports, newest first.
  Future<List<WfhDailyReportEntity>> getMyReports();

  /// Reports the signed-in user may review (empty for most employees).
  Future<List<WfhDailyReportEntity>> getReviewableReports();

  /// Creates the report for [date] (yyyy-MM-dd), or updates it while still
  /// pending review.
  Future<WfhReportSaveResult> submitReport({
    required String date,
    required String completedWork,
    required String pendingWork,
    required String updates,
  });

  Future<WfhReportSaveResult> reviewReport({
    required int id,
    required WfhReportReviewStatus outcome,
    required String remarks,
  });
}

import '../../domain/entities/wfh_daily_report_entity.dart';
import '../../domain/repositories/wfh_report_repository.dart';
import '../datasources/wfh_report_remote_datasource.dart';

class WfhReportRepositoryImpl implements WfhReportRepository {
  final WfhReportRemoteDataSource _ds;
  WfhReportRepositoryImpl(this._ds);

  @override
  Future<List<WfhDailyReportEntity>> getMyReports() => _ds.fetchReports(mine: true);

  @override
  Future<List<WfhDailyReportEntity>> getReviewableReports() => _ds.fetchReports(mine: false);

  @override
  Future<WfhReportSaveResult> submitReport({
    required String date,
    required String completedWork,
    required String pendingWork,
    required String updates,
  }) =>
      _ds.submitReport(date: date, completedWork: completedWork, pendingWork: pendingWork, updates: updates);

  @override
  Future<WfhReportSaveResult> reviewReport({
    required int id,
    required WfhReportReviewStatus outcome,
    required String remarks,
  }) =>
      _ds.reviewReport(id: id, outcome: outcome.apiValue, remarks: remarks);
}

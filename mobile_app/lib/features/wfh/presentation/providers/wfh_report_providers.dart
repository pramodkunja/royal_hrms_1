import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/wfh_report_remote_datasource.dart';
import '../../data/repositories/wfh_report_repository_impl.dart';
import '../../domain/entities/wfh_daily_report_entity.dart';
import '../../domain/repositories/wfh_report_repository.dart';
import 'wfh_providers.dart';

final wfhReportRepositoryProvider = Provider<WfhReportRepository>((ref) {
  return WfhReportRepositoryImpl(WfhReportRemoteDataSource(ref.watch(dioProvider)));
});

/// GET /wfh/reports/?mine=1
final wfhMyReportsProvider = FutureProvider.autoDispose<List<WfhDailyReportEntity>>(
  (ref) => ref.read(wfhReportRepositoryProvider).getMyReports(),
);

/// GET /wfh/reports/ — what the signed-in user may review. The server scopes
/// it (L1 approver, HR with wfh.approve, Branch Admin, settings.edit), so an
/// employee simply gets an empty list.
final wfhReviewReportsProvider = FutureProvider.autoDispose<List<WfhDailyReportEntity>>(
  (ref) => ref.read(wfhReportRepositoryProvider).getReviewableReports(),
);

/// Submits (or updates) a report. Returns the server's message on success
/// (`ok: true`) or a readable error. Refreshes "My Reports" on success.
Future<({bool ok, String message})> submitWfhReport(
  WidgetRef ref, {
  required String date,
  required String completedWork,
  required String pendingWork,
  required String updates,
}) async {
  try {
    final result = await ref.read(wfhReportRepositoryProvider).submitReport(
          date: date,
          completedWork: completedWork,
          pendingWork: pendingWork,
          updates: updates,
        );
    ref.invalidate(wfhMyReportsProvider);
    return (ok: true, message: result.message);
  } catch (e) {
    return (ok: false, message: friendlyWfhError(e));
  }
}

/// Reviews a report. Returns null on success (and refreshes the review list),
/// otherwise a readable error.
Future<String?> reviewWfhReport(
  WidgetRef ref, {
  required int id,
  required WfhReportReviewStatus outcome,
  required String remarks,
}) async {
  try {
    await ref.read(wfhReportRepositoryProvider).reviewReport(id: id, outcome: outcome, remarks: remarks);
    ref.invalidate(wfhReviewReportsProvider);
    return null;
  } catch (e) {
    return friendlyWfhError(e);
  }
}

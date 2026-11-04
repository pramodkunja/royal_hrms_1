import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/payroll_remote_datasource.dart';
import '../../data/models/payslip_model.dart';
import '../../data/models/payslip_query_model.dart';

final payrollDataSourceProvider = Provider<PayrollRemoteDataSource>((ref) {
  return PayrollRemoteDataSource(ref.watch(dioProvider));
});

// ── My Payslips ───────────────────────────────────────────────────────────────

final myPayslipsProvider =
    AsyncNotifierProvider.autoDispose<MyPayslipsNotifier, List<PayslipModel>>(
  MyPayslipsNotifier.new,
);

class MyPayslipsNotifier extends AutoDisposeAsyncNotifier<List<PayslipModel>> {
  PayrollRemoteDataSource get _ds => ref.read(payrollDataSourceProvider);

  @override
  Future<List<PayslipModel>> build() => _ds.fetchMyPayslips();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_ds.fetchMyPayslips);
  }

  /// Returns null on success, a user-facing error message on failure.
  Future<String?> acknowledge(String id) async {
    try {
      await _ds.acknowledgePayslip(id);
      state = AsyncData(
        (state.valueOrNull ?? [])
            .map((p) => p.id == id ? p.copyWith(status: 'acknowledged') : p)
            .toList(),
      );
      return null;
    } catch (e) {
      return friendlyPayrollError(e);
    }
  }
}

// ── Payslip queries ───────────────────────────────────────────────────────────

/// The signed-in employee's own payslip queries (every status).
final myPayslipQueriesProvider = FutureProvider.autoDispose<List<PayslipQueryModel>>(
  (ref) => ref.watch(payrollDataSourceProvider).fetchMyQueries(),
);

/// Raises a query; null on success, else the server's message. On success
/// the queries and the payslips (now "queried") are reloaded.
class PayslipQueryActions {
  PayslipQueryActions(this._ref);
  final Ref _ref;

  Future<String?> raise({required String payslipId, required String description}) async {
    final problem = validatePayslipQueryText(description);
    if (problem != null) return problem;
    try {
      await _ref.read(payrollDataSourceProvider).raiseQuery(payslipId: payslipId, description: description);
      _ref.invalidate(myPayslipQueriesProvider);
      _ref.invalidate(myPayslipsProvider);
      return null;
    } catch (e) {
      return friendlyPayrollError(e);
    }
  }
}

final payslipQueryActionsProvider = Provider<PayslipQueryActions>((ref) => PayslipQueryActions(ref));

// ── Error helper ──────────────────────────────────────────────────────────────

String friendlyPayrollError(Object e) {
  if (e is DioException) return parseDioException(e).message;
  final msg = e.toString();
  if (msg.contains('SocketException')) {
    return 'Cannot reach server. Check your connection.';
  }
  return msg.replaceAll('Exception:', '').trim();
}

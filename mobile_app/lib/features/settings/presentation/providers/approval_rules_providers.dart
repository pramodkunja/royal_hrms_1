import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/approval_rules_remote_datasource.dart';
import '../../data/models/approval_rule_model.dart';

final approvalRulesDataSourceProvider = Provider<ApprovalRulesRemoteDataSource>((ref) {
  return ApprovalRulesRemoteDataSource(ref.watch(dioProvider));
});

final approvalRulesProvider =
    AsyncNotifierProvider.autoDispose<ApprovalRulesNotifier, List<ApprovalRuleModel>>(
  ApprovalRulesNotifier.new,
);

class ApprovalRulesNotifier extends AutoDisposeAsyncNotifier<List<ApprovalRuleModel>> {
  ApprovalRulesRemoteDataSource get _ds => ref.read(approvalRulesDataSourceProvider);

  @override
  Future<List<ApprovalRuleModel>> build() => _ds.fetchRules();

  Future<void> refresh() async {
    state = const AsyncLoading<List<ApprovalRuleModel>>().copyWithPrevious(state);
    state = await AsyncValue.guard(() => _ds.fetchRules());
  }

  Future<String?> updateRule({
    required String workflowType,
    required int l1ApproverRole,
    required int? l2ApproverRole,
  }) async {
    try {
      final updated = await _ds.updateRule(
        workflowType: workflowType,
        l1ApproverRole: l1ApproverRole,
        l2ApproverRole: l2ApproverRole,
      );
      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncData(current
            .map((r) => r.workflowType == workflowType ? updated : r)
            .toList());
      }
      return null;
    } catch (e) {
      return friendlyApprovalRulesError(e);
    }
  }
}

String friendlyApprovalRulesError(Object e) {
  if (e is DioException) return parseDioException(e).message;
  final msg = e.toString();
  if (msg.contains('SocketException')) {
    return 'Cannot reach server. Check your connection.';
  }
  return msg.replaceAll('Exception:', '').trim();
}

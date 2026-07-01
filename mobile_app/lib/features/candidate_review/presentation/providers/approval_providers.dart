import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/approval_datasource.dart';
import '../../data/models/approval_model.dart';

final approvalDataSourceProvider = Provider<ApprovalRemoteDataSource>((ref) {
  return ApprovalRemoteDataSource(ref.watch(dioProvider));
});

final approvalsProvider =
    AsyncNotifierProvider.autoDispose<ApprovalsNotifier, List<ApprovalUser>>(
  ApprovalsNotifier.new,
);

class ApprovalsNotifier extends AutoDisposeAsyncNotifier<List<ApprovalUser>> {
  ApprovalRemoteDataSource get _ds => ref.read(approvalDataSourceProvider);

  @override
  Future<List<ApprovalUser>> build() => _ds.fetchApprovals();

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_ds.fetchApprovals);
  }

  // Returns null on success, error message on failure.
  Future<String?> act(
    String userId, {
    required String decision,
    String remarks = '',
    String? department,
    String? designation,
  }) async {
    try {
      await _ds.approveOrReject(
        userId,
        decision: decision,
        remarks: remarks,
        department: department,
        designation: designation,
      );
      // Remove the acted-on user from the local list immediately
      state = AsyncData(
        (state.valueOrNull ?? []).where((u) => u.id != userId).toList(),
      );
      return null;
    } catch (e) {
      return _msg(e);
    }
  }

  String _msg(Object e) {
    final s = e.toString();
    if (s.contains('403')) return 'You do not have permission to perform this action.';
    if (s.contains('404')) return 'User not found.';
    if (s.contains('400')) return 'Invalid request. Check inputs and try again.';
    if (s.contains('SocketException') || s.contains('connection')) {
      return 'Cannot reach server. Check your connection.';
    }
    // Try to extract backend message from DioException
    if (e is Exception) {
      final str = e.toString();
      final start = str.indexOf('"message"');
      if (start != -1) {
        final sub = str.substring(start + 11);
        final end = sub.indexOf('"', 1);
        if (end != -1) return sub.substring(1, end);
      }
    }
    return s.replaceAll('Exception:', '').trim();
  }
}

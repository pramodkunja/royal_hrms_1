import 'package:dio/dio.dart' show DioException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/approval_datasource.dart';
import '../../data/models/approval_model.dart';

final approvalDataSourceProvider = Provider<ApprovalRemoteDataSource>((ref) {
  return ApprovalRemoteDataSource(ref.watch(dioProvider));
});

/// Web candidate-review/page.tsx: canApprove = usePermission("employees.approve")
/// || usePermission("onboarding.approve") — a superuser, or either codename in
/// the user's own permissions. No settings.edit bypass (web has none).
bool canReviewOnboarding(UserEntity? user) =>
    user != null &&
    (user.isSuperuser ||
        user.permissions.contains('employees.approve') ||
        user.permissions.contains('onboarding.approve'));

/// Web: a "rejected" (sent back) application shows "Awaiting resubmission"
/// instead of Review, whoever is looking.
bool isAwaitingResubmission(ApprovalUser u) => u.onboardingStatus == 'rejected';

const kOnboardingReviewDenied = 'You do not have permission to review onboarding.';

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
    String? uanNumber,
    String? nameAsPerAadhar,
    String? panNumber,
    String? assessmentId,
  }) async {
    // Same rule as the Review button, so a decision can't be sent another way.
    if (!canReviewOnboarding(ref.read(authStateProvider).valueOrNull?.user)) return kOnboardingReviewDenied;
    final target = (state.valueOrNull ?? const <ApprovalUser>[]).where((u) => u.id == userId).firstOrNull;
    if (target != null && isAwaitingResubmission(target)) return kOnboardingReviewDenied;
    try {
      await _ds.approveOrReject(
        userId,
        decision: decision,
        remarks: remarks,
        department: department,
        designation: designation,
        uanNumber: uanNumber,
        nameAsPerAadhar: nameAsPerAadhar,
        panNumber: panNumber,
        assessmentId: assessmentId,
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
    // The server's own message (e.g. an invalid or already-registered PAN,
    // a missing department) — never a value the user typed.
    if (e is DioException) return parseDioException(e).message;
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

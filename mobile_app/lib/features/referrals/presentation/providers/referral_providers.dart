import 'package:dio/dio.dart' show DioException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/access_control.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../branches/domain/entities/branch_entity.dart';
import '../../../branches/presentation/providers/branch_providers.dart' show branchDataSourceProvider;
import '../../data/datasources/referral_remote_datasource.dart';
import '../../domain/entities/referral_entity.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final referralDataSourceProvider = Provider<ReferralRemoteDataSource>((ref) {
  return ReferralRemoteDataSource(ref.watch(dioProvider));
});

// ── My Referrals ──────────────────────────────────────────────────────────────

final myReferralsProvider = AsyncNotifierProvider.autoDispose<
    MyReferralsNotifier, List<ReferralEntity>>(MyReferralsNotifier.new);

class MyReferralsNotifier
    extends AutoDisposeAsyncNotifier<List<ReferralEntity>> {
  @override
  Future<List<ReferralEntity>> build() =>
      ref.read(referralDataSourceProvider).fetchMyReferrals();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(referralDataSourceProvider).fetchMyReferrals());
  }

  /// Returns null on success, or a user-facing error message on failure.
  Future<String?> submit({
    required String name,
    required String email,
    String? phone,
    required String positionApplied,
    int? branchId,
    String? notes,
  }) async {
    try {
      final created = await ref.read(referralDataSourceProvider).createReferral(
            name: name,
            email: email,
            phone: phone,
            positionApplied: positionApplied,
            branchId: branchId,
            notes: notes,
          );
      state = AsyncData([created, ...state.valueOrNull ?? []]);
      return null;
    } catch (e) {
      return friendlyReferralError(e);
    }
  }
}

// ── All Referrals (HR/admin — only ever watched when the caller holds
// 'recruitment.view'; the UI never mounts this tab otherwise) ────────────────

final allReferralsProvider = AsyncNotifierProvider.autoDispose<
    AllReferralsNotifier, List<ReferralEntity>>(AllReferralsNotifier.new);

class AllReferralsNotifier
    extends AutoDisposeAsyncNotifier<List<ReferralEntity>> {
  @override
  Future<List<ReferralEntity>> build() =>
      ref.read(referralDataSourceProvider).fetchAllReferrals();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(referralDataSourceProvider).fetchAllReferrals());
  }
}

// ── Referral Rules — read-only, no mutation ──────────────────────────────────

final referralRulesProvider =
    FutureProvider.autoDispose<List<ReferralRuleEntity>>((ref) async {
  final rules = await ref.read(referralDataSourceProvider).fetchReferralRules();
  final active = rules.where((r) => r.isActive).toList()
    ..sort((a, b) => a.order.compareTo(b.order));
  return active;
});

// ── Referral Rules admin CRUD (Settings screen) — separate from the read-only
// `referralRulesProvider` above because that one filters to active-only rules
// for the employee-facing display; HR needs to see and manage inactive rules
// too. Mutations invalidate `referralRulesProvider` so the employee Referrals
// screen picks up the change next time it's opened. ──────────────────────────

final referralRulesAdminProvider = AsyncNotifierProvider.autoDispose<
    ReferralRulesAdminNotifier, List<ReferralRuleEntity>>(ReferralRulesAdminNotifier.new);

/// Whether the Refer-a-Candidate dialog offers a branch picker (Task 76).
/// Web referrals/page.tsx shows it for usePermission("recruitment.view") and
/// fills it from GET /branch/branches/?status=active&page_size=100 — which
/// the backend (BranchListCreateView) allows only with has_perm
/// branches.view. So here the picker needs both, through the superuser /
/// settings.edit-aware helper: a recruitment.view user without branches.view
/// keeps the read-only branch label and no request is sent (on web they get
/// an empty, required dropdown after a 403 — reported, not bypassed).
bool canPickReferralBranch(UserEntity? user) =>
    userHasPermission(user, 'recruitment.view') && userHasPermission(user, 'branches.view');

/// Active branches for the Refer-a-Candidate picker — web's exact request
/// (`?status=active&page_size=100`). The server scopes the list (a user
/// without settings.edit sees only their own branch). Only read when
/// canPickReferralBranch.
final referralBranchOptionsProvider = FutureProvider.autoDispose<List<BranchEntity>>(
    (ref) => ref.read(branchDataSourceProvider).fetchBranches(pageSize: 100, status: 'active'));

/// Whether [user] may add, edit or delete referral rules: the backend's
/// has_perm(settings.edit) on ReferralRuleListCreateView.post and
/// ReferralRuleDetailView.patch/delete — a superuser or settings.edit.
/// settings.view alone only reads them.
bool canManageReferralRules(UserEntity? user) => userHasPermission(user, 'settings.edit');

const kReferralRulesNoPermission = 'You do not have permission to manage referral rules.';

class ReferralRulesAdminNotifier
    extends AutoDisposeAsyncNotifier<List<ReferralRuleEntity>> {
  bool get _canManage => canManageReferralRules(ref.read(authStateProvider).valueOrNull?.user);

  @override
  Future<List<ReferralRuleEntity>> build() async {
    final rules = await ref.read(referralDataSourceProvider).fetchReferralRules();
    return rules..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<String?> create({
    required String icon,
    required String title,
    required String body,
    required int order,
    required bool isActive,
  }) async {
    if (!_canManage) return kReferralRulesNoPermission;
    try {
      final created = await ref.read(referralDataSourceProvider).createReferralRule(
            icon: icon,
            title: title,
            body: body,
            order: order,
            isActive: isActive,
          );
      state = AsyncData([...state.valueOrNull ?? [], created]..sort((a, b) => a.order.compareTo(b.order)));
      ref.invalidate(referralRulesProvider);
      return null;
    } catch (e) {
      return friendlyReferralError(e);
    }
  }

  Future<String?> edit(
    int id, {
    required String icon,
    required String title,
    required String body,
    required int order,
    required bool isActive,
  }) async {
    if (!_canManage) return kReferralRulesNoPermission;
    try {
      final updated = await ref.read(referralDataSourceProvider).updateReferralRule(
            id,
            icon: icon,
            title: title,
            body: body,
            order: order,
            isActive: isActive,
          );
      state = AsyncData(
        (state.valueOrNull ?? []).map((r) => r.id == id ? updated : r).toList()
          ..sort((a, b) => a.order.compareTo(b.order)),
      );
      ref.invalidate(referralRulesProvider);
      return null;
    } catch (e) {
      return friendlyReferralError(e);
    }
  }

  Future<String?> remove(int id) async {
    if (!_canManage) return kReferralRulesNoPermission;
    try {
      await ref.read(referralDataSourceProvider).deleteReferralRule(id);
      state = AsyncData((state.valueOrNull ?? []).where((r) => r.id != id).toList());
      ref.invalidate(referralRulesProvider);
      return null;
    } catch (e) {
      return friendlyReferralError(e);
    }
  }
}

// ── Error helper ──────────────────────────────────────────────────────────────

String friendlyReferralError(Object e) {
  // AppException.toString() returns only its `message` field — never the
  // numeric status code — so the string-matching below on '400'/'401'/etc.
  // almost never matched a real AppException (e.g. a clean backend message
  // like "phone: Enter a valid phone number." contains none of those
  // substrings) and fell through to the generic "Something went wrong",
  // discarding the actual, actionable server message. Check the typed
  // statusCode first; only fall back to string-sniffing for non-AppException
  // errors (e.g. a raw parsing exception).
  if (e is DioException) return friendlyReferralError(parseDioException(e));
  if (e is ModuleDisabledException) return userFriendlyMessage(e); // keep the server's reason
  if (e is AppException) {
    if (e.statusCode == 401) return 'Session expired. Please log in again.';
    if (e.statusCode == 403) return 'You do not have permission to do this.';
    if (e.statusCode != null && e.statusCode! >= 500) {
      return 'Server error. Please try again later.';
    }
    if (e.message.isNotEmpty) return e.message;
  }

  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('400')) {
    final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(msg);
    if (match != null) return match.group(1)!;
    return 'Invalid request. Please check your inputs.';
  }
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('403')) return 'You do not have permission to do this.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return 'Something went wrong. Please try again.';
}

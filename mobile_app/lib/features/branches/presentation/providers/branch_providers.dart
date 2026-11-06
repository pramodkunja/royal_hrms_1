import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/router/access_control.dart' show userHasPermission;
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/branch_model.dart' show BranchAdminCandidate;
import '../../data/datasources/branch_remote_datasource.dart';
import '../../data/repositories/branch_repository_impl.dart';
import '../../domain/entities/branch_entity.dart';
import '../../domain/repositories/branch_repository.dart';

// ── Data source (stateless factory — kept alive) ──────────────────────────────

final branchDataSourceProvider = Provider<BranchRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return BranchRemoteDataSource(dio);
});

// ── Repository ────────────────────────────────────────────────────────────────

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepositoryImpl(ref.watch(branchDataSourceProvider));
});

// ── Stats ─────────────────────────────────────────────────────────────────────

final branchStatsProvider = AsyncNotifierProvider.autoDispose<
    BranchStatsNotifier, BranchStatsEntity>(BranchStatsNotifier.new);

class BranchStatsNotifier
    extends AutoDisposeAsyncNotifier<BranchStatsEntity> {
  BranchRepository get _repo => ref.read(branchRepositoryProvider);

  @override
  Future<BranchStatsEntity> build() => _repo.getStats();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getStats());
  }
}

// ── Distribution (employees per branch — feeds the chart) ──────────────────────

final branchDistributionProvider = AsyncNotifierProvider.autoDispose<
    BranchDistributionNotifier,
    List<BranchDistributionEntity>>(BranchDistributionNotifier.new);

class BranchDistributionNotifier
    extends AutoDisposeAsyncNotifier<List<BranchDistributionEntity>> {
  BranchRepository get _repo => ref.read(branchRepositoryProvider);

  @override
  Future<List<BranchDistributionEntity>> build() => _repo.getDistribution();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getDistribution());
  }
}

// ── Branch list ───────────────────────────────────────────────────────────────

/// Web BranchManagement shows Add / Edit / Delete only with settings.edit
/// (the server separately checks branches.create / .edit / .delete). Writes
/// are refused here without it, before any request.
const kBranchEditDenied = 'You do not have permission to perform this action.';

bool canManageBranches(Ref ref) =>
    userHasPermission(ref.read(authStateProvider).valueOrNull?.user, 'settings.edit');

/// Change / Assign Branch Admin. Web shows it to settings.edit holders (the
/// same gate as every branch action, [canManageBranches]); production
/// BranchReassignAdminView additionally requires `has_perm(user,
/// 'branches.edit')` (superuser or the role's codename). Both must hold, so
/// the action is never offered to someone the server would refuse.
bool canReassignBranchAdmin(UserEntity? user) =>
    userHasPermission(user, 'settings.edit') &&
    user != null &&
    (user.isSuperuser || user.permissions.contains('branches.edit'));

/// Web openReassign's list (active employees, 50, without system admins and
/// the current admin by email). Keyed by the current admin's email.
final branchAdminCandidatesProvider =
    FutureProvider.autoDispose.family<List<BranchAdminCandidate>, String?>(
  (ref, excludeEmail) => ref.read(branchDataSourceProvider).fetchAdminCandidates(excludeEmail: excludeEmail),
);

final branchListProvider = AsyncNotifierProvider.autoDispose<
    BranchListNotifier, List<BranchEntity>>(BranchListNotifier.new);

class BranchListNotifier
    extends AutoDisposeAsyncNotifier<List<BranchEntity>> {
  BranchRepository get _repo => ref.read(branchRepositoryProvider);

  @override
  Future<List<BranchEntity>> build() => _repo.getBranches();

  bool _reassigning = false;

  /// POST reassign-admin with the chosen employee's code. Refused before any
  /// request without the permission, or while one is running. On success the
  /// list, stats and distribution reload (web fetchData). Returns null on
  /// success, else the message to show.
  Future<String?> reassignAdmin(int branchId, String employeeCode) async {
    if (!canReassignBranchAdmin(ref.read(authStateProvider).valueOrNull?.user)) return kBranchEditDenied;
    if (employeeCode.trim().isEmpty) return 'employee_id is required.';
    if (_reassigning) return 'A reassignment is already in progress.';
    _reassigning = true;
    try {
      await ref.read(branchDataSourceProvider).reassignAdmin(branchId, employeeCode);
      ref
        ..invalidateSelf()
        ..invalidate(branchStatsProvider)
        ..invalidate(branchDistributionProvider);
      return null;
    } catch (e) {
      return reassignAdminError(e);
    } finally {
      _reassigning = false;
    }
  }

  Future<String?> create({
    required int cityId,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
  }) async {
    if (!canManageBranches(ref)) return kBranchEditDenied;
    try {
      final created = await _repo.createBranch(
        cityId: cityId,
        stateId: stateId,
        branchName: branchName,
        address: address,
        status: status,
        isHeadquarter: isHeadquarter,
      );
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return friendlyBranchError(e);
    }
  }

  Future<String?> edit({
    required int id,
    required int cityId,
    required int stateId,
    required String branchName,
    required String address,
    required String status,
    required bool isHeadquarter,
  }) async {
    if (!canManageBranches(ref)) return kBranchEditDenied;
    try {
      final updated = await _repo.updateBranch(
        id: id,
        cityId: cityId,
        stateId: stateId,
        branchName: branchName,
        address: address,
        status: status,
        isHeadquarter: isHeadquarter,
      );
      state = AsyncData(
        (state.valueOrNull ?? [])
            .map((b) => b.id == id ? updated : b)
            .toList(),
      );
      return null;
    } catch (e) {
      return friendlyBranchError(e);
    }
  }

  Future<String?> remove(int id) async {
    if (!canManageBranches(ref)) return kBranchEditDenied;
    try {
      await _repo.deleteBranch(id);
      state = AsyncData(
        (state.valueOrNull ?? []).where((b) => b.id != id).toList(),
      );
      return null;
    } catch (e) {
      return friendlyBranchError(e);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repo.getBranches());
  }
}

// ── States dropdown ───────────────────────────────────────────────────────────

final statesProvider = AsyncNotifierProvider.autoDispose<StatesNotifier,
    List<StateEntity>>(StatesNotifier.new);

class StatesNotifier extends AutoDisposeAsyncNotifier<List<StateEntity>> {
  @override
  Future<List<StateEntity>> build() =>
      ref.read(branchRepositoryProvider).getStates();
}

// ── Cities dropdown (family — one per selected stateId) ───────────────────────

final citiesProvider = AsyncNotifierProvider.autoDispose
    .family<CitiesNotifier, List<CityEntity>, int>(CitiesNotifier.new);

class CitiesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<CityEntity>, int> {
  @override
  Future<List<CityEntity>> build(int arg) =>
      ref.read(branchRepositoryProvider).getCities(arg);
}

// ── Error helper ──────────────────────────────────────────────────────────────

/// Turns a raw exception (DioException, SocketException, ...) into a message
/// safe to show a user — never a stack trace or internal URL.
String friendlyBranchError(Object e) {
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('403')) return 'You do not have permission to do this.';
  if (msg.contains('404')) return 'Resource not found.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return msg.replaceAll('Exception:', '').trim();
}

/// The server's own message for a refused reassignment (inactive, onboarding
/// not complete, Company Admin, already the admin here or elsewhere, scope),
/// else web's "Failed to reassign Branch Admin.".
String reassignAdminError(Object e) {
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map && body['message'] is String && (body['message'] as String).isNotEmpty) {
      return body['message'] as String;
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
  }
  return 'Failed to reassign Branch Admin.';
}

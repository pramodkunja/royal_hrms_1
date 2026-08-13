import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../settings/data/models/departments_model.dart';
import '../../../settings/data/models/roles_model.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/datasources/employees_remote_datasource.dart';
import '../../data/models/employee_model.dart';

// ── DataSource ─────────────────────────────────────────────────────────────────

final employeesDataSourceProvider = Provider<EmployeesRemoteDataSource>((ref) {
  return EmployeesRemoteDataSource(ref.watch(dioProvider));
});

// ── Filters (search / status / department) ─────────────────────────────────────

final employeeFiltersProvider =
    StateProvider.autoDispose<EmployeeFilters>((ref) => const EmployeeFilters());

// ── Full list ──────────────────────────────────────────────────────────────────
//
// Kept only for consumers that genuinely need the complete roster in memory
// (e.g. Attendance's employee-search autocomplete) and for the three
// mutation methods below it that are still reached from the Employee
// Profile screen's Approval Matrix / HR quick-edit / Document upload flows.
// Create/Edit/Status-toggle used to live here too, but calling them forced
// Riverpod to build (and therefore eagerly full-fetch) this provider just to
// reach the method — see createEmployeeAction/updateEmployeeAction/
// updateEmployeeStatusAction further below, which call
// EmployeesRemoteDataSource directly instead and are what the Add/Edit
// Employee sheet and the Profile screen's status toggle use now.

final employeesProvider =
    AsyncNotifierProvider.autoDispose<EmployeesNotifier, List<EmployeeModel>>(
  EmployeesNotifier.new,
);

class EmployeesNotifier extends AutoDisposeAsyncNotifier<List<EmployeeModel>> {
  EmployeesRemoteDataSource get _ds => ref.read(employeesDataSourceProvider);

  @override
  Future<List<EmployeeModel>> build() => _ds.fetchEmployees();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_ds.fetchEmployees);
  }

  // ── Reporting Relationships quick-edit (Approval Matrix tab) ─────────────

  Future<String?> updateReportingManager(String employeeId, String? managerId) async {
    try {
      await _ds.patchReportingManager(employeeId, managerId);
      ref.invalidate(employeeDetailProvider(employeeId));
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> updateHr(String employeeId, String? hrId) async {
    try {
      await _ds.patchHr(employeeId, hrId);
      ref.invalidate(employeeDetailProvider(employeeId));
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  // ── Document upload (Documents tab, HR/admin) ────────────────────────────

  Future<String?> uploadDocument(
    String employeeId, {
    required String documentType,
    required Uint8List bytes,
    required String filename,
  }) async {
    try {
      await _ds.uploadEmployeeDocument(
        employeeId,
        documentType: documentType,
        bytes: bytes,
        filename: filename,
      );
      // The upload response's file-URL key doesn't match EmployeeDocumentEntity
      // (see uploadEmployeeDocument doc comment) — refetch instead of merging.
      ref.invalidate(employeeDetailProvider(employeeId));
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }
}

// ── Paginated list (server-side search/filter/pagination) ──────────────────────
//
// Backs the Employees list screen specifically. Unlike `employeesProvider`
// above (kept as-is for the other screens/pickers that genuinely need the
// complete roster — see the doc comment on EmployeesNotifier), this fetches
// one page at a time from the same endpoint and sends search/department/
// branch/status as real query params instead of downloading everything and
// filtering client-side.

class EmployeeListState {
  final List<EmployeeModel> items;
  final int page;
  final int totalPages;
  final int count; // total matching the current filters, per the backend
  final bool isLoadingMore;
  final String? loadMoreError;

  const EmployeeListState({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.count,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  bool get hasMore => page < totalPages;
}

final employeeListProvider =
    AsyncNotifierProvider.autoDispose<EmployeeListNotifier, EmployeeListState>(
  EmployeeListNotifier.new,
);

class EmployeeListNotifier extends AutoDisposeAsyncNotifier<EmployeeListState> {
  EmployeesRemoteDataSource get _ds => ref.read(employeesDataSourceProvider);
  static const _pageSize = 20;

  // Bumped by build() (i.e. every filter change) and refresh(). A
  // loadNextPage() call that was already in flight when either happens
  // checks this on return and discards its result instead of appending a
  // stale page onto a list that's since moved on — otherwise a fast filter
  // change or pull-to-refresh right after triggering "load more" could
  // corrupt list order or resurrect filtered-out rows.
  int _generation = 0;

  @override
  Future<EmployeeListState> build() async {
    // Watched (not read) deliberately: changing any filter — including the
    // search box, once the screen debounces keystrokes before writing here —
    // re-runs this build from scratch, which is exactly "reset pagination to
    // page 1 and load only the filtered page 1."
    final filters = ref.watch(employeeFiltersProvider);
    _generation++;
    final result =
        await _ds.fetchEmployeesPage(page: 1, pageSize: _pageSize, filters: filters);
    return EmployeeListState(
      items: result.items,
      page: result.page,
      totalPages: result.totalPages,
      count: result.count,
    );
  }

  Future<void> loadNextPage() async {
    final current = state.valueOrNull;
    // No data yet (still on the initial load or a hard error), a load is
    // already in flight, or there simply isn't a next page — ignore. There
    // is no `await` between this check and the `isLoadingMore: true` write
    // below, so a rapid burst of scroll-triggered calls can't race past it:
    // whichever call runs first synchronously claims the flag before a
    // second call's check can observe the old value.
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    final generation = _generation;
    final filters = ref.read(employeeFiltersProvider);
    state = AsyncData(EmployeeListState(
      items: current.items,
      page: current.page,
      totalPages: current.totalPages,
      count: current.count,
      isLoadingMore: true,
    ));
    try {
      final result = await _ds.fetchEmployeesPage(
        page: current.page + 1,
        pageSize: _pageSize,
        filters: filters,
      );
      if (generation != _generation) return; // superseded — drop this page
      final latest = state.valueOrNull ?? current;
      state = AsyncData(EmployeeListState(
        items: [...latest.items, ...result.items],
        page: result.page,
        totalPages: result.totalPages,
        count: result.count,
        isLoadingMore: false,
      ));
    } catch (e) {
      if (generation != _generation) return;
      final latest = state.valueOrNull ?? current;
      // Deliberately keeps `latest.items` untouched — a failed next-page
      // load must never clear what's already visible.
      state = AsyncData(EmployeeListState(
        items: latest.items,
        page: latest.page,
        totalPages: latest.totalPages,
        count: latest.count,
        isLoadingMore: false,
        loadMoreError: userFriendlyMessage(e),
      ));
    }
  }

  // Pull-to-refresh: reloads page 1 with the current filters and replaces
  // the list, but keeps the previous page visible (via copyWithPrevious)
  // while that request is in flight instead of blanking the screen — see
  // the Phase 1 note on why a bare `AsyncLoading()` here would be wrong.
  Future<void> refresh() async {
    _generation++;
    final filters = ref.read(employeeFiltersProvider);
    state = const AsyncLoading<EmployeeListState>().copyWithPrevious(state);
    state = await AsyncValue.guard(() async {
      final result =
          await _ds.fetchEmployeesPage(page: 1, pageSize: _pageSize, filters: filters);
      return EmployeeListState(
        items: result.items,
        page: result.page,
        totalPages: result.totalPages,
        count: result.count,
      );
    });
  }
}

// ── Stats ──────────────────────────────────────────────────────────────────────
//
// Previously derived from the complete employee list (`employeesProvider`),
// which meant simply opening the Employees screen forced a full-roster
// download just to compute these four numbers. Total/Active/Onboarding now
// come from three lightweight `count`-only requests (same endpoint, same
// `status` param, page_size=1), and Departments reuses the org's master
// department list (already fetched elsewhere in the app for the Add/Edit
// Employee form) rather than deriving "distinct departments seen so far"
// from a partially-loaded roster.

final employeeStatsProvider = FutureProvider.autoDispose<EmployeeStats>((ref) async {
  final departments = await ref.watch(departmentsProvider.future);
  final counts = await ref.watch(employeesDataSourceProvider).fetchEmployeeStatusCounts();
  return EmployeeStats(
    total: counts.total,
    active: counts.active,
    onboarding: counts.onboarding,
    departments: departments.where((d) => d.employeeCount > 0).length,
  );
});

// ── Filter dropdown options for the Employees list screen ──────────────────────
//
// Deliberately separate from employeeDepartmentListProvider/
// employeeBranchNameListProvider below (which other screens, e.g.
// Attendance's HR filters, still read from the complete employee roster) —
// these instead reuse the org's master department/branch lists so the
// Employees screen's own filter chips never need that roster fetched at
// all. Returns a plain (not AsyncValue-wrapped) `List<String>`, same as the
// providers they're replacing here, so the screen's existing
// `if (list.isNotEmpty)` checks keep working unchanged — it's just empty
// until the underlying master-data fetch resolves.

final employeeListDepartmentOptionsProvider = Provider.autoDispose<List<String>>((ref) {
  final departments = ref.watch(departmentsProvider).valueOrNull ?? [];
  return (departments.map((d) => d.name).where((n) => n.isNotEmpty).toSet().toList())..sort();
});

final employeeListBranchOptionsProvider = Provider.autoDispose<List<String>>((ref) {
  final branches = ref.watch(employeeBranchesProvider).valueOrNull ?? [];
  return (branches.map((b) => b.name).where((n) => n.isNotEmpty).toSet().toList())..sort();
});

// ── Unique value lists for filter dropdowns ────────────────────────────────────

final employeeDepartmentListProvider = Provider.autoDispose<List<String>>((ref) {
  final employees = ref.watch(employeesProvider).valueOrNull ?? [];
  return (employees.map((e) => e.department).where((d) => d.isNotEmpty).toSet().toList())
    ..sort();
});

final employeeDesignationListProvider = Provider.autoDispose<List<String>>((ref) {
  final employees = ref.watch(employeesProvider).valueOrNull ?? [];
  return (employees.map((e) => e.designation).where((d) => d.isNotEmpty).toSet().toList())
    ..sort();
});

final employeeBranchNameListProvider = Provider.autoDispose<List<String>>((ref) {
  final employees = ref.watch(employeesProvider).valueOrNull ?? [];
  return (employees.map((e) => e.branch).where((b) => b.isNotEmpty).toSet().toList())
    ..sort();
});

// ── Employee detail (for profile screen) ──────────────────────────────────────

final employeeDetailProvider = FutureProvider.autoDispose
    .family<EmployeeModel, String>((ref, employeeId) {
  return ref.read(employeesDataSourceProvider).fetchEmployee(employeeId);
});

// ── Approval matrix (per-employee) ─────────────────────────────────────────────

final employeeApprovalMatrixProvider = AsyncNotifierProvider.autoDispose
    .family<EmployeeApprovalMatrixNotifier, List<EmployeeApprovalMatrixRow>, String>(
  EmployeeApprovalMatrixNotifier.new,
);

class EmployeeApprovalMatrixNotifier extends AutoDisposeFamilyAsyncNotifier<
    List<EmployeeApprovalMatrixRow>, String> {
  EmployeesRemoteDataSource get _ds => ref.read(employeesDataSourceProvider);

  @override
  Future<List<EmployeeApprovalMatrixRow>> build(String employeeId) =>
      _ds.fetchApprovalMatrix(employeeId);

  // Backend PATCH response is just the single updated row, not the full
  // list — refetch the whole matrix afterwards so overrides for other
  // workflow rows (and the row we just changed) stay in sync.
  Future<String?> updateOverride(
    String workflowType, {
    String? l1OverrideId,
    String? l2OverrideId,
  }) async {
    try {
      await _ds.updateApprovalOverride(
        arg,
        workflowType,
        l1OverrideId: l1OverrideId,
        l2OverrideId: l2OverrideId,
      );
      state = const AsyncLoading();
      state = await AsyncValue.guard(() => _ds.fetchApprovalMatrix(arg));
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }
}

// ── Form support providers ─────────────────────────────────────────────────────

// Roles — reuse from settings to avoid duplicate API calls
final employeeFormRolesProvider =
    Provider.autoDispose<AsyncValue<List<RoleModel>>>((ref) {
  return ref.watch(rolesProvider);
});

// Departments — reuse from settings
final employeeFormDepartmentsProvider =
    Provider.autoDispose<AsyncValue<List<DepartmentModel>>>((ref) {
  return ref.watch(departmentsProvider);
});

// Branches — fetched by employees feature
final employeeBranchesProvider =
    FutureProvider.autoDispose<List<EmployeeBranch>>((ref) {
  return ref.read(employeesDataSourceProvider).fetchBranches();
});

// Designations filtered by department ID
final employeeDesignationsByDeptProvider =
    FutureProvider.autoDispose.family<List<String>, int>((ref, deptId) {
  return ref.read(employeesDataSourceProvider).fetchDesignationNames(deptId);
});

// HR contact options, filtered by branch (Edit Employee sheet, edit-only)
final employeeHrOptionsProvider =
    FutureProvider.autoDispose.family<List<EmployeePickerOption>, String>((ref, branch) {
  return ref.read(employeesDataSourceProvider).fetchHrs(branch);
});

// Reporting manager options, filtered by branch (Edit Employee sheet,
// edit-only). Backend requires a non-empty branch — only call this with one.
final employeeManagerOptionsProvider =
    FutureProvider.autoDispose.family<List<EmployeePickerOption>, String>((ref, branch) {
  return ref.read(employeesDataSourceProvider).fetchManagers(branch);
});

// ── Create / Update / Status mutations (Add/Edit Employee sheet, Profile) ──────
//
// One-off actions, not tied to any list/notifier state — same top-level-
// function convention as sendEmployeeWishEmail below, and deliberately NOT
// methods on EmployeesNotifier: calling `ref.read(employeesProvider.notifier)`
// forces Riverpod to build that provider first, which eagerly downloads the
// entire employee roster (see EmployeesNotifier's doc comment above) just to
// reach the method. These call EmployeesRemoteDataSource directly instead,
// so opening Add/Edit Employee or toggling an employee's status never
// triggers that full fetch. Callers are responsible for invalidating
// `employeeListProvider`/`employeeStatsProvider` on success, same as they
// already do after any other list-affecting action.

Future<String?> createEmployeeAction(WidgetRef ref, EmployeeFormData form) async {
  try {
    await ref.read(employeesDataSourceProvider).createEmployee(form);
    return null;
  } catch (e) {
    // The one case worth preserving verbatim from the old `_friendlyError`:
    // a 409 here specifically means the email is already in use, which is
    // more actionable than the generic message `userFriendlyMessage` would
    // otherwise produce for an unmapped status code.
    if (e is DioException && e.response?.statusCode == 409) {
      return 'An employee with this email already exists.';
    }
    return userFriendlyMessage(e);
  }
}

Future<String?> updateEmployeeAction(
  WidgetRef ref,
  String employeeId,
  EmployeeUpdateFormData form,
) async {
  try {
    await ref.read(employeesDataSourceProvider).updateEmployee(employeeId, form);
    // The profile screen reads `employeeDetailProvider(employeeId)`
    // independently of the list — invalidate it so it refetches.
    ref.invalidate(employeeDetailProvider(employeeId));
    return null;
  } catch (e) {
    return userFriendlyMessage(e);
  }
}

Future<String?> updateEmployeeStatusAction(
  WidgetRef ref,
  String employeeId,
  bool isActive,
) async {
  try {
    await ref.read(employeesDataSourceProvider).patchEmployeeStatus(employeeId, isActive);
    return null;
  } catch (e) {
    return userFriendlyMessage(e);
  }
}

// ── Send wish email (Wishes tab) ────────────────────────────────────────────
//
// A one-off action, not tied to any list/notifier state — modeled as a
// top-level function taking `WidgetRef` directly, matching the convention
// already used by assessments' `assignCandidateToAssessment`. Deliberately
// does NOT use `_friendlyError` below: that helper string-matches status
// codes and flattens real backend text (e.g. "Candidate not found." for
// employees with no linked recruitment Candidate record) into generic
// messages like "Resource not found." `parseDioException` preserves the
// backend's own `message` field verbatim so that real limitation is visible
// to the user instead of being hidden behind a generic error.
Future<String?> sendEmployeeWishEmail(
  WidgetRef ref, {
  required String employeeId,
  required String templateName,
  required Map<String, String> extraContext,
}) async {
  try {
    await ref.read(employeesDataSourceProvider).sendCandidateEmail(
          employeeId,
          templateName: templateName,
          extraContext: extraContext,
        );
    return null;
  } catch (e) {
    if (e is DioException) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Cannot reach server. Check your connection.';
      }
      return parseDioException(e).message;
    }
    return e.toString().replaceAll('Exception:', '').trim();
  }
}

// ── Error helper ───────────────────────────────────────────────────────────────

String _friendlyError(Object e) {
  // Dio errors carry a real backend `message` (see parseDioException) — use
  // that instead of falling through to e.toString(), which for a
  // DioException is the raw "DioException [bad response]: ..." dump and
  // must never reach the UI (e.g. the Reporting Manager / Branch HR
  // quick-edit dialogs render this string directly).
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
    if (e.response?.statusCode == 409) {
      return 'An employee with this email already exists.';
    }
    return parseDioException(e).message;
  }
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  return msg.replaceAll('Exception:', '').trim();
}

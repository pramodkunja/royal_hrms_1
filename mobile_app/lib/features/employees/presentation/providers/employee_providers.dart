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

  Future<String?> create(EmployeeFormData form) async {
    try {
      final created = await _ds.createEmployee(form);
      final current = state.valueOrNull ?? [];
      state = AsyncData([created, ...current]);
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  Future<String?> updateStatus(String employeeId, bool isActive) async {
    try {
      await _ds.patchEmployeeStatus(employeeId, isActive);
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.map((e) {
        if (e.id != employeeId) return e;
        return e.copyWith(
          isActive: isActive,
          status: isActive ? 'active' : 'inactive',
        );
      }).toList());
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
  }

  // ── Update (edit) ────────────────────────────────────────────────────────

  Future<String?> updateEmployee(
    String employeeId,
    EmployeeUpdateFormData form,
  ) async {
    try {
      final updated = await _ds.updateEmployee(employeeId, form);
      final current = state.valueOrNull ?? [];
      state = AsyncData(current
          .map((e) => e.id == employeeId ? updated : e)
          .toList());
      // The profile screen reads `employeeDetailProvider(employeeId)`
      // independently of this list — invalidate it so it refetches.
      ref.invalidate(employeeDetailProvider(employeeId));
      return null;
    } catch (e) {
      return _friendlyError(e);
    }
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

// ── Filtered list (client-side) ────────────────────────────────────────────────

final filteredEmployeesProvider =
    Provider.autoDispose<AsyncValue<List<EmployeeModel>>>((ref) {
  final all     = ref.watch(employeesProvider);
  final filters = ref.watch(employeeFiltersProvider);

  return all.whenData((employees) {
    var list = employees;
    if (filters.search.isNotEmpty) {
      final query = filters.search.toLowerCase();
      list = list
          .where((e) =>
              e.fullName.toLowerCase().contains(query) ||
              e.email.toLowerCase().contains(query) ||
              e.employeeId.toLowerCase().contains(query) ||
              e.department.toLowerCase().contains(query) ||
              e.designation.toLowerCase().contains(query))
          .toList();
    }
    if (filters.status.isNotEmpty) {
      list = list.where((e) => e.status == filters.status).toList();
    }
    if (filters.department.isNotEmpty) {
      list = list.where((e) => e.department == filters.department).toList();
    }
    if (filters.designation.isNotEmpty) {
      list = list.where((e) => e.designation == filters.designation).toList();
    }
    if (filters.branch.isNotEmpty) {
      list = list.where((e) => e.branch == filters.branch).toList();
    }
    return list;
  });
});

// ── Stats ──────────────────────────────────────────────────────────────────────

final employeeStatsProvider =
    Provider.autoDispose<AsyncValue<EmployeeStats>>((ref) {
  return ref.watch(employeesProvider).whenData(EmployeeStats.fromList);
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
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('403')) return 'You do not have permission to do this.';
  if (msg.contains('409')) return 'An employee with this email already exists.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return msg.replaceAll('Exception:', '').trim();
}

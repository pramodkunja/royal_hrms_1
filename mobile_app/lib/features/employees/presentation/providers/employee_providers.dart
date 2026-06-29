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
        final newStatus = isActive ? 'active' : 'inactive';
        return EmployeeModel(
          id: e.id, employeeId: e.employeeId,
          firstName: e.firstName, lastName: e.lastName, fullName: e.fullName,
          email: e.email, phone: e.phone,
          department: e.department, designation: e.designation, branch: e.branch,
          roleDisplay: e.roleDisplay, isActive: isActive,
          status: newStatus, dateOfJoining: e.dateOfJoining,
        );
      }).toList());
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

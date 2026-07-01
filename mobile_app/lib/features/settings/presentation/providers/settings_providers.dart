import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/settings_remote_datasource.dart';
import '../../data/models/audit_model.dart';
import '../../data/models/company_model.dart';
import '../../data/models/departments_model.dart';
import '../../data/models/email_template_model.dart';
import '../../data/models/employee_code_model.dart';
import '../../data/models/leave_policy_model.dart';
import '../../data/models/roles_model.dart';
import '../../data/models/smtp_model.dart';

// ── Data source (kept alive — it's a stateless factory) ───────────────────────

final settingsDataSourceProvider = Provider<SettingsRemoteDataSource>((ref) {
  final dio = ref.watch(dioProvider);
  return SettingsRemoteDataSource(dio);
});

// ── Company ───────────────────────────────────────────────────────────────────
// autoDispose: disposed when company screen unmounts → fresh fetch on next visit

final companyProvider =
    AsyncNotifierProvider.autoDispose<CompanyNotifier, CompanyModel>(
  CompanyNotifier.new,
);

class CompanyNotifier extends AutoDisposeAsyncNotifier<CompanyModel> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<CompanyModel> build() => _ds.fetchCompany();

  Future<String?> save(CompanyModel model, {dynamic logoFile}) async {
    state = const AsyncLoading();
    try {
      final updated = await _ds.saveCompany(model, logoFile: logoFile);
      state = AsyncData(updated);
      return null;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _friendly(e);
    }
  }
}

// ── Employee Code ─────────────────────────────────────────────────────────────

final employeeCodeProvider =
    AsyncNotifierProvider.autoDispose<EmployeeCodeNotifier, EmployeeCodeModel>(
  EmployeeCodeNotifier.new,
);

class EmployeeCodeNotifier extends AutoDisposeAsyncNotifier<EmployeeCodeModel> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<EmployeeCodeModel> build() async {
    try {
      return await _ds.fetchEmployeeCode();
    } catch (_) {
      return EmployeeCodeModel.empty();
    }
  }

  Future<String?> save(EmployeeCodeModel model) async {
    state = const AsyncLoading();
    try {
      final updated = await _ds.saveEmployeeCode(model);
      state = AsyncData(updated);
      return null;
    } catch (e) {
      state = AsyncError(e, StackTrace.current);
      return _friendly(e);
    }
  }
}

// ── SMTP ──────────────────────────────────────────────────────────────────────

final smtpListProvider =
    AsyncNotifierProvider.autoDispose<SmtpListNotifier, List<SmtpModel>>(
  SmtpListNotifier.new,
);

class SmtpListNotifier extends AutoDisposeAsyncNotifier<List<SmtpModel>> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<List<SmtpModel>> build() => _ds.fetchSmtpList();

  Future<String?> create(SmtpFormData form) async {
    try {
      final created = await _ds.createSmtp(form);
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> edit(int id, SmtpFormData form) async {
    try {
      final updated = await _ds.updateSmtp(id, form);
      state = AsyncData(
        (state.valueOrNull ?? []).map((e) => e.id == id ? updated : e).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> activate(int id) async {
    try {
      await _ds.activateSmtp(id);
      final refreshed = await _ds.fetchSmtpList();
      state = AsyncData(refreshed);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> remove(int id) async {
    try {
      await _ds.deleteSmtp(id);
      state = AsyncData(
        (state.valueOrNull ?? []).where((e) => e.id != id).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> test(SmtpModel entry, String recipient, String password) async {
    try {
      await _ds.testSmtp(entry, recipient, password);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Email Templates ───────────────────────────────────────────────────────────

final emailTemplateCategoriesProvider =
    FutureProvider.autoDispose<List<EmailTemplateCategoryModel>>((ref) {
  return ref.read(settingsDataSourceProvider).fetchTemplateCategories();
});

final emailTemplatesProvider =
    AsyncNotifierProvider.autoDispose<EmailTemplatesNotifier, List<EmailTemplateModel>>(
  EmailTemplatesNotifier.new,
);

class EmailTemplatesNotifier
    extends AutoDisposeAsyncNotifier<List<EmailTemplateModel>> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<List<EmailTemplateModel>> build() => _ds.fetchTemplates();

  Future<String?> create(EmailTemplateFormData form) async {
    try {
      final created = await _ds.createTemplate(form);
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> edit(int id, EmailTemplateFormData form) async {
    try {
      final updated = await _ds.updateTemplate(id, form);
      state = AsyncData(
        (state.valueOrNull ?? []).map((e) => e.id == id ? updated : e).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> toggleActive(int id, bool isActive) async {
    try {
      await _ds.toggleTemplateActive(id, isActive);
      state = AsyncData(
        (state.valueOrNull ?? [])
            .map((e) => e.id == id ? e.copyWith(isActive: isActive) : e)
            .toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> remove(int id) async {
    try {
      await _ds.deleteTemplate(id);
      state = AsyncData(
        (state.valueOrNull ?? []).where((e) => e.id != id).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Departments ───────────────────────────────────────────────────────────────

final departmentsProvider =
    AsyncNotifierProvider.autoDispose<DepartmentsNotifier, List<DepartmentModel>>(
  DepartmentsNotifier.new,
);

class DepartmentsNotifier extends AutoDisposeAsyncNotifier<List<DepartmentModel>> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<List<DepartmentModel>> build() => _ds.fetchDepartments();

  Future<String?> createDept(DeptFormData form) async {
    try {
      final created = await _ds.createDepartment(form);
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> editDept(int id, DeptFormData form) async {
    try {
      final updated = await _ds.updateDepartment(id, form);
      state = AsyncData(
        (state.valueOrNull ?? []).map((d) => d.id == id ? updated : d).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> removeDept(int id) async {
    try {
      await _ds.deleteDepartment(id);
      state = AsyncData(
        (state.valueOrNull ?? []).where((d) => d.id != id).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

final designationsProvider =
    AsyncNotifierProvider.autoDispose<DesignationsNotifier, List<DesignationModel>>(
  DesignationsNotifier.new,
);

class DesignationsNotifier
    extends AutoDisposeAsyncNotifier<List<DesignationModel>> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<List<DesignationModel>> build() => _ds.fetchDesignations();

  Future<String?> createDesig(DesignationFormData form) async {
    try {
      final created = await _ds.createDesignation(form);
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> editDesig(int id, DesignationFormData form) async {
    try {
      final updated = await _ds.updateDesignation(id, form);
      state = AsyncData(
        (state.valueOrNull ?? []).map((d) => d.id == id ? updated : d).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> removeDesig(int id) async {
    try {
      await _ds.deleteDesignation(id);
      state = AsyncData(
        (state.valueOrNull ?? []).where((d) => d.id != id).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Leave Policy ──────────────────────────────────────────────────────────────
// No create/removeX methods — the 6 leave types are fixed by the backend
// (LeavePolicy.leave_type is a unique choices field); only editing is supported.

final leavePoliciesProvider =
    AsyncNotifierProvider.autoDispose<LeavePoliciesNotifier, List<LeavePolicyModel>>(
  LeavePoliciesNotifier.new,
);

class LeavePoliciesNotifier extends AutoDisposeAsyncNotifier<List<LeavePolicyModel>> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<List<LeavePolicyModel>> build() => _ds.fetchLeavePolicies();

  Future<String?> updatePolicy(String leaveType, LeavePolicyFormData form) async {
    try {
      final updated = await _ds.updateLeavePolicy(leaveType, form);
      state = AsyncData(
        (state.valueOrNull ?? [])
            .map((p) => p.leaveType == leaveType ? updated : p)
            .toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  // Real backend action — credits annual leave for every active employee for
  // [year] (or a single employee if [employeeId] is given). Requires
  // 'leave.approve'. Returns a human-readable success message, or throws with
  // a friendly message on failure.
  Future<String> creditAnnualLeave({int? year, String? employeeId}) async {
    try {
      final result = await _ds.creditLeaveBalances(year: year, employeeId: employeeId);
      return 'Credited ${result.credited} balance record${result.credited == 1 ? '' : 's'} for ${result.year}.';
    } catch (e) {
      throw Exception(_friendly(e));
    }
  }
}

// ── Roles & Permissions ───────────────────────────────────────────────────────

final allPermissionsProvider =
    FutureProvider.autoDispose<List<PermissionModel>>((ref) {
  return ref.read(settingsDataSourceProvider).fetchPermissions();
});

final rolesProvider =
    AsyncNotifierProvider.autoDispose<RolesNotifier, List<RoleModel>>(
  RolesNotifier.new,
);

class RolesNotifier extends AutoDisposeAsyncNotifier<List<RoleModel>> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<List<RoleModel>> build() async {
    final page = await _ds.fetchRoles();
    return page.roles;
  }

  Future<String?> create(RoleFormData form) async {
    try {
      final created = await _ds.createRole(form);
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> edit(dynamic id, RoleFormData form) async {
    try {
      final updated = await _ds.updateRole(id, form);
      state = AsyncData(
        (state.valueOrNull ?? [])
            .map((r) => r.idStr == id.toString() ? updated : r)
            .toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> toggleActive(dynamic id, bool isActive) async {
    try {
      await _ds.toggleRole(id, isActive);
      state = AsyncData(
        (state.valueOrNull ?? [])
            .map((r) => r.idStr == id.toString() ? r.copyWith(isActive: isActive) : r)
            .toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Audit Log ─────────────────────────────────────────────────────────────────

final auditFiltersProvider =
    StateProvider.autoDispose<AuditLogFilters>((ref) => const AuditLogFilters());

final auditLogProvider =
    AsyncNotifierProvider.autoDispose<AuditLogNotifier, AuditLogPage>(
  AuditLogNotifier.new,
);

class AuditLogNotifier extends AutoDisposeAsyncNotifier<AuditLogPage> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<AuditLogPage> build() {
    final filters = ref.watch(auditFiltersProvider);
    return _ds.fetchAuditLog(filters);
  }
}

// ── Error helper ──────────────────────────────────────────────────────────────

String _friendly(Object e) {
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

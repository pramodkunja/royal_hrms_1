import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/settings_remote_datasource.dart';
import '../../data/models/assessment_config_model.dart';
import '../../data/models/attendance_settings_model.dart';
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

// ── Company — Financial Year ─────────────────────────────────────────────────
// Saved independently of the company info form (matches web) — its own
// provider, its own save() call, own error handling.

final financialYearProvider = AsyncNotifierProvider.autoDispose<
    FinancialYearNotifier, CompanyFinancialYearModel>(
  FinancialYearNotifier.new,
);

class FinancialYearNotifier
    extends AutoDisposeAsyncNotifier<CompanyFinancialYearModel> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<CompanyFinancialYearModel> build() => _ds.fetchFinancialYear();

  Future<String?> save(String startMonth) async {
    try {
      final updated = await _ds.updateFinancialYear(startMonth);
      state = AsyncData(updated);
      return null;
    } catch (e) {
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

  Future<String?> uploadAttachment(int templateId, File file, String mimeType) async {
    try {
      final attachment = await _ds.uploadTemplateAttachment(templateId, file, mimeType);
      state = AsyncData((state.valueOrNull ?? []).map((t) {
        if (t.id != templateId) return t;
        return t.copyWith(attachments: [...t.attachments, attachment]);
      }).toList());
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> removeAttachment(int templateId, int attachmentId) async {
    try {
      await _ds.deleteTemplateAttachment(templateId, attachmentId);
      state = AsyncData((state.valueOrNull ?? []).map((t) {
        if (t.id != templateId) return t;
        return t.copyWith(
          attachments: t.attachments.where((a) => a.id != attachmentId).toList(),
        );
      }).toList());
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

  // Creates a new custom leave type via POST /api/leave/policy/ (see
  // LeavePolicyCreateSerializer). Not yet wired into leave_policy_screen.dart
  // — that UI work is tracked separately.
  Future<String?> createPolicy(
      LeavePolicyFormData form, {required String leaveTypeLabel}) async {
    try {
      final created =
          await _ds.createLeavePolicy(form, leaveTypeLabel: leaveTypeLabel);
      state = AsyncData([...(state.valueOrNull ?? []), created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  // Deletes a custom leave type via DELETE /api/leave/policy/<leaveType>/.
  // The backend rejects deletion of the 6 built-in types. Not yet wired into
  // leave_policy_screen.dart — that UI work is tracked separately.
  Future<String?> deletePolicy(String leaveType) async {
    try {
      await _ds.deleteLeavePolicy(leaveType);
      state = AsyncData(
        (state.valueOrNull ?? [])
            .where((p) => p.leaveType != leaveType)
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

// ── Carry Forward execution — see ApiConstants.carryForward* doc comment ──────

final carryForwardYearsProvider =
    FutureProvider.autoDispose<CarryForwardYearsModel>((ref) {
  return ref.read(settingsDataSourceProvider).fetchCarryForwardYears();
});

final carryForwardHistoryPageProvider = StateProvider.autoDispose<int>((ref) => 1);

final carryForwardHistoryProvider =
    FutureProvider.autoDispose<CarryForwardHistoryModel>((ref) {
  final page = ref.watch(carryForwardHistoryPageProvider);
  return ref.read(settingsDataSourceProvider).fetchCarryForwardHistory(page: page);
});

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

// ── Attendance Rules (singleton, 6 sections) ─────────────────────────────────

final attendanceSettingsProvider = AsyncNotifierProvider.autoDispose<
    AttendanceSettingsNotifier, AttendanceSettingsModel>(
  AttendanceSettingsNotifier.new,
);

class AttendanceSettingsNotifier
    extends AutoDisposeAsyncNotifier<AttendanceSettingsModel> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<AttendanceSettingsModel> build() => _ds.fetchAttendanceSettings();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _ds.fetchAttendanceSettings());
  }

  /// Patches a single section (matches the per-card "Save" button on web).
  /// [sectionJson] must be the already-built JSON body for that section.
  Future<String?> saveSection(String sectionKey, Map<String, dynamic> sectionJson) async {
    try {
      final updated = await _ds.patchAttendanceSettingsSection(sectionKey, sectionJson);
      state = AsyncData(updated);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  /// Saves everything currently held in local (edited) state via PUT.
  Future<String?> saveAll(AttendanceSettingsModel edited) async {
    try {
      final updated = await _ds.putAttendanceSettings(edited);
      state = AsyncData(updated);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Assessment Config (singleton) ────────────────────────────────────────────

final assessmentConfigProvider = AsyncNotifierProvider.autoDispose<
    AssessmentConfigNotifier, AssessmentConfigModel>(
  AssessmentConfigNotifier.new,
);

class AssessmentConfigNotifier
    extends AutoDisposeAsyncNotifier<AssessmentConfigModel> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<AssessmentConfigModel> build() => _ds.fetchAssessmentConfig();

  Future<String?> save(AssessmentConfigModel model) async {
    try {
      final updated = await _ds.updateAssessmentConfig(model);
      state = AsyncData(updated);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Error helper ──────────────────────────────────────────────────────────────

/// Public alias of [_friendly] for use outside this file (e.g. settings
/// screens rendering a raw fetch-error state, not just mutation results).
String friendlySettingsError(Object e) => _friendly(e);

// Dio's own DioException.toString() never includes the response status code
// or body — string-matching against it (the old approach here) could never
// actually match, silently discarding real backend validation messages (e.g.
// specific attendance-settings/leave-policy validation errors) in favor of a
// generic fallback. Route through the shared, already-proven
// parseDioException() instead, which reads the real
// {status, message, data} envelope. Backs every settings-screen mutation in
// this file, including attendance rules and leave-policy CRUD.
String _friendly(Object e) {
  if (e is DioException) return parseDioException(e).message;
  final msg = e.toString();
  if (msg.contains('SocketException')) {
    return 'Cannot reach server. Check your connection.';
  }
  return msg.replaceAll('Exception:', '').trim();
}

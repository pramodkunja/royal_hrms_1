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
import '../../data/models/onboarding_field_config_model.dart';
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

/// Creates a category, then refreshes [emailTemplateCategoriesProvider] so
/// the new category is immediately selectable. Returns the created category
/// on success, or null (with [onError] receiving a friendly message) on
/// failure.
Future<EmailTemplateCategoryModel?> createEmailTemplateCategory(
  WidgetRef ref,
  String displayName, {
  required void Function(String message) onError,
}) async {
  try {
    final created =
        await ref.read(settingsDataSourceProvider).createTemplateCategory(displayName);
    ref.invalidate(emailTemplateCategoriesProvider);
    await ref.read(emailTemplateCategoriesProvider.future);
    return created;
  } catch (e) {
    onError(_friendly(e));
    return null;
  }
}

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

// ── Onboarding Fields (wizard steps 0-3) ──────────────────────────────────────

OnboardingFieldConfigModel _withFieldOrder(OnboardingFieldConfigModel f, int order) =>
    OnboardingFieldConfigModel(
      fieldKey: f.fieldKey,
      label: f.label,
      fieldType: f.fieldType,
      options: f.options,
      allowMultiple: f.allowMultiple,
      step: f.step,
      order: order,
      visible: f.visible,
      required: f.required,
      isCustom: f.isCustom,
      isLocked: f.isLocked,
      updatedAt: f.updatedAt,
    );

DocumentTypeConfigModel _withTypeOrder(DocumentTypeConfigModel t, int order) => DocumentTypeConfigModel(
      typeKey: t.typeKey,
      label: t.label,
      order: order,
      visible: t.visible,
      required: t.required,
      allowMultiple: t.allowMultiple,
      isCustom: t.isCustom,
      isLocked: t.isLocked,
      updatedAt: t.updatedAt,
    );

final onboardingFieldsProvider = AsyncNotifierProvider.autoDispose<
    OnboardingFieldsNotifier, List<OnboardingFieldConfigModel>>(
  OnboardingFieldsNotifier.new,
);

class OnboardingFieldsNotifier
    extends AutoDisposeAsyncNotifier<List<OnboardingFieldConfigModel>> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<List<OnboardingFieldConfigModel>> build() => _ds.fetchOnboardingFields();

  Future<String?> create(OnboardingFieldFormData form) async {
    try {
      final created = await _ds.createOnboardingField(form);
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> _patch(String fieldKey, Map<String, dynamic> patch) async {
    try {
      final updated = await _ds.updateOnboardingField(fieldKey, patch);
      state = AsyncData(
        (state.valueOrNull ?? []).map((f) => f.fieldKey == fieldKey ? updated : f).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> setVisible(String fieldKey, bool visible) => _patch(fieldKey, {'visible': visible});

  Future<String?> setRequired(String fieldKey, bool required) =>
      _patch(fieldKey, {'required': required});

  /// Moves the field at [oldIndex] to [newIndex] within [stepFields] (that
  /// step's fields, already sorted by `order`) and PATCHes `order` for every
  /// field whose position actually shifted. Updates state optimistically so
  /// the drag-and-drop UI can animate the drop immediately, then rolls back
  /// to the pre-drag order if any PATCH fails.
  Future<String?> reorderField(
    List<OnboardingFieldConfigModel> stepFields,
    int oldIndex,
    int newIndex,
  ) async {
    final previous = state.valueOrNull ?? [];
    final reordered = List<OnboardingFieldConfigModel>.from(stepFields);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final optimistic = {
      for (var i = 0; i < reordered.length; i++) reordered[i].fieldKey: _withFieldOrder(reordered[i], i),
    };
    state = AsyncData(previous.map((f) => optimistic[f.fieldKey] ?? f).toList());

    final patches = <Future<OnboardingFieldConfigModel>>[
      for (var i = 0; i < reordered.length; i++)
        if (reordered[i].order != i) _ds.updateOnboardingField(reordered[i].fieldKey, {'order': i}),
    ];
    if (patches.isEmpty) return null;

    try {
      final results = await Future.wait(patches);
      final byKey = {for (final r in results) r.fieldKey: r};
      state = AsyncData((state.valueOrNull ?? []).map((f) => byKey[f.fieldKey] ?? f).toList());
      return null;
    } catch (e) {
      state = AsyncData(previous);
      return _friendly(e);
    }
  }

  Future<String?> remove(String fieldKey) async {
    try {
      await _ds.deleteOnboardingField(fieldKey);
      state = AsyncData((state.valueOrNull ?? []).where((f) => f.fieldKey != fieldKey).toList());
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Document Types (wizard step 4 — Documents) ───────────────────────────────

final documentTypesProvider = AsyncNotifierProvider.autoDispose<
    DocumentTypesNotifier, List<DocumentTypeConfigModel>>(
  DocumentTypesNotifier.new,
);

class DocumentTypesNotifier
    extends AutoDisposeAsyncNotifier<List<DocumentTypeConfigModel>> {
  SettingsRemoteDataSource get _ds => ref.read(settingsDataSourceProvider);

  @override
  Future<List<DocumentTypeConfigModel>> build() => _ds.fetchDocumentTypes();

  Future<String?> create(DocumentTypeFormData form) async {
    try {
      final created = await _ds.createDocumentType(form);
      state = AsyncData([...state.valueOrNull ?? [], created]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> _patch(String typeKey, Map<String, dynamic> patch) async {
    try {
      final updated = await _ds.updateDocumentType(typeKey, patch);
      state = AsyncData(
        (state.valueOrNull ?? []).map((t) => t.typeKey == typeKey ? updated : t).toList(),
      );
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> setVisible(String typeKey, bool visible) => _patch(typeKey, {'visible': visible});

  Future<String?> setRequired(String typeKey, bool required) =>
      _patch(typeKey, {'required': required});

  Future<String?> setAllowMultiple(String typeKey, bool allowMultiple) =>
      _patch(typeKey, {'allow_multiple': allowMultiple});

  /// Moves the type at [oldIndex] to [newIndex] within [types] (already
  /// sorted by `order`) and PATCHes `order` for every type whose position
  /// actually shifted. Updates state optimistically so the drag-and-drop UI
  /// can animate the drop immediately, then rolls back to the pre-drag order
  /// if any PATCH fails.
  Future<String?> reorderType(
    List<DocumentTypeConfigModel> types,
    int oldIndex,
    int newIndex,
  ) async {
    final previous = state.valueOrNull ?? [];
    final reordered = List<DocumentTypeConfigModel>.from(types);
    final moved = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, moved);

    final optimistic = {
      for (var i = 0; i < reordered.length; i++) reordered[i].typeKey: _withTypeOrder(reordered[i], i),
    };
    state = AsyncData(previous.map((t) => optimistic[t.typeKey] ?? t).toList());

    final patches = <Future<DocumentTypeConfigModel>>[
      for (var i = 0; i < reordered.length; i++)
        if (reordered[i].order != i) _ds.updateDocumentType(reordered[i].typeKey, {'order': i}),
    ];
    if (patches.isEmpty) return null;

    try {
      final results = await Future.wait(patches);
      final byKey = {for (final r in results) r.typeKey: r};
      state = AsyncData((state.valueOrNull ?? []).map((t) => byKey[t.typeKey] ?? t).toList());
      return null;
    } catch (e) {
      state = AsyncData(previous);
      return _friendly(e);
    }
  }

  Future<String?> remove(String typeKey) async {
    try {
      await _ds.deleteDocumentType(typeKey);
      state = AsyncData((state.valueOrNull ?? []).where((t) => t.typeKey != typeKey).toList());
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

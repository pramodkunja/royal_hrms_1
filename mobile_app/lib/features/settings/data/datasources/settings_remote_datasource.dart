import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/assessment_config_model.dart';
import '../models/attendance_settings_model.dart';
import '../models/audit_model.dart';
import '../models/company_model.dart';
import '../models/departments_model.dart';
import '../models/email_template_model.dart';
import '../models/employee_code_model.dart';
import '../models/leave_import_model.dart';
import '../models/leave_policy_model.dart';
import '../models/onboarding_field_config_model.dart';
import '../models/roles_model.dart';
import '../models/smtp_model.dart';

class SettingsRemoteDataSource {
  final Dio _dio;
  SettingsRemoteDataSource(this._dio);

  // ── Company ────────────────────────────────────────────────────────────────

  Future<CompanyModel> fetchCompany() async {
    final res = await _dio.get(ApiConstants.settingsCompany);
    final data = _unwrap(res.data);
    return CompanyModel.fromJson(data as Map<String, dynamic>);
  }

  Future<CompanyModel> saveCompany(CompanyModel model, {File? logoFile}) async {
    Response res;
    if (logoFile != null) {
      final formData = FormData.fromMap({
        ...model.toJson(),
        'logo': await MultipartFile.fromFile(
          logoFile.path,
          filename: logoFile.path.split('/').last,
        ),
      });
      res = await _dio.put(ApiConstants.settingsCompany, data: formData);
    } else {
      res = await _dio.put(ApiConstants.settingsCompany, data: model.toJson());
    }
    return CompanyModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Company — Financial Year ──────────────────────────────────────────────

  Future<CompanyFinancialYearModel> fetchFinancialYear() async {
    final res = await _dio.get(ApiConstants.settingsCompanyFinancialYear);
    final data = _unwrap(res.data);
    return CompanyFinancialYearModel.fromJson(data as Map<String, dynamic>);
  }

  // system_admin only — the backend returns 403 for anyone else.
  Future<CompanyFinancialYearModel> updateFinancialYear(
      String startMonth) async {
    final res = await _dio.put(
      ApiConstants.settingsCompanyFinancialYear,
      data: {'financial_year_start_month': startMonth},
    );
    return CompanyFinancialYearModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Employee Code ──────────────────────────────────────────────────────────

  Future<EmployeeCodeModel> fetchEmployeeCode() async {
    final res = await _dio.get(ApiConstants.settingsEmployeeCode);
    final data = _unwrap(res.data);
    return EmployeeCodeModel.fromJson(data as Map<String, dynamic>);
  }

  Future<EmployeeCodeModel> saveEmployeeCode(EmployeeCodeModel model) async {
    final res = await _dio.put(
      ApiConstants.settingsEmployeeCode,
      data: model.toJson(),
    );
    return EmployeeCodeModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // ── SMTP ───────────────────────────────────────────────────────────────────

  Future<List<SmtpModel>> fetchSmtpList() async {
    final res = await _dio.get(ApiConstants.settingsSmtp);
    final data = _unwrap(res.data);
    return _toList(data)
        .map((e) => SmtpModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SmtpModel> createSmtp(SmtpFormData form) async {
    final res = await _dio.post(ApiConstants.settingsSmtp,
        data: form.toJson(isAdd: true));
    return SmtpModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<SmtpModel> updateSmtp(int id, SmtpFormData form) async {
    final res = await _dio.put(
      ApiConstants.settingsSmtpDetail(id),
      data: form.toJson(isAdd: false),
    );
    return SmtpModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> activateSmtp(int id) async {
    await _dio.post(ApiConstants.settingsSmtpActivate(id));
  }

  Future<void> deleteSmtp(int id) async {
    await _dio.delete(ApiConstants.settingsSmtpDetail(id));
  }

  Future<void> testSmtp(
      SmtpModel entry, String recipient, String password) async {
    await _dio.post(ApiConstants.settingsSmtpTest, data: {
      'host': entry.host,
      'port': entry.port,
      'username': entry.username,
      'password': password,
      'use_tls': entry.useTls,
      'sender_name': entry.senderName,
      'from_email': entry.fromEmail,
      'bcc_email': entry.bccEmail,
      'test_recipient': recipient,
    });
  }

  // ── Email Templates ────────────────────────────────────────────────────────

  Future<List<EmailTemplateCategoryModel>> fetchTemplateCategories() async {
    final res = await _dio.get(ApiConstants.settingsEmailTemplateCategories);
    final data = _unwrap(res.data);
    return _toList(data)
        .map((e) =>
            EmailTemplateCategoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<EmailTemplateCategoryModel> createTemplateCategory(
      String displayName) async {
    final res = await _dio.post(ApiConstants.settingsEmailTemplateCategories, data: {
      'name': EmailTemplateFormData.toSlug(displayName),
      'display_name': displayName,
    });
    return EmailTemplateCategoryModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<EmailTemplateModel>> fetchTemplates() async {
    final res = await _dio.get(ApiConstants.settingsEmailTemplates);
    final data = _unwrap(res.data);
    // Backend returns paginated with results as grouped dict: {template_type: [templates...], ...}
    final grouped =
        (data is Map<String, dynamic>) ? (data['results'] ?? data) : data;
    final result = <EmailTemplateModel>[];
    if (grouped is Map<String, dynamic>) {
      for (final group in grouped.values) {
        if (group is List) {
          result.addAll(group.map(
              (e) => EmailTemplateModel.fromJson(e as Map<String, dynamic>)));
        }
      }
    } else if (grouped is List) {
      result.addAll(grouped
          .map((e) => EmailTemplateModel.fromJson(e as Map<String, dynamic>)));
    }
    return result;
  }

  Future<EmailTemplateModel> createTemplate(EmailTemplateFormData form) async {
    final res = await _dio.post(ApiConstants.settingsEmailTemplates,
        data: form.toJson(isAdd: true));
    return EmailTemplateModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<EmailTemplateModel> updateTemplate(
      int id, EmailTemplateFormData form) async {
    final res = await _dio.patch(ApiConstants.settingsEmailTemplateDetail(id),
        data: form.toJson(isAdd: false));
    return EmailTemplateModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> toggleTemplateActive(int id, bool isActive) async {
    await _dio.patch(ApiConstants.settingsEmailTemplateDetail(id),
        data: {'is_active': isActive});
  }

  Future<void> deleteTemplate(int id) async {
    await _dio.delete(ApiConstants.settingsEmailTemplateDetail(id));
  }

  // 10 MB / whitelisted-MIME limits are enforced server-side
  // (EmailTemplateAttachment.ALLOWED_MIME_TYPES, EmailTemplateDetailView._MAX_BYTES).
  Future<EmailTemplateAttachmentModel> uploadTemplateAttachment(
      int templateId, File file, String mimeType) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path,
        filename: file.path.split('/').last,
        contentType: DioMediaType.parse(mimeType),
      ),
    });
    final res = await _dio.post(
      ApiConstants.settingsEmailTemplateDetail(templateId),
      data: formData,
    );
    return EmailTemplateAttachmentModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteTemplateAttachment(int templateId, int attachmentId) async {
    await _dio.delete(
      ApiConstants.settingsEmailTemplateDetail(templateId),
      queryParameters: {'attachment_id': attachmentId},
    );
  }

  // ── Departments ────────────────────────────────────────────────────────────

  Future<List<DepartmentModel>> fetchDepartments() async {
    final res = await _dio
        .get(ApiConstants.departments, queryParameters: {'page_size': 200});
    final data = _unwrap(res.data);
    return _toList(data)
        .map((e) => DepartmentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DepartmentModel> createDepartment(DeptFormData form) async {
    final res = await _dio.post(ApiConstants.departments, data: form.toJson());
    return DepartmentModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<DepartmentModel> updateDepartment(int id, DeptFormData form) async {
    final res =
        await _dio.put(ApiConstants.departmentDetail(id), data: form.toJson());
    return DepartmentModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteDepartment(int id) async {
    await _dio.delete(ApiConstants.departmentDetail(id));
  }

  // ── Onboarding Fields (wizard steps 0-3) ──────────────────────────────────

  Future<List<OnboardingFieldConfigModel>> fetchOnboardingFields() async {
    final res = await _dio.get(ApiConstants.settingsOnboardingFields);
    return _toList(_unwrap(res.data))
        .map((e) => OnboardingFieldConfigModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<OnboardingFieldConfigModel> createOnboardingField(
      OnboardingFieldFormData form) async {
    final res = await _dio.post(ApiConstants.settingsOnboardingFields, data: form.toJson());
    return OnboardingFieldConfigModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<OnboardingFieldConfigModel> updateOnboardingField(
      String fieldKey, Map<String, dynamic> patch) async {
    final res = await _dio.patch(
      ApiConstants.settingsOnboardingFieldDetail(fieldKey),
      data: patch,
    );
    return OnboardingFieldConfigModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteOnboardingField(String fieldKey) async {
    await _dio.delete(ApiConstants.settingsOnboardingFieldDetail(fieldKey));
  }

  // ── Document Types (wizard step 4 — Documents) ────────────────────────────

  Future<List<DocumentTypeConfigModel>> fetchDocumentTypes() async {
    final res = await _dio.get(ApiConstants.settingsDocumentTypes);
    return _toList(_unwrap(res.data))
        .map((e) => DocumentTypeConfigModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DocumentTypeConfigModel> createDocumentType(DocumentTypeFormData form) async {
    final res = await _dio.post(ApiConstants.settingsDocumentTypes, data: form.toJson());
    return DocumentTypeConfigModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<DocumentTypeConfigModel> updateDocumentType(
      String typeKey, Map<String, dynamic> patch) async {
    final res = await _dio.patch(
      ApiConstants.settingsDocumentTypeDetail(typeKey),
      data: patch,
    );
    return DocumentTypeConfigModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteDocumentType(String typeKey) async {
    await _dio.delete(ApiConstants.settingsDocumentTypeDetail(typeKey));
  }

  // ── Leave Policy ───────────────────────────────────────────────────────────
  // The 6 built-in leave types (casual/earned/sick/lwp/maternity/paternity)
  // always exist; their full rule set can be edited via updateLeavePolicy.
  // Custom leave types can additionally be created/deleted — see
  // apps/hrms/views/leave.py LeavePolicyView (post()/delete()).

  Future<List<LeavePolicyModel>> fetchLeavePolicies() async {
    final res = await _dio.get(ApiConstants.leaveTypes);
    final data = _unwrap(res.data);
    return _toList(data)
        .map((e) => LeavePolicyModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<LeavePolicyModel> updateLeavePolicy(
      String leaveType, LeavePolicyFormData form) async {
    final res = await _dio.put(ApiConstants.leavePolicyDetail(leaveType),
        data: form.toJson());
    return LeavePolicyModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // POST /api/leave/policy/ — matches LeavePolicyCreateSerializer: requires
  // 'leave_type_label' (the backend derives the unique 'leave_type' key from
  // it) plus the same rule-field set as updateLeavePolicy.
  Future<LeavePolicyModel> createLeavePolicy(
      LeavePolicyFormData form, {required String leaveTypeLabel}) async {
    final res = await _dio.post(ApiConstants.leaveTypes, data: {
      'leave_type_label': leaveTypeLabel,
      ...form.toJson(),
    });
    return LeavePolicyModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // DELETE /api/leave/policy/<leaveType>/ — built-in types are rejected by
  // the backend (400); only custom leave types can actually be deleted.
  Future<void> deleteLeavePolicy(String leaveType) async {
    await _dio.delete(ApiConstants.leavePolicyDetail(leaveType));
  }

  // Real, working backend action (apps/hrms/views/leave.py LeaveBalanceView.post) —
  // credits each active employee's annual leave balance for the given year based
  // on LeavePolicy.annual_days. Requires 'leave.approve' permission.
  Future<CreditBalancesResult> creditLeaveBalances(
      {int? year, String? employeeId}) async {
    final res = await _dio.post(ApiConstants.leaveBalanceCredit, data: {
      if (year != null) 'year': year,
      if (employeeId != null && employeeId.isNotEmpty)
        'employee_id': employeeId,
    });
    return CreditBalancesResult.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Carry Forward execution — see ApiConstants.carryForward* doc comment ──

  Future<CarryForwardYearsModel> fetchCarryForwardYears() async {
    final res = await _dio.get(ApiConstants.carryForwardYears);
    return CarryForwardYearsModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<CarryForwardPreviewModel> previewCarryForward(
      {required int fromYear, required int toYear}) async {
    final res = await _dio.post(ApiConstants.carryForwardPreview,
        data: {'from_year': fromYear, 'to_year': toYear});
    return CarryForwardPreviewModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<CarryForwardLogModel> runCarryForward(
      {required int fromYear, required int toYear}) async {
    final res = await _dio.post(ApiConstants.carryForwardRun,
        data: {'from_year': fromYear, 'to_year': toYear});
    return CarryForwardLogModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<CarryForwardHistoryModel> fetchCarryForwardHistory(
      {int page = 1, int pageSize = 20}) async {
    final res = await _dio.get(ApiConstants.carryForwardHistory,
        queryParameters: {'page': page, 'page_size': pageSize});
    return CarryForwardHistoryModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<DesignationModel>> fetchDesignations() async {
    final res = await _dio
        .get(ApiConstants.designations, queryParameters: {'page_size': 200});
    final data = _unwrap(res.data);
    return _toList(data)
        .map((e) => DesignationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<DesignationModel> createDesignation(DesignationFormData form) async {
    final res = await _dio.post(ApiConstants.designations, data: form.toJson());
    return DesignationModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<DesignationModel> updateDesignation(
      int id, DesignationFormData form) async {
    final res =
        await _dio.put(ApiConstants.designationDetail(id), data: form.toJson());
    return DesignationModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteDesignation(int id) async {
    await _dio.delete(ApiConstants.designationDetail(id));
  }

  // ── Roles & Permissions ────────────────────────────────────────────────────

  Future<List<PermissionModel>> fetchPermissions() async {
    final res = await _dio.get(ApiConstants.permissions, queryParameters: {'page_size': 100});
    var data = _unwrap(res.data);
    // The list is wrapped in the standard pagination envelope
    // ({count, page, page_size, total_pages, results}) — the module-grouped
    // map lives under `results`, not directly under `data`. Drilling into it
    // here used to be skipped, so the loop below iterated over
    // {count, page, page_size, total_pages, results} itself: none of those
    // top-level values is a List, so every permission fetch silently
    // returned [] — the Roles screen's Permission Matrix section and the
    // Add/Edit Role form's permission picker both went empty as a result.
    if (data is Map<String, dynamic> && data['results'] != null) {
      data = data['results'];
    }
    // Backend returns grouped by module: {module: [{id, codename, module, action}...], ...}
    if (data is Map<String, dynamic>) {
      final result = <PermissionModel>[];
      for (final group in data.values) {
        if (group is List) {
          result.addAll(
            group.map(
                (e) => PermissionModel.fromJson(e as Map<String, dynamic>)),
          );
        }
      }
      return result;
    }
    if (data is List) {
      return data
          .map((e) => PermissionModel.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<RolesPage> fetchRoles() async {
    final res = await _dio.get(ApiConstants.roles);
    final data = _unwrap(res.data);
    // Backend returns paginated: {count, page, page_size, total_pages, results}
    if (data is Map<String, dynamic>) {
      final results = data['results'] as List<dynamic>? ?? [];
      final roles = results
          .map((e) => RoleModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return RolesPage(
          roles: roles, count: data['count'] as int? ?? roles.length);
    }
    if (data is List) {
      final roles = data
          .map((e) => RoleModel.fromJson(e as Map<String, dynamic>))
          .toList();
      return RolesPage(roles: roles, count: roles.length);
    }
    return RolesPage.empty();
  }

  Future<RoleModel> createRole(RoleFormData form) async {
    final res = await _dio.post(ApiConstants.roles, data: form.toJson());
    return RoleModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<RoleModel> updateRole(dynamic id, RoleFormData form) async {
    final res =
        await _dio.put(ApiConstants.roleDetail(id), data: form.toJson());
    return RoleModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> toggleRole(dynamic id, bool isActive) async {
    await _dio
        .patch(ApiConstants.roleDetail(id), data: {'is_active': isActive});
  }

  // ── Audit Log ──────────────────────────────────────────────────────────────

  Future<AuditLogPage> fetchAuditLog(AuditLogFilters filters) async {
    final res = await _dio.get(
      ApiConstants.settingsAudit,
      queryParameters: filters.toQueryParams(),
    );
    final data = _unwrap(res.data);

    if (data is Map<String, dynamic>) {
      final results = data['results'] as List<dynamic>? ?? [];
      final count = data['count'] as int? ?? results.length;
      final totalPages = data['total_pages'] as int? ?? 1;
      return AuditLogPage(
        entries: results
            .map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: count,
        currentPage: data['page'] as int? ?? filters.page,
        totalPages: totalPages,
        hasNext: filters.page < totalPages,
      );
    }
    return AuditLogPage.empty();
  }

  // ── Attendance Rules (singleton settings object, 6 sections) ──────────────

  Future<AttendanceSettingsModel> fetchAttendanceSettings() async {
    final res = await _dio.get(ApiConstants.attendanceSettings);
    final data = _unwrap(res.data);
    return AttendanceSettingsModel.fromJson(data as Map<String, dynamic>);
  }

  Future<AttendanceSettingsModel> putAttendanceSettings(
      AttendanceSettingsModel model) async {
    final res =
        await _dio.put(ApiConstants.attendanceSettings, data: model.toJson());
    return AttendanceSettingsModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<AttendanceSettingsModel> patchAttendanceSettingsSection(
      String sectionKey, Map<String, dynamic> sectionJson) async {
    final res = await _dio.patch(ApiConstants.attendanceSettings,
        data: {sectionKey: sectionJson});
    return AttendanceSettingsModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Assessment Config (singleton) ──────────────────────────────────────────

  Future<AssessmentConfigModel> fetchAssessmentConfig() async {
    final res = await _dio.get(ApiConstants.settingsAssessmentConfig);
    final data = _unwrap(res.data);
    return AssessmentConfigModel.fromJson(data as Map<String, dynamic>);
  }

  Future<AssessmentConfigModel> updateAssessmentConfig(
      AssessmentConfigModel model) async {
    final res = await _dio.put(ApiConstants.settingsAssessmentConfig,
        data: model.toJson());
    return AssessmentConfigModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Opening Balance & History bulk import (one-time migration tool) ───────

  Future<List<int>> downloadLeaveBalanceImportSample(String format) async {
    final res = await _dio.get(
      ApiConstants.leaveBalanceImportSample,
      queryParameters: {'format': format},
      options: Options(responseType: ResponseType.bytes),
    );
    return res.data as List<int>;
  }

  Future<LeaveImportValidateResult> validateLeaveBalanceImport(
      List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post(ApiConstants.leaveBalanceImportValidate, data: formData);
    return LeaveImportValidateResult.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<LeaveImportResult> importLeaveBalanceFile(List<int> bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post(ApiConstants.leaveBalanceImport, data: formData);
    return LeaveImportResult.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  // Backend envelope: {success: true, message: "...", data: ...}
  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) return body['data'];
    }
    return body;
  }

  // All list endpoints return a paginated object {count, page, results:[...]}.
  // This extracts the results array from that wrapper, or falls back to a
  // plain list if the endpoint ever returns one directly.
  List<dynamic> _toList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      return data['results'] as List<dynamic>? ?? [];
    }
    return [];
  }
}

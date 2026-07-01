import 'dart:io';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/audit_model.dart';
import '../models/company_model.dart';
import '../models/departments_model.dart';
import '../models/email_template_model.dart';
import '../models/employee_code_model.dart';
import '../models/leave_policy_model.dart';
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
    return EmployeeCodeModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // ── SMTP ───────────────────────────────────────────────────────────────────

  Future<List<SmtpModel>> fetchSmtpList() async {
    final res = await _dio.get(ApiConstants.settingsSmtp);
    final data = _unwrap(res.data);
    return _toList(data).map((e) => SmtpModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<SmtpModel> createSmtp(SmtpFormData form) async {
    final res = await _dio.post(ApiConstants.settingsSmtp, data: form.toJson(isAdd: true));
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

  Future<void> testSmtp(SmtpModel entry, String recipient, String password) async {
    await _dio.post(ApiConstants.settingsSmtpTest, data: {
      'host':           entry.host,
      'port':           entry.port,
      'username':       entry.username,
      'password':       password,
      'use_tls':        entry.useTls,
      'sender_name':    entry.senderName,
      'from_email':     entry.fromEmail,
      'bcc_email':      entry.bccEmail,
      'test_recipient': recipient,
    });
  }

  // ── Email Templates ────────────────────────────────────────────────────────

  Future<List<EmailTemplateCategoryModel>> fetchTemplateCategories() async {
    final res = await _dio.get(ApiConstants.settingsEmailTemplateCategories);
    final data = _unwrap(res.data);
    return _toList(data).map((e) => EmailTemplateCategoryModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<EmailTemplateModel>> fetchTemplates() async {
    final res = await _dio.get(ApiConstants.settingsEmailTemplates);
    final data = _unwrap(res.data);
    // Backend returns paginated with results as grouped dict: {template_type: [templates...], ...}
    final grouped = (data is Map<String, dynamic>) ? (data['results'] ?? data) : data;
    final result = <EmailTemplateModel>[];
    if (grouped is Map<String, dynamic>) {
      for (final group in grouped.values) {
        if (group is List) {
          result.addAll(group.map((e) => EmailTemplateModel.fromJson(e as Map<String, dynamic>)));
        }
      }
    } else if (grouped is List) {
      result.addAll(grouped.map((e) => EmailTemplateModel.fromJson(e as Map<String, dynamic>)));
    }
    return result;
  }

  Future<EmailTemplateModel> createTemplate(EmailTemplateFormData form) async {
    final res = await _dio.post(ApiConstants.settingsEmailTemplates, data: form.toJson(isAdd: true));
    return EmailTemplateModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<EmailTemplateModel> updateTemplate(int id, EmailTemplateFormData form) async {
    final res = await _dio.patch(ApiConstants.settingsEmailTemplateDetail(id), data: form.toJson(isAdd: false));
    return EmailTemplateModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> toggleTemplateActive(int id, bool isActive) async {
    await _dio.patch(ApiConstants.settingsEmailTemplateDetail(id), data: {'is_active': isActive});
  }

  Future<void> deleteTemplate(int id) async {
    await _dio.delete(ApiConstants.settingsEmailTemplateDetail(id));
  }

  // ── Departments ────────────────────────────────────────────────────────────

  Future<List<DepartmentModel>> fetchDepartments() async {
    final res = await _dio.get(ApiConstants.departments, queryParameters: {'page_size': 200});
    final data = _unwrap(res.data);
    return _toList(data).map((e) => DepartmentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DepartmentModel> createDepartment(DeptFormData form) async {
    final res = await _dio.post(ApiConstants.departments, data: form.toJson());
    return DepartmentModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<DepartmentModel> updateDepartment(int id, DeptFormData form) async {
    final res = await _dio.put(ApiConstants.departmentDetail(id), data: form.toJson());
    return DepartmentModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteDepartment(int id) async {
    await _dio.delete(ApiConstants.departmentDetail(id));
  }

  // ── Leave Policy ───────────────────────────────────────────────────────────
  // No create/delete — the 6 leave types are fixed; only their policy fields
  // (annual_days, can_carry_forward, max_carry_forward_days, policy_note,
  // is_active) can be edited. See apps/hrms/views/leave.py LeavePolicyView.

  Future<List<LeavePolicyModel>> fetchLeavePolicies() async {
    final res = await _dio.get(ApiConstants.leaveTypes);
    final data = _unwrap(res.data);
    return _toList(data).map((e) => LeavePolicyModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<LeavePolicyModel> updateLeavePolicy(String leaveType, LeavePolicyFormData form) async {
    final res = await _dio.put(ApiConstants.leavePolicyDetail(leaveType), data: form.toJson());
    return LeavePolicyModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // Real, working backend action (apps/hrms/views/leave.py LeaveBalanceView.post) —
  // credits each active employee's annual leave balance for the given year based
  // on LeavePolicy.annual_days. Requires 'leave.approve' permission.
  Future<CreditBalancesResult> creditLeaveBalances({int? year, String? employeeId}) async {
    final res = await _dio.post(ApiConstants.leaveBalanceCredit, data: {
      if (year != null) 'year': year,
      if (employeeId != null && employeeId.isNotEmpty) 'employee_id': employeeId,
    });
    return CreditBalancesResult.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<DesignationModel>> fetchDesignations() async {
    final res = await _dio.get(ApiConstants.designations, queryParameters: {'page_size': 200});
    final data = _unwrap(res.data);
    return _toList(data).map((e) => DesignationModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<DesignationModel> createDesignation(DesignationFormData form) async {
    final res = await _dio.post(ApiConstants.designations, data: form.toJson());
    return DesignationModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<DesignationModel> updateDesignation(int id, DesignationFormData form) async {
    final res = await _dio.put(ApiConstants.designationDetail(id), data: form.toJson());
    return DesignationModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteDesignation(int id) async {
    await _dio.delete(ApiConstants.designationDetail(id));
  }

  // ── Roles & Permissions ────────────────────────────────────────────────────

  Future<List<PermissionModel>> fetchPermissions() async {
    final res = await _dio.get(ApiConstants.permissions);
    final data = _unwrap(res.data);
    // Backend returns grouped by module: {module: [{id, codename, module, action}...], ...}
    if (data is Map<String, dynamic>) {
      final result = <PermissionModel>[];
      for (final group in data.values) {
        if (group is List) {
          result.addAll(
            group.map((e) => PermissionModel.fromJson(e as Map<String, dynamic>)),
          );
        }
      }
      return result;
    }
    if (data is List) {
      return data.map((e) => PermissionModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  Future<RolesPage> fetchRoles() async {
    final res = await _dio.get(ApiConstants.roles);
    final data = _unwrap(res.data);
    // Backend returns paginated: {count, page, page_size, total_pages, results}
    if (data is Map<String, dynamic>) {
      final results = data['results'] as List<dynamic>? ?? [];
      final roles = results.map((e) => RoleModel.fromJson(e as Map<String, dynamic>)).toList();
      return RolesPage(roles: roles, count: data['count'] as int? ?? roles.length);
    }
    if (data is List) {
      final roles = data.map((e) => RoleModel.fromJson(e as Map<String, dynamic>)).toList();
      return RolesPage(roles: roles, count: roles.length);
    }
    return RolesPage.empty();
  }

  Future<RoleModel> createRole(RoleFormData form) async {
    final res = await _dio.post(ApiConstants.roles, data: form.toJson());
    return RoleModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<RoleModel> updateRole(dynamic id, RoleFormData form) async {
    final res = await _dio.put(ApiConstants.roleDetail(id), data: form.toJson());
    return RoleModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> toggleRole(dynamic id, bool isActive) async {
    await _dio.patch(ApiConstants.roleDetail(id), data: {'is_active': isActive});
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
      final count      = data['count'] as int? ?? results.length;
      final totalPages = data['total_pages'] as int? ?? 1;
      return AuditLogPage(
        entries:     results.map((e) => AuditLogEntry.fromJson(e as Map<String, dynamic>)).toList(),
        total:       count,
        currentPage: data['page'] as int? ?? filters.page,
        totalPages:  totalPages,
        hasNext:     filters.page < totalPages,
      );
    }
    return AuditLogPage.empty();
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
    if (data is Map<String, dynamic>) return data['results'] as List<dynamic>? ?? [];
    return [];
  }
}

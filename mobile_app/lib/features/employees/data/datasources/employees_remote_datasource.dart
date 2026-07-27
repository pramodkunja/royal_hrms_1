import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../shared/models/bulk_import_result.dart';
import '../models/employee_model.dart';

// ── Approval matrix row (per-employee) ────────────────────────────────────
// Matches backend `_build_matrix_row` (EmployeeApprovalMatrixView). Lives
// here rather than in employee_model.dart since that file is considered
// finished/frozen for this feature slice.

class EmployeeApprovalMatrixRow {
  final String workflowType;
  final String workflowLabel;
  final String l1ApproverRole;
  final String l1ApproverLabel;
  final String? l1ApproverId;
  final String? l1ApproverName;
  final bool l1IsOverride;
  final String? l2ApproverRole; // null/empty => single-level workflow
  final String? l2ApproverLabel;
  final String? l2ApproverId;
  final String? l2ApproverName;
  final bool l2IsOverride;

  const EmployeeApprovalMatrixRow({
    required this.workflowType,
    required this.workflowLabel,
    required this.l1ApproverRole,
    required this.l1ApproverLabel,
    this.l1ApproverId,
    this.l1ApproverName,
    this.l1IsOverride = false,
    this.l2ApproverRole,
    this.l2ApproverLabel,
    this.l2ApproverId,
    this.l2ApproverName,
    this.l2IsOverride = false,
  });

  bool get isSingleLevel => l2ApproverRole == null || l2ApproverRole!.isEmpty;

  factory EmployeeApprovalMatrixRow.fromJson(Map<String, dynamic> json) =>
      EmployeeApprovalMatrixRow(
        workflowType:    json['workflow_type'] as String? ?? '',
        workflowLabel:   json['workflow_label'] as String? ?? '',
        l1ApproverRole:  json['l1_approver_role'] as String? ?? '',
        l1ApproverLabel: json['l1_approver_label'] as String? ?? '',
        l1ApproverId:    json['l1_approver_id'] as String?,
        l1ApproverName:  json['l1_approver_name'] as String?,
        l1IsOverride:    json['l1_is_override'] as bool? ?? false,
        l2ApproverRole:  json['l2_approver_role'] as String?,
        l2ApproverLabel: json['l2_approver_label'] as String?,
        l2ApproverId:    json['l2_approver_id'] as String?,
        l2ApproverName:  json['l2_approver_name'] as String?,
        l2IsOverride:    json['l2_is_override'] as bool? ?? false,
      );
}

class EmployeesRemoteDataSource {
  final Dio _dio;
  EmployeesRemoteDataSource(this._dio);

  // ── List ───────────────────────────────────────────────────────────────────
  //
  // Backend paginates this endpoint (default page_size 20, max 50) — the
  // stats/filters UI expects the *complete* employee list client-side, so
  // this walks every page and concatenates results rather than returning
  // just the first one (which previously under-counted Total Employees and
  // the list itself whenever there were more than 20 employees).

  Future<List<EmployeeModel>> fetchEmployees() async {
    final employees = <EmployeeModel>[];
    var page = 1;
    var totalPages = 1;
    do {
      final res = await _dio.get(
        ApiConstants.employees,
        queryParameters: {'page': page, 'page_size': 50},
      );
      final raw = _unwrap(res.data);
      if (raw is List) {
        employees.addAll(
            raw.whereType<Map<String, dynamic>>().map(EmployeeModel.fromJson));
        break;
      } else if (raw is Map<String, dynamic>) {
        final list = raw['results'] as List<dynamic>? ?? [];
        employees.addAll(
            list.whereType<Map<String, dynamic>>().map(EmployeeModel.fromJson));
        totalPages = raw['total_pages'] as int? ?? 1;
      } else {
        break;
      }
      page++;
    } while (page <= totalPages);
    return employees;
  }

  // ── Detail ─────────────────────────────────────────────────────────────────

  Future<EmployeeModel> fetchEmployee(String employeeId) async {
    final res = await _dio.get(ApiConstants.employeeDetail(employeeId));
    return EmployeeModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Create ─────────────────────────────────────────────────────────────────

  Future<EmployeeModel> createEmployee(EmployeeFormData form) async {
    final res = await _dio.post(ApiConstants.employees, data: form.toJson());
    return EmployeeModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Update (edit) ─────────────────────────────────────────────────────────
  //
  // PUT only reads/persists 8 fields server-side (see EmployeeUpdateFormData
  // doc comment) — the response body is the full, refreshed employee dict.

  Future<EmployeeModel> updateEmployee(
    String employeeId,
    EmployeeUpdateFormData form,
  ) async {
    final res = await _dio.put(
      ApiConstants.employeeDetail(employeeId),
      data: form.toJson(),
    );
    return EmployeeModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Status toggle ──────────────────────────────────────────────────────────

  Future<void> patchEmployeeStatus(String employeeId, bool isActive) async {
    await _dio.patch(
      ApiConstants.employeeDetail(employeeId),
      data: {'is_active': isActive},
    );
  }

  // ── Branches for form dropdown ─────────────────────────────────────────────

  Future<List<EmployeeBranch>> fetchBranches() async {
    final res = await _dio.get(ApiConstants.branches);
    final raw = _unwrap(res.data);
    final list = raw is List
        ? raw
        : (raw is Map<String, dynamic>
            ? raw['results'] as List<dynamic>? ?? []
            : <dynamic>[]);
    return list
        .whereType<Map<String, dynamic>>()
        .map(EmployeeBranch.fromJson)
        .toList();
  }

  // ── HR / Reporting-manager pickers (Edit Employee sheet, edit-only) ─────────
  // Both endpoints return the same shape: {id, employee_id, full_name,
  // department, branch}. `branch` is optional for hrs/, required for managers/.

  Future<List<EmployeePickerOption>> fetchHrs(String branch) async {
    final res = await _dio.get(
      ApiConstants.employeesHrList,
      queryParameters: {if (branch.isNotEmpty) 'branch': branch},
    );
    return _unwrapPickerList(res.data);
  }

  Future<List<EmployeePickerOption>> fetchManagers(String branch) async {
    final res = await _dio.get(
      ApiConstants.employeesManagerList,
      queryParameters: {'branch': branch},
    );
    return _unwrapPickerList(res.data);
  }

  List<EmployeePickerOption> _unwrapPickerList(dynamic body) {
    final raw = _unwrap(body);
    final list = raw is List
        ? raw
        : (raw is Map<String, dynamic>
            ? raw['results'] as List<dynamic>? ?? []
            : <dynamic>[]);
    return list
        .whereType<Map<String, dynamic>>()
        .map(EmployeePickerOption.fromJson)
        .toList();
  }

  // ── Approval matrix (per-employee) ──────────────────────────────────────────
  // `loan` is technically a 4th workflow the backend returns, but the web UI
  // hides it — filtered out here so callers never see it.

  Future<List<EmployeeApprovalMatrixRow>> fetchApprovalMatrix(
    String employeeId,
  ) async {
    final res = await _dio.get(ApiConstants.employeeApprovalMatrix(employeeId));
    final raw = _unwrap(res.data);
    final list = raw is List ? raw : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map(EmployeeApprovalMatrixRow.fromJson)
        .where((r) => r.workflowType != 'loan')
        .toList();
  }

  Future<EmployeeApprovalMatrixRow> updateApprovalOverride(
    String employeeId,
    String workflowType, {
    String? l1OverrideId,
    String? l2OverrideId,
  }) async {
    final res = await _dio.patch(
      ApiConstants.employeeApprovalMatrix(employeeId),
      data: {
        'workflow_type': workflowType,
        'l1_override_id': l1OverrideId,
        'l2_override_id': l2OverrideId,
      },
    );
    return EmployeeApprovalMatrixRow.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Send wish email (Wishes tab) ────────────────────────────────────────────
  // POST /recruitment/candidates/<id>/send-email/. Only succeeds when the
  // employee has a linked recruitment `Candidate` record — the backend
  // resolves `id` as a numeric candidate pk first, then falls back to
  // `portal_user__employee_id`, so passing the human-readable employee code
  // works the same way the web app already sends it. Employees created
  // directly via "Add Employee" have no Candidate record and this 404s with
  // "Candidate not found." — that error is left to propagate to the caller
  // verbatim (via parseDioException), not swallowed here.
  Future<void> sendCandidateEmail(
    String employeeId, {
    required String templateName,
    required Map<String, String> extraContext,
  }) async {
    await _dio.post(
      ApiConstants.candidateSendEmail(employeeId),
      data: {
        'template_name': templateName,
        'extra_context': extraContext,
      },
    );
  }

  // ── Designations filtered by department ID ─────────────────────────────────

  Future<List<String>> fetchDesignationNames(int deptId) async {
    final res = await _dio.get(
      ApiConstants.designations,
      queryParameters: {'department': deptId},
    );
    final raw = _unwrap(res.data);
    final list = raw is List ? raw : <dynamic>[];
    return list
        .whereType<Map<String, dynamic>>()
        .map((e) => e['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  // ── Bulk Import (CSV/XLSX, max 1000 rows / 5MB — system_admin/hr_admin only) ─
  //
  // Required columns: first_name, last_name, email, role, department,
  // designation, branch, date_of_joining. Optional: phone, employee_type,
  // gender, date_of_birth, blood_group, address. See
  // EmployeeBulkImportRowSerializer in the backend for exact validation.

  Future<BulkImportResult> bulkImport({
    required Uint8List bytes,
    required String filename,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final res = await _dio.post(
      ApiConstants.employeeBulkImport,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return BulkImportResult.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}

import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/employee_model.dart';

class EmployeesRemoteDataSource {
  final Dio _dio;
  EmployeesRemoteDataSource(this._dio);

  // ── List ───────────────────────────────────────────────────────────────────

  Future<List<EmployeeModel>> fetchEmployees() async {
    final res = await _dio.get(ApiConstants.employees);
    final list = _unwrap(res.data);
    if (list is! List) return [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(EmployeeModel.fromJson)
        .toList();
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

  // ── Helper ─────────────────────────────────────────────────────────────────

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}

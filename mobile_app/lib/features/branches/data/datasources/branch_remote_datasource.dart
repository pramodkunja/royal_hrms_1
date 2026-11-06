import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/branch_model.dart';

class BranchRemoteDataSource {
  final Dio _dio;
  BranchRemoteDataSource(this._dio);

  // ── States ──────────────────────────────────────────────────────────────────

  Future<List<StateModel>> fetchStates() async {
    final res = await _dio.get(ApiConstants.branchStates);
    final data = _unwrap(res.data);
    final list = _toList(data);
    return list.map((item) => StateModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  // ── Cities ──────────────────────────────────────────────────────────────────

  Future<List<CityModel>> fetchCities(int stateId) async {
    final res = await _dio.get(ApiConstants.branchCities(stateId));
    final data = _unwrap(res.data);
    final list = _toList(data);
    return list.map((item) => CityModel.fromJson(item as Map<String, dynamic>)).toList();
  }

  // ── Preview Code ────────────────────────────────────────────────────────────

  Future<String> fetchPreviewCode(int cityId) async {
    final res = await _dio.get(
      ApiConstants.branchPreviewCode,
      queryParameters: {'city_id': cityId},
    );
    final data = _unwrap(res.data);
    if (data is Map<String, dynamic>) {
      return data['branch_code'] as String? ?? '';
    }
    return '';
  }

  // ── Stats ───────────────────────────────────────────────────────────────────

  Future<BranchStatsModel> fetchStats() async {
    final res = await _dio.get(ApiConstants.branchStats);
    final data = _unwrap(res.data);
    return BranchStatsModel.fromJson(data as Map<String, dynamic>);
  }

  // ── Distribution (employees per branch, for the chart) ─────────────────────────

  Future<List<BranchDistributionModel>> fetchDistribution() async {
    final res = await _dio.get(ApiConstants.branchDistribution);
    final data = _unwrap(res.data);
    final list = _toList(data);
    return list
        .map((item) =>
            BranchDistributionModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  // ── Branches ────────────────────────────────────────────────────────────────

  Future<List<BranchModel>> fetchBranches({
    int page = 1,
    int pageSize = 50,
  }) async {
    final res = await _dio.get(
      ApiConstants.branches,
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    final data = _unwrap(res.data);
    if (data is Map<String, dynamic>) {
      final results = data['results'] as List<dynamic>? ?? [];
      return results
          .map((item) => BranchModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    if (data is List) {
      return data
          .map((item) => BranchModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  Future<BranchModel> createBranch(Map<String, dynamic> payload) async {
    final res = await _dio.post(ApiConstants.branches, data: payload);
    return BranchModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<BranchModel> updateBranch(
      int id, Map<String, dynamic> payload) async {
    final res =
        await _dio.put(ApiConstants.branchDetail(id), data: payload);
    return BranchModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteBranch(int id) async {
    await _dio.delete(ApiConstants.branchDetail(id));
  }

  // ── Branch Admin reassignment (web BranchManagement openReassign / doReassign) ─

  /// GET /employees/?page_size=50&status=active — web's candidate list, minus
  /// system admins and the current admin (matched by email, as web does).
  Future<List<BranchAdminCandidate>> fetchAdminCandidates({String? excludeEmail}) async {
    final res = await _dio.get(ApiConstants.employees, queryParameters: {'page_size': 50, 'status': 'active'});
    final data = _unwrap(res.data);
    final list = data is Map ? (data['results'] is List ? data['results'] as List : const []) : _toList(data);
    return list
        .whereType<Map>()
        .map((e) => BranchAdminCandidate.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.role != 'system_admin' && c.email != (excludeEmail ?? ''))
        .toList();
  }

  /// POST /branch/branches/<id>/reassign-admin/ with `{employee_id: <code>}`.
  /// Returns the server's message and the updated branch.
  Future<({String message, BranchModel? branch})> reassignAdmin(int branchId, String employeeCode) async {
    final res = await _dio.post(ApiConstants.branchReassignAdmin(branchId), data: {'employee_id': employeeCode});
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    return (
      message: body is Map && body['message'] is String ? body['message'] as String : '',
      branch: data is Map ? BranchModel.fromJson(Map<String, dynamic>.from(data)) : null,
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      if (body.containsKey('data')) return body['data'];
    }
    return body;
  }

  List<dynamic> _toList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) return data['results'] as List<dynamic>? ?? [];
    return [];
  }
}

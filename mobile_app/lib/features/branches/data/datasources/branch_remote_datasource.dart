import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../settings/data/models/roles_model.dart';
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

  /// PATCH (partial) like web's Edit Branch — only the fields sent change.
  Future<BranchModel> updateBranch(
      int id, Map<String, dynamic> payload) async {
    final res =
        await _dio.patch(ApiConstants.branchDetail(id), data: payload);
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

  // ── Add Branch → Assign Branch Admin (web BranchManagement LeaderForm) ──────

  /// Web Add Branch: GET /employees/?page_size=50&status=active, without
  /// system admins (no email exclusion here — that's the reassign list).
  Future<List<BranchAdminCandidate>> fetchBranchLeaderCandidates() async {
    final res = await _dio.get(ApiConstants.employees, queryParameters: {'page_size': 50, 'status': 'active'});
    final data = _unwrap(res.data);
    final list = data is Map ? (data['results'] is List ? data['results'] as List : const []) : _toList(data);
    return list
        .whereType<Map>()
        .map((e) => BranchAdminCandidate.fromJson(Map<String, dynamic>.from(e)))
        .where((c) => c.role != 'system_admin')
        .toList();
  }

  /// Web: GET /roles/?page_size=100 (open to any signed-in user).
  Future<List<RoleModel>> fetchRolesForBranchAdmin() async {
    final res = await _dio.get(ApiConstants.roles, queryParameters: {'page_size': 100});
    return _toList(_unwrap(res.data)).whereType<Map>().map((e) => RoleModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Web transfer check: GET /employees/?<filter>=<uuid>&page_size=1 → count.
  /// [filter] is 'reporting_manager_id' or 'hr_id'; both take the user's UUID.
  Future<int> countEmployeesBy(String filter, String uuid) async {
    final res = await _dio.get(ApiConstants.employees, queryParameters: {filter: uuid, 'page_size': 1});
    final data = _unwrap(res.data);
    final count = data is Map ? data['count'] : null;
    return count is num ? count.toInt() : 0;
  }

  /// "existing": PUT /employees/<code>/ with only {role, branch}.
  Future<void> assignExistingBranchAdmin(String employeeCode, Map<String, dynamic> payload) =>
      _dio.put(ApiConstants.employeeDetail(employeeCode), data: payload);

  /// "new": POST /employees/ (invite with the generated temporary password).
  Future<void> inviteBranchAdmin(Map<String, dynamic> payload) => _dio.post(ApiConstants.employees, data: payload);

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

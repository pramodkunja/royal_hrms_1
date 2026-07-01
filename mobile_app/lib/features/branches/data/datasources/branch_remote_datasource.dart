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

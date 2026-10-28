import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';

class OrgChartRemoteDataSource {
  final Dio _dio;
  OrgChartRemoteDataSource(this._dio);

  /// Hits the same `GET /org-chart/` endpoint the web app uses. [branch] is
  /// sent as-is (backend matches it case-insensitively); omit for the
  /// server's default scope (own branch, or all branches for company-scope
  /// viewers).
  Future<Map<String, dynamic>> fetchOrgChart({String? branch}) async {
    final res = await _dio.get(
      ApiConstants.orgChart,
      queryParameters: (branch != null && branch.isNotEmpty)
          ? {'branch': branch}
          : null,
    );
    final data = _unwrap(res.data);
    return data is Map<String, dynamic> ? data : {};
  }

  /// Branch names for the company-scope branch picker — same source the web
  /// app's branch dropdown uses.
  Future<List<String>> fetchBranchNames() async {
    final res = await _dio.get(
      ApiConstants.branches,
      queryParameters: {'page_size': 100},
    );
    final data = _unwrap(res.data);
    final results = data is Map<String, dynamic>
        ? (data['results'] as List<dynamic>? ?? [])
        : (data is List ? data : const []);
    return results
        .cast<Map<String, dynamic>>()
        .map((b) => b['branch_name'] as String? ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}

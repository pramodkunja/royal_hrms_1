import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';

class OrgChartRemoteDataSource {
  final Dio _dio;
  OrgChartRemoteDataSource(this._dio);

  Future<List<Map<String, dynamic>>> fetchEmployees() async {
    final res = await _dio.get(
      ApiConstants.employees,
      queryParameters: {'page_size': 200},
    );
    final data = _unwrap(res.data);
    if (data is Map<String, dynamic>) {
      final results = data['results'] as List<dynamic>? ?? [];
      return results.cast<Map<String, dynamic>>();
    }
    if (data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<String> fetchCompanyName() async {
    try {
      final res = await _dio.get(ApiConstants.settingsCompany);
      final data = _unwrap(res.data);
      if (data is Map<String, dynamic>) {
        return data['name'] as String? ?? 'Royal HRMS';
      }
      return 'Royal HRMS';
    } catch (_) {
      return 'Royal HRMS';
    }
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}

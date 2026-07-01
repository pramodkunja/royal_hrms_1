import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/approval_model.dart';

class ApprovalRemoteDataSource {
  final Dio _dio;
  ApprovalRemoteDataSource(this._dio);

  Future<List<ApprovalUser>> fetchApprovals() async {
    final res = await _dio.get(
      ApiConstants.onboardingApprovals,
      queryParameters: {'page_size': 100},
    );
    final body = res.data;
    dynamic data;
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      data = body['data'];
    } else {
      data = body;
    }
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      items = (data['results'] as List<dynamic>?) ?? [];
    } else {
      items = [];
    }
    return items
        .map((e) => ApprovalUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> approveOrReject(
    String userId, {
    required String decision,
    String remarks = '',
    String? department,
    String? designation,
  }) async {
    await _dio.post(
      ApiConstants.onboardingApprove(userId),
      data: {
        'decision': decision,
        'remarks': remarks,
        if (department != null && department.isNotEmpty) 'department': department,
        if (designation != null && designation.isNotEmpty) 'designation': designation,
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchDepartments() async {
    final res = await _dio.get(
      ApiConstants.departments,
      queryParameters: {'page_size': 200},
    );
    final body = res.data;
    dynamic data;
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      data = body['data'];
    } else {
      data = body;
    }
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      items = (data['results'] as List<dynamic>?) ?? [];
    } else {
      items = [];
    }
    return items.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchDesignations() async {
    final res = await _dio.get(
      ApiConstants.designations,
      queryParameters: {'page_size': 200},
    );
    final body = res.data;
    dynamic data;
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      data = body['data'];
    } else {
      data = body;
    }
    final List<dynamic> items;
    if (data is List) {
      items = data;
    } else if (data is Map<String, dynamic>) {
      items = (data['results'] as List<dynamic>?) ?? [];
    } else {
      items = [];
    }
    return items.cast<Map<String, dynamic>>();
  }
}

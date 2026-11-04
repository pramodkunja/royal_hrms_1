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
    String? uanNumber,
    String? nameAsPerAadhar,
    String? panNumber,
    String? assessmentId,
  }) async {
    bool has(String? v) => v != null && v.trim().isNotEmpty;
    await _dio.post(
      ApiConstants.onboardingApprove(userId),
      data: {
        'decision': decision,
        'remarks': remarks,
        if (has(department)) 'department': department,
        if (has(designation)) 'designation': designation,
        // Optional approval extras (OnboardingApprovalView): sent only when
        // filled, as web does; the server keeps the profile value otherwise.
        if (has(uanNumber)) 'uan_number': uanNumber!.trim(),
        if (has(nameAsPerAadhar)) 'name_as_per_aadhar': nameAsPerAadhar!.trim(),
        if (has(panNumber)) 'pan_number': panNumber!.trim().toUpperCase(),
        // The backend's current field (it still accepts a single
        // assessment_id from older callers).
        if (has(assessmentId)) 'assessment_ids': [assessmentId],
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

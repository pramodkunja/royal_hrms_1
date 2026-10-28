import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/approval_rule_model.dart';

class ApprovalRulesRemoteDataSource {
  final Dio _dio;
  ApprovalRulesRemoteDataSource(this._dio);

  Future<List<ApprovalRuleModel>> fetchRules() async {
    final res = await _dio.get(ApiConstants.settingsApprovalRules);
    final data = _unwrap(res.data);
    final list = data is List ? data : const [];
    return list.map((e) => ApprovalRuleModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ApprovalRuleModel> updateRule({
    required String workflowType,
    required int l1ApproverRole,
    required int? l2ApproverRole,
  }) async {
    final res = await _dio.patch(
      ApiConstants.settingsApprovalRules,
      data: {
        'workflow_type': workflowType,
        'l1_approver_role': l1ApproverRole,
        'l2_approver_role': l2ApproverRole,
      },
    );
    return ApprovalRuleModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}

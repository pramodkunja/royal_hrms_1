import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/referral_model.dart';

class ReferralRemoteDataSource {
  final Dio _dio;
  ReferralRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  List<dynamic> _resultsList(dynamic data) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      return data['results'] as List<dynamic>? ?? [];
    }
    return [];
  }

  Future<List<ReferralModel>> fetchMyReferrals() async {
    final res = await _dio.get(ApiConstants.referrals);
    return _resultsList(_unwrap(res.data))
        .whereType<Map<String, dynamic>>()
        .map(ReferralModel.fromJson)
        .toList();
  }

  // Requires the caller to hold 'recruitment.view' — the backend 403s otherwise.
  Future<List<ReferralModel>> fetchAllReferrals() async {
    final res = await _dio.get(ApiConstants.referralsAll);
    return _resultsList(_unwrap(res.data))
        .whereType<Map<String, dynamic>>()
        .map(ReferralModel.fromJson)
        .toList();
  }

  // branchId/phone/notes omitted from the body entirely when empty, matching
  // the backend's optional-field handling in CandidateCreateSerializer.
  Future<ReferralModel> createReferral({
    required String name,
    required String email,
    String? phone,
    required String positionApplied,
    int? branchId,
    String? notes,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'position_applied': positionApplied,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (branchId != null) 'branch': branchId,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    };
    final res = await _dio.post(ApiConstants.referrals, data: body);
    return ReferralModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<ReferralRuleModel>> fetchReferralRules() async {
    final res = await _dio.get(ApiConstants.referralRules);
    return _resultsList(_unwrap(res.data))
        .whereType<Map<String, dynamic>>()
        .map(ReferralRuleModel.fromJson)
        .toList();
  }

  // ── Referral Rules admin CRUD (Settings screen — requires settings.view) ────

  Future<ReferralRuleModel> createReferralRule({
    required String icon,
    required String title,
    required String body,
    required int order,
    required bool isActive,
  }) async {
    final res = await _dio.post(ApiConstants.referralRules, data: {
      'icon': icon,
      'title': title,
      'body': body,
      'order': order,
      'is_active': isActive,
    });
    return ReferralRuleModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<ReferralRuleModel> updateReferralRule(
    int id, {
    required String icon,
    required String title,
    required String body,
    required int order,
    required bool isActive,
  }) async {
    final res = await _dio.patch(ApiConstants.referralRuleDetail(id), data: {
      'icon': icon,
      'title': title,
      'body': body,
      'order': order,
      'is_active': isActive,
    });
    return ReferralRuleModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteReferralRule(int id) async {
    await _dio.delete(ApiConstants.referralRuleDetail(id));
  }
}

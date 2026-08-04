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

  // Keeps a leading '+' (if present) and strips everything but digits, so
  // "+91 987-654-3210" (a plausible, UI-encouraged input) becomes
  // "+919876543210" — matching the backend's `^\+?[0-9]{10,15}$`.
  String _normalizePhone(String phone) {
    final trimmed = phone.trim();
    final hasPlus = trimmed.startsWith('+');
    final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
    return hasPlus ? '+$digitsOnly' : digitsOnly;
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
    // The dialog's own validator (and its "+91 9876543210" hint text) accepts
    // spaces/dashes/parens/dots, but the backend's ReferralSubmitSerializer
    // (-> CandidateCreateSerializer.validate_phone) only accepts an optional
    // leading '+' followed by 10-15 digits — no separators at all. Sending
    // the raw, human-formatted text as-typed therefore 400s on the very
    // input the UI encourages. Strip everything except a leading '+' and
    // digits so a normally-formatted number still passes backend validation.
    final normalizedPhone = phone == null ? null : _normalizePhone(phone);
    final body = <String, dynamic>{
      'name': name,
      'email': email,
      'position_applied': positionApplied,
      if (normalizedPhone != null && normalizedPhone.isNotEmpty) 'phone': normalizedPhone,
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

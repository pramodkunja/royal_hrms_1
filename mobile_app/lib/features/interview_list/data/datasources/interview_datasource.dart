import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/candidate_model.dart';

class InterviewDataSource {
  final Dio _dio;
  InterviewDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic>) {
      return body['data'] ?? body;
    }
    return body;
  }

  Future<CandidateStatsModel> fetchStats() async {
    final res = await _dio.get(ApiConstants.candidateStats);
    return CandidateStatsModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<List<CandidateModel>> fetchCandidates({
    String? status,
    int? branchId,
  }) async {
    final params = <String, dynamic>{'page_size': 100};
    if (status != null && status != 'all') params['status'] = status;
    if (branchId != null) params['branch'] = branchId;

    final res = await _dio.get(ApiConstants.candidates,
        queryParameters: params);
    final data = _unwrap(res.data);
    final results = (data is Map<String, dynamic>
            ? data['results']
            : data) as List<dynamic>;
    return results
        .map((e) => CandidateModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CandidateModel> fetchCandidate(int id) async {
    final res = await _dio.get(ApiConstants.candidateDetail(id));
    return CandidateModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<CandidateModel> createCandidate(
      Map<String, dynamic> data) async {
    final res = await _dio.post(ApiConstants.candidates, data: data);
    return CandidateModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<CandidateModel> updateStatus(int id, String status) async {
    final res = await _dio.patch(
      ApiConstants.candidateStatus(id),
      data: {'status': status},
    );
    return CandidateModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> sendPortalLogin(int id) async {
    await _dio.post(ApiConstants.candidateSendLogin(id));
  }

  Future<void> resendPortalLogin(int id) async {
    await _dio.post(ApiConstants.candidateResendLogin(id));
  }
}

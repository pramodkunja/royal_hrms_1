import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/email_log_models.dart';

class EmailLogRemoteDataSource {
  final Dio _dio;
  EmailLogRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  // GET /recruitment/emails/ — read-only, company-wide candidate-email audit
  // log, gated server-side on the recruitment.view permission (403 if the
  // caller lacks it). `search` matches candidate name OR recipient email
  // only — there is no status/date/type filter on the backend (see
  // CandidateEmailLogView.get, apps/recruitment/views.py).
  Future<EmailLogPageModel> fetchEmailLogs({
    int page = 1,
    int pageSize = 20,
    String? search,
  }) async {
    final params = <String, dynamic>{'page': page, 'page_size': pageSize};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res =
        await _dio.get(ApiConstants.emailLogs, queryParameters: params);
    return EmailLogPageModel.fromJson(_unwrap(res.data));
  }
}

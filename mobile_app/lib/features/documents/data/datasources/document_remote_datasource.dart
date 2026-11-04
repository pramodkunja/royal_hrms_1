import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/document_model.dart';
import '../models/policy_ack_models.dart';

class DocumentRemoteDataSource {
  final Dio _dio;
  DocumentRemoteDataSource(this._dio);

  Future<DocumentStatsModel> fetchStats() async {
    final res = await _dio.get(ApiConstants.documentStats);
    final data = _unwrap(res.data);
    return DocumentStatsModel.fromJson(data as Map<String, dynamic>);
  }

  Future<List<DocumentModel>> fetchDocuments({
    String? category,
    String? search,
    int page = 1,
    int pageSize = 50,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (category != null && category != 'all') params['category'] = category;
    if (search != null && search.isNotEmpty) params['search'] = search;

    final res = await _dio.get(
      ApiConstants.documents,
      queryParameters: params,
    );
    final data = _unwrap(res.data);
    List<dynamic> results;
    if (data is Map<String, dynamic>) {
      results = data['results'] as List<dynamic>? ?? [];
    } else if (data is List) {
      results = data;
    } else {
      results = [];
    }
    return results
        .map((item) => DocumentModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<DocumentModel> createDocument({
    required String filePath,
    required String fileName,
    required String title,
    required String description,
    required String category,
    bool requiresAcknowledgement = false,
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'title': title,
      'description': description,
      'category': category,
      // As web: only sent when ticked (the server defaults to false).
      if (requiresAcknowledgement) 'requires_acknowledgement': 'true',
    });
    final res = await _dio.post(
      ApiConstants.documents,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return DocumentModel.fromJson(
      _unwrap(res.data) as Map<String, dynamic>,
    );
  }

  Future<void> deleteDocument(int id) async {
    await _dio.delete(ApiConstants.documentDetail(id));
  }

  // ── Policy acknowledgement (contract in policy_ack_models.dart) ──────────
  // Failures are rethrown as the app's typed exceptions, which keep the
  // server's message and status code (409 = a newer version exists).

  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw parseDioException(e);
    }
  }

  Future<List<PendingAcknowledgement>> fetchPendingAcknowledgements() => _call(() async {
        final res = await _dio.get(ApiConstants.documentPendingAcknowledgements);
        final data = _unwrap(res.data);
        return (data is List ? data : const [])
            .whereType<Map>()
            .map((e) => PendingAcknowledgement.fromJson(e.cast<String, dynamic>()))
            .toList();
      });

  Future<DocumentModel> fetchDocument(int id) => _call(() async {
        final res = await _dio.get(ApiConstants.documentDetail(id));
        return DocumentModel.fromJson((_unwrap(res.data) as Map).cast<String, dynamic>());
      });

  /// Returns acknowledged_at from the server.
  Future<String> acknowledge(int id, int version) => _call(() async {
        final res = await _dio.post(ApiConstants.documentAcknowledge(id), data: {'version': version});
        final data = _unwrap(res.data);
        return data is Map && data['acknowledged_at'] != null ? '${data['acknowledged_at']}' : '';
      });

  Future<AckReport> fetchAcknowledgementReport(int id) => _call(() async {
        final res = await _dio.get(ApiConstants.documentAcknowledgements(id));
        return AckReport.fromJson((_unwrap(res.data) as Map).cast<String, dynamic>());
      });

  Future<DocumentModel> setRequiresAcknowledgement(int id, bool value) => _call(() async {
        final res = await _dio.patch(ApiConstants.documentDetail(id), data: {'requires_acknowledgement': value});
        return DocumentModel.fromJson((_unwrap(res.data) as Map).cast<String, dynamic>());
      });

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}

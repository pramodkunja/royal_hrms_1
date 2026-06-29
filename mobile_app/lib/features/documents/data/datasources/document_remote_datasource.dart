import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/document_model.dart';

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
  }) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      'title': title,
      'description': description,
      'category': category,
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

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}

import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/onboarding_model.dart';

class OnboardingDatasource {
  const OnboardingDatasource(this._dio);

  final Dio _dio;

  Future<OnboardingProfileModel> fetchProfile({String status = 'pending'}) async {
    final results = await Future.wait([
      _dio.get(ApiConstants.onboardingProfile),
      fetchDocuments(),
    ]);
    final response = results[0] as Response;
    final documents = results[1] as List<OnboardingDocModel>;
    return OnboardingProfileModel.fromJson(
      response.data as Map<String, dynamic>,
      status: status,
      documents: documents,
    );
  }

  Future<void> saveStep(int step, Map<String, dynamic> data) async {
    try {
      await _dio.patch(ApiConstants.onboardingStep(step), data: data);
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map && responseData['message'] is String) {
        throw Exception(responseData['message'] as String);
      }
      rethrow;
    }
  }

  Future<List<OnboardingDocModel>> fetchDocuments() async {
    final response = await _dio.get(ApiConstants.onboardingDocuments);
    final body = response.data;
    final data = body is Map && body.containsKey('data') ? body['data'] : body;
    return (data as List<dynamic>? ?? [])
        .map((d) => OnboardingDocModel.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<OnboardingDocModel> uploadDocument(
      String docType, MultipartFile file) async {
    try {
      final formData = FormData.fromMap({
        'document_type': docType,
        'file': file,
      });
      final response = await _dio.post(
        ApiConstants.onboardingDocuments,
        data: formData,
      );
      final data = response.data is Map &&
              (response.data as Map).containsKey('data')
          ? response.data['data'] as Map<String, dynamic>
          : response.data as Map<String, dynamic>;
      return OnboardingDocModel.fromJson(data);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        throw Exception(data['message'] as String);
      }
      rethrow;
    }
  }

  Future<void> deleteDocument(int id) async {
    await _dio.delete(ApiConstants.onboardingDocumentDetail(id));
  }

  Future<void> submitProfile() async {
    try {
      await _dio.post(ApiConstants.onboardingProfile);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        throw Exception(data['message'] as String);
      }
      rethrow;
    }
  }
}

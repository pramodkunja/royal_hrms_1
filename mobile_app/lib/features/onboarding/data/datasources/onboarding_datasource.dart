import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/onboarding_model.dart';

class OnboardingDatasource {
  const OnboardingDatasource(this._dio);

  final Dio _dio;

  Future<OnboardingProfileModel> fetchProfile() async {
    final response = await _dio.get(ApiConstants.onboardingProfile);
    return OnboardingProfileModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<void> saveStep(int step, Map<String, dynamic> data) async {
    await _dio.patch(ApiConstants.onboardingStep(step), data: data);
  }

  Future<OnboardingDocModel> uploadDocument(
      String docType, MultipartFile file) async {
    final formData = FormData.fromMap({
      'doc_type': docType,
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
  }

  Future<void> deleteDocument(int id) async {
    await _dio.delete(ApiConstants.onboardingDocumentDetail(id));
  }

  Future<void> submitProfile() async {
    await _dio.post(ApiConstants.onboardingSubmit);
  }
}

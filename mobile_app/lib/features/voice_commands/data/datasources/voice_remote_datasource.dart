import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/voice_result_model.dart';

class VoiceRemoteDataSource {
  final Dio _dio;
  VoiceRemoteDataSource(this._dio);

  Future<VoiceResultModel> parse({
    required String transcript,
    String lang = 'en',
    double? latitude,
    double? longitude,
  }) async {
    final res = await _dio.post(ApiConstants.voiceParse, data: {
      'transcript': transcript,
      'lang': lang,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    });
    final body = res.data;
    final data = body is Map && body['data'] != null ? body['data'] : body;
    return VoiceResultModel.fromJson(data as Map<String, dynamic>);
  }
}

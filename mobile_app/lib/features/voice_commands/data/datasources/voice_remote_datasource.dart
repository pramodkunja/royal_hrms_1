import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/voice_result_model.dart';
import '../models/voice_transcribe_fallback_model.dart';

class VoiceRemoteDataSource {
  final Dio _dio;
  VoiceRemoteDataSource(this._dio);

  // stt_language_probability/stt_used_language_hint/stt_detected_language
  // are ONLY meaningful (and must ONLY be sent) alongside a transcript that
  // came back from transcribeFallback() below — see
  // apps/voice_commands/views.py's VoiceParseView docstring: each is
  // documented as "sent only alongside a transcript that came from the
  // Sarvam-STT retry". They are never populated from on-device
  // speech_to_text's own recognition confidence, which is a different
  // signal (word-recognition confidence, not language-detection
  // confidence) backend has no field for and never asked for.
  // face_embedding/liveness_passed/liveness_score/capture_session_id are the
  // same kind of optional, clock_in/clock_out-only payload as latitude/
  // longitude — carried only on the resubmit that follows the "Taking
  // facial proof" turn (apps/voice_commands/conversation_clock_in_face.py's
  // AWAITING_FACE_PROOF_STAGE). Every other intent ignores them untouched.
  Future<VoiceResultModel> parse({
    required String transcript,
    String lang = 'en',
    double? latitude,
    double? longitude,
    List<double>? faceEmbedding,
    bool? livenessPassed,
    double? livenessScore,
    String? captureSessionId,
    double? sttLanguageProbability,
    bool? sttUsedLanguageHint,
    String? sttDetectedLanguage,
  }) async {
    final res = await _dio.post(ApiConstants.voiceParse, data: {
      'transcript': transcript,
      'lang': lang,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (faceEmbedding != null) 'face_embedding': faceEmbedding,
      if (livenessPassed != null) 'liveness_passed': livenessPassed,
      if (livenessScore != null) 'liveness_score': livenessScore,
      if (captureSessionId != null && captureSessionId.isNotEmpty)
        'capture_session_id': captureSessionId,
      if (sttLanguageProbability != null) 'stt_language_probability': sttLanguageProbability,
      if (sttUsedLanguageHint != null) 'stt_used_language_hint': sttUsedLanguageHint,
      if (sttDetectedLanguage != null) 'stt_detected_language': sttDetectedLanguage,
    });
    final body = res.data;
    final data = body is Map && body['data'] != null ? body['data'] : body;
    return VoiceResultModel.fromJson(data as Map<String, dynamic>);
  }

  // POST /voice/transcribe-fallback/ — multipart, field name "audio" (backend
  // apps/voice_commands/views_transcribe.py: request.FILES.get('audio')).
  // contentType must be one of audio/webm, audio/ogg, audio/wav, audio/x-wav
  // (backend's _ALLOWED_CONTENT_TYPES whitelist) or the request is rejected
  // with 422 before Sarvam is ever called.
  Future<VoiceTranscribeFallbackModel> transcribeFallback({
    required Uint8List audioBytes,
    String filename = 'clip.wav',
    String contentType = 'audio/wav',
  }) async {
    final parts = contentType.split('/');
    final formData = FormData.fromMap({
      'audio': MultipartFile.fromBytes(
        audioBytes,
        filename: filename,
        contentType: DioMediaType(parts[0], parts.length > 1 ? parts[1] : 'wav'),
      ),
    });
    // 25s, matching frontend/lib/voiceSttFallback.ts's own override of this
    // endpoint's timeout — a real Sarvam STT call has been observed taking
    // 12+ seconds server-side alone (see that file's comment), well past
    // this app's normal 30s connect/receive defaults' safety margin for a
    // multi-step upload + upstream call + response chain.
    final res = await _dio.post(
      ApiConstants.voiceTranscribeFallback,
      data: formData,
      options: Options(
        sendTimeout: const Duration(seconds: 25),
        receiveTimeout: const Duration(seconds: 25),
      ),
    );
    final body = res.data;
    final data = body is Map && body['data'] != null ? body['data'] : body;
    return VoiceTranscribeFallbackModel.fromJson(data as Map<String, dynamic>);
  }

  // POST /voice/speak/ — JSON in, raw audio/wav bytes out on success (NOT
  // the {success, message, data} envelope every other endpoint in this app
  // uses — see apps/voice_commands/views_speak.py's own docstring for why).
  // On failure the backend falls back to the normal JSON error envelope, so
  // responseType.bytes means Dio hands back the *raw* error body too — decode
  // it back into a Map before rethrowing so the shared parseDioException()
  // helper (which expects error.response.data to already be JSON) still
  // works unchanged for callers.
  Future<Uint8List> speak({required String text, required String languageCode}) async {
    try {
      final res = await _dio.post(
        ApiConstants.voiceSpeak,
        data: {'text': text, 'language_code': languageCode},
        options: Options(
          responseType: ResponseType.bytes,
          // 20s, matching frontend/lib/voiceTts.ts's own SPEAK_TIMEOUT_MS —
          // sized with margin above the backend's own 15s Sarvam TTS budget.
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 20),
        ),
      );
      return Uint8List.fromList(res.data as List<int>);
    } on DioException catch (e) {
      throw _withDecodedErrorBody(e);
    }
  }

  DioException _withDecodedErrorBody(DioException e) {
    final raw = e.response?.data;
    if (raw is! List<int> || e.response == null) return e;
    try {
      final decoded = jsonDecode(utf8.decode(raw));
      if (decoded is! Map<String, dynamic>) return e;
      return DioException(
        requestOptions: e.requestOptions,
        response: Response(
          requestOptions: e.response!.requestOptions,
          data: decoded,
          statusCode: e.response!.statusCode,
          statusMessage: e.response!.statusMessage,
          headers: e.response!.headers,
        ),
        type: e.type,
        error: e.error,
      );
    } catch (_) {
      return e; // Not a decodable JSON body — surface the original error as-is.
    }
  }
}

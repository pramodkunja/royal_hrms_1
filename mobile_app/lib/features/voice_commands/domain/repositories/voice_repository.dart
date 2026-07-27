import '../entities/voice_result_entity.dart';

abstract class VoiceRepository {
  /// One round trip to POST /api/voice/parse/ — used both for the original
  /// utterance and, when needed, the silent geolocation retry resubmit
  /// (same transcript and lang, coordinates added the second time only).
  Future<VoiceResultEntity> parse({
    required String transcript,
    String lang = 'en',
    double? latitude,
    double? longitude,
  });
}

import 'dart:typed_data';

import '../../domain/entities/voice_result_entity.dart';
import '../../domain/entities/voice_transcribe_fallback_entity.dart';
import '../../domain/repositories/voice_repository.dart';
import '../datasources/voice_remote_datasource.dart';

class VoiceRepositoryImpl implements VoiceRepository {
  final VoiceRemoteDataSource _ds;
  VoiceRepositoryImpl(this._ds);

  @override
  Future<VoiceResultEntity> parse({
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
  }) =>
      _ds.parse(
        transcript: transcript,
        lang: lang,
        latitude: latitude,
        longitude: longitude,
        faceEmbedding: faceEmbedding,
        livenessPassed: livenessPassed,
        livenessScore: livenessScore,
        captureSessionId: captureSessionId,
        sttLanguageProbability: sttLanguageProbability,
        sttUsedLanguageHint: sttUsedLanguageHint,
        sttDetectedLanguage: sttDetectedLanguage,
      );

  @override
  Future<VoiceTranscribeFallbackEntity> transcribeFallback({
    required Uint8List audioBytes,
    String filename = 'clip.wav',
    String contentType = 'audio/wav',
  }) =>
      _ds.transcribeFallback(audioBytes: audioBytes, filename: filename, contentType: contentType);

  @override
  Future<Uint8List> speak({required String text, required String languageCode}) =>
      _ds.speak(text: text, languageCode: languageCode);
}

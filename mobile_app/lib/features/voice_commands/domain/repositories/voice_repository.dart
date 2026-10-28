import 'dart:typed_data';

import '../entities/voice_result_entity.dart';
import '../entities/voice_transcribe_fallback_entity.dart';

abstract class VoiceRepository {
  /// One round trip to POST /api/voice/parse/ — used for the original
  /// utterance, the silent geolocation retry resubmit (same transcript and
  /// lang, coordinates added the second time only), the facial-proof
  /// resubmit (a captured embedding/liveness result, for clock_in/
  /// clock_out's AWAITING_FACE_PROOF_STAGE), and the Hindi-STT fallback
  /// resubmit (a Sarvam-produced transcript plus the stt_* hint fields —
  /// see transcribeFallback).
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
  });

  /// One round trip to POST /api/voice/transcribe-fallback/ — the "maybe
  /// that was Hindi, not garbled English" retry, called only after a
  /// voice-sourced transcript already round-tripped through [parse] and
  /// came back as a final no_match.
  Future<VoiceTranscribeFallbackEntity> transcribeFallback({
    required Uint8List audioBytes,
    String filename = 'clip.wav',
    String contentType = 'audio/wav',
  });

  /// One round trip to POST /api/voice/speak/ — returns raw audio/wav bytes
  /// synthesized from [text] in the given Sarvam language code ('en-IN' /
  /// 'hi-IN').
  Future<Uint8List> speak({required String text, required String languageCode});
}

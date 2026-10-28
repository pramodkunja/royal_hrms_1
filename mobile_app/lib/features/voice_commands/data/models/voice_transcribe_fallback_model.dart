import '../../domain/entities/voice_transcribe_fallback_entity.dart';

class VoiceTranscribeFallbackModel extends VoiceTranscribeFallbackEntity {
  const VoiceTranscribeFallbackModel({
    required super.transcript,
    super.languageProbability,
    required super.wasLanguageHinted,
    required super.detectedLanguage,
  });

  // json is the inner `data` object — apps/voice_commands/views_transcribe.py
  // VoiceTranscribeFallbackView.post() returns success('Transcribed.', result)
  // where result is sarvam_client.transcribe_audio()'s own dict plus
  // detected_language appended.
  factory VoiceTranscribeFallbackModel.fromJson(Map<String, dynamic> json) {
    return VoiceTranscribeFallbackModel(
      transcript: json['transcript'] as String? ?? '',
      languageProbability: (json['language_probability'] as num?)?.toDouble(),
      wasLanguageHinted: json['was_language_hinted'] as bool? ?? false,
      detectedLanguage: json['detected_language'] as String? ?? 'en',
    );
  }
}

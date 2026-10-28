// Mirrors backend apps/voice_commands/views_transcribe.py's response `data`
// and frontend/lib/voiceSttFallback.ts's TranscribeFallbackResult — the
// result of the Hindi-STT retry (POST /voice/transcribe-fallback/), called
// only after an on-device transcript has already round-tripped through
// /voice/parse/ and come back as a final no_match (see
// VoiceCommandController's own doc comment for the exact trigger).
class VoiceTranscribeFallbackEntity {
  final String transcript;
  // Sarvam's own confidence in which language it heard — null whenever the
  // successful attempt used an explicit hint (see wasLanguageHinted; a
  // hinted call never gets a probability back from Sarvam at all).
  final double? languageProbability;
  // True whenever this succeeded at all — both retry tiers (hi-IN, then
  // en-IN) always pass an explicit hint now.
  final bool wasLanguageHinted;
  // 'en' | 'hi' — which of the two hint tiers actually produced this
  // transcript; the accurate signal, preferred over wasLanguageHinted alone
  // when forwarding to /voice/parse/ as stt_detected_language.
  final String detectedLanguage;

  const VoiceTranscribeFallbackEntity({
    required this.transcript,
    this.languageProbability,
    required this.wasLanguageHinted,
    required this.detectedLanguage,
  });
}

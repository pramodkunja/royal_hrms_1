// Mirrors backend apps/voice_commands/conversation.py::_payload() and
// frontend/types/voice.ts's VoiceParseResult exactly — see
// apps/voice_commands/registry/intents_en.yaml for the full intent list.
class VoiceResultEntity {
  final String intent;
  final double? confidence;
  final dynamic result;
  final String message;
  // The redacted stand-in for `message` that TTS should speak instead of the
  // full text whenever the response carries confidentiality-sensitive content
  // (e.g. another employee's leave/salary details) — `message` itself is
  // still what the panel displays. Null/empty means speak `message` as-is.
  final String? speechMessage;
  // Property of the INTENT itself (true for apply_leave/approve_leave/
  // reject_leave on every one of their responses), not of this one turn.
  final bool conversational;
  // True only when THIS response is a clarification question expecting a
  // follow-up answer — conversation state itself lives server-side (Redis,
  // 120s sliding TTL); the client tracks nothing beyond this flag.
  final bool awaitingInput;
  // Whether the recognized intent's own action succeeded — false for a
  // terminal negative outcome (no-match, a rejected clock_in/out, permission
  // denied), true for a normal mid-dialogue continuation too.
  final bool success;
  // 'en' | 'hi' — which language backend used for this response's
  // message/speech_message (apps/voice_commands/language.py's
  // get_current_language(), set ambiently per-request from
  // stt_used_language_hint/stt_detected_language). Drives the language_code
  // this app sends to POST /voice/speak/ for the spoken reply — never
  // decided client-side, always this backend-reported value.
  final String language;

  const VoiceResultEntity({
    required this.intent,
    required this.confidence,
    required this.result,
    required this.message,
    this.speechMessage,
    required this.conversational,
    required this.awaitingInput,
    required this.success,
    required this.language,
  });
}

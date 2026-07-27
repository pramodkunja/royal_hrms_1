// Mirrors backend apps/voice_commands/conversation.py::_payload() and
// frontend/types/voice.ts's VoiceParseResult exactly — see
// apps/voice_commands/registry/intents_en.yaml for the full intent list.
class VoiceResultEntity {
  final String intent;
  final double? confidence;
  final dynamic result;
  final String message;
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

  const VoiceResultEntity({
    required this.intent,
    required this.confidence,
    required this.result,
    required this.message,
    required this.conversational,
    required this.awaitingInput,
    required this.success,
  });
}

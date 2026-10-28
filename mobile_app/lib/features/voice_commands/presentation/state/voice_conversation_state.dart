// Mirrors frontend/hooks/useVoiceCommand.ts's VoiceConversationState /
// VoicePanelPhase / VoiceResultStatus.

/// "listening": mic capturing speech. "typing": composing a fresh command by
/// text instead of speech (the keyboard-badge entry point next to the mic
/// bubble — a typed-fallback alternative to speaking, same idea as the web
/// app's keyboard-icon toggle, left as this app's own UI/UX call). "transcript":
/// recognized/typed text shown while the request is in flight. "retrying": an
/// automatic, backend-driven second capture after a voice-sourced transcript
/// came back as a final no_match — see VoiceCommandController's Hindi-STT
/// fallback (POST /voice/transcribe-fallback/); distinct from "listening" so
/// the panel can explain why the mic reopened without any tap. "faceProof":
/// backend responded to a clock_in/clock_out with AWAITING_FACE_PROOF_STAGE
/// (apps/voice_commands/conversation_clock_in_face.py) — the existing
/// facial_recognition capture sheet is about to open (or has just closed
/// pending its result); distinct from "result" so the panel doesn't show the
/// normal "Answer by voice / type an answer" controls, which make no sense
/// for a camera step. "result": a response has come back — either the next
/// turn of a conversational dialogue, or the final answer.
enum VoicePanelPhase { listening, typing, transcript, retrying, faceProof, result }

enum VoiceResultStatus { success, error }

class VoiceConversationState {
  final String transcript;
  final String interimTranscript;
  final String message;
  final VoicePanelPhase phase;
  final bool conversational;
  final bool awaitingInput;
  final bool isProcessing;
  // Only meaningful once phase is `result`. "error" covers both a failed
  // request itself and a recognized command the backend rejected (permission
  // denied, a geofencing rejection that survived the retry, etc.).
  final VoiceResultStatus? resultStatus;
  // The raw `data.result` payload from the backend envelope (see
  // conversation.py's _payload) — intent-specific, e.g. a payslip's
  // gross/net/status fields for check_my_payslip/check_employee_payslip.
  // Most intents' UI needs nothing beyond `message`; this exists only so a
  // result view (see PayslipSummaryCard) can render a richer summary when
  // the shape is recognized, without the controller needing to know about
  // any particular intent.
  final dynamic result;
  // 'en' | 'hi' — only meaningful once phase is `result`; backend-reported
  // (VoiceResultEntity.language), never inferred client-side. Drives the
  // small language badge the result view shows for a Hindi reply (see
  // VoiceConversationPanel) — omitted for English since that's the
  // overwhelming common case and a badge on every single result would just
  // be noise.
  final String language;

  const VoiceConversationState({
    this.transcript = '',
    this.interimTranscript = '',
    this.message = '',
    this.phase = VoicePanelPhase.listening,
    this.conversational = false,
    this.awaitingInput = false,
    this.isProcessing = false,
    this.resultStatus,
    this.result,
    this.language = 'en',
  });

  VoiceConversationState copyWith({
    String? transcript,
    String? interimTranscript,
    String? message,
    VoicePanelPhase? phase,
    bool? conversational,
    bool? awaitingInput,
    bool? isProcessing,
    VoiceResultStatus? resultStatus,
    dynamic result,
    String? language,
  }) {
    return VoiceConversationState(
      transcript: transcript ?? this.transcript,
      interimTranscript: interimTranscript ?? this.interimTranscript,
      message: message ?? this.message,
      phase: phase ?? this.phase,
      conversational: conversational ?? this.conversational,
      awaitingInput: awaitingInput ?? this.awaitingInput,
      isProcessing: isProcessing ?? this.isProcessing,
      resultStatus: resultStatus ?? this.resultStatus,
      result: result ?? this.result,
      language: language ?? this.language,
    );
  }
}

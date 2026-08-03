// Mirrors frontend/hooks/useVoiceCommand.ts's VoiceConversationState /
// VoicePanelPhase / VoiceResultStatus.

/// "listening": mic capturing speech. "typing": composing a fresh command by
/// text instead of speech (the keyboard-badge entry point next to the mic
/// bubble — a typed-fallback alternative to speaking, same idea as the web
/// app's keyboard-icon toggle, left as this app's own UI/UX call). "transcript":
/// recognized/typed text shown while the request is in flight. "result": a
/// response has come back — either the next turn of a conversational
/// dialogue, or the final answer.
enum VoicePanelPhase { listening, typing, transcript, result }

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
    );
  }
}

// Mirrors frontend/hooks/useVoiceCommand.ts's VoiceConversationState /
// VoicePanelPhase / VoiceResultStatus.

/// "listening": mic capturing speech. "transcript": recognized speech shown
/// while the request is in flight. "result": a response has come back —
/// either the next turn of a conversational dialogue, or the final answer.
enum VoicePanelPhase { listening, transcript, result }

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

  const VoiceConversationState({
    this.transcript = '',
    this.interimTranscript = '',
    this.message = '',
    this.phase = VoicePanelPhase.listening,
    this.conversational = false,
    this.awaitingInput = false,
    this.isProcessing = false,
    this.resultStatus,
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
    );
  }
}

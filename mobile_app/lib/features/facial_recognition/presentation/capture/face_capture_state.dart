// One capture engine shared by self-registration, HR-assisted registration,
// and clock-in verification — all three just need "get me a liveness-checked
// photo and its server-computed embedding", nothing else differs between them.
enum FaceCapturePhase {
  idle,
  // Flutter Web has no ML Kit implementation at all (google_mlkit_face_detection
  // is Android/iOS-only) — checked up front, before touching the camera, so
  // browser sessions get a clear message instead of a camera preview that
  // hangs forever because face detection can never actually run.
  unsupportedPlatform,
  initializingCamera,
  cameraDenied,
  detecting,
  livenessChecking,
  livenessFailed,
  extractingEmbedding,
  // The one-shot lighting/eye-occlusion check on the captured still photo
  // failed (mirrors web's "quality_failed" phase in useFaceLivenessCapture.ts)
  // — distinct from `error`: this is an ordinary, expected, retryable outcome
  // (reposition/relight and try again), not something actually broken.
  qualityFailed,
  ready,
  error,
}

class FaceCaptureUiState {
  final FaceCapturePhase phase;
  final String? message;
  final List<double>? embedding;
  final bool livenessPassed;
  final double? livenessScore;
  final String captureSessionId;
  // Live, continuously-updating framing feedback set by the pre-liveness
  // face-count/distance/frontality checks (e.g. "Move closer") — only
  // meaningful while phase is `detecting`; null means "nothing to correct
  // right now", so the caller shows its own static instruction text instead.
  // Distinct from `message`, which is a one-shot result set on a phase
  // transition (error/qualityFailed/livenessFailed) — this instead tracks a
  // live signal that can freely flip back to null as framing improves,
  // without ever changing `phase` itself (see face_capture_controller.dart's
  // _handleFaces).
  final String? liveHint;

  const FaceCaptureUiState({
    this.phase = FaceCapturePhase.idle,
    this.message,
    this.embedding,
    this.livenessPassed = false,
    this.livenessScore,
    this.captureSessionId = '',
    this.liveHint,
  });

  FaceCaptureUiState copyWith({
    FaceCapturePhase? phase,
    String? message,
    List<double>? embedding,
    bool? livenessPassed,
    double? livenessScore,
    String? captureSessionId,
    String? liveHint,
  }) {
    return FaceCaptureUiState(
      phase: phase ?? this.phase,
      message: message,
      embedding: embedding ?? this.embedding,
      livenessPassed: livenessPassed ?? this.livenessPassed,
      livenessScore: livenessScore ?? this.livenessScore,
      captureSessionId: captureSessionId ?? this.captureSessionId,
      liveHint: liveHint,
    );
  }
}

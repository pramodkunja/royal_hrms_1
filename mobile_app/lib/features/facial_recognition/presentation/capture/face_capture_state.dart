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

  const FaceCaptureUiState({
    this.phase = FaceCapturePhase.idle,
    this.message,
    this.embedding,
    this.livenessPassed = false,
    this.livenessScore,
    this.captureSessionId = '',
  });

  FaceCaptureUiState copyWith({
    FaceCapturePhase? phase,
    String? message,
    List<double>? embedding,
    bool? livenessPassed,
    double? livenessScore,
    String? captureSessionId,
  }) {
    return FaceCaptureUiState(
      phase: phase ?? this.phase,
      message: message,
      embedding: embedding ?? this.embedding,
      livenessPassed: livenessPassed ?? this.livenessPassed,
      livenessScore: livenessScore ?? this.livenessScore,
      captureSessionId: captureSessionId ?? this.captureSessionId,
    );
  }
}

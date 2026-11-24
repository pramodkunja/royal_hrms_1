import 'dart:io';
import 'dart:ui' as ui;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:uuid/uuid.dart';

import 'package:image/image.dart' as img;

import '../../face_api/face_api_image.dart';
import '../../face_api/face_api_nets.dart';
import '../../face_api/face_api_pipeline.dart';
import 'face_capture_geometry.dart';
import 'face_capture_state.dart';
import 'face_embedding_model.dart';
import 'liveness_tracker.dart';

// How many consecutive single-face frames are required before the liveness
// challenge starts, and how long the challenge itself has to complete —
// mirrors the shape (not the exact numbers-source) of the web's
// useFaceLivenessCapture.ts, adapted to ML Kit's built-in signals instead of
// hand-computed eye-aspect-ratio from 68 landmarks.
const _kStableFramesToStart = 10;
const _kLivenessTimeout = Duration(milliseconds: 9000);

// ─── Pre-capture quality checks (FR-2) ─────────────────────────────────────
// Five signals gating a doomed capture before it ever reaches the backend —
// UX only, never a substitute for backend's own liveness/embedding
// verification (see FaceVerificationService.verify_for_punch). Thresholds
// are ported from frontend/lib/faceApi/qualityGate.ts and frameCapture.ts
// wherever the underlying signal is the same shape; two are NOT literal
// ports because the signal itself differs in kind, not just in value — see
// each constant's own comment.

// Distance/size — IDENTICAL signal to web's faceWidthRatio (bounding-box
// width / frame width), so these are ported verbatim from
// qualityGate.ts's QUALITY_THRESHOLDS.MIN/MAX_FACE_WIDTH_RATIO.
const _kMinFaceWidthRatio = 0.20;
const _kMaxFaceWidthRatio = 0.75;

// Frontality — NOT a literal port of web's MIN_FRONTALITY (0.7). Web's value
// is a dimensionless [0,1] score from computeFrontality() — a landmark-based
// nose-to-eye asymmetry ratio face-api.js's 68 points make possible. ML Kit
// exposes no equivalent landmark set for that formula; the only comparable
// signal here is headEulerAngleY, an absolute yaw in DEGREES — a different
// unit entirely, so "adapt 0.7" has no literal meaning. Chosen instead so
// this sits comfortably below _kHeadTurnDegrees (15°, the liveness
// challenge's deliberate-turn threshold): a frontal-facing bar anywhere near
// 15° would read as "frontal enough" for a pose already halfway into a
// liveness turn, defeating the point of checking frontality before that
// challenge even starts. 12° is a common tolerance in face-alignment
// pipelines for "facing the camera" and leaves clear separation from 15°.
const _kMaxFrontalYawDegrees = 12.0;

const _kMultipleFacesHint = 'Multiple faces detected — make sure only your face is in frame.';
const _kTooFarHint = 'Move closer to the camera.';
const _kTooCloseHint = 'Move back a little.';
const _kNotFrontalHint = 'Face the camera directly.';
const _kNotCenteredHint = 'Centre your face in the oval.';
const _kTooDarkHint = 'Find better lighting — your face looks too dark.';
const _kLostFaceHint = 'Keep your face in the oval.';
const _kDifferentFaceHint = 'A different face was detected — let\'s start the check again.';

// During the liveness window a face may vanish briefly (head turn, blink,
// motion blur). The challenge keeps running through such gaps instead of
// restarting, but only for a bounded wall-clock time, and only for the SAME
// tracked face (see _kDifferentFaceHint).
// Time-based companion to the frame count: the frame rate varies by device
// and load, so continuity is judged in wall-clock time as well.
const _kMaxLostDuringLiveness = Duration(milliseconds: 800);
// UI state for frame-driven updates is published at most this often; camera
// frames arrive far faster than the screen needs to repaint.
const _kUiUpdateInterval = Duration(milliseconds: 100);
// Mean luma (0-255) of the Y plane below which framing is called too dark
// (web readiness.ts uses 50 as its dark floor).
const _kTooDarkLuma = 50.0;
final _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Duration of the one model load of this app session (null until loaded) —
/// a number for the debug diagnostics only.
int? lastFaceModelLoadMs;

/// The face-api.js networks, loaded once per app session (~25 MB of models;
/// web likewise keeps them cached after the first load). Tests override it.
/// CPU threads for the TFLite interpreters. 1 = the library default (what
/// every verified run so far used). Only changed from `main.dart` in a
/// diagnostics (debug/profile) build, to A/B-benchmark on a device before any
/// default is changed.
final faceApiThreadsProvider = Provider<int>((_) => 1);

/// Diagnostics builds only: also run a single-thread copy of the recognition
/// net to measure descriptor equality against the multi-thread one.
final faceApiCompareThreadsProvider = Provider<bool>((_) => false);

/// Diagnostics builds only: on the first still of a run, also decode it with
/// the platform codec and record aggregate pixel differences vs the Dart
/// decoder (numbers only, nothing kept). Never used for recognition.
final faceDecodeCompareProvider = Provider<bool>((_) => false);

final faceApiNetsProvider = FutureProvider<FaceApiNets>((ref) async {
  final sw = Stopwatch()..start();
  final nets = await loadFaceApiNets(
    threads: ref.watch(faceApiThreadsProvider),
    compareThreads: ref.watch(faceApiCompareThreadsProvider),
  );
  lastFaceModelLoadMs = sw.elapsedMilliseconds;
  ref.onDispose(nets.dispose);
  return nets;
});

/// Drives live camera preview + on-device liveness detection (blink or head
/// turn, via ML Kit's face classification/head-angle output) and, once
/// liveness passes, takes [kRegistrationFramesToCapture] /
/// [kVerificationFramesToCapture] stills and runs them through the web app's
/// own face pipeline (face-api.js 0.22.2 networks, CLAHE, quality gate,
/// multi-frame averaging — see face_api/face_api_pipeline.dart), so the
/// descriptor is comparable with web registrations and verifications. The
/// backend has no endpoint that accepts an image.
/// Shared by self-registration, HR-assisted registration, and clock-in
/// verification — none of them need anything beyond "give me a
/// liveness-checked embedding".
class FaceCaptureController extends AutoDisposeNotifier<FaceCaptureUiState> {
  CameraController? _cameraController;
  FaceDetector? _detector;
  int _framesToCapture = kVerificationFramesToCapture;
  int _stableFrames = 0;
  DateTime? _livenessDeadline;
  LivenessMode _livenessMode = LivenessMode.turnOnly;
  LivenessTracker? _liveness;
  bool _processingFrame = false;
  bool _stopped = false;
  DateTime? _lostSince;
  int _session = 0; // bumped on every start/teardown: stale async work checks it
  int _stillMicros = 0, _prepMicros = 0, _analysisMicros = 0;
  int? _livenessStartedMs;
  FaceApiStageTimes _stageTimes = FaceApiStageTimes();
  int _stillsTaken = 0;
  // Framing efficiency counters (aggregate numbers only).
  int _framesReceived = 0, _framesDroppedBusy = 0, _framesProcessed = 0, _noFaceFrames = 0, _multiFaceFrames = 0;
  int _stableResets = 0, _detectMicrosSum = 0, _detectMicrosMax = 0, _gapMicrosSum = 0, _gapMicrosMax = 0;
  int? _lastDetectDoneMicros;
  final Stopwatch _clock = Stopwatch()..start();
  int _firstStillMicros = 0;
  DateTime Function() _now = DateTime.now;
  int? _trackedId;
  final Stopwatch _sinceStart = Stopwatch();
  final Map<String, int> _timings = {};
  DateTime _lastUiEmit = DateTime.fromMillisecondsSinceEpoch(0);
  static CameraDescription? _frontCamera; // chosen once per app session
  double _lastLuma = 128;

  CameraController? get cameraController => _cameraController;

  @override
  FaceCaptureUiState build() {
    ref.onDispose(_teardown);
    return const FaceCaptureUiState();
  }

  /// [framesToCapture]: 4 for registration, 3 for clock-in verification
  /// (web REGISTRATION_/VERIFICATION_FRAMES_TO_CAPTURE).
  /// [livenessMode]: blink AND head turn for registration, head turn for
  /// clock-in verification (web liveness.ts / FaceVerificationModal).
  Future<void> start({int? framesToCapture, LivenessMode? livenessMode}) async {
    if (framesToCapture != null) _framesToCapture = framesToCapture;
    if (livenessMode != null) _livenessMode = livenessMode;
    if (kIsWeb) {
      // Never even touches getUserMedia/camera on web — google_mlkit_face_detection
      // has no web implementation, so face detection could never run even if
      // the camera preview came up, and there is no non-liveness-checked
      // fallback for a security-sensitive feature like this one.
      state = const FaceCaptureUiState(
        phase: FaceCapturePhase.unsupportedPlatform,
        message: 'Face ID capture isn\'t available in a web browser. Please use the '
            'Royal HRMS mobile app on your phone to register or verify your face.',
      );
      return;
    }
    _session++;
    _stillMicros = _prepMicros = _analysisMicros = 0;
    _stillsTaken = 0;
    _framesReceived = _framesDroppedBusy = _framesProcessed = _noFaceFrames = _multiFaceFrames = 0;
    _stableResets = _detectMicrosSum = _detectMicrosMax = _gapMicrosSum = _gapMicrosMax = 0;
    _lastDetectDoneMicros = null;
    _firstStillMicros = 0;
    _stageTimes = FaceApiStageTimes();
    _livenessStartedMs = null;
    _stopped = false;
    _timings.clear();
    _sinceStart
      ..reset()
      ..start();
    state = FaceCaptureUiState(
      phase: FaceCapturePhase.initializingCamera,
      captureSessionId: const Uuid().v4(),
    );
    try {
      // The ~25 MB descriptor models load in parallel with the camera (cached
      // for the app session after the first load), instead of after it.
      ref.read(faceApiNetsProvider.future).ignore();
      var camera = _frontCamera;
      if (camera == null) {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          state = state.copyWith(phase: FaceCapturePhase.error, message: 'No camera available on this device.');
          return;
        }
        camera = _frontCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
      }
      _mark('camera_lookup');
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await _cameraController!.initialize();
      _mark('camera_ready');
      if (_stopped) return;

      _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          // Live framing + liveness only (eye-open probabilities, head
          // angle). The captured frames are analysed by the face-api.js
          // pipeline, with web's own 68-landmark eye-occlusion check.
          performanceMode: FaceDetectorMode.fast,
          // Lets the liveness challenge notice that a DIFFERENT face took
          // over after a gap (see _handleFaces).
          enableTracking: true,
        ),
      );
      state = state.copyWith(phase: FaceCapturePhase.detecting);
      await _cameraController!.startImageStream(_onFrame);
      _mark('stream_started');
    } on CameraException catch (e) {
      state = state.copyWith(
        phase: FaceCapturePhase.cameraDenied,
        message: e.description ?? 'Camera permission is required to continue.',
      );
    } catch (_) {
      state = state.copyWith(phase: FaceCapturePhase.error, message: 'Could not start the camera.');
    }
  }

  Future<void> retry() async {
    await _teardown();
    _stableFrames = 0;
    _lostSince = null;
    _trackedId = null;
    _liveness = null;
    _livenessDeadline = null;
    await start();
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_stopped || _detector == null || _cameraController == null) return;
    if (state.phase != FaceCapturePhase.detecting && state.phase != FaceCapturePhase.livenessChecking) return;
    _framesReceived++;
    if (_processingFrame) {
      _framesDroppedBusy++; // bounded pipeline: a busy detector drops the frame, nothing queues
      return;
    }
    _processingFrame = true;
    try {
      final inputImage = _toInputImage(image, _cameraController!.description);
      if (inputImage == null) return;
      final rotation = inputImage.metadata?.rotation.rawValue ?? 0;
      final upright = uprightSize(Size(image.width.toDouble(), image.height.toDouble()), rotation);
      if (Platform.isAndroid && image.planes.isNotEmpty) _lastLuma = meanLuma(image.planes.first.bytes);
      _mark('first_frame');
      final detectWatch = Stopwatch()..start();
      final faces = await _detector!.processImage(inputImage);
      _mark('first_detection_result');
      final tookUs = detectWatch.elapsedMicroseconds;
      _framesProcessed++;
      _detectMicrosSum += tookUs;
      if (tookUs > _detectMicrosMax) _detectMicrosMax = tookUs;
      final doneUs = _clock.elapsedMicroseconds;
      final last = _lastDetectDoneMicros;
      if (last != null) {
        final gap = doneUs - last;
        _gapMicrosSum += gap;
        if (gap > _gapMicrosMax) _gapMicrosMax = gap;
      }
      _lastDetectDoneMicros = doneUs;
      if (faces.isEmpty) _noFaceFrames++;
      if (faces.length > 1) _multiFaceFrames++;
      if (!_stopped) await _handleFaces(faces, upright);
    } catch (_) {
      // A single failed frame shouldn't abort the whole capture attempt.
    } finally {
      _processingFrame = false;
    }
  }

  @visibleForTesting
  set livenessModeForTest(LivenessMode m) => _livenessMode = m;

  @visibleForTesting
  set clockForTest(DateTime Function() clock) => _now = clock;

  @visibleForTesting
  void expireLivenessForTest() => _livenessDeadline = _now().subtract(const Duration(seconds: 1));

  void _snapshotCounters() {
    final n = _framesProcessed;
    _timings
      ..['frames_received'] = _framesReceived
      ..['frames_processed'] = n
      ..['frames_dropped_busy'] = _framesDroppedBusy
      ..['no_face_frames'] = _noFaceFrames
      ..['multi_face_frames'] = _multiFaceFrames
      ..['stable_resets'] = _stableResets
      ..['detect_mean_ms'] = n == 0 ? 0 : _detectMicrosSum ~/ n ~/ 1000
      ..['detect_max_ms'] = _detectMicrosMax ~/ 1000
      ..['detect_gap_mean_ms'] = n < 2 ? 0 : _gapMicrosSum ~/ (n - 1) ~/ 1000
      ..['detect_gap_max_ms'] = _gapMicrosMax ~/ 1000;
  }

  void _mark(String stage) => _timings.putIfAbsent(stage, () => _sinceStart.elapsedMilliseconds);

  /// Frame-driven updates are throttled; phase changes and hint changes are
  /// published at once so the screen never lags a real transition.
  void _publish(FaceCaptureUiState next) {
    final now = _now();
    var timingsChanged = false;
    if (_timings.length != next.timingsMs.length) {
      next = next.copyWith(liveHint: next.liveHint, message: next.message, timingsMs: Map.of(_timings));
      timingsChanged = true;
    }
    final important = timingsChanged ||
        next.phase != state.phase ||
        next.liveHint != state.liveHint ||
        next.blinkSeen != state.blinkSeen ||
        next.turnSeen != state.turnSeen;
    if (!important && now.difference(_lastUiEmit) < _kUiUpdateInterval) return;
    _lastUiEmit = now;
    state = next;
  }

  /// Test seam: feeds detector output (no camera, no pixels) through the same
  /// framing + liveness logic the live stream uses.
  @visibleForTesting
  Future<void> feedFacesForTest(List<Face> faces, Size upright, {FaceCapturePhase? phase}) {
    _stopped = false;
    if (phase != null) state = state.copyWith(phase: phase);
    return _handleFaces(faces, upright);
  }

  Future<void> _handleFaces(List<Face> faces, Size upright) async {
    final camera = _cameraController;
    final geometry = camera == null
        ? null
        : (
            aspect: portraitPreviewAspect(camera.value.previewSize),
            mirrored: camera.description.lensDirection == CameraLensDirection.front,
          );
    final inLiveness = state.phase == FaceCapturePhase.livenessChecking;

    if (faces.length != 1) {
      if (inLiveness) {
        // Brief loss of the face must not throw the challenge away: keep the
        // tracker and deadline, tell the user what to do, and only fail once
        // the face has been gone for a sustained stretch (or time runs out).
        final lostSince = _lostSince ??= _now();
        if (_livenessExpired()) return _failLiveness();
        _publish(state.copyWith(
          liveHint: faces.length > 1 ? _kMultipleFacesHint : _kLostFaceHint,
          clearFace: true,
          uprightFrame: upright,
          previewAspect: geometry?.aspect,
          mirrored: geometry?.mirrored,
          blinkSeen: _liveness?.blinkSeen,
          turnSeen: _liveness?.turnSeen,
          livenessSecondsLeft: _secondsLeft(),
        ));
        if (_now().difference(lostSince) > _kMaxLostDuringLiveness) {
          // Sustained loss: restart framing (not the whole camera).
          _stableFrames = 0;
          _liveness = null;
          _trackedId = null;
          _lostSince = null;
          _publish(state.copyWith(phase: FaceCapturePhase.detecting, liveHint: _kLostFaceHint, clearFace: true));
        }
        return;
      }
      _stableFrames = 0;
      // "No face" stays silent (mirrors web's classifyDetectedFaceCount); only
      // multiple faces gets a distinct hint.
      _publish(state.copyWith(
        phase: FaceCapturePhase.detecting,
        liveHint: faces.length > 1 ? _kMultipleFacesHint : null,
        clearFace: true,
        uprightFrame: upright,
        previewAspect: geometry?.aspect,
        mirrored: geometry?.mirrored,
      ));
      return;
    }
    _lostSince = null;
    final face = faces.first;
    if (inLiveness && _trackedId != null && face.trackingId != null && face.trackingId != _trackedId) {
      // The face that completed part of the challenge is not the one in front
      // of the camera now: nobody inherits another person's progress.
      _stableFrames = 0;
      _liveness = null;
      _trackedId = null;
      _publish(state.copyWith(
        phase: FaceCapturePhase.detecting,
        liveHint: _kDifferentFaceHint,
        clearFace: true,
        blinkSeen: false,
        turnSeen: false,
      ));
      return;
    }
    final box = face.boundingBox;

    if (state.phase == FaceCapturePhase.detecting) {
      // Distance / centring / frontality / lighting gate this phase only — not
      // livenessChecking, where the head deliberately moves.
      final hint = _liveFramingHint(face, upright);
      if (hint != null) {
        if (_stableFrames > 0) _stableResets++;
        _stableFrames = 0;
        _publish(state.copyWith(
          liveHint: hint,
          faceBox: box,
          uprightFrame: upright,
          previewAspect: geometry?.aspect,
          mirrored: geometry?.mirrored,
        ));
        return;
      }

      _stableFrames++;
      if (_stableFrames >= _kStableFramesToStart) {
        _livenessStartedMs = _sinceStart.elapsedMilliseconds;
        _mark('liveness_started');
        _snapshotCounters();
        _livenessDeadline = _now().add(_kLivenessTimeout);
        final tracker = _liveness = LivenessTracker(_livenessMode);
        _trackedId = face.trackingId;
        tracker.addSample(yaw: face.headEulerAngleY); // facing-the-camera baseline
        _publish(state.copyWith(
          phase: FaceCapturePhase.livenessChecking,
          liveHint: tracker.prompt,
          faceBox: box,
          uprightFrame: upright,
          previewAspect: geometry?.aspect,
          mirrored: geometry?.mirrored,
          blinkRequired: _livenessMode == LivenessMode.blinkAndTurn,
          blinkSeen: false,
          turnSeen: false,
          livenessSecondsLeft: _secondsLeft(),
        ));
      } else {
        _publish(state.copyWith(faceBox: box, uprightFrame: upright, previewAspect: geometry?.aspect, mirrored: geometry?.mirrored));
      }
      return;
    }

    if (inLiveness) {
      final tracker = _liveness;
      if (tracker == null) return;
      tracker.addSample(
        leftEyeOpen: face.leftEyeOpenProbability,
        rightEyeOpen: face.rightEyeOpenProbability,
        yaw: face.headEulerAngleY,
      );
      if (tracker.passed) {
        await _onLivenessPassed(score: tracker.score);
        return;
      }
      if (_livenessExpired()) return _failLiveness();
      _publish(state.copyWith(
        liveHint: tracker.prompt,
        faceBox: box,
        uprightFrame: upright,
        previewAspect: geometry?.aspect,
        mirrored: geometry?.mirrored,
        blinkSeen: tracker.blinkSeen,
        turnSeen: tracker.turnSeen,
        livenessSecondsLeft: _secondsLeft(),
      ));
    }
  }

  bool _livenessExpired() => _livenessDeadline != null && _now().isAfter(_livenessDeadline!);

  int? _secondsLeft() {
    final d = _livenessDeadline;
    if (d == null) return null;
    final ms = d.difference(_now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _failLiveness() {
    state = state.copyWith(
      phase: FaceCapturePhase.livenessFailed,
      message: _liveness?.missingMessage ?? 'Liveness check was not completed. Please try again.',
      blinkSeen: _liveness?.blinkSeen,
      turnSeen: _liveness?.turnSeen,
      clearFace: true,
    );
  }

  /// Distance, centring, frontality, lighting — the live per-frame checks that
  /// gate the pre-liveness `detecting` phase. Only geometry blocks (as on web);
  /// headEulerAngleY null just skips the frontality check for that frame.
  String? _liveFramingHint(Face face, Size upright) {
    if (upright.width <= 0 || upright.height <= 0) return null;
    final widthRatio = faceWidthRatio(face.boundingBox, upright);
    if (widthRatio < _kMinFaceWidthRatio) return _kTooFarHint;
    if (widthRatio > _kMaxFaceWidthRatio) return _kTooCloseHint;

    // Centring against the same oval the user sees (guide is drawn in preview
    // coordinates; the upright image maps onto the preview by pure scale).
    final preview = Size(upright.width, upright.height);
    final guide = guideOval(preview);
    if (!faceCentreInsideGuide(face.boundingBox, guide)) return _kNotCenteredHint;

    final yaw = face.headEulerAngleY;
    if (yaw != null && yaw.abs() > _kMaxFrontalYawDegrees) return _kNotFrontalHint;

    if (_lastLuma < _kTooDarkLuma) return _kTooDarkHint;
    return null;
  }

  Future<void> _onLivenessPassed({required double score}) async {
    if (_stopped) return;
    _stopped = true; // stop reacting to further frames immediately
    final session = _session;
    final started = _livenessStartedMs;
    if (started != null) _timings['liveness_ms'] = _sinceStart.elapsedMilliseconds - started;
    _mark('liveness_passed');
    state = state.copyWith(phase: FaceCapturePhase.extractingEmbedding, livenessPassed: true, livenessScore: score);
    try {
      final stopWatch = Stopwatch()..start();
      await _cameraController?.stopImageStream();
      _timings['stop_stream_ms'] = stopWatch.elapsedMilliseconds;
      final nets = await ref.read(faceApiNetsProvider.future);
      // Cancelled (screen closed / retried) while waiting: drop everything —
      // no stale descriptor, no state write on a disposed notifier.
      if (session != _session) return;
      _mark('nets_ready');
      final outcome = await FaceApiPipeline(nets).capture(
        nextFrame: () => _takeFrame(session),
        framesToCapture: _framesToCapture,
        framesArePrepared: true,
        onAnalysisTime: (us) => _analysisMicros += us,
        isCancelled: () => session != _session,
        times: _stageTimes,
      );
      if (session != _session) return;
      _mark('descriptor_done');
      _snapshotCounters();
      faceApiNumericDiagnostics.forEach((k, v) => _timings[k] = v.toInt());
      _timings['still_capture_total'] = _stillMicros ~/ 1000;
      _timings['preprocess_total'] = _prepMicros ~/ 1000;
      _timings['inference_total'] = _analysisMicros ~/ 1000;
      final t = _stageTimes;
      _timings
        ..['stills_taken'] = _stillsTaken
        ..['still_first'] = _firstStillMicros ~/ 1000
        ..['decode_total'] = t.decodeUs ~/ 1000
        ..['convert_total'] = t.convertUs ~/ 1000
        ..['scale_total'] = t.scaleUs ~/ 1000
        ..['clahe_total'] = t.claheUs ~/ 1000
        ..['detect_total'] = t.detectUs ~/ 1000
        ..['landmarks_total'] = t.landmarksUs ~/ 1000
        ..['describe_total'] = t.describeUs ~/ 1000
        ..['quality_total'] = t.qualityUs ~/ 1000
        ..['average_total'] = t.averageUs ~/ 1000
        ..['frames_analysed'] = t.framesAnalysed;
      final descriptor = outcome.descriptor;
      if (descriptor == null) {
        // Web "quality_failed": retryable (reposition / relight), not broken.
        state = state.copyWith(phase: FaceCapturePhase.qualityFailed, message: outcome.message, timingsMs: Map.of(_timings));
        return;
      }
      state = state.copyWith(
        phase: FaceCapturePhase.ready,
        embedding: descriptor,
        captureFrameCount: outcome.frameCount,
        captureVariance: outcome.variance,
        timingsMs: Map.of(_timings),
      );
    } catch (_) {
      if (session == _session) {
        state = state.copyWith(phase: FaceCapturePhase.error, message: 'Could not process the captured photo.');
      }
    } finally {
      if (session == _session) await _teardown();
    }
  }

  /// One still from the camera, decoded upright; the photo file is deleted
  /// straight away (nothing of the face is kept on the device). Null when no
  /// usable photo could be taken — counted as a failed attempt.
  Future<RgbaBuffer?> _takeFrame(int session) async {
    final camera = _cameraController;
    if (session != _session || camera == null || !camera.value.isInitialized) return null;
    XFile? shot;
    try {
      final sw = Stopwatch()..start();
      shot = await camera.takePicture();
      _stillMicros += sw.elapsedMicroseconds;
      if (++_stillsTaken == 1) _firstStillMicros = sw.elapsedMicroseconds;
      _mark('first_still');
      // JPEG decode, upright, downscale and CLAHE run on a worker isolate so
      // the preview and Cancel stay responsive; the pipeline is told the
      // frame is already prepared.
      final bytes = await shot.readAsBytes();
      if (_stillsTaken == 1 && ref.read(faceDecodeCompareProvider)) await _compareDecoders(bytes);
      final prep = Stopwatch()..start();
      final frame = await prepareStillOffUi(bytes, times: _stageTimes);
      _prepMicros += prep.elapsedMicroseconds;
      return frame;
    } catch (_) {
      return null;
    } finally {
      if (shot != null) {
        try {
          await File(shot.path).delete();
        } catch (_) {}
      }
    }
  }

  /// Diagnostics only: platform codec vs the Dart decoder on the same still.
  /// Records durations and aggregate pixel differences — nothing is kept.
  Future<void> _compareDecoders(Uint8List bytes) async {
    try {
      final nativeWatch = Stopwatch()..start();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final nw = frame.image.width, nh = frame.image.height;
      _timings['native_decode_ms'] = nativeWatch.elapsedMilliseconds;
      frame.image.dispose();
      codec.dispose();
      final dartWatch = Stopwatch()..start();
      final decoded = img.decodeImage(bytes);
      if (decoded == null || data == null) return;
      final dart = RgbaBuffer.fromImage(decoded);
      _timings['dart_decode_ms'] = dartWatch.elapsedMilliseconds;
      _timings['cmp_dims_equal'] = (dart.width == nw && dart.height == nh) ? 1 : 0;
      _timings['cmp_native_w'] = nw;
      _timings['cmp_native_h'] = nh;
      _timings['cmp_dart_w'] = dart.width;
      _timings['cmp_dart_h'] = dart.height;
      if (dart.width == nw && dart.height == nh) {
        final a = dart.data, b = data.buffer.asUint8List();
        var sum = 0, max = 0, over2 = 0, n = 0;
        for (var i = 0; i < a.length; i += 4) {
          for (var c = 0; c < 3; c++) {
            final d = (a[i + c] - b[i + c]).abs();
            sum += d;
            if (d > max) max = d;
            if (d > 2) over2++;
            n++;
          }
        }
        _timings['cmp_mean_x1000'] = n == 0 ? 0 : sum * 1000 ~/ n;
        _timings['cmp_max'] = max;
        _timings['cmp_pct_over2_x100'] = n == 0 ? 0 : over2 * 10000 ~/ n;
      }
    } catch (_) {
      _timings['cmp_failed'] = 1;
    }
  }

  InputImage? _toInputImage(CameraImage image, CameraDescription camera) {
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      final controller = _cameraController;
      if (controller == null) return null;
      var rotationCompensation = _orientations[controller.value.deviceOrientation];
      if (rotationCompensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation = (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (Platform.isIOS) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    // NV21 normally arrives as one packed plane: use it as is (no copy).
    final Uint8List bytes;
    if (image.planes.length == 1) {
      bytes = image.planes.first.bytes;
    } else {
      final allBytes = WriteBuffer();
      for (final plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      bytes = allBytes.done().buffer.asUint8List();
    }
    return InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: InputImageFormat.nv21,
        bytesPerRow: image.planes.first.bytesPerRow,
      ),
    );
  }

  Future<void> _teardown() async {
    _stopped = true;
    _session++;
    final camera = _cameraController;
    _cameraController = null;
    try {
      if (camera != null && camera.value.isStreamingImages) {
        await camera.stopImageStream();
      }
    } catch (_) {}
    await camera?.dispose();
    await _detector?.close();
    _detector = null;
  }
}

final faceCaptureControllerProvider = AutoDisposeNotifierProvider<FaceCaptureController, FaceCaptureUiState>(
  FaceCaptureController.new,
);

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import '../../face_api/face_api_image.dart';
import '../../face_api/face_api_nets.dart';
import '../../face_api/face_api_pipeline.dart';
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
final _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// The face-api.js networks, loaded once per app session (~25 MB of models;
/// web likewise keeps them cached after the first load). Tests override it.
final faceApiNetsProvider = FutureProvider<FaceApiNets>((ref) async {
  final nets = await loadFaceApiNets();
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
    _stopped = false;
    state = FaceCaptureUiState(
      phase: FaceCapturePhase.initializingCamera,
      captureSessionId: const Uuid().v4(),
    );
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        state = state.copyWith(phase: FaceCapturePhase.error, message: 'No camera available on this device.');
        return;
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      _cameraController = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
      );
      await _cameraController!.initialize();
      if (_stopped) return;

      _detector = FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          // Live framing + liveness only (eye-open probabilities, head
          // angle). The captured frames are analysed by the face-api.js
          // pipeline, with web's own 68-landmark eye-occlusion check.
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      state = state.copyWith(phase: FaceCapturePhase.detecting);
      // Load the descriptor models during framing/liveness (web: the big
      // recognition net downloads while the person blinks and turns).
      ref.read(faceApiNetsProvider.future).ignore();
      await _cameraController!.startImageStream(_onFrame);
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
    _liveness = null;
    await start();
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_processingFrame || _stopped || _detector == null || _cameraController == null) return;
    if (state.phase != FaceCapturePhase.detecting && state.phase != FaceCapturePhase.livenessChecking) return;
    _processingFrame = true;
    try {
      final inputImage = _toInputImage(image, _cameraController!.description);
      if (inputImage == null) return;
      final faces = await _detector!.processImage(inputImage);
      if (!_stopped) await _handleFaces(faces, image.width);
    } catch (_) {
      // A single failed frame shouldn't abort the whole capture attempt.
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _handleFaces(List<Face> faces, int frameWidth) async {
    if (faces.length != 1) {
      _stableFrames = 0;
      // "No face" stays silent (state.liveHint: null, falling back to the
      // caller's static instruction text) — mirrors web's own
      // classifyDetectedFaceCount handling exactly (`faceCount === 'none'`
      // returns empty reasons, only 'multiple' gets a message). Only the
      // multiple-faces case gets a distinct hint; there's no separate "no
      // face" message to add on top of the ambient "Looking for a face…"
      // status this phase's UI already shows.
      state = state.copyWith(
        phase: FaceCapturePhase.detecting,
        liveHint: faces.length > 1 ? _kMultipleFacesHint : null,
      );
      return;
    }
    final face = faces.first;

    if (state.phase == FaceCapturePhase.detecting) {
      // Distance/frontality only gate this phase — not livenessChecking,
      // where the head is deliberately moving/turning as part of the
      // challenge itself; checking frontality there would just fight the
      // very motion being asked for. See this file's module-level comment
      // for why these run pre-liveness at all (a deliberate mobile-specific
      // adaptation — web's own equivalent checks only run post-liveness, at
      // actual frame-capture time, since its capture is multi-frame and
      // averaged; this app's is a single still, so catching bad framing
      // before spending 9s on the liveness challenge is worth the earlier
      // check here).
      final hint = _liveFramingHint(face, frameWidth);
      if (hint != null) {
        _stableFrames = 0;
        state = state.copyWith(liveHint: hint);
        return;
      }
      if (state.liveHint != null) state = state.copyWith(liveHint: null);

      _stableFrames++;
      if (_stableFrames >= _kStableFramesToStart) {
        _livenessDeadline = DateTime.now().add(_kLivenessTimeout);
        final tracker = _liveness = LivenessTracker(_livenessMode);
        tracker.addSample(yaw: face.headEulerAngleY); // facing-the-camera baseline
        state = state.copyWith(phase: FaceCapturePhase.livenessChecking, liveHint: tracker.prompt);
      }
      return;
    }

    if (state.phase == FaceCapturePhase.livenessChecking) {
      final tracker = _liveness;
      if (tracker == null) return;
      // Web LivenessTracker: a head turn AND (registration) a blink, both
      // within the window, in any order.
      tracker.addSample(
        leftEyeOpen: face.leftEyeOpenProbability,
        rightEyeOpen: face.rightEyeOpenProbability,
        yaw: face.headEulerAngleY,
      );
      if (tracker.passed) {
        await _onLivenessPassed(score: tracker.score);
        return;
      }
      if (_livenessDeadline != null && DateTime.now().isAfter(_livenessDeadline!)) {
        state = state.copyWith(phase: FaceCapturePhase.livenessFailed, message: tracker.missingMessage);
        return;
      }
      if (state.liveHint != tracker.prompt) state = state.copyWith(liveHint: tracker.prompt);
    }
  }

  /// Distance, then frontality — the two live, per-frame checks that gate
  /// the pre-liveness `detecting` phase (multi-face is handled by the caller
  /// before this is ever reached). Returns null when framing looks fine.
  /// headEulerAngleY is "guaranteed only in accurate mode" per ML Kit's own
  /// docs (this detector runs `fast`, same as the pre-existing head-turn
  /// liveness check above, which already relies on the same field) — a null
  /// reading here just skips the frontality check for that frame rather than
  /// blocking on it, same fail-open shape as the liveness code already uses.
  String? _liveFramingHint(Face face, int frameWidth) {
    if (frameWidth <= 0) return null;
    final widthRatio = face.boundingBox.width / frameWidth;
    if (widthRatio < _kMinFaceWidthRatio) return _kTooFarHint;
    if (widthRatio > _kMaxFaceWidthRatio) return _kTooCloseHint;

    final yaw = face.headEulerAngleY;
    if (yaw != null && yaw.abs() > _kMaxFrontalYawDegrees) return _kNotFrontalHint;

    return null;
  }

  Future<void> _onLivenessPassed({required double score}) async {
    if (_stopped) return;
    _stopped = true; // stop reacting to further frames immediately
    state = state.copyWith(phase: FaceCapturePhase.extractingEmbedding, livenessPassed: true, livenessScore: score);
    try {
      await _cameraController?.stopImageStream();
      final nets = await ref.read(faceApiNetsProvider.future);
      final outcome = await FaceApiPipeline(nets).capture(nextFrame: _takeFrame, framesToCapture: _framesToCapture);
      final descriptor = outcome.descriptor;
      if (descriptor == null) {
        // Web "quality_failed": retryable (reposition / relight), not broken.
        state = state.copyWith(phase: FaceCapturePhase.qualityFailed, message: outcome.message);
        return;
      }
      state = state.copyWith(
        phase: FaceCapturePhase.ready,
        embedding: descriptor,
        captureFrameCount: outcome.frameCount,
        captureVariance: outcome.variance,
      );
    } catch (_) {
      state = state.copyWith(phase: FaceCapturePhase.error, message: 'Could not process the captured photo.');
    } finally {
      await _teardown();
    }
  }

  /// One still from the camera, decoded upright; the photo file is deleted
  /// straight away (nothing of the face is kept on the device). Null when no
  /// usable photo could be taken — counted as a failed attempt.
  Future<RgbaBuffer?> _takeFrame() async {
    final camera = _cameraController;
    if (camera == null || !camera.value.isInitialized) return null;
    XFile? shot;
    try {
      shot = await camera.takePicture();
      final decoded = img.decodeImage(await shot.readAsBytes());
      return decoded == null ? null : RgbaBuffer.fromImage(decoded);
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

    final allBytes = WriteBuffer();
    for (final plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();
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

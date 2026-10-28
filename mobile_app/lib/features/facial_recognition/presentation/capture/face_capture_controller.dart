import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:uuid/uuid.dart';

import 'face_capture_state.dart';
import 'face_embedding_model.dart';

// How many consecutive single-face frames are required before the liveness
// challenge starts, and how long the challenge itself has to complete —
// mirrors the shape (not the exact numbers-source) of the web's
// useFaceLivenessCapture.ts, adapted to ML Kit's built-in signals instead of
// hand-computed eye-aspect-ratio from 68 landmarks.
const _kStableFramesToStart = 10;
const _kLivenessTimeout = Duration(milliseconds: 9000);
const _kBlinkClosedThreshold = 0.3;
const _kBlinkOpenThreshold = 0.6;
const _kHeadTurnDegrees = 15.0;

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

// Lighting — same 0-255 mean-luminance scale regardless of platform (ITU-R
// BT.601, computed identically below), so ported verbatim from
// qualityGate.ts's MIN/MAX_MEAN_LUMINANCE.
const _kMinMeanLuminance = 60.0;
const _kMaxMeanLuminance = 200.0;

// Eye occlusion — same luminance/contrast signal and formula as web's
// frameCapture.ts (EYE_OCCLUSION_MAX_LUMINANCE/MAX_STD_DEV), ported verbatim.
// Deliberately conservative, same as web: BOTH eyes must read as
// dark-AND-flat, run only once the frame has already cleared every other
// check above, and framed to the user as a best-effort guess, never a
// certainty — see _assessEyeOcclusion's own doc comment.
const _kEyeOcclusionMaxLuminance = 50.0;
const _kEyeOcclusionMaxStdDev = 10.0;

const _kMultipleFacesHint = 'Multiple faces detected — make sure only your face is in frame.';
const _kTooFarHint = 'Move closer to the camera.';
const _kTooCloseHint = 'Move back a little.';
const _kNotFrontalHint = 'Face the camera directly.';
const _kTooDarkMessage = 'Lighting too dark — move to a better-lit area and try again.';
const _kTooBrightMessage = 'Lighting too bright — avoid direct backlight or glare and try again.';
// Verbatim match of web's EYE_OCCLUSION_MESSAGE (frameCapture.ts) — same
// deliberately non-accusatory framing ("we couldn't clearly detect", not
// "you're wearing sunglasses"), since this is a heuristic guess, not a
// certain diagnosis.
const _kEyeOcclusionMessage =
    "We couldn't clearly detect your eyes — please remove sunglasses or anything covering your face and try again.";

final _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// Drives live camera preview + on-device liveness detection (blink or head
/// turn, via ML Kit's face classification/head-angle output) and, once
/// liveness passes, captures a still and runs it through a bundled
/// on-device embedding model (see face_embedding_model.dart — the backend
/// has no endpoint that accepts an image or computes anything server-side).
/// Shared by self-registration, HR-assisted registration, and clock-in
/// verification — none of them need anything beyond "give me a
/// liveness-checked embedding".
class FaceCaptureController extends AutoDisposeNotifier<FaceCaptureUiState> {
  CameraController? _cameraController;
  FaceDetector? _detector;
  final _embedder = MobileFaceNetEmbedder();
  int _stableFrames = 0;
  DateTime? _livenessDeadline;
  double? _baselineYaw;
  bool _blinkDipped = false;
  bool _processingFrame = false;
  bool _stopped = false;

  CameraController? get cameraController => _cameraController;

  @override
  FaceCaptureUiState build() {
    ref.onDispose(_teardown);
    // Kept alive across retry()'s camera-only teardown/restart cycle (see
    // _teardown below) — reloading the 5MB model from the asset bundle on
    // every retry would add a needless delay; only actually released when
    // this whole provider is torn down (the capture sheet closes).
    ref.onDispose(_embedder.dispose);
    return const FaceCaptureUiState();
  }

  Future<void> start() async {
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
          // Contours (not landmarks) — FaceLandmarkType.leftEye/rightEye is
          // a single center point, too coarse to build a real eye-region box
          // from; FaceContourType.leftEye/rightEye gives the multi-point
          // outline this needs, the same shape web's per-eye landmark set
          // gives boundingBoxOfPoints() in frameCapture.ts. Only consumed
          // once, post-liveness, against the still photo (see
          // _assessEyeOcclusion) — computed on every live frame too since
          // FaceDetectorOptions is shared by both passes and ML Kit has no
          // per-call override, a deliberate simplicity/perf tradeoff worth
          // revisiting if real-device profiling shows it matters.
          enableContours: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
      state = state.copyWith(phase: FaceCapturePhase.detecting);
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
    _blinkDipped = false;
    _baselineYaw = null;
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
        _baselineYaw = face.headEulerAngleY;
        state = state.copyWith(phase: FaceCapturePhase.livenessChecking);
      }
      return;
    }

    if (state.phase == FaceCapturePhase.livenessChecking) {
      if (_livenessDeadline != null && DateTime.now().isAfter(_livenessDeadline!)) {
        state = state.copyWith(
          phase: FaceCapturePhase.livenessFailed,
          message: 'We could not confirm liveness in time. Please try again.',
        );
        return;
      }

      final leftOpen = face.leftEyeOpenProbability;
      final rightOpen = face.rightEyeOpenProbability;
      if (leftOpen != null && rightOpen != null) {
        final avgOpen = (leftOpen + rightOpen) / 2;
        if (avgOpen < _kBlinkClosedThreshold) _blinkDipped = true;
        if (_blinkDipped && avgOpen > _kBlinkOpenThreshold) {
          await _onLivenessPassed(score: avgOpen);
          return;
        }
      }

      final yaw = face.headEulerAngleY;
      if (yaw != null && _baselineYaw != null) {
        final delta = (yaw - _baselineYaw!).abs();
        if (delta > _kHeadTurnDegrees) {
          await _onLivenessPassed(score: (delta / 45.0).clamp(0.0, 1.0));
          return;
        }
      }
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
      final picture = await _cameraController!.takePicture();

      // Detect against the still photo itself (not the live stream frame) so
      // the crop used for embedding matches exactly what was captured —
      // reuses the same detector instance already loaded for liveness.
      final stillFaces = await _detector!.processImage(InputImage.fromFilePath(picture.path));
      if (stillFaces.isEmpty) {
        state = state.copyWith(
          phase: FaceCapturePhase.error,
          message: 'Could not find your face in the captured photo. Please try again.',
        );
        return;
      }
      final stillFace = stillFaces.first;

      // Lighting + eye-occlusion — the two checks that need actual pixel
      // data, so (unlike distance/frontality above) these run once, here, on
      // the committed still photo rather than on every live preview frame —
      // matches web's own captureOneQualityGatedFrame, which likewise only
      // samples pixel luminance on the frame that's actually a capture
      // candidate, never on every frame of its live preview loop.
      final decoded = img.decodeImage(await File(picture.path).readAsBytes());
      if (decoded != null) {
        final qualityFailure = _assessStillPhotoQuality(decoded, stillFace);
        if (qualityFailure != null) {
          state = state.copyWith(phase: FaceCapturePhase.qualityFailed, message: qualityFailure);
          return;
        }
      }
      // decoded == null (a still photo the `image` package couldn't parse)
      // deliberately falls through rather than blocking the capture — the
      // photo already passed ML Kit's own detection above, so treating an
      // unrelated decode failure as a hard rejection would block a
      // perfectly usable capture over a problem in an unrelated check.

      final embedding = await _embedder.embed(picture.path, stillFace.boundingBox);
      state = state.copyWith(phase: FaceCapturePhase.ready, embedding: embedding);
    } catch (_) {
      state = state.copyWith(phase: FaceCapturePhase.error, message: 'Could not process the captured photo.');
    } finally {
      await _teardown();
    }
  }

  /// Lighting first, then eye occlusion — matches web's own ordering
  /// (assessFrameQuality's luminance check, then assessEyeOcclusion only
  /// once everything else already passed). Returns the user-facing message
  /// for whichever check fails first, or null if both pass.
  String? _assessStillPhotoQuality(img.Image decoded, Face face) {
    final box = _clampedBox(face.boundingBox, decoded.width, decoded.height);
    if (box == null) return null; // degenerate box — nothing meaningful to sample

    final luminance = _meanLuminanceOfBox(decoded, box);
    if (luminance < _kMinMeanLuminance) return _kTooDarkMessage;
    if (luminance > _kMaxMeanLuminance) return _kTooBrightMessage;

    if (_assessEyeOcclusion(decoded, face)) return _kEyeOcclusionMessage;
    return null;
  }

  ({int x0, int y0, int x1, int y1})? _clampedBox(Rect box, int imageWidth, int imageHeight) {
    final x0 = box.left.floor().clamp(0, imageWidth);
    final y0 = box.top.floor().clamp(0, imageHeight);
    final x1 = box.right.ceil().clamp(0, imageWidth);
    final y1 = box.bottom.ceil().clamp(0, imageHeight);
    if (x1 <= x0 || y1 <= y0) return null;
    return (x0: x0, y0: y0, x1: x1, y1: y1);
  }

  /// ITU-R BT.601 mean luminance over a pixel region — identical formula and
  /// scale (0-255) to web's meanLuminanceOfBox (frameCapture.ts), just read
  /// from a decoded still photo via package:image instead of canvas
  /// ImageData.
  double _meanLuminanceOfBox(img.Image image, ({int x0, int y0, int x1, int y1}) box) {
    double sum = 0;
    var count = 0;
    for (var y = box.y0; y < box.y1; y++) {
      for (var x = box.x0; x < box.x1; x++) {
        final p = image.getPixel(x, y);
        sum += 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        count++;
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  /// Best-effort guess at covered eyes (sunglasses, a mask pulled up too
  /// high, a hand, ...) — NOT a dedicated occlusion detector; ML Kit has no
  /// signal for this any more than face-api.js did. Mirrors web's
  /// assessEyeOcclusion exactly: both eye regions must read as
  /// dark-AND-flat (low mean luminance AND low standard deviation — a real,
  /// visible open eye has internal contrast a covered one doesn't), using
  /// FaceContourType eye outlines for the region instead of face-api.js's
  /// landmark points. Deliberately conservative — this only ever runs after
  /// lighting has already passed above, so a dark reading here reflects the
  /// eye region specifically, not just a dim room. Prefer under-triggering
  /// over over-triggering: telling a legitimately dim-lit but unobstructed
  /// user to "remove sunglasses" they aren't wearing is worse than missing
  /// an actual pair once in a while.
  bool _assessEyeOcclusion(img.Image decoded, Face face) {
    final left = face.contours[FaceContourType.leftEye]?.points;
    final right = face.contours[FaceContourType.rightEye]?.points;
    if (left == null || left.isEmpty || right == null || right.isEmpty) {
      return false; // no contour data this attempt — fail open, same as a null headEulerAngleY does above
    }
    final leftBox = _clampedBox(_boundingBoxOfPoints(left), decoded.width, decoded.height);
    final rightBox = _clampedBox(_boundingBoxOfPoints(right), decoded.width, decoded.height);
    if (leftBox == null || rightBox == null) return false;

    return _looksOccluded(decoded, leftBox) && _looksOccluded(decoded, rightBox);
  }

  bool _looksOccluded(img.Image decoded, ({int x0, int y0, int x1, int y1}) box) {
    double sum = 0, sumSquares = 0;
    var count = 0;
    for (var y = box.y0; y < box.y1; y++) {
      for (var x = box.x0; x < box.x1; x++) {
        final p = decoded.getPixel(x, y);
        final luminance = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
        sum += luminance;
        sumSquares += luminance * luminance;
        count++;
      }
    }
    if (count == 0) return false;
    final mean = sum / count;
    final variance = (sumSquares / count - mean * mean).clamp(0.0, double.infinity);
    final stdDev = sqrt(variance);
    return mean < _kEyeOcclusionMaxLuminance && stdDev < _kEyeOcclusionMaxStdDev;
  }

  Rect _boundingBoxOfPoints(List<Point<int>> points) {
    final xs = points.map((p) => p.x.toDouble());
    final ys = points.map((p) => p.y.toDouble());
    final minX = xs.reduce((a, b) => a < b ? a : b);
    final maxX = xs.reduce((a, b) => a > b ? a : b);
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    return Rect.fromLTRB(minX, minY, maxX, maxY);
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

final faceCaptureControllerProvider =
    AutoDisposeNotifierProvider<FaceCaptureController, FaceCaptureUiState>(
  FaceCaptureController.new,
);

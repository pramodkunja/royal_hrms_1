import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
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
      if (!_stopped) await _handleFaces(faces);
    } catch (_) {
      // A single failed frame shouldn't abort the whole capture attempt.
    } finally {
      _processingFrame = false;
    }
  }

  Future<void> _handleFaces(List<Face> faces) async {
    if (faces.length != 1) {
      _stableFrames = 0;
      if (state.phase != FaceCapturePhase.detecting) {
        state = state.copyWith(phase: FaceCapturePhase.detecting);
      }
      return;
    }
    final face = faces.first;

    if (state.phase == FaceCapturePhase.detecting) {
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

      final embedding = await _embedder.embed(picture.path, stillFaces.first.boundingBox);
      state = state.copyWith(phase: FaceCapturePhase.ready, embedding: embedding);
    } catch (_) {
      state = state.copyWith(phase: FaceCapturePhase.error, message: 'Could not process the captured photo.');
    } finally {
      await _teardown();
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

final faceCaptureControllerProvider =
    AutoDisposeNotifierProvider<FaceCaptureController, FaceCaptureUiState>(
  FaceCaptureController.new,
);

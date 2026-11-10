import 'face_api_image.dart';
import 'face_api_math.dart';
import 'face_api_nets.dart';

// The web app's face-descriptor pipeline (frontend/hooks/
// useFaceLivenessCapture.ts captureOneQualityGatedFrame + captureMultipleFrames,
// on face-api.js 0.22.2), step for step, so a descriptor produced here lands
// in the same 128-d space the backend compares with Euclidean distance
// (FACE_RECOGNITION_MODEL_VERSION 'face-api.js-faceRecognitionNet-v1'):
//
//  1. frame drawn at most 800 px wide (CAPTURE_MAX_FRAME_WIDTH);
//  2. CLAHE lighting normalisation (normalizeLighting: true — registration
//     and clock-in verification both use it on web);
//  3. TinyFaceDetector (inputSize 224, scoreThreshold 0.5) — exactly one face;
//  4. FaceLandmark68Net on the detection crop;
//  5. dlib-style alignment box from the eye/mouth centres → crop →
//     FaceRecognitionNet (150 px, centred) → 128 floats;
//  6. web's per-frame quality gate (confidence, distance, frontality,
//     lighting, eye occlusion);
//  7. N good frames (4 registration / 3 verification), pairwise within 0.35,
//     averaged element-wise.

const kCaptureMaxFrameWidth = 800;
const kDetectorInputSize = 224;
const kDetectorScoreThreshold = 0.5;

/// Web REGISTRATION_FRAMES_TO_CAPTURE / VERIFICATION_FRAMES_TO_CAPTURE.
const kRegistrationFramesToCapture = 4;
const kVerificationFramesToCapture = 3;

/// Web MULTI_FRAME_ATTEMPTS_PER_TARGET_FRAME.
const kAttemptsPerTargetFrame = 4;

class FrameAttempt {
  const FrameAttempt({this.descriptor, this.codes = const [], this.reasons = const []});
  final List<double>? descriptor;
  final List<String> codes;
  final List<String> reasons;
}

class FaceApiPipeline {
  FaceApiPipeline(this.nets);
  final FaceApiNets nets;

  /// One frame → a descriptor, or why not (web captureOneQualityGatedFrame).
  Future<FrameAttempt> analyzeFrame(RgbaBuffer raw, {bool normalizeLighting = true}) async {
    final frame = scaleToMaxWidth(raw, kCaptureMaxFrameWidth);
    if (normalizeLighting) applyClahe(frame);

    final detections = decodeTinyFaceDetector(
      await nets.detect(imageToSquareRgb(frame, kDetectorInputSize, center: false)),
      imageWidth: frame.width,
      imageHeight: frame.height,
      inputSize: kDetectorInputSize,
      scoreThreshold: kDetectorScoreThreshold,
    );
    if (detections.isEmpty) return const FrameAttempt(codes: ['no_face']);
    if (detections.length > 1) {
      return const FrameAttempt(codes: ['multiple_faces'], reasons: [kMultipleFacesMessage]);
    }
    final det = detections.single;

    // Landmarks on the detection crop (extractFaces: box floored, clipped).
    final detCropBox = det.box.floor().clipAtImageBorders(frame.width, frame.height);
    if (detCropBox.width < 1 || detCropBox.height < 1) return const FrameAttempt(codes: ['no_face']);
    final detCrop = frame.crop(detCropBox);
    final rel = landmarkRelativePositions(
      await nets.landmarks(imageToSquareRgb(detCrop, 112, center: true)),
      cropWidth: detCrop.width,
      cropHeight: detCrop.height,
    );
    final landmarks = FaceLandmarks68(rel, detCrop.width, detCrop.height, FaPoint(det.box.x, det.box.y));

    // Descriptor on the dlib-aligned crop (useDlibAlignment: true).
    final faceBox = landmarks.alignDlib().clipAtImageBorders(frame.width, frame.height);
    if (faceBox.width < 1 || faceBox.height < 1) return const FrameAttempt(codes: ['no_face']);
    final descriptor = await nets.describe(imageToSquareRgb(frame.crop(faceBox), 150, center: true));

    final failures = assessFrameQuality(FrameQualityMetrics(
      detectionScore: det.score,
      faceWidthRatio: det.box.width / frame.width,
      frontality: computeFrontality(landmarks.leftEye, landmarks.rightEye, landmarks.nose[3]),
      meanLuminance: meanLuminanceOfBox(frame, det.box),
    ));
    if (failures.isNotEmpty) {
      return FrameAttempt(codes: [for (final f in failures) f.code], reasons: [for (final f in failures) f.message]);
    }
    if (eyesLookOccluded(frame, landmarks.leftEye, landmarks.rightEye)) {
      return const FrameAttempt(codes: ['eye_occlusion'], reasons: [kEyeOcclusionMessage]);
    }
    return FrameAttempt(descriptor: List<double>.from(descriptor));
  }

  /// Web captureMultipleFrames: up to framesToCapture × 4 attempts (frames
  /// from [nextFrame], [interval] apart), then the consistency check and the
  /// average. [nextFrame] returning null counts as a failed attempt.
  Future<CaptureOutcome> capture({
    required Future<RgbaBuffer?> Function() nextFrame,
    required int framesToCapture,
    Duration interval = const Duration(milliseconds: 250),
    bool normalizeLighting = true,
  }) async {
    final collected = <List<double>>[];
    final reasonsPerAttempt = <List<String>>[];
    final maxAttempts = framesToCapture * kAttemptsPerTargetFrame;
    for (var attempt = 0; attempt < maxAttempts && collected.length < framesToCapture; attempt++) {
      if (attempt > 0) await Future<void>.delayed(interval);
      final frame = await nextFrame();
      if (frame == null) {
        reasonsPerAttempt.add(const []);
        continue;
      }
      final r = await analyzeFrame(frame, normalizeLighting: normalizeLighting);
      if (r.descriptor != null) {
        collected.add(r.descriptor!);
      } else {
        reasonsPerAttempt.add(r.reasons);
      }
    }
    if (collected.length < framesToCapture) {
      String? specific;
      for (final reasons in reasonsPerAttempt) {
        if (reasons.isNotEmpty) specific = reasons.first;
      }
      return CaptureOutcome.failed(specific ??
          (framesToCapture > 1
              ? "Couldn't get enough clear captures — make sure you're well-lit, centered, and holding still, then try again."
              : "Couldn't get a clear capture — make sure you're well-lit, centered, and holding still, then try again."));
    }
    final consistency = assessCaptureConsistency(collected, kMaxIntraCaptureDistance);
    if (!consistency.passed) {
      return CaptureOutcome.failed("Your captures didn't quite agree with each other — hold still and try again.");
    }
    return CaptureOutcome.captured(averageDescriptors(collected),
        frameCount: collected.length, variance: consistency.mean);
  }
}

class CaptureOutcome {
  const CaptureOutcome._(this.descriptor, this.message, this.frameCount, this.variance);
  factory CaptureOutcome.captured(List<double> d, {required int frameCount, required double variance}) =>
      CaptureOutcome._(d, null, frameCount, variance);
  factory CaptureOutcome.failed(String message) => CaptureOutcome._(null, message, 0, 0);

  /// The averaged 128-d descriptor (null when the capture failed).
  final List<double>? descriptor;
  final String? message;
  final int frameCount;

  /// Mean pairwise distance between the frames (web capture_variance).
  final double variance;
}

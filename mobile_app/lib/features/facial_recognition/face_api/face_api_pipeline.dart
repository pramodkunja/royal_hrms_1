import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

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

/// JPEG bytes → the frame the networks see: decoded, EXIF-upright, at most
/// 800 px wide, CLAHE-normalised (pipeline steps 1–2). Pure CPU work, so
/// [prepareStillOffUi] runs it on a worker isolate and keeps the UI smooth.
/// Returns null when the bytes are not a decodable image.
RgbaBuffer? prepareStillJpeg(Uint8List jpeg, {bool normalizeLighting = true}) =>
    prepareStillTimed(jpeg, normalizeLighting: normalizeLighting).frame;

/// [prepareStillJpeg] plus the microseconds spent in decode / scale / CLAHE.
({RgbaBuffer? frame, int decodeUs, int convertUs, int scaleUs, int claheUs}) prepareStillTimed(
  Uint8List jpeg, {
  bool normalizeLighting = true,
}) {
  final sw = Stopwatch()..start();
  final img.Image? decoded;
  try {
    decoded = img.decodeImage(jpeg);
  } catch (_) {
    return (frame: null, decodeUs: 0, convertUs: 0, scaleUs: 0, claheUs: 0); // truncated / corrupt file
  }
  if (decoded == null) return (frame: null, decodeUs: 0, convertUs: 0, scaleUs: 0, claheUs: 0);
  final decodeUs = sw.elapsedMicroseconds; // JPEG → pixels
  sw.reset();
  final upright = RgbaBuffer.fromImage(decoded); // EXIF orientation + RGBA
  final convertUs = sw.elapsedMicroseconds;
  sw.reset();
  // The decoded buffer is ours alone, so a frame that needs no scaling is
  // used in place (no copy) — CLAHE then normalises it in place as before.
  final frame = scaleToMaxWidth(upright, kCaptureMaxFrameWidth, copyIfUnscaled: false);
  final scaleUs = sw.elapsedMicroseconds;
  sw.reset();
  if (normalizeLighting) applyClahe(frame);
  return (frame: frame, decodeUs: decodeUs, convertUs: convertUs, scaleUs: scaleUs, claheUs: sw.elapsedMicroseconds);
}

/// [prepareStillJpeg] on a short-lived worker isolate (one per still, not per
/// camera frame; only the bytes are sent and only the pixels come back).
Future<RgbaBuffer?> prepareStillOffUi(Uint8List jpeg, {bool normalizeLighting = true, FaceApiStageTimes? times}) async {
  final r = await Isolate.run(() => prepareStillTimed(jpeg, normalizeLighting: normalizeLighting));
  if (times != null) {
    times.decodeUs += r.decodeUs;
    times.convertUs += r.convertUs;
    times.scaleUs += r.scaleUs;
    times.claheUs += r.claheUs;
  }
  return r.frame;
}

/// Aggregate microseconds per pipeline stage (numbers only), summed over the
/// frames of one capture — diagnostics for finding the real bottleneck.
class FaceApiStageTimes {
  int detectUs = 0, landmarksUs = 0, describeUs = 0, qualityUs = 0, averageUs = 0;
  int decodeUs = 0, convertUs = 0, scaleUs = 0, claheUs = 0;
  int framesAnalysed = 0;
}

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
  ///
  /// [prepared]: the frame already went through [prepareStillJpeg] (scaled and
  /// CLAHE-normalised, e.g. on a worker isolate) — the steps are not repeated.
  Future<FrameAttempt> analyzeFrame(
    RgbaBuffer raw, {
    bool normalizeLighting = true,
    bool prepared = false,
    FaceApiStageTimes? times,
  }) async {
    final sw = Stopwatch();
    times?.framesAnalysed++;
    final RgbaBuffer frame;
    if (prepared) {
      frame = raw;
    } else {
      frame = scaleToMaxWidth(raw, kCaptureMaxFrameWidth);
      if (normalizeLighting) applyClahe(frame);
    }

    sw.start();
    final detOut = await nets.detect(imageToSquareRgb(frame, kDetectorInputSize, center: false));
    times?.detectUs += sw.elapsedMicroseconds;
    final detections = decodeTinyFaceDetector(
      detOut,
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
    sw.reset();
    final lmkOut = await nets.landmarks(imageToSquareRgb(detCrop, 112, center: true));
    times?.landmarksUs += sw.elapsedMicroseconds;
    final rel = landmarkRelativePositions(
      lmkOut,
      cropWidth: detCrop.width,
      cropHeight: detCrop.height,
    );
    final landmarks = FaceLandmarks68(rel, detCrop.width, detCrop.height, FaPoint(det.box.x, det.box.y));

    // Descriptor on the dlib-aligned crop (useDlibAlignment: true).
    final faceBox = landmarks.alignDlib().clipAtImageBorders(frame.width, frame.height);
    if (faceBox.width < 1 || faceBox.height < 1) return const FrameAttempt(codes: ['no_face']);
    // The quality gate and the eye-occlusion check do not depend on the
    // descriptor, so they run first: a frame that fails them no longer pays
    // for the (largest) recognition inference. Outcome is unchanged.
    sw.reset();
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
    times?.qualityUs += sw.elapsedMicroseconds;

    sw.reset();
    final descriptor = await nets.describe(imageToSquareRgb(frame.crop(faceBox), 150, center: true));
    times?.describeUs += sw.elapsedMicroseconds;
    return FrameAttempt(descriptor: List<double>.from(descriptor));
  }

  /// Web captureMultipleFrames: up to framesToCapture × 4 attempts, then the
  /// consistency check and the average — same frame count, same per-frame
  /// quality gate, same consistency rule, same averaging.
  ///
  /// Overlap: while a still is being analysed the next one is already being
  /// taken (camera, worker isolate and the networks work in parallel), but no
  /// more stills are started than could still be needed
  /// (good + in-flight < [framesToCapture]), and consecutive stills are never
  /// closer than [interval] to each other. Descriptors are averaged in
  /// attempt order, exactly as a one-at-a-time capture would.
  Future<CaptureOutcome> capture({
    required Future<RgbaBuffer?> Function() nextFrame,
    required int framesToCapture,
    Duration interval = const Duration(milliseconds: 250),
    bool normalizeLighting = true,
    bool framesArePrepared = false,
    void Function(int micros)? onAnalysisTime,
    bool Function()? isCancelled,
    FaceApiStageTimes? times,
  }) async {
    final maxAttempts = framesToCapture * kAttemptsPerTargetFrame;
    final attempts = <FrameAttempt?>[]; // by attempt index; null = still running
    final active = <Future<void>>{};
    var good = 0;
    var started = 0;
    var lastCaptureTook = Duration.zero;

    bool cancelled() => isCancelled?.call() ?? false;

    while (started < maxAttempts) {
      if (cancelled()) return CaptureOutcome.failed('Cancelled.');
      if (good + active.length >= framesToCapture) {
        if (good >= framesToCapture) break;
        // Everything that could finish the job is already running: wait for
        // one of them (a failure frees a slot for another still).
        await Future.any(active);
        continue;
      }
      if (started > 0 && lastCaptureTook < interval) await Future<void>.delayed(interval - lastCaptureTook);
      if (cancelled()) return CaptureOutcome.failed('Cancelled.');
      final took = Stopwatch()..start();
      final frame = await nextFrame();
      lastCaptureTook = took.elapsed;
      final index = started++;
      if (frame == null) {
        attempts.add(const FrameAttempt());
        continue;
      }
      attempts.add(null);
      late final Future<void> job;
      job = () async {
        final sw = Stopwatch()..start();
        final r = await analyzeFrame(frame, normalizeLighting: normalizeLighting, prepared: framesArePrepared, times: times);
        onAnalysisTime?.call(sw.elapsedMicroseconds);
        attempts[index] = r;
        if (r.descriptor != null) good++;
      }()
          .whenComplete(() => active.remove(job));
      active.add(job);
    }
    await Future.wait(active.toList());
    if (cancelled()) return CaptureOutcome.failed('Cancelled.');

    final collected = <List<double>>[
      for (final a in attempts)
        if (a?.descriptor != null) a!.descriptor!
    ];
    if (collected.length > framesToCapture) collected.length = framesToCapture;
    if (collected.length < framesToCapture) {
      String? specific;
      for (final a in attempts) {
        if (a != null && a.descriptor == null && a.reasons.isNotEmpty) specific = a.reasons.first;
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
    final avg = Stopwatch()..start();
    final averaged = averageDescriptors(collected);
    times?.averageUs += avg.elapsedMicroseconds;
    return CaptureOutcome.captured(averaged, frameCount: collected.length, variance: consistency.mean);
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

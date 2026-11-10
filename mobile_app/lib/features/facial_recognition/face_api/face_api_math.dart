import 'dart:math' as math;
import 'dart:typed_data';

// Pure-Dart port of the parts of face-api.js 0.22.2 (the exact version the
// web app pins — frontend/package.json) and of the web app's own
// lib/faceApi/qualityGate.ts that decide WHICH pixels become the 128-d face
// descriptor and whether a frame is accepted. Each function names the
// face-api.js / web source it mirrors; numbers are kept identical so mobile
// and web descriptors land in the same space (see face_api_pipeline.dart).

class FaPoint {
  const FaPoint(this.x, this.y);
  final double x;
  final double y;
  @override
  String toString() => '($x, $y)';
}

/// face-api.js classes/Box (x, y, width, height).
class FaBox {
  const FaBox(this.x, this.y, this.width, this.height);
  final double x;
  final double y;
  final double width;
  final double height;

  double get right => x + width;
  double get bottom => y + height;
  double get area => width * height;

  /// Box.floor: every component floored.
  FaBox floor() => FaBox(x.floorToDouble(), y.floorToDouble(), width.floorToDouble(), height.floorToDouble());

  /// Box.rescale.
  FaBox rescale(double sx, double sy) => FaBox(x * sx, y * sy, width * sx, height * sy);

  /// Box.clipAtImageBorders (ends with .floor()).
  FaBox clipAtImageBorders(int imgWidth, int imgHeight) {
    final clippedX = math.max(x, 0.0);
    final clippedY = math.max(y, 0.0);
    final newWidth = right - clippedX;
    final newHeight = bottom - clippedY;
    final clippedWidth = math.min(newWidth, imgWidth - clippedX);
    final clippedHeight = math.min(newHeight, imgHeight - clippedY);
    return FaBox(clippedX, clippedY, clippedWidth, clippedHeight).floor();
  }

  @override
  String toString() => 'FaBox($x, $y, $width, $height)';
}

double _sigmoid(double x) => 1 / (1 + math.exp(-x));

/// ops/iou.js (isIOU = true).
double iou(FaBox a, FaBox b) {
  final w = math.max(0.0, math.min(a.right, b.right) - math.max(a.x, b.x));
  final h = math.max(0.0, math.min(a.bottom, b.bottom) - math.max(a.y, b.y));
  final inter = w * h;
  return inter / (a.area + b.area - inter);
}

/// ops/nonMaxSuppression.js — indices kept, highest score first. Ties keep
/// JS Array.prototype.sort's stable order (ascending, then popped from the end).
List<int> nonMaxSuppression(List<FaBox> boxes, List<double> scores, double iouThreshold) {
  final order = List<int>.generate(scores.length, (i) => i);
  // Stable ascending sort by score.
  final indexed = [for (final i in order) (i, scores[i])];
  _stableSortAscending(indexed);
  var remaining = [for (final e in indexed) e.$1];
  final pick = <int>[];
  while (remaining.isNotEmpty) {
    final curr = remaining.removeLast();
    pick.add(curr);
    remaining = [
      for (final idx in remaining)
        if (iou(boxes[curr], boxes[idx]) <= iouThreshold) idx,
    ];
  }
  return pick;
}

void _stableSortAscending(List<(int, double)> list) {
  // Insertion sort: stable, and lists here are tiny (<= 245 candidates).
  for (var i = 1; i < list.length; i++) {
    final item = list[i];
    var j = i - 1;
    while (j >= 0 && list[j].$2 > item.$2) {
      list[j + 1] = list[j];
      j--;
    }
    list[j + 1] = item;
  }
}

/// utils/computeReshapedDimensions.
({int width, int height}) computeReshapedDimensions(int width, int height, int inputSize) {
  final scale = inputSize / math.max(height, width);
  return (width: (width * scale).round(), height: (height * scale).round());
}

/// tinyFaceDetector/const.js BOX_ANCHORS.
const _kAnchors = <FaPoint>[
  FaPoint(1.603231, 2.094468),
  FaPoint(6.041143, 7.080126),
  FaPoint(2.882459, 3.518061),
  FaPoint(4.266906, 5.178857),
  FaPoint(9.041765, 10.66308),
];
const kTinyFaceDetectorIouThreshold = 0.4;

/// A face found by the Tiny Face Detector: score and box in IMAGE pixels
/// (FaceDetection(score, relativeBox, imageDims).box).
class FaceDetection {
  const FaceDetection(this.score, this.relativeBox, this.imageWidth, this.imageHeight);
  final double score;
  final FaBox relativeBox;
  final int imageWidth;
  final int imageHeight;
  FaBox get box => relativeBox.rescale(imageWidth.toDouble(), imageHeight.toDouble());
}

/// TinyYolov2Base.detect (withSeparableConvs, one class, no class scores):
/// decodes the raw [1, numCells, numCells, 5 anchors × 5] network output for
/// an image of [imageWidth]×[imageHeight] that was drawn top-left into the
/// [inputSize] square, keeps boxes with score > [scoreThreshold], then
/// non-max suppression at IoU 0.4 on boxes rescaled to the input size.
List<FaceDetection> decodeTinyFaceDetector(
  Float32List raw, {
  required int imageWidth,
  required int imageHeight,
  int inputSize = 224,
  double scoreThreshold = 0.5,
}) {
  const numBoxes = 5;
  const encoding = 5;
  final numCells = math.sqrt(raw.length / (numBoxes * encoding)).round();
  final reshaped = computeReshapedDimensions(imageWidth, imageHeight, inputSize);
  final blobSize = math.max(reshaped.width, reshaped.height);
  final cfX = blobSize / reshaped.width;
  final cfY = blobSize / reshaped.height;

  final boxes = <FaBox>[];
  final scores = <double>[];
  for (var row = 0; row < numCells; row++) {
    for (var col = 0; col < numCells; col++) {
      for (var anchor = 0; anchor < numBoxes; anchor++) {
        final base = ((row * numCells + col) * numBoxes + anchor) * encoding;
        final score = _sigmoid(raw[base + 4]);
        if (scoreThreshold != 0 && !(score > scoreThreshold)) continue;
        final ctX = ((col + _sigmoid(raw[base])) / numCells) * cfX;
        final ctY = ((row + _sigmoid(raw[base + 1])) / numCells) * cfY;
        final w = ((math.exp(raw[base + 2]) * _kAnchors[anchor].x) / numCells) * cfX;
        final h = ((math.exp(raw[base + 3]) * _kAnchors[anchor].y) / numCells) * cfY;
        final x = ctX - w / 2;
        final y = ctY - h / 2;
        boxes.add(FaBox(x, y, w, h));
        scores.add(score);
      }
    }
  }
  final keep = nonMaxSuppression(
    [for (final b in boxes) b.rescale(inputSize.toDouble(), inputSize.toDouble())],
    scores,
    kTinyFaceDetectorIouThreshold,
  );
  return [for (final i in keep) FaceDetection(scores[i], boxes[i], imageWidth, imageHeight)];
}

/// FaceLandmarks68 positioned in IMAGE pixels: the landmark net's relative
/// output × the crop size it ran on, shifted by the (unfloored) detection
/// origin — WithFaceLandmarks.extendWithFaceLandmarks.
class FaceLandmarks68 {
  FaceLandmarks68(this.relative, this.imageWidth, this.imageHeight, this.shift)
      : positions = [
          for (final p in relative) FaPoint(p.x * imageWidth + shift.x, p.y * imageHeight + shift.y),
        ];

  final List<FaPoint> relative;

  /// The crop the landmarks were computed on (face-api's `_imgDims`).
  final int imageWidth;
  final int imageHeight;
  final FaPoint shift;
  final List<FaPoint> positions;

  List<FaPoint> get nose => positions.sublist(27, 36);
  List<FaPoint> get leftEye => positions.sublist(36, 42);
  List<FaPoint> get rightEye => positions.sublist(42, 48);
  List<FaPoint> get mouth => positions.sublist(48, 68);

  /// FaceLandmarks.alignDlib (relX 0.5, relY 0.43, relScale 0.45) — the box
  /// the descriptor is computed from (useDlibAlignment: true).
  FaBox alignDlib() {
    final centers = [centerOf(leftEye), centerOf(rightEye), centerOf(mouth)];
    final mouthCenter = centers[2];
    double distToMouth(FaPoint p) => math.sqrt(math.pow(mouthCenter.x - p.x, 2) + math.pow(mouthCenter.y - p.y, 2));
    final eyeToMouthDist = (distToMouth(centers[0]) + distToMouth(centers[1])) / 2;
    final size = (eyeToMouthDist / 0.45).floorToDouble();
    final ref = centerOf(centers);
    final x = math.max(0.0, ref.x - 0.5 * size).floorToDouble();
    final y = math.max(0.0, ref.y - 0.43 * size).floorToDouble();
    return FaBox(x, y, math.min(size, imageWidth + x), math.min(size, imageHeight + y));
  }
}

/// utils/getCenterPoint.
FaPoint centerOf(List<FaPoint> pts) {
  var sx = 0.0, sy = 0.0;
  for (final p in pts) {
    sx += p.x;
    sy += p.y;
  }
  return FaPoint(sx / pts.length, sy / pts.length);
}

/// FaceLandmark68NetBase.postProcess for one face: the net's 136 outputs for
/// a [cropWidth]×[cropHeight] crop drawn centred into the [inputSize] square
/// → 68 points relative to the crop (0..1).
List<FaPoint> landmarkRelativePositions(Float32List out,
    {required int cropWidth, required int cropHeight, int inputSize = 112}) {
  final scale = inputSize / math.max(cropHeight, cropWidth);
  final w = cropWidth * scale;
  final h = cropHeight * scale;
  final padX = w < h ? (w - h).abs() / 2 : 0.0;
  final padY = h < w ? (w - h).abs() / 2 : 0.0;
  return [
    for (var i = 0; i < 68; i++) FaPoint((out[2 * i] * inputSize - padX) / w, (out[2 * i + 1] * inputSize - padY) / h),
  ];
}

// ── Web lib/faceApi/qualityGate.ts ──────────────────────────────────────────

const kMinDetectionScore = 0.8;
const kMinFaceWidthRatio = 0.20;
const kMaxFaceWidthRatio = 0.75;
const kMinFrontality = 0.7;
const kMinMeanLuminance = 60.0;
const kMaxMeanLuminance = 200.0;

/// Web MAX_INTRA_CAPTURE_DISTANCE (useFaceLivenessCapture.ts).
const kMaxIntraCaptureDistance = 0.35;

double _dist(FaPoint a, FaPoint b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));

/// computeFrontality(leftEye, rightEye, nose[3]).
double computeFrontality(List<FaPoint> leftEye, List<FaPoint> rightEye, FaPoint noseTip) {
  final l = centerOf(leftEye);
  final r = centerOf(rightEye);
  final interEye = _dist(l, r);
  if (interEye == 0) return 0;
  final asymmetry = (_dist(l, noseTip) - _dist(r, noseTip)).abs() / interEye;
  return math.max(0, math.min(1, 1 - asymmetry / 0.5));
}

class FrameQualityMetrics {
  const FrameQualityMetrics({
    required this.detectionScore,
    required this.faceWidthRatio,
    required this.frontality,
    required this.meanLuminance,
  });
  final double detectionScore;
  final double faceWidthRatio;
  final double frontality;
  final double meanLuminance;
}

/// assessFrameQuality: failing codes with web's messages, in web's order.
List<({String code, String message})> assessFrameQuality(FrameQualityMetrics m) => [
      if (m.detectionScore < kMinDetectionScore)
        (
          code: 'detection_low',
          message: 'Face detection confidence too low — hold still and make sure your face is unobstructed.'
        ),
      if (m.faceWidthRatio < kMinFaceWidthRatio)
        (code: 'too_far', message: 'Face too far from the camera — move closer.'),
      if (m.faceWidthRatio > kMaxFaceWidthRatio)
        (code: 'too_close', message: 'Face too close to the camera — move back a little.'),
      if (m.frontality < kMinFrontality)
        (code: 'not_frontal', message: 'Face not centered/frontal enough — look directly at the camera.'),
      if (m.meanLuminance < kMinMeanLuminance)
        (code: 'too_dark', message: 'Lighting too dark — move to a better-lit area.'),
      if (m.meanLuminance > kMaxMeanLuminance)
        (code: 'too_bright', message: 'Lighting too bright/overexposed — avoid direct backlight or glare.'),
    ];

/// euclideanDistance.
double euclideanDistance(List<double> a, List<double> b) {
  if (a.length != b.length) throw ArgumentError('euclideanDistance: length mismatch.');
  var s = 0.0;
  for (var i = 0; i < a.length; i++) {
    final d = a[i] - b[i];
    s += d * d;
  }
  return math.sqrt(s);
}

/// assessCaptureConsistency: every pair of frames within [maxAllowed].
({bool passed, double mean, double max}) assessCaptureConsistency(List<List<double>> descriptors, double maxAllowed) {
  final d = <double>[
    for (var i = 0; i < descriptors.length; i++)
      for (var j = i + 1; j < descriptors.length; j++) euclideanDistance(descriptors[i], descriptors[j]),
  ];
  if (d.isEmpty) return (passed: true, mean: 0, max: 0);
  final max = d.reduce(math.max);
  return (passed: max <= maxAllowed, mean: d.reduce((a, b) => a + b) / d.length, max: max);
}

/// averageDescriptors: element-wise mean.
List<double> averageDescriptors(List<List<double>> descriptors) {
  if (descriptors.isEmpty) throw ArgumentError('averageDescriptors: need at least one descriptor.');
  final n = descriptors.first.length;
  final sums = List<double>.filled(n, 0);
  for (final d in descriptors) {
    if (d.length != n) throw ArgumentError('averageDescriptors: all descriptors must have the same length.');
    for (var i = 0; i < n; i++) {
      sums[i] += d[i];
    }
  }
  return [for (final s in sums) s / descriptors.length];
}

const kMultipleFacesMessage = 'Multiple faces detected — please make sure only your face is in frame.';
const kEyeOcclusionMessage =
    "We couldn't clearly detect your eyes — please remove sunglasses or anything covering your face and try again.";

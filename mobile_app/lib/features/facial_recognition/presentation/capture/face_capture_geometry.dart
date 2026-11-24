import 'dart:math' as math;
import 'dart:ui';

/// Pure camera-geometry helpers for the Face ID scan screen. Nothing here
/// touches the camera, a frame or a face image — only sizes and rectangles —
/// so every transform is unit-testable without a device.
///
/// Terminology
///  * raw size   — `CameraImage.width/height` as delivered by the sensor
///                 (landscape on almost every phone).
///  * upright    — the raw size after the ML Kit rotation is applied. ML Kit
///                 returns bounding boxes in THIS coordinate space.
///  * preview    — the on-screen rectangle the camera texture is painted into.

/// Size of a frame after rotating it by [rotationDegrees] (0/90/180/270).
Size uprightSize(Size raw, int rotationDegrees) {
  final quarter = (rotationDegrees ~/ 90).isOdd;
  return quarter ? Size(raw.height, raw.width) : raw;
}

/// Natural aspect ratio (width / height) of the previewed image in portrait.
/// [sensorSize] is `CameraController.value.previewSize` (landscape, as
/// reported by the plugin) — the portrait ratio is its inverse. Falls back to
/// 3:4 when the size is unknown or degenerate.
double portraitPreviewAspect(Size? sensorSize) {
  if (sensorSize == null || sensorSize.width <= 0 || sensorSize.height <= 0) return 3 / 4;
  final w = math.min(sensorSize.width, sensorSize.height);
  final h = math.max(sensorSize.width, sensorSize.height);
  return w / h;
}

/// Largest rectangle of [aspect] (w/h) that fits inside [available] without
/// distortion (contain). Never stretches.
Size fitAspect(Size available, double aspect) {
  if (available.width <= 0 || available.height <= 0 || aspect <= 0) return Size.zero;
  var w = available.width;
  var h = w / aspect;
  if (h > available.height) {
    h = available.height;
    w = h * aspect;
  }
  return Size(w, h);
}

/// Ratio of the face width to the UPRIGHT frame width — the same signal as the
/// web's `faceWidthRatio`. The raw sensor width must not be used: on a
/// portrait phone it is the image HEIGHT, which under-reports the ratio.
double faceWidthRatio(Rect faceBox, Size upright) => upright.width <= 0 ? 0 : faceBox.width / upright.width;

/// Maps a rectangle from upright image coordinates into [preview] coordinates.
/// The preview shows the whole image (aspect-matched), so this is a pure
/// scale. When [mirrored] (front camera) the x axis is flipped so the box
/// lines up with the mirrored preview the user sees.
Rect mapToPreview(Rect box, Size upright, Size preview, {required bool mirrored}) {
  if (upright.width <= 0 || upright.height <= 0) return Rect.zero;
  final sx = preview.width / upright.width;
  final sy = preview.height / upright.height;
  final left = mirrored ? (upright.width - box.right) * sx : box.left * sx;
  final right = mirrored ? (upright.width - box.left) * sx : box.right * sx;
  return Rect.fromLTRB(left, box.top * sy, right, box.bottom * sy);
}

/// The framing oval, as fractions of the preview. Same numbers as the web's
/// GUIDE (guide.ts): 0.44 of a 4:3 stage's width by 0.80 of its height,
/// centred — an oval of width/height ≈ 0.733, i.e. taller than wide like a
/// face, not the near-circular shape that made the user move too far away.
const double kGuideWidthFraction = 0.44;
const double kGuideHeightFraction = 0.80;
const _kWebStageAspect = 4 / 3;

/// Oval rectangle inside a preview of [preview] size. The guide keeps the
/// web's face proportion even when the preview is portrait (3:4): its
/// height follows the preview height and its width is derived from the web's
/// width/height ratio, so it is never stretched.
Rect guideOval(Size preview) {
  const ovalAspect = (kGuideWidthFraction * _kWebStageAspect) / kGuideHeightFraction; // ≈ 0.733
  var h = preview.height * kGuideHeightFraction;
  var w = h * ovalAspect;
  final maxW = preview.width * 0.86;
  if (w > maxW) {
    w = maxW;
    h = w / ovalAspect;
  }
  return Rect.fromCenter(center: preview.center(Offset.zero), width: w, height: h);
}

/// True when the centre of [faceInPreview] lies inside the guide ellipse
/// (web `faceInsideGuide`). [slack] widens the ellipse so a slightly
/// off-centre face is not rejected.
bool faceCentreInsideGuide(Rect faceInPreview, Rect guide, {double slack = 1.15}) {
  if (guide.isEmpty) return true;
  final c = faceInPreview.center;
  final rx = guide.width / 2 * slack;
  final ry = guide.height / 2 * slack;
  final dx = (c.dx - guide.center.dx) / rx;
  final dy = (c.dy - guide.center.dy) / ry;
  return dx * dx + dy * dy <= 1.0;
}

/// Mean luma (0–255) of an NV21/Y-plane buffer sampled on a coarse grid — used
/// only as a one-number "too dark" cue; nothing of the frame is kept.
double meanLuma(List<int> yPlane, {int step = 97}) {
  if (yPlane.isEmpty) return 0;
  var sum = 0;
  var n = 0;
  for (var i = 0; i < yPlane.length; i += step) {
    sum += yPlane[i];
    n++;
  }
  return n == 0 ? 0 : sum / n;
}

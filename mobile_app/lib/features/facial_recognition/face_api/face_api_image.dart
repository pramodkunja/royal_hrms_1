import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'face_api_math.dart';

// Pixel operations of the web face pipeline, reproduced on an RGBA buffer
// (the same byte layout as canvas ImageData):
//  - drawing a frame / face crop onto a canvas (grabVideoFrame, face-api.js
//    imageToSquare) — canvas drawImage with smoothing, i.e. bilinear sampling
//    at pixel centres;
//  - web lib/faceApi/clahe.ts (exact port);
//  - web lib/faceApi/frameCapture.ts luminance and eye-occlusion statistics.

/// RGBA pixels, row-major, 4 bytes per pixel.
class RgbaBuffer {
  RgbaBuffer(this.width, this.height, this.data) : assert(data.length == width * height * 4);
  factory RgbaBuffer.blank(int width, int height) => RgbaBuffer(width, height, Uint8List(width * height * 4));

  /// From a decoded photo, honouring its EXIF orientation (what a browser
  /// shows for a video frame is always upright).
  factory RgbaBuffer.fromImage(img.Image source) {
    final upright = img.bakeOrientation(source);
    final rgba = upright.convert(format: img.Format.uint8, numChannels: 4, alpha: 255);
    return RgbaBuffer(rgba.width, rgba.height, Uint8List.fromList(rgba.getBytes(order: img.ChannelOrder.rgba)));
  }

  final int width;
  final int height;
  final Uint8List data;

  /// Integer-rectangle copy (canvas getImageData/putImageData — face-api.js
  /// extractFaces). The box must already be clipped and floored.
  RgbaBuffer crop(FaBox box) {
    final x0 = box.x.toInt(), y0 = box.y.toInt(), w = box.width.toInt(), h = box.height.toInt();
    final out = RgbaBuffer.blank(w, h);
    for (var y = 0; y < h; y++) {
      final src = ((y0 + y) * width + x0) * 4;
      out.data.setRange(y * w * 4, (y + 1) * w * 4, data, src);
    }
    return out;
  }
}

/// Bilinear sample of channel [c] at source coordinate (sx, sy) in pixel
/// units with pixel centres at +0.5 — clamped at the edges.
double _bilinear(RgbaBuffer s, double sx, double sy, int c) {
  final fx = sx - 0.5, fy = sy - 0.5;
  var x0 = fx.floor(), y0 = fy.floor();
  final ax = fx - x0, ay = fy - y0;
  int cx(int x) => x < 0 ? 0 : (x >= s.width ? s.width - 1 : x);
  int cy(int y) => y < 0 ? 0 : (y >= s.height ? s.height - 1 : y);
  final xa = cx(x0), xb = cx(x0 + 1), ya = cy(y0), yb = cy(y0 + 1);
  final d = s.data;
  final p00 = d[(ya * s.width + xa) * 4 + c];
  final p10 = d[(ya * s.width + xb) * 4 + c];
  final p01 = d[(yb * s.width + xa) * 4 + c];
  final p11 = d[(yb * s.width + xb) * 4 + c];
  final top = p00 + (p10 - p00) * ax;
  final bottom = p01 + (p11 - p01) * ax;
  return top + (bottom - top) * ay;
}

/// web grabVideoFrame(video, canvas, maxWidth): the frame redrawn at most
/// [maxWidth] wide (aspect kept, rounded dimensions).
RgbaBuffer scaleToMaxWidth(RgbaBuffer src, int maxWidth) {
  if (src.width <= maxWidth) return RgbaBuffer(src.width, src.height, Uint8List.fromList(src.data));
  final scale = maxWidth / src.width;
  final w = (src.width * scale).round();
  final h = (src.height * scale).round();
  final out = RgbaBuffer.blank(w, h);
  final sx = src.width / w, sy = src.height / h;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      for (var c = 0; c < 3; c++) {
        out.data[o + c] = _bilinear(src, (x + 0.5) * sx, (y + 0.5) * sy, c).round().clamp(0, 255);
      }
      out.data[o + 3] = 255;
    }
  }
  return out;
}

/// face-api.js dom/imageToSquare(input, size, center) + tf.browser.fromPixels:
/// the image scaled so its longer side is [size], drawn at the top-left (or
/// centred on the shorter axis when [center]) on a transparent square, read
/// back as RGB floats 0..255 (undrawn pixels are 0). Returns size×size×3.
Float32List imageToSquareRgb(RgbaBuffer src, int size, {required bool center}) {
  final scale = size / math.max(src.height, src.width);
  final w = scale * src.width;
  final h = scale * src.height;
  final offset = (w - h).abs() / 2;
  final dx = center && w < h ? offset : 0.0;
  final dy = center && h < w ? offset : 0.0;
  final out = Float32List(size * size * 3);
  for (var y = 0; y < size; y++) {
    final py = y + 0.5;
    if (py < dy || py >= dy + h) continue;
    for (var x = 0; x < size; x++) {
      final px = x + 0.5;
      if (px < dx || px >= dx + w) continue;
      final sx = (px - dx) / scale, sy = (py - dy) / scale;
      final o = (y * size + x) * 3;
      if (scale == 1) {
        final i = ((sy.floor()) * src.width + sx.floor()) * 4;
        out[o] = src.data[i].toDouble();
        out[o + 1] = src.data[i + 1].toDouble();
        out[o + 2] = src.data[i + 2].toDouble();
      } else {
        // Canvas stores 8-bit pixels; fromPixels reads those bytes back.
        out[o] = _bilinear(src, sx, sy, 0).round().clamp(0, 255).toDouble();
        out[o + 1] = _bilinear(src, sx, sy, 1).round().clamp(0, 255).toDouble();
        out[o + 2] = _bilinear(src, sx, sy, 2).round().clamp(0, 255).toDouble();
      }
    }
  }
  return out;
}

// ── web lib/faceApi/clahe.ts (exact port: tile 32, clip 3.0) ───────────────

const _kTile = 32;
const _kClip = 3.0;
const _kBins = 256;

int _roundJs(double v) => (v + 0.5).floor(); // JS Math.round (half up)
int _clampByte(double v) => math.min(255, math.max(0, _roundJs(v)));

/// applyClahe(buffer) — in place, returns the buffer.
RgbaBuffer applyClahe(RgbaBuffer b, {int tileSize = _kTile, double clipLimit = _kClip}) {
  final width = b.width, height = b.height, data = b.data;
  if (width <= 0 || height <= 0) return b;
  final lum = Float32List(width * height);
  for (var i = 0, p = 0; i < lum.length; i++, p += 4) {
    lum[i] = 0.299 * data[p] + 0.587 * data[p + 1] + 0.114 * data[p + 2];
  }
  final tilesX = math.max(1, (width / tileSize).ceil());
  final tilesY = math.max(1, (height / tileSize).ceil());
  final mappings = List<Uint8List>.generate(tilesX * tilesY, (i) {
    final tx = i % tilesX, ty = i ~/ tilesX;
    final x0 = tx * tileSize, y0 = ty * tileSize;
    final x1 = math.min(x0 + tileSize, width), y1 = math.min(y0 + tileSize, height);
    final hist = Float64List(_kBins);
    var count = 0;
    for (var y = y0; y < y1; y++) {
      for (var x = x0; x < x1; x++) {
        hist[math.min(_kBins - 1, math.max(0, _roundJs(lum[y * width + x])))] += 1;
        count++;
      }
    }
    final mapping = Uint8List(_kBins);
    if (count == 0) {
      for (var k = 0; k < _kBins; k++) {
        mapping[k] = k;
      }
      return mapping;
    }
    final clip = clipLimit * (count / _kBins);
    var excess = 0.0;
    for (var k = 0; k < _kBins; k++) {
      if (hist[k] > clip) {
        excess += hist[k] - clip;
        hist[k] = clip;
      }
    }
    final redistribution = excess / _kBins;
    var cumulative = 0.0;
    for (var k = 0; k < _kBins; k++) {
      hist[k] += redistribution;
      cumulative += hist[k];
      mapping[k] = math.min(255, math.max(0, _roundJs(((_kBins - 1) * cumulative) / count)));
    }
    return mapping;
  });
  for (var y = 0; y < height; y++) {
    final ty = y / tileSize - 0.5;
    final ty0 = math.min(tilesY - 1, math.max(0, ty.floor()));
    final ty1 = math.min(tilesY - 1, math.max(0, ty0 + 1));
    final wy = math.min(1.0, math.max(0.0, ty - ty.floor()));
    for (var x = 0; x < width; x++) {
      final tx = x / tileSize - 0.5;
      final tx0 = math.min(tilesX - 1, math.max(0, tx.floor()));
      final tx1 = math.min(tilesX - 1, math.max(0, tx0 + 1));
      final wx = math.min(1.0, math.max(0.0, tx - tx.floor()));
      final oldY = lum[y * width + x];
      final bin = math.min(_kBins - 1, math.max(0, _roundJs(oldY)));
      final m00 = mappings[ty0 * tilesX + tx0][bin];
      final m10 = mappings[ty0 * tilesX + tx1][bin];
      final m01 = mappings[ty1 * tilesX + tx0][bin];
      final m11 = mappings[ty1 * tilesX + tx1][bin];
      final top = m00 * (1 - wx) + m10 * wx;
      final bottom = m01 * (1 - wx) + m11 * wx;
      final newY = top * (1 - wy) + bottom * wy;
      final scale = oldY > 1 ? newY / oldY : 1.0;
      final p = (y * width + x) * 4;
      data[p] = _clampByte(data[p] * scale);
      data[p + 1] = _clampByte(data[p + 1] * scale);
      data[p + 2] = _clampByte(data[p + 2] * scale);
    }
  }
  return b;
}

// ── web lib/faceApi/frameCapture.ts ────────────────────────────────────────

({double mean, double stdDev}) _lumStats(RgbaBuffer b, FaBox box) {
  final x0 = math.max(0, box.x.floor());
  final y0 = math.max(0, box.y.floor());
  final x1 = math.min(b.width, box.right.ceil());
  final y1 = math.min(b.height, box.bottom.ceil());
  if (x1 <= x0 || y1 <= y0) return (mean: 0, stdDev: 0);
  var sum = 0.0, sq = 0.0;
  var n = 0;
  for (var y = y0; y < y1; y++) {
    for (var x = x0; x < x1; x++) {
      final p = (y * b.width + x) * 4;
      final l = 0.299 * b.data[p] + 0.587 * b.data[p + 1] + 0.114 * b.data[p + 2];
      sum += l;
      sq += l * l;
      n++;
    }
  }
  final mean = sum / n;
  return (mean: mean, stdDev: math.sqrt(math.max(0, sq / n - mean * mean)));
}

/// meanLuminanceOfBox.
double meanLuminanceOfBox(RgbaBuffer b, FaBox box) => _lumStats(b, box).mean;

FaBox _bboxOf(List<FaPoint> pts) {
  final xs = pts.map((p) => p.x), ys = pts.map((p) => p.y);
  final x = xs.reduce(math.min), y = ys.reduce(math.min);
  return FaBox(x, y, xs.reduce(math.max) - x, ys.reduce(math.max) - y);
}

/// assessEyeOcclusion: both eye regions dark (< 50) AND flat (std < 10).
bool eyesLookOccluded(RgbaBuffer b, List<FaPoint> leftEye, List<FaPoint> rightEye) {
  bool occluded(({double mean, double stdDev}) s) => s.mean < 50 && s.stdDev < 10;
  return occluded(_lumStats(b, _bboxOf(leftEye))) && occluded(_lumStats(b, _bboxOf(rightEye)));
}

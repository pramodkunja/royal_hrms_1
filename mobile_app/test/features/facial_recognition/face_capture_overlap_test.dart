import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_image.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_nets.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_pipeline.dart';

/// Reference = the previous, straightforward scaler (per-pixel bilinear).
RgbaBuffer _referenceScale(RgbaBuffer src, int maxWidth) {
  final scale = maxWidth / src.width;
  final w = (src.width * scale).round(), h = (src.height * scale).round();
  final out = RgbaBuffer.blank(w, h);
  final sx = src.width / w, sy = src.height / h;
  double bil(double px, double py, int c) {
    final fx = px - 0.5, fy = py - 0.5;
    final x0 = fx.floor(), y0 = fy.floor();
    final ax = fx - x0, ay = fy - y0;
    int cx(int x) => x < 0 ? 0 : (x >= src.width ? src.width - 1 : x);
    int cy(int y) => y < 0 ? 0 : (y >= src.height ? src.height - 1 : y);
    int p(int x, int y) => src.data[(cy(y) * src.width + cx(x)) * 4 + c];
    final top = p(x0, y0) + (p(x0 + 1, y0) - p(x0, y0)) * ax;
    final bottom = p(x0, y0 + 1) + (p(x0 + 1, y0 + 1) - p(x0, y0 + 1)) * ax;
    return top + (bottom - top) * ay;
  }

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final o = (y * w + x) * 4;
      for (var c = 0; c < 3; c++) {
        out.data[o + c] = bil((x + 0.5) * sx, (y + 0.5) * sy, c).round().clamp(0, 255);
      }
      out.data[o + 3] = 255;
    }
  }
  return out;
}

class _Nets implements FaceApiNets {
  @override
  Future<Float32List> detect(Float32List rgb224) async => Float32List(7 * 7 * 25);
  @override
  Future<Float32List> landmarks(Float32List rgb112) async => Float32List(136);
  @override
  Future<Float32List> describe(Float32List rgb150) async => Float32List(128);
  @override
  Future<void> dispose() async {}
}

/// A pipeline whose per-frame outcome is scripted (no networks needed).
class _Scripted extends FaceApiPipeline {
  _Scripted(this.script) : super(_Nets());
  final List<FrameAttempt> script;
  final order = <int>[];
  int active = 0, maxActive = 0;
  @override
  Future<FrameAttempt> analyzeFrame(RgbaBuffer raw,
      {bool normalizeLighting = true, bool prepared = false, FaceApiStageTimes? times}) async {
    final i = raw.width; // frame index smuggled in the width
    order.add(i);
    active++;
    maxActive = math.max(maxActive, active);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    active--;
    return script[i % script.length];
  }
}

RgbaBuffer _frame(int i) => RgbaBuffer(i, 1, Uint8List(i * 4));

FrameAttempt _good(double v) => FrameAttempt(descriptor: List<double>.filled(128, v));

void main() {
  test('faster scaler is byte-identical to the reference per-pixel bilinear', () {
    final r = math.Random(7);
    final src = RgbaBuffer.blank(1203, 677);
    for (var i = 0; i < src.data.length; i++) {
      src.data[i] = r.nextInt(256);
    }
    final fast = scaleToMaxWidth(src, 800);
    final ref = _referenceScale(src, 800);
    expect((fast.width, fast.height), (ref.width, ref.height));
    expect(fast.data, ref.data);
  });

  test('overlapped capture: same count, attempt-order averaging, stills never exceed what is needed', () async {
    final p = _Scripted([_good(0.10), _good(0.12), _good(0.11), _good(0.50)]);
    var taken = 0;
    final out = await p.capture(
      nextFrame: () async => _frame(taken++),
      framesToCapture: 3,
      interval: Duration.zero,
    );
    expect(taken, 3, reason: 'no wasted extra still when every frame is good');
    expect(out.frameCount, 3);
    expect(out.descriptor!.first, closeTo((0.10 + 0.12 + 0.11) / 3, 1e-9));
    expect(p.maxActive, greaterThan(1), reason: 'analyses overlap the next capture');
  });

  test('a failed frame frees a slot: another still is taken, total attempts stay capped', () async {
    final p = _Scripted([_good(0.1), const FrameAttempt(codes: ['too_dark'], reasons: ['dark']), _good(0.1), _good(0.1)]);
    var taken = 0;
    final out = await p.capture(
      nextFrame: () async => _frame(taken++),
      framesToCapture: 3,
      interval: Duration.zero,
    );
    expect(out.descriptor, isNotNull);
    expect(taken, 4);
  });

  test('never more than 4× attempts; failure message is the last specific reason', () async {
    final p = _Scripted([const FrameAttempt(codes: ['x'], reasons: ['first']), const FrameAttempt(codes: ['y'], reasons: ['last'])]);
    var taken = 0;
    final out = await p.capture(
      nextFrame: () async => _frame(taken++),
      framesToCapture: 2,
      interval: Duration.zero,
    );
    expect(out.descriptor, isNull);
    expect(taken, 8);
    expect(out.message, 'last');
  });

  test('inconsistent frames are still refused (0.35 rule unchanged)', () async {
    final p = _Scripted([_good(0.0), _good(0.5), _good(0.0)]);
    var taken = 0;
    final out = await p.capture(
      nextFrame: () async => _frame(taken++),
      framesToCapture: 3,
      interval: Duration.zero,
    );
    expect(out.descriptor, isNull);
    expect(out.message, contains("didn't quite agree"));
  });

  test('stills are never started closer together than the interval', () async {
    final p = _Scripted([_good(0.1)]);
    final stamps = <int>[];
    final sw = Stopwatch()..start();
    await p.capture(
      nextFrame: () async {
        stamps.add(sw.elapsedMilliseconds);
        return _frame(stamps.length - 1);
      },
      framesToCapture: 3,
      interval: const Duration(milliseconds: 120),
    );
    for (var i = 1; i < stamps.length; i++) {
      expect(stamps[i] - stamps[i - 1], greaterThanOrEqualTo(110));
    }
  });

  test('one camera operation at a time: still captures never overlap each other', () async {
    final p = _Scripted([_good(0.1)]);
    var inCapture = 0, maxInCapture = 0, taken = 0;
    await p.capture(
      nextFrame: () async {
        inCapture++;
        maxInCapture = math.max(maxInCapture, inCapture);
        await Future<void>.delayed(const Duration(milliseconds: 15));
        inCapture--;
        return _frame(taken++);
      },
      framesToCapture: 4,
      interval: Duration.zero,
    );
    expect(maxInCapture, 1);
  });

  test('a cancel while stills are in flight yields no descriptor (nothing stale is returned)', () async {
    final p = _Scripted([_good(0.1)]);
    var cancelled = false, taken = 0;
    final out = await p.capture(
      nextFrame: () async {
        final f = _frame(taken++);
        if (taken == 2) cancelled = true;
        return f;
      },
      framesToCapture: 3,
      interval: Duration.zero,
      isCancelled: () => cancelled,
    );
    expect(out.descriptor, isNull);
  });
}

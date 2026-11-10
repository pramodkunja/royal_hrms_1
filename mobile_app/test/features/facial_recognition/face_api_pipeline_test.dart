import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_image.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_math.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_nets.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_pipeline.dart';

// The capture pipeline end to end with stand-in networks (the real TFLite
// networks are validated against face-api.js separately — see
// tool/face_api_conversion/README.md): the detector stub returns a raw output
// that decodes to a chosen face box, the landmark stub a frontal 68-point
// layout, the recognition stub controllable descriptors. Exercises the real
// decoding, cropping, quality gate, attempt budget, consistency check and
// averaging.

double _logit(double p) => math.log(p / (1 - p));

const _anchor0 = (1.603231, 2.094468);

/// Raw [7×7×25] output whose single confident detection is [box] (pixels)
/// in a [w]×[h] frame drawn top-left into 224 (TinyYolov2 encoding inverted).
Float32List rawFor(List<FaBox> boxes, int w, int h, {double scoreLogit = 4}) {
  final raw = Float32List(7 * 7 * 25);
  for (var i = 4; i < raw.length; i += 5) {
    raw[i] = -12; // every anchor: no face
  }
  final r = computeReshapedDimensions(w, h, 224);
  final cfX = 224 / r.width, cfY = 224 / r.height;
  for (final b in boxes) {
    final cx = (b.x + b.width / 2) / w / cfX * 7, cy = (b.y + b.height / 2) / h / cfY * 7;
    final col = cx.floor().clamp(0, 6), row = cy.floor().clamp(0, 6);
    final base = (row * 7 + col) * 25; // anchor 0
    raw[base] = _logit((cx - col).clamp(0.01, 0.99));
    raw[base + 1] = _logit((cy - row).clamp(0.01, 0.99));
    raw[base + 2] = math.log((b.width / w) / cfX * 7 / _anchor0.$1);
    raw[base + 3] = math.log((b.height / h) / cfY * 7 / _anchor0.$2);
    raw[base + 4] = scoreLogit;
  }
  return raw;
}

/// A frontal face layout, relative to the crop (0..1).
List<FaPoint> frontalFace() => [
      for (var i = 0; i < 17; i++) FaPoint(0.1 + 0.8 * i / 16, 0.5 + 0.4 * math.sin(math.pi * i / 16)),
      for (var i = 0; i < 10; i++) FaPoint(0.2 + 0.6 * i / 9, 0.3),
      for (var i = 0; i < 4; i++) FaPoint(0.5, 0.4 + 0.06 * i), // 27-30, 30 = tip
      for (var i = 0; i < 5; i++) FaPoint(0.42 + 0.04 * i, 0.62),
      for (var i = 0; i < 6; i++)
        FaPoint(0.33 + 0.05 * math.cos(math.pi * i / 3), 0.42 + 0.02 * math.sin(math.pi * i / 3)),
      for (var i = 0; i < 6; i++)
        FaPoint(0.67 + 0.05 * math.cos(math.pi * i / 3), 0.42 + 0.02 * math.sin(math.pi * i / 3)),
      for (var i = 0; i < 20; i++)
        FaPoint(0.5 + 0.12 * math.cos(2 * math.pi * i / 20), 0.78 + 0.04 * math.sin(2 * math.pi * i / 20)),
    ];

class StubNets implements FaceApiNets {
  StubNets({required this.boxes, this.descriptors, this.scoreLogit = 4});
  List<FaBox> boxes;
  double scoreLogit;
  List<double> Function(int call)? descriptors;
  int w = 0, h = 0;
  final calls = <String>[];
  final describeInputs = <Float32List>[];
  int _desc = 0;

  @override
  Future<Float32List> detect(Float32List rgb224) async {
    calls.add('detect');
    expect(rgb224.length, 224 * 224 * 3);
    return rawFor(boxes, w, h, scoreLogit: scoreLogit);
  }

  @override
  Future<Float32List> landmarks(Float32List rgb112) async {
    calls.add('landmarks');
    expect(rgb112.length, 112 * 112 * 3);
    // Encode the frontal layout for a square-ish crop (postProcess inverse
    // for an exactly square crop: out = rel).
    final out = Float32List(136);
    final pts = frontalFace();
    for (var i = 0; i < 68; i++) {
      out[2 * i] = pts[i].x;
      out[2 * i + 1] = pts[i].y;
    }
    return out;
  }

  @override
  Future<Float32List> describe(Float32List rgb150) async {
    calls.add('describe');
    describeInputs.add(rgb150);
    final d = descriptors?.call(_desc++) ?? List<double>.generate(128, (i) => 0.01 * (i % 7) - 0.03);
    return Float32List.fromList(d);
  }

  @override
  Future<void> dispose() async {}
}

RgbaBuffer grayFrame(int w, int h, [int v = 128]) {
  final b = RgbaBuffer.blank(w, h);
  for (var i = 0; i < b.data.length; i += 4) {
    b.data[i] = b.data[i + 1] = b.data[i + 2] = v;
    b.data[i + 3] = 255;
  }
  return b;
}

Future<CaptureOutcome> run(StubNets nets, {int frames = 3, int w = 640, int h = 480, int nullFrames = 0}) {
  nets
    ..w = w
    ..h = h;
  var served = 0;
  return FaceApiPipeline(nets).capture(
    framesToCapture: frames,
    interval: Duration.zero,
    nextFrame: () async => served++ < nullFrames ? null : grayFrame(w, h),
  );
}

const goodBox = FaBox(210, 150, 220, 220); // 34% of the width, centred

void main() {
  test('good frames: 3 (clock-in) averaged into one 128-d descriptor; frame count and variance reported', () async {
    final nets = StubNets(boxes: [goodBox], descriptors: (i) => List<double>.generate(128, (k) => 0.05 + 0.001 * i));
    final out = await run(nets);
    expect(out.message, isNull);
    expect(out.descriptor, hasLength(128));
    expect(out.descriptor!.first, closeTo(0.05 + 0.001, 1e-6), reason: 'mean of 0.050, 0.051, 0.052');
    expect(out.frameCount, 3);
    expect(out.variance, greaterThan(0));
    expect(nets.calls.where((c) => c == 'describe'), hasLength(3));
    expect(nets.describeInputs.every((t) => t.length == 150 * 150 * 3), isTrue);
    expect(nets.describeInputs.first.any((v) => v > 0), isTrue, reason: 'the aligned face crop is drawn');
  });

  test('registration takes 4 frames', () async {
    final out = await run(StubNets(boxes: [goodBox]), frames: kRegistrationFramesToCapture);
    expect(out.frameCount, 4);
  });

  test('no face: gives up after framesToCapture × 4 attempts with web\'s generic message', () async {
    final nets = StubNets(boxes: [goodBox], scoreLogit: -3); // below the 0.5 detector threshold
    final out = await run(nets);
    expect(out.descriptor, isNull);
    expect(out.message,
        "Couldn't get enough clear captures — make sure you're well-lit, centered, and holding still, then try again.");
    expect(nets.calls.where((c) => c == 'detect'), hasLength(12));
    expect(nets.calls.contains('describe'), isFalse);
  });

  test('two faces: web\'s multiple-faces message', () async {
    final out = await run(StubNets(boxes: [const FaBox(40, 120, 200, 200), const FaBox(400, 120, 200, 200)]));
    expect(out.message, kMultipleFacesMessage);
  });

  test('face too far (under 20% of the width) and low detector confidence are refused with web\'s messages', () async {
    expect((await run(StubNets(boxes: [const FaBox(290, 200, 60, 60)]))).message,
        'Face too far from the camera — move closer.');
    // sigmoid(1.0) = 0.73: above the 0.5 detection threshold, below the 0.8 quality bar.
    expect((await run(StubNets(boxes: [goodBox], scoreLogit: 1.0))).message,
        'Face detection confidence too low — hold still and make sure your face is unobstructed.');
  });

  test('too dark / too bright frames are refused (luminance gate after CLAHE)', () async {
    final nets = StubNets(boxes: [goodBox])
      ..w = 640
      ..h = 480;
    final dark = await FaceApiPipeline(nets).analyzeFrame(grayFrame(640, 480, 0));
    expect(dark.codes, contains('too_dark'));
    final bright = await FaceApiPipeline(nets).analyzeFrame(grayFrame(640, 480, 255));
    expect(bright.codes, contains('too_bright'));
  });

  test('frames that disagree (> 0.35 apart) are not averaged: web\'s inconsistency message', () async {
    final out = await run(
        StubNets(boxes: [goodBox], descriptors: (i) => List<double>.generate(128, (k) => i.isEven ? 0.0 : 0.05)));
    expect(out.descriptor, isNull);
    expect(out.message, "Your captures didn't quite agree with each other — hold still and try again.");
  });

  test('a frame that could not be taken counts as a failed attempt; enough good ones still succeed', () async {
    final out = await run(StubNets(boxes: [goodBox]), nullFrames: 2);
    expect(out.frameCount, 3);
  });

  test('large frames are scaled to 800 px wide before detection (face width ratio measured on that frame)', () async {
    // The detector's output is relative to the frame, so the same face is
    // found on the 800 px frame the pipeline actually works on.
    final nets = StubNets(boxes: [const FaBox(420, 300, 440, 440)]);
    final out = await run(nets, w: 1280, h: 960);
    expect(out.message, isNull);
    expect(out.frameCount, 3);
    expect(scaleToMaxWidth(grayFrame(1280, 960), kCaptureMaxFrameWidth).width, 800);
  });
}

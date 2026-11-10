import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_image.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_math.dart';

// The pure-Dart port of the web face pipeline, checked against expected values
// produced by the REAL code: the web app's own lib/faceApi/clahe.ts,
// qualityGate.ts and frameCapture.ts (imported unchanged by Node) and the real
// face-api.js 0.22.2 (its locateFaces decode + NMS, FaceLandmark68Net
// postProcess, FaceLandmarks68.shiftBy/align({useDlibAlignment}),
// Box.clipAtImageBorders). Generator: tool/face_api_conversion/make_fixtures.mjs.

late Map<String, dynamic> fx;

List<double> nums(Object? l) => [for (final v in l as List) (v as num).toDouble()];

void main() {
  setUpAll(() {
    fx = jsonDecode(File('test/features/facial_recognition/fixtures/face_api_fixtures.json').readAsStringSync())
        as Map<String, dynamic>;
  });

  test('CLAHE = web clahe.ts, byte for byte (incl. partial tiles, dark, bright, 1×1)', () {
    for (final c in fx['clahe'] as List) {
      final w = c['width'] as int, h = c['height'] as int;
      final buf = RgbaBuffer(w, h, Uint8List.fromList([for (final v in c['input'] as List) v as int]));
      applyClahe(buf);
      expect(buf.data, [for (final v in c['output'] as List) v as int], reason: '${w}x$h');
    }
  });

  test('Tiny Face Detector decode + NMS = face-api.js locateFaces (scores, boxes, crop boxes)', () {
    var faces = 0;
    for (final c in fx['detect'] as List) {
      final w = c['width'] as int, h = c['height'] as int;
      final got = decodeTinyFaceDetector(Float32List.fromList(nums(c['raw'])), imageWidth: w, imageHeight: h);
      final want = c['faces'] as List;
      expect(got.length, want.length, reason: '${w}x$h');
      for (var i = 0; i < got.length; i++) {
        final e = want[i] as Map;
        expect(got[i].score, closeTo((e['score'] as num).toDouble(), 1e-6));
        final b = got[i].box, eb = nums(e['box']);
        for (final (a, x) in [(b.x, eb[0]), (b.y, eb[1]), (b.width, eb[2]), (b.height, eb[3])]) {
          expect(a, closeTo(x, 1e-3), reason: 'box ${w}x$h #$i');
        }
        final cb = b.floor().clipAtImageBorders(w, h), ecb = nums(e['cropBox']);
        expect([cb.x, cb.y, cb.width, cb.height], ecb, reason: 'crop ${w}x$h #$i');
        faces++;
      }
    }
    expect(faces, greaterThan(100));
  });

  test('landmarks: postProcess + shift = face-api.js; dlib box and its clip are identical; frontality = web', () {
    for (final c in fx['landmarks'] as List) {
      final rel = landmarkRelativePositions(Float32List.fromList(nums(c['raw'])),
          cropWidth: c['cropW'] as int, cropHeight: c['cropH'] as int);
      final shift = nums(c['shift']);
      final m = FaceLandmarks68(rel, c['cropW'] as int, c['cropH'] as int, FaPoint(shift[0], shift[1]));
      final want = c['positions'] as List;
      for (var i = 0; i < 68; i++) {
        final p = nums(want[i]);
        expect(m.positions[i].x, closeTo(p[0], 1e-3));
        expect(m.positions[i].y, closeTo(p[1], 1e-3));
      }
      final d = m.alignDlib();
      expect([d.x, d.y, d.width, d.height], nums(c['dlib']));
      final clip = d.clipAtImageBorders(c['frameW'] as int, c['frameH'] as int);
      expect([clip.x, clip.y, clip.width, clip.height], nums(c['clipped']));
      expect(computeFrontality(m.leftEye, m.rightEye, m.nose[3]), closeTo((c['frontality'] as num).toDouble(), 1e-6));
    }
  });

  test('quality gate codes, eye-occlusion and luminance = web qualityGate.ts / frameCapture.ts', () {
    for (final c in fx['quality'] as List) {
      if (c['metrics'] != null) {
        final m = c['metrics'] as Map;
        final got = assessFrameQuality(FrameQualityMetrics(
          detectionScore: (m['detectionScore'] as num).toDouble(),
          faceWidthRatio: (m['faceWidthRatio'] as num).toDouble(),
          frontality: (m['frontality'] as num).toDouble(),
          meanLuminance: (m['meanLuminance'] as num).toDouble(),
        ));
        expect([for (final g in got) g.code], c['codes']);
      } else {
        final im = c['eyeImage'] as Map;
        final buf = RgbaBuffer(im['width'] as int, im['height'] as int,
            Uint8List.fromList([for (final v in im['data'] as List) v as int]));
        List<FaPoint> pts(Object l) => [for (final p in l as List) FaPoint(nums(p)[0], nums(p)[1])];
        expect(eyesLookOccluded(buf, pts(c['leftEye']), pts(c['rightEye'])), c['occluded']);
        expect(meanLuminanceOfBox(buf, const FaBox(3.4, 2.2, 30.5, 20.9)),
            closeTo((c['meanLum'] as num).toDouble(), 1e-9));
      }
    }
  });

  test('multi-frame consistency (0.35) and averaging = web', () {
    for (final c in fx['combine'] as List) {
      final ds = [for (final d in c['descriptors'] as List) nums(d)];
      final r = assessCaptureConsistency(ds, kMaxIntraCaptureDistance);
      expect(r.passed, c['passed']);
      expect(r.mean, closeTo((c['mean'] as num).toDouble(), 1e-12));
      expect(r.max, closeTo((c['max'] as num).toDouble(), 1e-12));
      final avg = averageDescriptors(ds), want = nums(c['average']);
      for (var i = 0; i < avg.length; i++) {
        expect(avg[i], closeTo(want[i], 1e-12));
      }
    }
  });
}

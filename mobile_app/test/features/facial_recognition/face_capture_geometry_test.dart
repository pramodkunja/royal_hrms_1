import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_geometry.dart';

void main() {
  group('upright size / preview aspect', () {
    test('90/270 rotation swaps the raw sensor dimensions, 0/180 does not', () {
      const raw = Size(640, 480);
      expect(uprightSize(raw, 90), const Size(480, 640));
      expect(uprightSize(raw, 270), const Size(480, 640));
      expect(uprightSize(raw, 0), raw);
      expect(uprightSize(raw, 180), raw);
    });

    test('portrait aspect is the inverse of the landscape sensor size, any ratio', () {
      expect(portraitPreviewAspect(const Size(640, 480)), closeTo(0.75, 1e-9));
      expect(portraitPreviewAspect(const Size(1280, 720)), closeTo(9 / 16, 1e-9));
      expect(portraitPreviewAspect(const Size(480, 640)), closeTo(0.75, 1e-9)); // already portrait
      expect(portraitPreviewAspect(null), 0.75);
      expect(portraitPreviewAspect(Size.zero), 0.75);
    });

    test('fitAspect never stretches and never overflows', () {
      for (final avail in const [Size(320, 400), Size(393, 900), Size(360, 300), Size(430, 500)]) {
        final fit = fitAspect(avail, 0.75);
        expect(fit.width / fit.height, closeTo(0.75, 1e-9));
        expect(fit.width, lessThanOrEqualTo(avail.width + 1e-9));
        expect(fit.height, lessThanOrEqualTo(avail.height + 1e-9));
      }
    });
  });

  group('face width ratio', () {
    test('uses the UPRIGHT width, not the raw sensor width', () {
      const raw = Size(640, 480); // landscape sensor
      final upright = uprightSize(raw, 270); // 480 x 640
      const face = Rect.fromLTWH(100, 100, 192, 240);
      expect(faceWidthRatio(face, upright), closeTo(0.4, 1e-9));
      // The old (buggy) denominator would have said 0.3.
      expect(face.width / raw.width, closeTo(0.3, 1e-9));
    });
  });

  group('mapToPreview', () {
    const upright = Size(480, 640);
    const preview = Size(240, 320);

    test('scales uniformly when aspect matches', () {
      final r = mapToPreview(const Rect.fromLTWH(48, 64, 96, 128), upright, preview, mirrored: false);
      expect(r, const Rect.fromLTWH(24, 32, 48, 64));
    });

    test('front camera: x is mirrored, y untouched; left/right/up/down verified', () {
      // A face in the image's LEFT third appears in the RIGHT third of the mirrored preview.
      const left = Rect.fromLTWH(0, 0, 100, 100);
      final m = mapToPreview(left, upright, preview, mirrored: true);
      expect(m.right, closeTo(preview.width, 1e-9));
      expect(m.left, closeTo(preview.width - 50, 1e-9));
      expect(m.top, 0);
      // Up stays up.
      final top = mapToPreview(const Rect.fromLTWH(190, 0, 100, 100), upright, preview, mirrored: true);
      final bottom = mapToPreview(const Rect.fromLTWH(190, 540, 100, 100), upright, preview, mirrored: true);
      expect(top.center.dy, lessThan(bottom.center.dy));
    });

    test('mirroring twice is the identity (round trip)', () {
      const box = Rect.fromLTWH(60, 120, 200, 250);
      final once = mapToPreview(box, upright, upright, mirrored: true);
      final twice = mapToPreview(once, upright, upright, mirrored: true);
      expect(twice.left, closeTo(box.left, 1e-9));
      expect(twice.right, closeTo(box.right, 1e-9));
    });

    test('works for any sensor aspect (16:9)', () {
      const up = Size(720, 1280);
      final pv = fitAspect(const Size(360, 800), portraitPreviewAspect(const Size(1280, 720)));
      final r = mapToPreview(const Rect.fromLTWH(0, 0, 720, 1280), up, pv, mirrored: false);
      expect(r.size.width, closeTo(pv.width, 1e-9));
      expect(r.size.height, closeTo(pv.height, 1e-9));
    });
  });

  group('guide oval', () {
    test('keeps the web face proportion (~0.733) on every preview size and is centred', () {
      for (final pv in const [Size(240, 320), Size(300, 400), Size(360, 480), Size(200, 355)]) {
        final o = guideOval(pv);
        expect(o.width / o.height, closeTo(0.733, 0.01), reason: '$pv');
        expect(o.center.dx, closeTo(pv.width / 2, 1e-9));
        expect(o.center.dy, closeTo(pv.height / 2, 1e-9));
        expect(o.left, greaterThanOrEqualTo(0));
        expect(o.right, lessThanOrEqualTo(pv.width));
        expect(o.top, greaterThanOrEqualTo(0));
        expect(o.bottom, lessThanOrEqualTo(pv.height));
      }
    });

    test('centre-inside test: centred face passes, face in a corner fails', () {
      const pv = Size(300, 400);
      final o = guideOval(pv);
      expect(faceCentreInsideGuide(Rect.fromCenter(center: const Offset(150, 200), width: 120, height: 150), o), isTrue);
      expect(faceCentreInsideGuide(Rect.fromCenter(center: const Offset(20, 20), width: 60, height: 80), o), isFalse);
      expect(faceCentreInsideGuide(Rect.fromCenter(center: const Offset(290, 390), width: 60, height: 80), o), isFalse);
    });
  });

  test('meanLuma samples only brightness and handles empty input', () {
    expect(meanLuma(const []), 0);
    expect(meanLuma(List.filled(1000, 200)), 200);
    expect(meanLuma(List.filled(1000, 10)), 10);
  });
}

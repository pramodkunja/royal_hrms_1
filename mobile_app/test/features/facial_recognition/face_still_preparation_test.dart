import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_app/features/facial_recognition/face_api/face_api_image.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_pipeline.dart';

Uint8List _jpeg({int w = 1000, int h = 500, int? exifOrientation}) {
  final image = img.Image(width: w, height: h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // left half red, right half blue; top bright, bottom dark (asymmetric on both axes)
      final v = y < h / 2 ? 220 : 90;
      image.setPixelRgb(x, y, x < w / 2 ? v : 20, 30, x < w / 2 ? 20 : v);
    }
  }
  if (exifOrientation != null) image.exif.imageIfd.orientation = exifOrientation;
  return Uint8List.fromList(img.encodeJpg(image, quality: 95));
}

({int r, int g, int b}) _px(RgbaBuffer b, int x, int y) {
  final i = (y * b.width + x) * 4;
  return (r: b.data[i], g: b.data[i + 1], b: b.data[i + 2]);
}

void main() {
  test('stills are scaled to 800 px wide, aspect kept', () {
    final f = prepareStillJpeg(_jpeg(), normalizeLighting: false)!;
    expect((f.width, f.height), (800, 400));
  });

  test('NO mirroring: a still keeps left as left and top as top (nothing flips the image)', () {
    final f = prepareStillJpeg(_jpeg(), normalizeLighting: false)!;
    final left = _px(f, 100, 100), right = _px(f, 700, 100);
    expect(left.r, greaterThan(left.b));
    expect(right.b, greaterThan(right.r));
    expect(_px(f, 100, 50).r, greaterThan(_px(f, 100, 350).r)); // top brighter than bottom
  });

  test('EXIF orientation is honoured (portrait phone photo stored rotated)', () {
    // orientation 6 = rotate 90° clockwise to display; a 1000x500 file shows as 500x1000.
    final f = prepareStillJpeg(_jpeg(exifOrientation: 6), normalizeLighting: false)!;
    expect(f.height, greaterThan(f.width));
  });

  test('off-UI-isolate preparation is byte-identical to the in-process path', () async {
    final bytes = _jpeg();
    final inProcess = prepareStillJpeg(bytes)!;
    final worker = (await prepareStillOffUi(bytes))!;
    expect((worker.width, worker.height), (inProcess.width, inProcess.height));
    expect(worker.data, inProcess.data);
  });

  test('prepared == the original raw → scale → CLAHE steps, so descriptors are unchanged by the optimisation', () {
    final decoded = img.decodeImage(_jpeg())!;
    final manual = applyClahe(scaleToMaxWidth(RgbaBuffer.fromImage(decoded), kCaptureMaxFrameWidth));
    final prepared = prepareStillJpeg(_jpeg())!;
    expect(prepared.data, manual.data);
  });

  test('garbage bytes are not an image (counts as a failed attempt, never throws)', () {
    expect(prepareStillJpeg(Uint8List.fromList([1, 2, 3])), isNull);
  });
}

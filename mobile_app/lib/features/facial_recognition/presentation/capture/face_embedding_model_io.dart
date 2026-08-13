import 'dart:io';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// On-device face embedding — the backend has no endpoint that accepts an
/// image or computes anything server-side, it only ever accepts an
/// already-computed float vector (exactly like the web app's face-api.js
/// output). Mobile has no browser, so this runs a bundled MobileFaceNet
/// model (assets/models/mobilefacenet.tflite, ~5MB) entirely on-device.
///
/// Not numerically compatible with face-api.js's embeddings — different
/// model, different training data. An employee registering on mobile can
/// only be verified on mobile (and vice versa for web); the two platforms
/// don't share a descriptor space. That's a deliberate, accepted tradeoff
/// for not requiring any backend change (see project decision, 2026-08-13).
class MobileFaceNetEmbedder {
  static const _assetPath = 'assets/models/mobilefacenet.tflite';
  static const _inputSize = 112;
  static const _outputSize = 192;
  // Fraction of the detected face box added as padding on every side before
  // cropping — MobileFaceNet was trained on faces with a little headroom,
  // not a tight crop exactly matching the detector's box.
  static const _boxPaddingFraction = 0.18;

  Interpreter? _interpreter;

  Future<void> _ensureLoaded() async {
    if (_interpreter != null) return;
    _interpreter = await Interpreter.fromAsset(_assetPath);
  }

  /// Runs inference for the face at [faceBoundingBox] (already detected via
  /// ML Kit against this same file) inside the image at [imagePath].
  /// Returns a 192-length embedding.
  Future<List<double>> embed(String imagePath, Rect faceBoundingBox) async {
    await _ensureLoaded();

    final bytes = await File(imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode the captured image.');
    }

    final padX = faceBoundingBox.width * _boxPaddingFraction;
    final padY = faceBoundingBox.height * _boxPaddingFraction;
    final x = (faceBoundingBox.left - padX).clamp(0, decoded.width - 1).round();
    final y = (faceBoundingBox.top - padY).clamp(0, decoded.height - 1).round();
    final width = (faceBoundingBox.width + padX * 2).clamp(1, decoded.width - x).round();
    final height = (faceBoundingBox.height + padY * 2).clamp(1, decoded.height - y).round();

    final cropped = img.copyCrop(decoded, x: x, y: y, width: width, height: height);
    final resized = img.copyResize(cropped, width: _inputSize, height: _inputSize);

    // MobileFaceNet's expected preprocessing: per-channel (pixel - 128) / 128.
    final input = List.generate(
      1,
      (_) => List.generate(
        _inputSize,
        (row) => List.generate(_inputSize, (col) {
          final pixel = resized.getPixel(col, row);
          return [
            (pixel.r - 128) / 128,
            (pixel.g - 128) / 128,
            (pixel.b - 128) / 128,
          ];
        }),
      ),
    );

    final output = List.generate(1, (_) => List.filled(_outputSize, 0.0));
    _interpreter!.run(input, output);
    return List<double>.from(output[0]);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

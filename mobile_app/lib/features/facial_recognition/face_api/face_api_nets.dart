import 'dart:typed_data';

// The three face-api.js 0.22.2 networks the web app loads from
// frontend/public/models (pinned commit a86f011d — see that folder's README),
// converted op-for-op to TFLite from the SAME weight files (conversion scripts
// and equivalence checks: tool/face_api_conversion/). Inputs are raw RGB
// squares in 0..255 (each model subtracts its own mean and divides by 256 /
// 255 inside, exactly like face-api.js); outputs are the raw network outputs.
abstract class FaceApiNets {
  /// TinyFaceDetector: [224×224×3] → [7×7×25].
  Future<Float32List> detect(Float32List rgb224);

  /// FaceLandmark68Net: [112×112×3] → [136].
  Future<Float32List> landmarks(Float32List rgb112);

  /// FaceRecognitionNet: [150×150×3] → the 128-d descriptor.
  Future<Float32List> describe(Float32List rgb150);

  Future<void> dispose();
}

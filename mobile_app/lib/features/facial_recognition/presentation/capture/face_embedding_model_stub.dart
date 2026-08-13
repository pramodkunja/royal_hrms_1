import 'dart:ui';

/// Web build of [MobileFaceNetEmbedder] — never actually invoked, since
/// FaceCaptureController.start() bails out on kIsWeb before the embedder is
/// touched. Exists only so the web build doesn't pull in tflite_flutter,
/// which imports dart:ffi and fails to compile for web entirely. See
/// face_embedding_model.dart for the conditional export that picks this
/// file vs. face_embedding_model_io.dart per platform.
class MobileFaceNetEmbedder {
  Future<List<double>> embed(String imagePath, Rect faceBoundingBox) async {
    throw UnsupportedError('Face embedding is not supported on web.');
  }

  void dispose() {}
}

// Web can never run tflite_flutter (it needs dart:ffi, unavailable on web),
// so the real MobileFaceNet implementation is conditionally excluded from
// web builds in favor of a stub that's never actually invoked (see
// FaceCaptureController.start()'s kIsWeb early-return).
export 'face_embedding_model_stub.dart'
    if (dart.library.io) 'face_embedding_model_io.dart';

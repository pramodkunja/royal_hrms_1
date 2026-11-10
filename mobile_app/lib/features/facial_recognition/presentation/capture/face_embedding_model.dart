// Web can never run tflite_flutter (it needs dart:ffi), so the TFLite face
// models are conditionally excluded from web builds in favour of a stub that's
// never actually invoked (see FaceCaptureController.start()'s kIsWeb return).
export 'face_embedding_model_stub.dart' if (dart.library.io) 'face_embedding_model_io.dart';

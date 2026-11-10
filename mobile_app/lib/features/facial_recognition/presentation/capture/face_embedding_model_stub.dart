import '../../face_api/face_api_nets.dart';

/// Web builds: tflite_flutter needs dart:ffi, so the face models never load
/// in a browser (FaceCaptureController.start() returns unsupportedPlatform
/// before anything would ask for them).
Future<FaceApiNets> loadFaceApiNets() =>
    Future.error(UnsupportedError('Face descriptors are not available in a web browser.'));

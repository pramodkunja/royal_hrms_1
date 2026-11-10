import '../../face_api/face_api_nets.dart';
import '../../face_api/face_api_tflite.dart';

/// On-device face descriptors with the web app's own face-api.js 0.22.2
/// networks (converted to TFLite — see tool/face_api_conversion/), so mobile
/// and web registrations and verifications share one 128-d descriptor space
/// (backend FACE_RECOGNITION_MODEL_VERSION 'face-api.js-faceRecognitionNet-v1').
/// The backend only ever receives the computed vector, never an image.
Future<FaceApiNets> loadFaceApiNets() => TfliteFaceApiNets.load();

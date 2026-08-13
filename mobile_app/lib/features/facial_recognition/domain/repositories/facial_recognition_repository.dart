import '../entities/face_employee_entity.dart';
import '../entities/face_registration_entity.dart';
import '../entities/face_verification_status_entity.dart';

// Mirrors apps/attendance's real face-registration/face-verification
// contract exactly (see api_constants.dart). The backend has no endpoint
// that accepts an image or computes anything server-side — it only ever
// accepts an already-computed embedding, exactly like the browser's
// face-api.js output. Mobile has no browser, so the embedding is computed
// entirely on-device instead (see presentation/capture/ — a bundled
// MobileFaceNet TFLite model); this repository never sees a raw image, only
// the finished float vector, same as web.
abstract class FacialRecognitionRepository {
  Future<FaceVerificationStatusEntity> getVerificationStatus();

  Future<FaceRegistrationEntity?> getMyRegistrationStatus();

  Future<FaceRegistrationEntity> submitRegistration({
    required List<double> faceEmbedding,
    required bool livenessPassed,
    double? livenessScore,
    required bool consentAcknowledged,
  });

  Future<PaginatedFaceRegistrations> getPendingRegistrations({int page = 1, int pageSize = 20});

  Future<FaceRegistrationEntity> reviewRegistration({
    required String id,
    required bool approve,
    String notes = '',
  });

  Future<List<FaceEmployeeEntity>> searchEmployees(String query);

  Future<FaceRegistrationEntity?> getEmployeeStatus(String employeeUuid);

  Future<FaceRegistrationEntity> hrRegister({
    required String employeeUuid,
    required List<double> faceEmbedding,
    required bool livenessPassed,
    double? livenessScore,
    required bool consentAcknowledged,
  });
}

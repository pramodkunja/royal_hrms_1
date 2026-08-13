import '../../domain/entities/face_employee_entity.dart';
import '../../domain/entities/face_registration_entity.dart';
import '../../domain/entities/face_verification_status_entity.dart';
import '../../domain/repositories/facial_recognition_repository.dart';
import '../datasources/facial_recognition_remote_datasource.dart';

class FacialRecognitionRepositoryImpl implements FacialRecognitionRepository {
  final FacialRecognitionRemoteDataSource _dataSource;
  FacialRecognitionRepositoryImpl(this._dataSource);

  @override
  Future<FaceVerificationStatusEntity> getVerificationStatus() =>
      _dataSource.getVerificationStatus();

  @override
  Future<FaceRegistrationEntity?> getMyRegistrationStatus() =>
      _dataSource.getMyRegistrationStatus();

  @override
  Future<FaceRegistrationEntity> submitRegistration({
    required List<double> faceEmbedding,
    required bool livenessPassed,
    double? livenessScore,
    required bool consentAcknowledged,
  }) =>
      _dataSource.submitRegistration(
        faceEmbedding: faceEmbedding,
        livenessPassed: livenessPassed,
        livenessScore: livenessScore,
        consentAcknowledged: consentAcknowledged,
      );

  @override
  Future<PaginatedFaceRegistrations> getPendingRegistrations({int page = 1, int pageSize = 20}) =>
      _dataSource.getPendingRegistrations(page: page, pageSize: pageSize);

  @override
  Future<FaceRegistrationEntity> reviewRegistration({
    required String id,
    required bool approve,
    String notes = '',
  }) =>
      _dataSource.reviewRegistration(id: id, approve: approve, notes: notes);

  @override
  Future<List<FaceEmployeeEntity>> searchEmployees(String query) =>
      _dataSource.searchEmployees(query);

  @override
  Future<FaceRegistrationEntity?> getEmployeeStatus(String employeeUuid) =>
      _dataSource.getEmployeeStatus(employeeUuid);

  @override
  Future<FaceRegistrationEntity> hrRegister({
    required String employeeUuid,
    required List<double> faceEmbedding,
    required bool livenessPassed,
    double? livenessScore,
    required bool consentAcknowledged,
  }) =>
      _dataSource.hrRegister(
        employeeUuid: employeeUuid,
        faceEmbedding: faceEmbedding,
        livenessPassed: livenessPassed,
        livenessScore: livenessScore,
        consentAcknowledged: consentAcknowledged,
      );
}

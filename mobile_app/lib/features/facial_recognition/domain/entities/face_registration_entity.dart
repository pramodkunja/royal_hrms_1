// Mirrors apps/attendance/serializers_face_registration.py::FaceRegistrationReadSerializer
// exactly — one FaceRegistrationRequest row (an employee's latest submission,
// self- or HR-submitted). The raw face embedding is never exposed by that
// serializer (an approver decides from liveness_passed/liveness_score alone),
// so it has no field here either.
enum FaceRegistrationStatus { pending, approved, rejected }

FaceRegistrationStatus faceRegistrationStatusFromJson(String? value) {
  switch (value) {
    case 'approved':
      return FaceRegistrationStatus.approved;
    case 'rejected':
      return FaceRegistrationStatus.rejected;
    default:
      return FaceRegistrationStatus.pending;
  }
}

class FaceRegistrationEntity {
  final String id;
  final String employeeName;
  final String employeeEmail;
  final bool livenessPassed;
  final double? livenessScore;
  final String embeddingModelVersion;
  final FaceRegistrationStatus status;
  final String approvedByName;
  final DateTime? approvedAt;
  final String notes;
  final DateTime createdAt;

  const FaceRegistrationEntity({
    required this.id,
    required this.employeeName,
    required this.employeeEmail,
    required this.livenessPassed,
    this.livenessScore,
    required this.embeddingModelVersion,
    required this.status,
    required this.approvedByName,
    this.approvedAt,
    required this.notes,
    required this.createdAt,
  });
}

// A page of pending face-registration requests. Mirrors web's
// PaginatedFaceRegistrations type (frontend/types/faceRegistration.ts) and
// the backend's `{count, page, page_size, total_pages, results}` envelope
// (core/pagination.py, used by apps/attendance's
// FaceRegistrationPendingListView) — page_size=20, matching web exactly.
// Deliberately a small local wrapper rather than importing attendance's
// PaginatedListEntity<T>, to avoid a facial_recognition -> attendance
// cross-feature dependency.
class PaginatedFaceRegistrations {
  final List<FaceRegistrationEntity> results;
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;

  const PaginatedFaceRegistrations({
    required this.results,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });
}

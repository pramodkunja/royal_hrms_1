import '../../domain/entities/face_registration_entity.dart';

enum FaceRegistrationPhase {
  idle, // no registration on file yet, nothing in progress
  capturing, // capture flow (camera + liveness) is open
  submitting,
  pending,
  approved,
  rejected,
  error,
}

class FaceRegistrationUiState {
  final FaceRegistrationPhase phase;
  final FaceRegistrationEntity? registration;
  final String? errorMessage;

  const FaceRegistrationUiState({
    this.phase = FaceRegistrationPhase.idle,
    this.registration,
    this.errorMessage,
  });

  FaceRegistrationUiState copyWith({
    FaceRegistrationPhase? phase,
    FaceRegistrationEntity? registration,
    String? errorMessage,
  }) {
    return FaceRegistrationUiState(
      phase: phase ?? this.phase,
      registration: registration ?? this.registration,
      errorMessage: errorMessage,
    );
  }
}

FaceRegistrationPhase phaseForRegistration(FaceRegistrationEntity? registration) {
  if (registration == null) return FaceRegistrationPhase.idle;
  switch (registration.status) {
    case FaceRegistrationStatus.pending:
      return FaceRegistrationPhase.pending;
    case FaceRegistrationStatus.approved:
      return FaceRegistrationPhase.approved;
    case FaceRegistrationStatus.rejected:
      return FaceRegistrationPhase.rejected;
  }
}

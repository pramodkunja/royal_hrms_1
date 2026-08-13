import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../capture/face_capture_state.dart';
import '../providers/facial_recognition_providers.dart';
import '../state/face_registration_state.dart';

/// Backs both the Profile self-service card and the HR "register/update"
/// screen — `submit`/`submitForEmployee` differ only in which repository
/// call they end up making, so both live here rather than duplicating the
/// submitting/pending/approved/rejected/error state machine twice.
class FaceRegistrationController extends Notifier<FaceRegistrationUiState> {
  @override
  FaceRegistrationUiState build() => const FaceRegistrationUiState();

  Future<void> loadStatus() async {
    try {
      final registration =
          await ref.read(facialRecognitionRepositoryProvider).getMyRegistrationStatus();
      state = state.copyWith(phase: phaseForRegistration(registration), registration: registration);
    } catch (e) {
      state = state.copyWith(phase: FaceRegistrationPhase.error, errorMessage: _friendlyMessage(e));
    }
  }

  void startCapture() {
    state = state.copyWith(phase: FaceRegistrationPhase.capturing);
  }

  void cancelCapture() {
    state = state.copyWith(phase: phaseForRegistration(state.registration));
  }

  Future<void> submit(FaceCaptureUiState captured, {required bool consentAcknowledged}) async {
    final embedding = captured.embedding;
    if (embedding == null) return;
    state = state.copyWith(phase: FaceRegistrationPhase.submitting);
    try {
      final registration = await ref.read(facialRecognitionRepositoryProvider).submitRegistration(
            faceEmbedding: embedding,
            livenessPassed: captured.livenessPassed,
            livenessScore: captured.livenessScore,
            consentAcknowledged: consentAcknowledged,
          );
      state = state.copyWith(phase: phaseForRegistration(registration), registration: registration);
    } catch (e) {
      state = state.copyWith(phase: FaceRegistrationPhase.error, errorMessage: _friendlyMessage(e));
    }
  }
}

final faceRegistrationControllerProvider =
    NotifierProvider<FaceRegistrationController, FaceRegistrationUiState>(
  FaceRegistrationController.new,
);

String _friendlyMessage(Object e) {
  if (e is DioException) return parseDioException(e).message;
  return 'Something went wrong. Please try again.';
}

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../data/datasources/facial_recognition_remote_datasource.dart';
import '../../data/repositories/facial_recognition_repository_impl.dart';
import '../../domain/entities/face_registration_entity.dart';
import '../../domain/entities/face_verification_status_entity.dart';
import '../../domain/repositories/facial_recognition_repository.dart';

final facialRecognitionRemoteDataSourceProvider =
    Provider<FacialRecognitionRemoteDataSource>(
  (ref) => FacialRecognitionRemoteDataSource(ref.watch(dioProvider)),
);

final facialRecognitionRepositoryProvider = Provider<FacialRecognitionRepository>(
  (ref) => FacialRecognitionRepositoryImpl(
    ref.watch(facialRecognitionRemoteDataSourceProvider),
  ),
);

/// Org-wide Face ID toggle (Attendance Rules -> Face ID Verification).
/// autoDispose so screens re-check it fresh each time they're opened, rather
/// than caching a toggle an admin may have just flipped elsewhere.
final faceVerificationStatusProvider = FutureProvider.autoDispose<FaceVerificationStatusEntity>(
  (ref) => ref.watch(facialRecognitionRepositoryProvider).getVerificationStatus(),
);

/// The signed-in employee's own latest face registration request (or null if
/// they've never submitted one) — backs both the Profile self-service card
/// and the clock-in gate ("must be approved before punching").
final myFaceRegistrationProvider = FutureProvider.autoDispose<FaceRegistrationEntity?>(
  (ref) => ref.watch(facialRecognitionRepositoryProvider).getMyRegistrationStatus(),
);

/// Current page (1-based) for the Approvals "Face ID Approvals" tab —
/// matches web's page/page_size=20 pagination (Prev/Next, not infinite
/// scroll). Mirrors attendance's overtimePageProvider convention.
final facePendingRegistrationsPageProvider = StateProvider.autoDispose<int>((ref) => 1);

/// Pending face-registration queue backing the Approvals "Face ID Approvals"
/// tab, one page at a time — ref.invalidate this after acting on a request
/// to refresh the current page.
final facePendingRegistrationsProvider =
    FutureProvider.autoDispose<PaginatedFaceRegistrations>((ref) {
  final page = ref.watch(facePendingRegistrationsPageProvider);
  return ref.watch(facialRecognitionRepositoryProvider).getPendingRegistrations(page: page);
});

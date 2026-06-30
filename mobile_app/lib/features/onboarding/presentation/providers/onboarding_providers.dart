import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/onboarding_datasource.dart';
import '../../domain/entities/onboarding_entity.dart';

final onboardingDatasourceProvider = Provider.autoDispose<OnboardingDatasource>(
  (ref) => OnboardingDatasource(ref.watch(dioProvider)),
);

// Current wizard step (0-4)
final onboardingStepProvider = StateProvider.autoDispose<int>((ref) => 0);

// Full profile loaded from API
final onboardingProfileProvider =
    AsyncNotifierProvider.autoDispose<OnboardingProfileNotifier, OnboardingProfileEntity>(
  OnboardingProfileNotifier.new,
);

class OnboardingProfileNotifier
    extends AutoDisposeAsyncNotifier<OnboardingProfileEntity> {
  @override
  Future<OnboardingProfileEntity> build() async {
    final ds = ref.watch(onboardingDatasourceProvider);
    try {
      final profile = await ds.fetchProfile();
      // Restore the saved step
      ref.read(onboardingStepProvider.notifier).state = profile.currentStep;
      return profile;
    } catch (_) {
      return OnboardingProfileEntity.empty();
    }
  }

  Future<String?> saveStep(int step, Map<String, dynamic> data) async {
    final ds = ref.read(onboardingDatasourceProvider);
    try {
      await ds.saveStep(step, data);
      ref.invalidateSelf();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> uploadDocument(
      String docType, OnboardingDocUploadRequest request) async {
    final ds = ref.read(onboardingDatasourceProvider);
    try {
      await ds.uploadDocument(docType, request.file);
      ref.invalidateSelf();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteDocument(int id) async {
    final ds = ref.read(onboardingDatasourceProvider);
    try {
      await ds.deleteDocument(id);
      ref.invalidateSelf();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> submitProfile() async {
    final ds = ref.read(onboardingDatasourceProvider);
    try {
      await ds.submitProfile();
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}

// Wrapper for file upload request
class OnboardingDocUploadRequest {
  final dynamic file; // MultipartFile in practice
  const OnboardingDocUploadRequest(this.file);
}

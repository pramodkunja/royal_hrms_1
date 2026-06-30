import 'package:dio/dio.dart';
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
  // Guard: only restore the saved step on first fetch, not on every re-fetch
  // triggered by invalidateSelf() after saves/uploads. Without this flag,
  // re-fetching after a step save resets the step indicator back to 0.
  bool _stepInitialized = false;

  @override
  Future<OnboardingProfileEntity> build() async {
    final ds = ref.watch(onboardingDatasourceProvider);
    try {
      final profile = await ds.fetchProfile();
      if (!_stepInitialized) {
        _stepInitialized = true;
        ref.read(onboardingStepProvider.notifier).state = profile.currentStep;
      }
      return profile;
    } catch (_) {
      if (!_stepInitialized) {
        _stepInitialized = true;
      }
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

  Future<String?> uploadDocument(String docType, MultipartFile file) async {
    final ds = ref.read(onboardingDatasourceProvider);
    try {
      await ds.uploadDocument(docType, file);
      ref.invalidateSelf();
      return null;
    } catch (e) {
      final raw = e.toString();
      return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
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
      final raw = e.toString();
      return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    }
  }
}


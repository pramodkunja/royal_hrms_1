import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/datasources/onboarding_datasource.dart';
import '../../data/models/onboarding_config_models.dart';
import '../../domain/entities/onboarding_entity.dart';

final onboardingDatasourceProvider = Provider.autoDispose<OnboardingDatasource>(
  (ref) => OnboardingDatasource(ref.watch(dioProvider)),
);

/// The admin-configured fields and document types (GET field-config and
/// document-type-config). A failure is shown with Retry — the wizard never
/// falls back to a guessed field list.
final onboardingConfigProvider = FutureProvider.autoDispose<OnboardingConfig>(
  (ref) => ref.watch(onboardingDatasourceProvider).fetchConfig(),
);

/// Files already uploaded for custom "file" fields.
final onboardingCustomFilesProvider = FutureProvider.autoDispose<List<CustomFileValue>>(
  (ref) => ref.watch(onboardingDatasourceProvider).fetchCustomFiles(),
);

/// Unsaved edits by field_key, kept while moving between steps (web keeps
/// one form for the whole wizard the same way). Cleared for a step's keys
/// once that step is saved.
final onboardingDraftProvider = StateProvider.autoDispose<Map<String, String>>((ref) => const {});

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

  // Each build gets a number; only the newest one may restore the step, so a
  // build that was superseded mid-fetch (e.g. auth changed) cannot apply a
  // stale step or mark the step as restored.
  int _generation = 0;

  @override
  Future<OnboardingProfileEntity> build() async {
    final generation = ++_generation;
    final ds = ref.watch(onboardingDatasourceProvider);
    // Wait for the signed-in employee before choosing anything — the
    // onboarding status comes from auth, and a fetch started before auth
    // resolved would be thrown away by the rebuild that follows.
    String? status;
    try {
      status = (await ref.watch(authStateProvider.future)).user?.onboardingStatus;
    } catch (_) {
      status = null;
    }
    if (generation != _generation) return OnboardingProfileEntity.empty();

    final OnboardingProfileEntity profile;
    try {
      profile = await ds.fetchProfile(status: status ?? 'pending');
    } catch (_) {
      // Not marked as restored: the next successful load picks the step.
      return OnboardingProfileEntity.empty();
    }
    if (generation == _generation && !_stepInitialized) {
      _stepInitialized = true;
      ref.read(onboardingStepProvider.notifier).state = profile.currentStep;
    }
    return profile;
  }

  Future<String?> saveStep(int step, Map<String, dynamic> data) async {
    final ds = ref.read(onboardingDatasourceProvider);
    try {
      await ds.saveStep(step, data);
      ref.invalidateSelf();
      return null;
    } catch (e) {
      final raw = e.toString();
      return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    }
  }

  /// Saves one configured step. Returns null on success, otherwise the
  /// server's refusal including any per-field messages.
  Future<OnboardingSaveException?> saveConfiguredStep(int step, Map<String, dynamic> data) async {
    final ds = ref.read(onboardingDatasourceProvider);
    try {
      await ds.saveStep(step, data);
      ref.invalidateSelf();
      return null;
    } on OnboardingSaveException catch (e) {
      return e;
    } catch (e) {
      final raw = e.toString();
      return OnboardingSaveException(raw.startsWith('Exception: ') ? raw.substring(11) : raw);
    }
  }

  /// Uploads a file for a custom "file" field. Returns an error message or null.
  Future<String?> uploadCustomFile(String fieldKey, String fileName, List<int> bytes) async {
    final problem = onboardingUploadError(fileName, bytes.length);
    if (problem != null) return problem;
    try {
      await ref.read(onboardingDatasourceProvider).uploadCustomFile(fieldKey, fileName, bytes);
      ref.invalidate(onboardingCustomFilesProvider);
      return null;
    } catch (e) {
      final raw = e.toString();
      return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    }
  }

  Future<String?> deleteCustomFile(int id) async {
    try {
      await ref.read(onboardingDatasourceProvider).deleteCustomFile(id);
      ref.invalidate(onboardingCustomFilesProvider);
      return null;
    } catch (e) {
      final raw = e.toString();
      return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    }
  }

  /// Saves the PAN number before the PAN card is uploaded (web:
  /// handlePanCardUpload). Returns an error message or null.
  Future<String?> savePanNumber(String pan) async {
    try {
      await ref.read(onboardingDatasourceProvider).savePanNumber(pan);
      return null;
    } on OnboardingSaveException catch (e) {
      return e.message;
    } catch (_) {
      return 'Could not save PAN number. Please try again.';
    }
  }

  /// Save Draft on the Documents step: the server only confirms the
  /// required documents are present (nothing is submitted).
  Future<({bool ok, String message})> saveDocumentsDraft() async {
    try {
      final message = await ref.read(onboardingDatasourceProvider).verifyDocuments();
      return (ok: true, message: message);
    } on OnboardingSaveException catch (e) {
      return (ok: false, message: e.message);
    } catch (_) {
      return (ok: false, message: 'Could not save the draft. Please try again.');
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


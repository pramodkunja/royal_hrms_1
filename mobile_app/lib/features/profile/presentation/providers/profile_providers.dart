import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/models/my_profile_model.dart';
import '../../data/models/profile_document_model.dart';
import '../../data/models/profile_document_rows.dart';
import '../../data/services/profile_document_viewer.dart';
import 'package:path_provider/path_provider.dart';
import '../../../settings/data/models/onboarding_field_config_model.dart';

// ── DataSource ─────────────────────────────────────────────────────────────────

final profileDataSourceProvider = Provider<ProfileRemoteDataSource>((ref) {
  return ProfileRemoteDataSource(ref.watch(dioProvider));
});

// ── My profile ─────────────────────────────────────────────────────────────────

final myProfileProvider =
    AsyncNotifierProvider.autoDispose<MyProfileNotifier, MyProfileModel>(
  MyProfileNotifier.new,
);

class MyProfileNotifier extends AutoDisposeAsyncNotifier<MyProfileModel> {
  ProfileRemoteDataSource get _ds => ref.read(profileDataSourceProvider);

  @override
  Future<MyProfileModel> build() => _ds.fetchMyProfile();

  // Pull-to-refresh was replacing the whole profile screen (all sections,
  // scroll position) with a blank spinner while refetching. `.when()`'s
  // default `skipLoadingOnRefresh: true` renders the `data:` branch instead
  // of `loading:` whenever the AsyncLoading carries a previous value via
  // copyWithPrevious, so this fix is entirely provider-side — no screen
  // change needed. Same pattern already established for
  // employeeListProvider's refresh() in the Employees feature.
  //
  // Deliberately a try/catch, not `AsyncValue.guard()`: guard()'s own
  // AsyncError carries no previous value, so a failed refresh (e.g. a
  // connectivity blip) would still blank the whole screen despite the line
  // above — verified against the framework's own asyncTransition() in
  // package:riverpod/src/common.dart, which is what makes ref.invalidate()
  // preserve previous data on failure automatically; a hand-rolled
  // refresh() has to do the equivalent itself.
  Future<void> refresh() async {
    final previous = state;
    state = const AsyncLoading<MyProfileModel>().copyWithPrevious(state);
    try {
      state = AsyncData(await _ds.fetchMyProfile());
    } catch (e, st) {
      state = AsyncError<MyProfileModel>(e, st).copyWithPrevious(previous);
    }
  }

  /// Returns null on success, a user-facing error message on failure.
  Future<String?> updateProfile(MyProfileUpdateData data) async {
    final current = state.valueOrNull;
    try {
      await _ds.updateMyProfile(data);
      // The PATCH response carries no body other than a success message —
      // apply the edit locally instead of a second round-trip.
      state = AsyncData(
        current?.applyUpdate(data) ?? await _ds.fetchMyProfile(),
      );
      return null;
    } catch (e) {
      return friendlyProfileError(e);
    }
  }

  /// Saves the self-editable (Emergency-step) custom fields, then reloads.
  /// Returns null on success, a user-facing error message on failure.
  Future<String?> saveCustomFields(Map<String, String> values) async {
    try {
      await _ds.updateMyCustomFields(values);
      await refresh();
      return null;
    } catch (e) {
      return friendlyProfileError(e);
    }
  }

  /// Returns null on success, a user-facing error message on failure.
  Future<String?> uploadPhoto(File file) async {
    final current = state.valueOrNull;
    try {
      final newUrl = await _ds.uploadPhoto(file);
      if (current != null) state = AsyncData(current.copyWithPhotoUrl(newUrl));
      return null;
    } catch (e) {
      return friendlyProfileError(e);
    }
  }

  /// Returns null on success, a user-facing error message on failure.
  Future<String?> removePhoto() async {
    final current = state.valueOrNull;
    try {
      await _ds.removePhoto();
      if (current != null) state = AsyncData(current.copyWithPhotoUrl(null));
      return null;
    } catch (e) {
      return friendlyProfileError(e);
    }
  }
}

// ── Documents (read-only list) ──────────────────────────────────────────────────

final myDocumentsProvider =
    FutureProvider.autoDispose<List<ProfileDocumentModel>>((ref) {
  return ref.read(profileDataSourceProvider).fetchMyDocuments();
});

// ── Documents (self-service upload / replace) ───────────────────────────────────

/// Every document type the admin configured (visible or not).
final myDocumentTypesProvider = FutureProvider.autoDispose<List<DocumentTypeConfigModel>>((ref) {
  return ref.read(profileDataSourceProvider).fetchDocumentTypes();
});

/// The Documents rows: configured types merged with the employee's uploads.
/// The uploads must load (their failure is the section's error); a failed
/// type configuration falls back to web's built-in list, as web does.
final profileDocumentListingProvider = FutureProvider.autoDispose<ProfileDocumentListing>((ref) async {
  final docsFuture = ref.watch(myDocumentsProvider.future);
  final typesFuture = ref.watch(myDocumentTypesProvider.future);
  List<DocumentTypeConfigModel> types;
  try {
    types = await typesFuture;
  } catch (_) {
    types = const [];
  }
  return buildProfileDocumentListing(types, await docsFuture);
});

/// The app-private folders holding temporary profile document copies.
final profileDocumentTempStoreProvider = Provider<ProfileDocumentTempStore>((ref) {
  return ProfileDocumentTempStore(tempRoot: getTemporaryDirectory, documentsRoot: getApplicationDocumentsDirectory);
});

/// Prepares the employee's own documents for the in-app viewer: downloaded
/// with their login and checked (see ProfileDocumentViewer).
final profileDocumentViewerProvider = Provider.autoDispose<ProfileDocumentViewer>((ref) {
  return ProfileDocumentViewer(
    download: ref.watch(profileDataSourceProvider).downloadMyDocument,
    store: ref.watch(profileDocumentTempStoreProvider),
  );
});

sealed class DocumentUploadOutcome {
  const DocumentUploadOutcome();
}

/// Saved by the server (2xx with the new document); the list is reloaded.
class DocumentUploadSucceeded extends DocumentUploadOutcome {
  final ProfileDocumentModel document;
  const DocumentUploadSucceeded(this.document);
}

/// Not saved. [message] is the server's (or the pre-upload check's) text.
class DocumentUploadFailed extends DocumentUploadOutcome {
  final String message;
  const DocumentUploadFailed(this.message);
}

/// Nothing was sent: an upload for this type is already in progress.
class DocumentUploadIgnored extends DocumentUploadOutcome {
  const DocumentUploadIgnored();
}

/// The document types with an upload in flight. One upload per type at a
/// time (web disables that row while it uploads); other rows stay usable.
final profileDocumentUploadProvider =
    NotifierProvider.autoDispose<ProfileDocumentUploadNotifier, Set<String>>(ProfileDocumentUploadNotifier.new);

class ProfileDocumentUploadNotifier extends AutoDisposeNotifier<Set<String>> {
  bool _disposed = false;

  @override
  Set<String> build() {
    ref.onDispose(() => _disposed = true);
    return const {};
  }

  /// Uploads [file] for [row] to the signed-in employee's own profile. The
  /// target is always the employee code from their own `/employees/me/`
  /// profile — never another employee. A replace confirmation, when
  /// [ProfileDocumentRow.replaceNeedsConfirmation], is the caller's job.
  Future<DocumentUploadOutcome> upload(ProfileDocumentRow row, ProfileUploadFile file) async {
    final type = row.documentType;
    if (state.contains(type)) return const DocumentUploadIgnored();
    if (!row.canUpload) return const DocumentUploadFailed('This document type can no longer be uploaded.');
    final employeeId = ref.read(myProfileProvider).valueOrNull?.employeeId.trim() ?? '';
    if (employeeId.isEmpty) {
      return const DocumentUploadFailed('Your profile is still loading. Please try again.');
    }
    state = {...state, type};
    try {
      final doc = await ref.read(profileDataSourceProvider).uploadMyDocument(employeeId, type, file);
      if (!_disposed) ref.invalidate(myDocumentsProvider);
      return DocumentUploadSucceeded(doc);
    } catch (e) {
      return DocumentUploadFailed(userFriendlyMessage(e));
    } finally {
      if (!_disposed) state = {...state}..remove(type);
    }
  }
}

// ── Change password ─────────────────────────────────────────────────────────────
//
// Stateless mutation (there is no state to hold beyond the request itself).
// CRITICAL: on success the backend forces a logout (blacklists the refresh
// token, clears auth cookies) — the caller (profile screen) must log the
// user out and navigate to the login screen after this returns null.

Future<String?> changeMyPassword(
  WidgetRef ref, {
  required String oldPassword,
  required String newPassword,
  required String confirmPassword,
}) async {
  try {
    await ref.read(profileDataSourceProvider).changePassword(
          oldPassword: oldPassword,
          newPassword: newPassword,
          confirmPassword: confirmPassword,
        );
    return null;
  } catch (e) {
    return friendlyProfileError(e);
  }
}

// ── Error helper ───────────────────────────────────────────────────────────────
//
// Mirrors assessments_providers.dart's `_friendly()` rather than the older
// string-matching `_friendlyError()` duplicated in employee_providers.dart —
// this uses the shared `parseDioException()` so backend validation text
// (e.g. "Current password is incorrect.", the phone/IFSC regex messages)
// reaches the user verbatim instead of a generic fallback.
String friendlyProfileError(Object e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
    return parseDioException(e).message;
  }
  return e.toString().replaceAll('Exception:', '').trim();
}

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/profile_remote_datasource.dart';
import '../../data/models/my_profile_model.dart';
import '../../data/models/profile_document_model.dart';

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

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_ds.fetchMyProfile);
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
}

// ── Documents (read-only list) ──────────────────────────────────────────────────

final myDocumentsProvider =
    FutureProvider.autoDispose<List<ProfileDocumentModel>>((ref) {
  return ref.read(profileDataSourceProvider).fetchMyDocuments();
});

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

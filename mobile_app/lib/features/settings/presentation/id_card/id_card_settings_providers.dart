import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/exceptions.dart';
import '../../../profile/data/models/profile_document_model.dart';
import '../../../profile/data/services/profile_document_viewer.dart';
import '../../../profile/presentation/providers/profile_providers.dart' show profileDocumentTempStoreProvider;
import '../../data/models/company_model.dart';
import '../../data/models/id_card_settings_model.dart';
import '../providers/settings_providers.dart';

// Settings → ID Card (web app/dashboard/settings/id-card/page.tsx).

const kIdCardSettingsLoadError = 'Could not load ID card settings.';
const kIdCardSettingsSaveError = 'Failed to save. Please try again.';
const kIdCardSettingsSaved = 'ID card settings saved.';
const kIdCardReferencePdfOpenError = 'Could not open the reference PDF. Please try again.';

/// What the page loads (web: both requests together). The company is only
/// branding for the preview — if it can't be read the page still opens with
/// none (web `.catch(() => ({}))`); the settings themselves are required.
class IdCardSettingsPageData {
  const IdCardSettingsPageData(this.settings, this.company);
  final IdCardSettingsModel settings;
  final CompanyModel? company;
}

final idCardSettingsPageProvider = FutureProvider.autoDispose<IdCardSettingsPageData>((ref) async {
  final ds = ref.watch(settingsDataSourceProvider);
  final company = ds.fetchCompany().then<CompanyModel?>((c) => c, onError: (_) => null);
  final settings = await ds.fetchIdCardSettings();
  return IdCardSettingsPageData(settings, await company);
});

/// The server's `message` from an error response (JSON, or the raw bytes of
/// a bytes request), or null.
String? idCardServerMessage(Object error) {
  if (error is! DioException) return null;
  Object? data = error.response?.data;
  if (data is List<int>) {
    try {
      data = jsonDecode(utf8.decode(data));
    } catch (_) {
      return null;
    }
  }
  if (data is Map && data['message'] is String && (data['message'] as String).trim().isNotEmpty) {
    return data['message'] as String;
  }
  return null;
}

IdCardPickedFile? _picked(FilePickerResult? r) {
  final f = r?.files.singleOrNull;
  if (f == null || f.path == null) return null;
  return IdCardPickedFile(path: f.path!, name: f.name, size: f.size);
}

/// Web `<input type="file" accept=".pdf,application/pdf">`. Tests override.
final idCardReferencePdfPickerProvider = Provider<Future<IdCardPickedFile?> Function()>((ref) =>
    () async => _picked(await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['pdf'])));

/// Web `<input type="file" accept="image/png,image/jpeg,image/webp">`.
final idCardSignaturePickerProvider = Provider<Future<IdCardPickedFile?> Function()>((ref) => () async => _picked(
    await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: const ['png', 'jpg', 'jpeg', 'webp'])));

/// Opens the stored reference PDF inside the app. Web streams it from the API
/// with the session (never a public link) and opens it in a new tab; here it
/// is downloaded with the user's login and shown by the app's own document
/// viewer, whose temporary copy is deleted when the viewer closes or the
/// session ends (see ProfileDocumentViewer).
final idCardReferencePdfViewerProvider = Provider.autoDispose<ProfileDocumentViewer>((ref) {
  final ds = ref.watch(settingsDataSourceProvider);
  return ProfileDocumentViewer(
    store: ref.watch(profileDocumentTempStoreProvider),
    download: (_) async {
      try {
        final f = await ds.downloadIdCardReferencePdf();
        return ProfileDocumentFile(bytes: f.bytes, contentType: f.contentType, fileName: 'id-card-reference.pdf');
      } catch (e) {
        throw ServerException(idCardServerMessage(e) ?? kIdCardReferencePdfOpenError);
      }
    },
  );
});

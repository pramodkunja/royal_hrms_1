import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../profile/data/services/profile_document_viewer.dart';
import '../../../profile/presentation/providers/profile_providers.dart';
import 'training_providers.dart';

/// Result of handing a training PowerPoint / Word file to another app.
enum TrainingOfficeOpenResult { opened, noApp, failed }

const _mimes = {
  'pptx': 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
};

/// The Android side (MainActivity "royalhrms/training_files").
typedef TrainingOfficeLauncher = Future<String?> Function(String path, String mime);

final trainingOfficeLauncherProvider = Provider<TrainingOfficeLauncher>((ref) {
  const channel = MethodChannel('royalhrms/training_files');
  return (path, mime) => channel.invokeMethod<String>('openDocument', {'path': path, 'mime': mime});
});

/// HO-47 — web offers PowerPoint / Word materials as a download; on mobile
/// they are opened in another app instead:
///  - the file is fetched with the user's login and must really be an
///    Office (zip) file of the expected type;
///  - it is written only to the app-private temporary folder
///    (`profile_docs/training-material.pptx|docx`, no title or id), the
///    same folder the profile-document cleanup empties at app start, before
///    each view and at sign-out;
///  - Android shares it through a non-exported FileProvider with a
///    temporary read-only grant; nothing goes to public storage.
/// Fetching the file records no learner progress (the caller records
/// "open" separately when that is wanted).
class TrainingOfficeOpener {
  TrainingOfficeOpener(this._ref);
  final Ref _ref;

  static bool supports(String fileFormat) => _mimes.containsKey(fileFormat.toLowerCase());

  Future<TrainingOfficeOpenResult> open(String materialId, String fileFormat) async {
    final ext = fileFormat.toLowerCase();
    final mime = _mimes[ext];
    if (mime == null) return TrainingOfficeOpenResult.failed;
    final ProfileDocumentTempStore store = _ref.read(profileDocumentTempStoreProvider);
    final file = await _ref.read(trainingDatasourceProvider).fetchMaterialFile(materialId);
    final b = file.bytes;
    // Office Open XML files are zip archives: "PK\x03\x04".
    if (b.length < 4 || b[0] != 0x50 || b[1] != 0x4B || b[2] != 0x03 || b[3] != 0x04) {
      return TrainingOfficeOpenResult.failed;
    }
    await store.clearAll();
    final target = await store.trainingOfficeFile(ext);
    await target.writeAsBytes(b, flush: true);
    final r = await _ref.read(trainingOfficeLauncherProvider)(target.path, mime);
    return switch (r) {
      'opened' => TrainingOfficeOpenResult.opened,
      'no_app' => TrainingOfficeOpenResult.noApp,
      _ => TrainingOfficeOpenResult.failed,
    };
  }
}

final trainingOfficeOpenerProvider = Provider<TrainingOfficeOpener>((ref) => TrainingOfficeOpener(ref));

/// User-facing text for a result.
String trainingOfficeOpenMessage(TrainingOfficeOpenResult r) => switch (r) {
      TrainingOfficeOpenResult.opened => '',
      TrainingOfficeOpenResult.noApp =>
        'No app on this phone can open this file. Install PowerPoint / Word (or Google Docs / Slides), '
            'or open the course on the web app.',
      TrainingOfficeOpenResult.failed => 'The file could not be opened. Please try again.',
    };

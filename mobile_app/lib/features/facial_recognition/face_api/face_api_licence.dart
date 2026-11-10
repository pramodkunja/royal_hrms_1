import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;

const _kLicenceAsset = 'assets/face_api/LICENSE-face-api.js.txt';

/// Adds face-api.js's MIT licence (the converted model weights) to the app's
/// licence page.
void registerFaceApiLicense() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['face-api.js (face models)'], await rootBundle.loadString(_kLicenceAsset));
  });
}

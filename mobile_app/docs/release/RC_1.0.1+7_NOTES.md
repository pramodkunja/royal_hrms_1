# Release candidate 1.0.1 (7) — build notes

Built 2026-11-11 11:05 IST with `flutter build appbundle --release`. Not uploaded.

| Item | Value |
|---|---|
| Version / code | 1.0.1 / 7 (from the merged release manifest) |
| Application ID | com.royalhrms.app |
| minSdk / targetSdk | 24 / 36 |
| Output | `build/app/outputs/bundle/release/app-release.aab`, 139,750,926 bytes (~139.8 MB) |
| Upload certificate SHA-256 | C3:64:02:52:0D:91:0B:77:8C:9B:D4:91:08:52:0D:3B:1B:EB:DC:A1:8A:F6:06:76:3B:DC:F0:C8:7E:2B:92:A7 |
| Production API | https://royalhrms.com/api/ (only URL found in the compiled app; forced in release builds) |

**Version code 7 is NOT confirmed available in Play Console** (no console access when this was built). Check App bundle explorer before upload; if 7 was used, raise the version in `pubspec.yaml` and rebuild.

## Face recognition — what this build does and does not claim

- Uses the 128-dimension face-api-compatible networks (TFLite). Server-side face verification stays mandatory when the company setting is on; thresholds are unchanged; no registration is deleted.
- **NOT validated:** real-face accuracy, cross-platform (web vs mobile) matching and physical-device behaviour have not been tested. Do not describe face recognition as validated.
- **Old 192-dimension registrations:** registrations made with the earlier MobileFaceNet model (192-d) are a different embedding space from the 128-d descriptors this build sends. The backend checkout reviewed fails closed for such a mismatch, so affected employees may be refused at a mandatory face check until they re-register through the normal HR flow. Companies with the setting off are unaffected. Confirm production backend behaviour before wide rollout.
- Recommended: staged rollout, and an HR pilot (register + punch with a real face on a physical Android device) before widening.

## Not done
Signed-in testing, physical-device testing, Play upload, iOS.

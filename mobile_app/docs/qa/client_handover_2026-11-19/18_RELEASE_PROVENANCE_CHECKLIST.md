# 18 — Release Provenance Checklist (Task 92, 18 Nov 2026; HO-31 / HO-32)

**This is a procedure, not a build.**
- Nothing was built, signed or uploaded.
- No production server was touched.
- No secret was read; the AAB signer below is the **public** certificate.

## 0. Current facts

| Item | Value |
|---|---|
| Existing release AAB | `mobile_app/build/app/outputs/bundle/release/app-release.aab`, 141,482,970 bytes, 17 Nov 16:06, SHA-256 `e073c6f3fa713927c25ac0a49268f62c1b4f0aef37ed948fd6642bd4badc9125` |
| Its signer (public certificate, read with `keytool -printcert -jarfile`) | `CN=Royal HRMS, OU=Royal Staffing, O=Royal Staffing, L=Hyderabad, ST=Telangana, C=IN`, valid 23 Sep 2026 – 8 Feb 2054, SHA-256 `C3:64:02:52:0D:91:0B:77:8C:9B:D4:91:08:52:0D:3B:1B:EB:DC:A1:8A:F6:06:76:3B:DC:F0:C8:7E:2B:92:A7` |
| Is it current? | **No.** Its manifest has no `trainingfiles` provider, so it predates Task 90 batch 3. It contains none of Tasks 88–90, and its source state was never recorded (HO-32) |
| Debug builds on the test phone | versionCodes 11–16, debug key `38eabe8f…c128`; **not releasable** |
| pubspec | `1.0.2+10` (unchanged since 17 Nov) |
| Release signing config | `android/app/build.gradle.kts:11-80` reads `android/key.properties` (keys present: `keyAlias`, `keyPassword`, `storeFile`, `storePassword`); the build **fails closed** if it is missing |
| Production backend | Single checkout `/var/www/royalhrms/app`, branch `production`, run by Supervisor (`royalhrms_backend` / `_frontend` / `_celery_*`), from `web_frontend_backend/server-deployment-context.md` §25 |
| Local reference clone | `web_frontend_backend/` (branch `production`, pulled 18 Nov 11:26); exact commit not recorded here (no Git in these tasks) |

## 1. Identify the backend revision running in production (HO-31)
An authorised server operator does this. All steps are read-only.

1. As the `royalhrms` user, run `git -C /var/www/royalhrms/app rev-parse HEAD` and `git -C /var/www/royalhrms/app status --porcelain`. Record the **commit SHA**, and whether the working tree is clean (any local edit on the server is itself a finding).
2. Run `supervisorctl status royalhrms_backend` and record the process start time. A process started before the last pull runs old code.
3. Run `cd backend && .venv/bin/python manage.py showmigrations --plan | tail -40` (read-only). Record the last applied migration per app, especially `accounts` (is `0070` applied?), `training`, `attendance`, `tenants`.
4. Read-only role check (Django shell or admin, no writes): does role `branch_admin` hold `settings.edit` in tenant `DEMO2026`? This is evidence for HO-18.
5. Archive the output with date and operator name in the release record.

## 2. Compare with the local source (no production change)
1. On the developer machine: `git -C web_frontend_backend rev-parse HEAD`. This needs the user's approval for Git, or the developer runs it.
2. If the SHAs differ, run `git diff --stat <prod-sha> <local-sha> -- backend/` and list the changed files that affect: `apps/attendance/*face*`, `serializers_my_attendance.py`, `core/permissions.py`, `apps/training/*`, `apps/hrms/views/{leave,workfromhome,birthdays}.py`.
3. Re-confirm every HO-01 / HO-18 / HO-45 / HO-50 / HO-51 finding (doc 16) at the **production** SHA before closing it.

## 3. Record the mobile source revision
1. Make sure the `mobile_app/` tree is in its intended state. The repo currently shows a large uncommitted working tree on branch `mobile/p0-auth-fixes`; the user decides what is committed.
2. Preferred: commit, then tag, e.g. `mobile-1.0.2+17` (needs the user's Git approval).
3. Alternative (no Git): create an immutable snapshot `tar` of `mobile_app/` without `build/` and `.dart_tool/`, plus the per-file SHA-256 manifest (the format of `build_1.0.2+16-debug_source_manifest.txt`, including Kotlin and `res/xml`) and the tarball's own SHA-256. Store both outside the working tree.

## 4. Reconcile Android version codes
1. In Play Console (production and every testing track), record the **highest versionCode ever uploaded**.
2. The new release must use **versionCode > max(Play highest, 16)**. The test phone has 16; a release-signed build can't install over a debug-signed one anyway, but keeping codes unique avoids confusion. Recommendation: **`1.0.3+17`** (or the next free code above the Play maximum).
3. Bump `pubspec.yaml` `version:` in a recorded change. Don't use `--build-number` for release builds, so the version lives in source.

## 5. Verify the upload key identity (without exposing secrets)
1. The key owner runs `keytool -list -v -keystore <storeFile> -alias <keyAlias>` locally; the password is typed, never pasted into chat or logs. Read the **SHA-256 certificate fingerprint**.
2. In Play Console → App integrity → **Upload key certificate**, read its SHA-256.
3. Both must equal the fingerprint the existing AAB was signed with: `C3:64:02:52:…:2B:92:A7` (§0).
   - If Play shows a different upload key, **stop**: the AAB would be rejected, and a key reset needs Google's process.
4. Record only fingerprints, never passwords or the keystore path contents.

## 6. Build the signed release AAB (only after approval)
1. Preconditions:
   - HO-01 fixed on the backend, or a written risk acceptance;
   - HO-18 / HO-50 decided;
   - staging write tests (docs 15 / 17) passed or explicitly deferred;
   - source recorded (§3);
   - version bumped (§4);
   - key verified (§5).
2. Coordinate with other developers; Android Studio must not be building.
3. Run `flutter clean`, then `flutter pub get`, then `flutter test`, then `flutter analyze` (expect 13 info). Record the results.
4. `flutter build appbundle --release` (no `--build-number`).
5. Record:
   - `shasum -a 256 build/app/outputs/bundle/release/app-release.aab`;
   - `keytool -printcert -jarfile …aab`, whose SHA-256 must equal §5;
   - versionCode / versionName from the bundle manifest (bundletool `dump manifest`, if available);
   - file size; build time; Flutter version (`flutter --version`).
6. Write `build_<version>_release_source_manifest.txt` immediately after the build. Same format; its aggregate must match the snapshot / tag of §3.

## 7. Confirm the artifact corresponds to the tested source
1. The source manifest at release build time = the manifest of the debug build that passed device / staging testing, except `pubspec.yaml` (version line only). Any other difference means retesting.
2. Install check on a test device:
   - generate universal APKs from the AAB with bundletool, signed for local install only;
   - smoke-test login, dashboard, Training read screens and My Learning read screens;
   - this needs uninstalling the debug build on that device, and **approval**, because it clears app data.
3. Keep a release record with the AAB SHA-256, signer fingerprint, versionCode, mobile source tag / snapshot hash, backend production SHA (§1), and the test reports.
4. **Do not upload** until the release owner signs the record.

## 8. Retire the old artifact
Mark `app-release.aab` (`e073c6f3…`) as **"do not upload — unrecorded source, predates Training"**. Move it out of `build/` to an archive folder with that label (with approval), so it can't be uploaded by mistake.

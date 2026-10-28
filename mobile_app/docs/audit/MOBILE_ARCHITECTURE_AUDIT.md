# Mobile Architecture Audit — Royal HRMS Flutter App

*Audit date: 2026-10-28 · Scope: `mobile_app/` (lib/, android/, ios/, test/) · Read-only review, no application code changed.*

## Executive verdict

**Keep the current architecture and improve it selectively. Do not rewrite it.** The foundation is modern and coherent:

- Riverpod 2 AsyncNotifier with autoDispose by default, and no legacy StateNotifier.
- A remote datasource in every feature.
- A typed exception hierarchy.
- Release-safe logging and a production URL forced in release builds.
- A single-flight token refresh that survives network failures.
- Documented back-button handling.

The problems are:

- **Uneven adoption** of the good patterns: 24 copy-pasted `_unwrap` helpers, typed errors used by only 4 datasources, and Dio imported in 24 presentation files.
- **A handful of concrete correctness and release defects:**
  - the token-refresh deadlock;
  - the iOS bundle id and camera usage description;
  - silent debug signing of release builds;
  - forced password change not enforced;
  - dashboard role resolution.
- **Very large screen files**, up to 3,525 lines.

## Corrections and additions from cross-checking (2026-10-28)

These points were verified against source after the detailed review below was written. Where they conflict with it, they take precedence.

1. **Credential storage: keep the cookie jar.** The backend never returns tokens in the response body.
   - Login returns only `data.user` (`web_frontend_backend/backend/apps/accounts/views.py:584-604`) and refresh returns `data={}` (`:678`).
   - Tokens are set **only** as httpOnly cookies `royal_access_token` (900 s) and `royal_refresh_token` (7 d).
   - The tenant is resolved **only** from the access-token cookie's `company_schema` claim (`apps/tenants/middleware.py:56-66`).
   - So `PersistCookieJar` is the *only* working credential store on native. The Bearer header and secure-storage token code in `auth_interceptor.dart` / `auth_repository_impl.dart` is dead: it reads tokens that are never written.
   - Recommendation P2-11 below is amended: **do not drop the cookie jar.** Move it to a no-backup location (application-support directory), set `android:allowBackup="false"` or `dataExtractionRules`, and delete the dead Bearer code. Alternatively, have the backend team return tokens in the body *and* resolve the tenant from `Authorization: Bearer`. That is a backend change and needs approval.
2. **Refresh deadlock confirmed.** `AuthInterceptor extends Interceptor` (plain, not `QueuedInterceptor`) and retries with `_dio.fetch(err.requestOptions)` on the same Dio instance (`lib/core/network/api_client.dart:45`). A 401 on the retry is queued behind the refresh that is awaiting it, so `_isRefreshing` never resets. See §4.
3. **Dashboard role resolution is outdated (new finding).**
   - `resolveRoleCategory()` (`lib/features/dashboard/presentation/widgets/quick_access.dart:17-23`) classifies by **role-name substring**. `branch_admin` contains "admin", so it maps to `AdminDashboardView`, which calls `/dashboard/system-admin/*`. The backend gates those on `settings.edit` (`backend/apps/dashboard/views/overview.py:24-25`), so a Branch Admin without that permission sees 403s.
   - Custom tenant roles are mis-classified the same way.
   - Web now selects the dashboard by flags: `is_superuser` → Admin, `can_manage_team` → Manager, `employees.view` → HR, otherwise Employee (`frontend/app/dashboard/page.tsx:13-26`). Mobile already parses `isSuperuser`, `canManageTeam` and `canManageBranch` but does not use them for this.
4. **`assessmentStatus` is parsed but never used.** Web redirects users with a pending assessment to `/onboarding/assessments`. Mobile has no such gate and no candidate assessment portal.
5. **Face embeddings.** The current code computes a 192-d MobileFaceNet embedding on the device and posts only the vector. The backend stores it (`apps/attendance/views/face_registration.py`). Web uses face-api.js (128-d), so **a face registered on one platform cannot be verified on the other.** This is a product decision to confirm, not a code bug.

---

## Detailed review

Date: 2026-10-28. Scope: `mobile_app/lib` (~106k LOC Dart), android/, ios/, test/.
Resolved versions (pubspec.lock): flutter_riverpod 2.6.1, go_router 14.8.1, dio 5.9.2, cookie_jar 4.0.9, flutter_secure_storage 9.2.4, camera 0.11.4. pubspec SDK constraint: `>=3.5.0 <4.0.0`. Local toolchain used for checks: Flutter 3.44.8 / Dart 3.12.2.
Method: static reading and grep only. Nothing was built, run or changed. No secrets are reproduced here.

Legend: [F] = fact verified in code, [A] = assumption or inference, [R] = recommendation.

---

## 1. Layering

There are 27 feature directories (not 28). Every feature except `my_requests` has a `data/datasources/*RemoteDataSource`, so raw HTTP is almost always kept out of widgets. The difference between features is how much sits **above** the datasource.

| Group | Count | Features | Shape |
|---|---|---|---|
| A. Full clean layering | 11 | attendance, auth, branches, documents, email_log, facial_recognition, leave, org_chart, separation, voice_commands, wfh | datasource -> models -> `domain/repositories` interface + `data/repositories/*_impl` -> `domain/entities`. Only auth also has usecases (5 one-liners). |
| B. Entities, no repository | 5 | hrms, interview_list, onboarding, profile, referrals | datasource + models, `domain/entities`, and providers call the datasource directly |
| C. Datasource + models only | 10 | announcements, approvals, assessments, candidate_review, dashboard, employees, expenses, notifications, payroll, settings (3 datasources, 15 model files) | providers call the datasource and use models as UI state |
| D. Presentation only | 1 | my_requests | composes other features' providers |

Places where the layering breaks:
- [F] **Dio called straight from widgets** (2 places): `features/interview_list/presentation/widgets/add_candidate_sheet.dart:69` (`ref.read(dioProvider).get(ApiConstants.branches, ...)`) and `features/onboarding/presentation/screens/awaiting_approval_screen.dart:38` (`dio.get(ApiConstants.myProfile)`).
- [F] **Datasources are wired in `presentation/providers/*`** in 26 features (for example `leave_providers.dart:13`, `return LeaveRemoteDataSource(ref.watch(dioProvider));`). It works, but the DI seam sits in the presentation layer.
- [F] **`package:dio` is imported in 24 presentation files**, mostly to catch `DioException` or build `FormData`/`MultipartFile`. Examples: `employee_providers.dart` (15 DioException refs), `settings_providers.dart` (14 FormData), `expense_form_sheet.dart`. Transport types leak into the UI layer.
- [F] **The response envelope unwrap is copy-pasted.** 24 private `dynamic _unwrap(dynamic body)` helpers exist (for example `leave_remote_datasource.dart:9`, `attendance_remote_datasource.dart:10`, `settings_remote_datasource.dart:583`), and each one handles `{data: ...}` and `{count, results}` itself.

**Verdict:** one pattern is clearly worth keeping. Group A is: datasource (throws) -> repository impl (maps model to entity) -> AutoDispose(Family)AsyncNotifier that exposes `Future<String?>` mutations returning an error message, followed by targeted `ref.invalidate`. The leave and separation features are the best templates. Groups B and C are a lighter variant that is still coherent. The real problem is inconsistency, not a missing architecture.

## 2. State management

[F] Counts across lib/:
- `AutoDisposeAsyncNotifier`: 54. `AutoDisposeFamilyAsyncNotifier`: 9. `AsyncNotifier`: 1 (AuthNotifier). `Notifier`: 5. `AutoDisposeNotifier`: 1.
- `FutureProvider`: 75, of which 74 are `.autoDispose`. The only non-autoDispose one is `deviceIdProvider`.
- `StateProvider`: about 92 references, mostly `.autoDispose` filter and tab state. `StreamProvider`: 1 (`isOnlineProvider`).
- `.family`: 51. `.autoDispose`: 198.
- `StateNotifier`: 0. `ChangeNotifier`: 0, except `_RouterRefreshNotifier`. `@riverpod` codegen: 0.

Assessment:
- [F] The code consistently uses the modern Notifier/AsyncNotifier API. There is no legacy StateNotifier and no codegen. AutoDispose is the default, and the only `keepAlive()` is in `AuthNotifier.build()` (`auth_notifier.dart:18`).
- [F] Only six providers are global and not autoDispose: `sessionExpiredProvider`, `currentVisiblePathProvider`, `dashboardRevisitProvider`, `themeModeProvider`, `voiceMutedProvider` and `expandableFabOpenProvider`. None of them holds user data, so the risk of one user's data leaking to the next after logout is low.
- [F] There are 206 `ref.invalidate` / `ref.refresh` calls. Mutations invalidate their sibling providers explicitly. For example, `LeaveTeamPendingNotifier.approveRequest` calls `invalidateSelf()` and then invalidates `leaveStatsProvider` and `leaveTeamHistoryProvider` (`leave_providers.dart:228-236`).
- [F] One workaround is needed: `dashboardRevisitProvider` (`app_router.dart:209`) is bumped to force the dashboard to refetch. Shell routes reached with `push()` stay mounted, so their autoDispose providers never reach zero listeners. This is acceptable but should be documented.
- [F] Error handling inside notifiers is inconsistent. `userFriendlyMessage()` is used in only 10 files. Others hand-roll messages, for example `attendance_providers.dart:680`: `e.toString().replaceAll('Exception:', '')`.

## 3. Routing (`core/router/app_router.dart`, 541 lines)

- [F] **Routes:**
  - Auth: `/`, `/login`, `/forgot-password`.
  - Onboarding: `/onboarding`, `/onboarding/awaiting-approval`.
  - Outside the shell: 16 `/settings/*` screens plus `/employees/bulk-import` and `/interview-list/bulk-import`.
  - Inside one `ShellRoute(DashboardShell)`: 26 `/dashboard/*` routes, with two param children (`employees/:employeeId` and `separation/:requestId`, which use `state.extra` as optional initial data). `/dashboard/reports` is a `PlaceholderScreen`.
  - `errorBuilder` renders `NotFoundView` (a Lottie 404).
- [F] **Redirect** (`app_router.dart:229-270`):
  - If not authenticated, any path starting with `/dashboard`, `/settings` or `/onboarding` goes to `/login`.
  - If authenticated, onboarding status is gated: `needsOnboarding || onboardingRejected` goes to `/onboarding`, and `awaitingApproval` goes to `/onboarding/awaiting-approval`. A user who has completed onboarding is bounced off `/onboarding*`.
  - `refreshListenable` is driven by `ref.listen(authStateProvider)`.
- [F] **Guard gap:** `/employees/bulk-import` and `/interview-list/bulk-import` do not match any guarded prefix, so the redirect does not protect them when the user is unauthenticated. Today the impact is low because there are no deep links and the backend returns 401, but this is a latent hole.
- [F] **No role- or permission-based route guards.** Permission checks happen inside screens (`ref.watch(authStateProvider)...permissions` in 8 settings screens) and in the sidebar. `UserEntity.hasPermission()` exists (`user_entity.dart:64`) but the router does not use it.
- [F] **`mustChangePassword` is parsed** (`user_model.dart`) **but never read anywhere**, so a forced password change is not enforced on mobile.
- [F] **Back handling:**
  - `DashboardShell` wraps the shell in `PopScope(canPop: false)` (`dashboard_shell.dart:69-127`). On back it pops if it can, otherwise it goes to `/dashboard`, otherwise it shows an "Exit Application?" dialog and calls `SystemNavigator.pop()`.
  - AndroidManifest sets `android:enableOnBackInvokedCallback="false"`, with a comment explaining the ShellRoute predictive-back bug.
  - `goToDashboardSection()` pops to root and then `push()`es, which keeps the back stack bounded.
  - The manifest comment cites "go_router 17.3.0", but the lock file has 14.8.1. The comment is stale.
- [F] **Deep links:** none. There is no `<intent-filter>` with a VIEW action or data, and no `FlutterDeepLinkingEnabled` in Info.plist.
- [F] There is no `redirect` for an authenticated user who lands on `/login`. The splash screen and the login form navigate manually.

## 4. Auth lifecycle

**Two parallel credential stores [F]:**
1. **Cookies.** In `main.dart:35-39`, `PersistCookieJar(ignoreExpires: false, storage: FileStorage('${appDir.path}/.cookies/'))` is stored under `getApplicationDocumentsDirectory()`. These are plain, unencrypted files. On iOS, the Documents directory is included in iCloud/iTunes backup by default. On web an in-memory `CookieJar` is used and no CookieManager is attached (`api_client.dart:40-42`).
2. **Bearer tokens.** Access and refresh tokens are written to `flutter_secure_storage` (Android EncryptedSharedPreferences, iOS Keychain with `first_unlock`) at `auth_repository_impl.dart:48-53`. `AuthInterceptor.onRequest` always attaches `Authorization: Bearer` (`auth_interceptor.dart:40-56`). The comments say the backend checks the cookie first and falls back to the header.

**Refresh logic (`auth_interceptor.dart:61-173`):**
- [F] Refresh is single-flight: `_isRefreshing` plus a `_pending` queue. Queued requests are replayed on success, or rejected with the same verdict on failure.
- [F] Login, refresh, logout, forgot-password, OTP and reset paths are excluded from refresh, so a 401 from the refresh call cannot loop.
- [F] A session is treated as expired only when the refresh call itself gets a **server response**. Network failures do not force a logout. Non-Dio errors (for example a Keychain exception) still settle the queue.
- [F] **Latent deadlock:** the retry (`_dio.fetch(err.requestOptions)`, line 123) runs back through this same interceptor while `_isRefreshing` is still `true`. If the retried request gets **another 401** (refresh succeeded but the user is deactivated, tenant or permission state changed, or the new token is not accepted), `onError` queues it into `_pending` (line 92-95) and never settles it. The outer `await` then never completes, `finally` never runs, `_isRefreshing` stays `true` forever, and **every later 401 in the app hangs silently**. [R] Mark retries with `options.extra['_authRetried']=true` and pass them straight to `handler.next`. Also handle the retry with a 401 by signalling session expiry.
- [F] Minor: in `_resolvePending`, `onError` only settles the handler when `err is DioException`. Any other error leaves that queued request hanging (line 191-193).
- [F] Minor: a request that was already in flight with the old token and gets a 401 *after* the refresh finished triggers a second refresh. This is harmless unless the backend blacklists rotated refresh tokens. In that case the refresh token is re-read from storage, which mitigates it.

**401 leads to forced logout:**
- [F] The interceptor sets `sessionExpiredProvider = true`. `AuthNotifier.build()` listens for it, resets the flag and calls `logout()` (`auth_notifier.dart:23-28`). The router refreshes and redirects to `/login`. This works correctly.

**Cold start:**
- [F] `AuthNotifier.build()` returns only the cached `UserModel` from secure storage (`keyUserData`). There is **no server validation and no `/me` refresh** at startup.
- [F] Role, permissions and onboarding status therefore stay as they were at login until the next login. One exception: `awaiting_approval_screen` polls `myProfile` itself.
- [F] An expired session is only discovered on the first API call, which then triggers refresh or logout.

**Logout:**
- [F] `AuthRepositoryImpl.logout` calls the server inside try/finally, then `clearSession()`. That runs `_storage.deleteAll()` and `cookieJar.delete(Uri.parse(baseUrl), true)` (`auth_repository_impl.dart:103-109`).
- [F] Side effect: `deleteAll()` also deletes the persisted **theme preference**, which is stored in the same secure storage (`theme_mode_provider.dart:30`). Dark mode therefore resets on every logout.

**Company code and tenant:**
- [F] `company_code` is only sent in the login body (`login_request_model.dart:13`). It is not persisted for pre-fill, and the login form starts empty.
- [F] There is **no tenant header** (no `X-Tenant`, `X-Company` or similar), so tenancy must be resolved server-side from the JWT or cookie. [A] This is consistent with a django-tenants login that resolves the schema from company_code and embeds it in the token.
- [F] `UserModel` does carry `companyCode`, `companyName` and branding back from the server.

## 5. API client (`core/network/api_client.dart`)

- [F] **BaseOptions:** connect, send and receive timeouts are each 30s (`api_constants.dart:17-22`). JSON content-type and accept headers are set. `extra.withCredentials=true` is set for web.
- [F] **Interceptor order:** CookieManager (native only), then AuthInterceptor, then `_DebugLoggingInterceptor`.
- [F] **Logging:** the logging interceptor is only added when `kDebugMode`, and even then it logs only method, path, status and duration. It never logs headers or bodies. There are 0 `print`/`debugPrint` calls in lib/. Release logging is clean.
- [F] **Error mapping:**
  - `parseDioException()` maps errors to a typed `AppException` hierarchy (`core/error/exceptions.dart`): NoInternet, Network, Unauthorized, Forbidden, AccountLocked (403 on the login path), NotFound, Validation (422), RateLimit (429) and Server (5xx).
  - It prefers the server's `message` or `detail` field and never shows Dio internals.
  - `userFriendlyMessage()` provides one shared conversion to user-facing text.
  - **Adoption is low.** Only 4 datasources call `parseDioException`, and only 10 files use `userFriendlyMessage`. Most features catch `DioException` in providers and format messages themselves.
- [F] **Envelope:** there is no central unwrap. The 24 copy-pasted `_unwrap` helpers each handle `{status/success, message, data}` and DRF `{count, results}`. 400 responses with field-level errors fall through to `NetworkException(serverMessage ?? generic)`, so a dict-shaped `message` produces the generic text.
- [F] **Connectivity:** `isOnlineProvider` (connectivity_plus stream) drives `_ConnectivityGate` in `app.dart`. This is a full-screen, input-blocking `NoInternetView`. It reflects link-layer state only. There is no offline cache, no request retry or backoff, and no request deduplication or cancellation (`CancelToken` is not used for screen disposal).

## 6. Models and JSON

- [F] All `fromJson`/`toJson` methods are hand-written: about 166 `factory ...fromJson`. json_serializable, freezed and equatable are not used. `AuthState` implements `==` by hand.
- [F] Null-safety is generally defensive, with about 1,015 nullable casts (`as String?`, `as int?`, `as num?`) and `?? default`. There are about 36 hard casts that throw on null or a type mismatch. Most are on `id` fields in settings models (`email_template_model.dart:19,49,122`, `smtp_model.dart:47`, `departments_model.dart:39,68`) plus `user_model.dart` (`json['email'] as String`). An int-vs-UUID or null id from the backend will crash parsing for the whole list.
- [F] There are model/entity pairs per feature in group A, with mapping inside the repository impl.
- [F] **Duplicated models:** `EmployeePickerOption` is defined twice (`separation/domain/entities/separation_entity.dart:256` and `employees/data/models/employee_model.dart:268`). Branch, department and designation shapes appear in several features (`BranchModel`, `BranchSimple`, `EmployeeBranch`, `DepartmentModel`, `OrgDepartmentEntity`). `shared/models` only contains `bulk_import_result.dart`.

## 7. Reusable UI and theme

- [F] **Shared widgets** (`shared/widgets`): `AppButton` (26 uses in features), `AppTextField` (16), `AppErrorState` (21), `AppEmptyState` (7), `AppLoadingWidget` (15), `StatCard` (69), `BlueHeroBanner` (20), `ExpandableFab`, `NotFoundView`, `NoInternetView`.
- [F] **Tokens:** `AppColors` (174 lines) is referenced 3,633 times and `AppTextStyles` 1,666 times. Raw Material `Colors.*` (excluding white, black and transparent) appears only once in features. However, there are 218 raw `Color(0x...)` literals and 219 inline `TextStyle(` constructors in features. Token discipline is good, but not complete.
- [F] **Theming mechanism:**
  - `AppColors` fields are **mutable statics**, switched by `AppColors.applyMode(isDark)`.
  - `MaterialApp.router` is keyed on `ValueKey('app-theme-$isDark')` (`app.dart`), so toggling the theme remounts the whole app and loses form state and scroll position. This is a deliberate trade-off that is documented in the code, but it bypasses `Theme.of(context)`.
- [F] `AppTextStyles._base` is `GoogleFonts.poppins(...)`, and its getters allocate a new style on every call. Fonts are not bundled under assets and `allowRuntimeFetching` is not disabled, so Poppins is fetched from the network at runtime. A fresh offline install falls back to the system font.
- [F] **Duplicated widgets:**
  - 9 private `_StatusBadge` classes.
  - 3 `_BranchDropdown` classes (`holiday_form_dialog.dart:278`, `post_announcement_sheet.dart:382`, `add_employee_sheet.dart:972`).
  - `_DepartmentHeadcountCard` and `_EmployeeLifecycleCard` are duplicated between `admin_dashboard_view.dart` (377, 517) and `hr_dashboard_view.dart` (485, 657).
  - There are 177 raw `CircularProgressIndicator(` versus 15 `AppLoadingWidget` uses.

## 8. Pagination and performance

- [F] Infinite scroll uses a ScrollController threshold plus `loadMore()` with `hasMore`/`loadingMore` state. It is implemented in: email_log (`email_log_screen.dart:56`), separation (`separation_screen.dart:55`), leave team pending/history (`leave_providers.dart:184-290`), employees (`employees_screen.dart:31`, `fetchEmployeesPage`). WFH has the `hasMore` entity. The admin dashboard audit log uses a manual "Load more" button (`admin_dashboard_view.dart:848`).
- [F] Elsewhere, lists are fetched with a large fixed `page_size` and no paging: interview list 100, candidate_review 100 and 200, assessments 100, attendance 100 in several places, departments and designations 200, permissions 100. `EmployeesRemoteDataSource.fetchEmployees()` (`employees_remote_datasource.dart:94-101`) **loops every page** (50 each) for pickers. Lists silently truncate past the cap, or the app downloads the whole company.
- [F] **15 largest files** (god-files are the ones over about 1,000 lines):

| Lines | File |
|---|---|
| 3525 | features/attendance/presentation/screens/attendance_screen.dart |
| 2231 | features/attendance/presentation/screens/my_attendance_screen.dart |
| 2089 | features/leave/presentation/widgets/apply_leave_tab.dart |
| 1967 | features/employees/presentation/screens/employee_profile_screen.dart |
| 1684 | features/onboarding/presentation/widgets/onboarding_steps.dart |
| 1396 | features/employees/presentation/widgets/add_employee_sheet.dart |
| 1373 | features/settings/presentation/holiday_calendar/holiday_calendar_screen.dart |
| 1360 | features/dashboard/presentation/screens/employee_dashboard_view.dart |
| 1183 | features/leave/presentation/widgets/leave_dashboard_tab.dart |
| 1094 | features/settings/presentation/email_templates/widgets/template_editor_sheet.dart |
| 1093 | features/settings/presentation/leave_policy/widgets/leave_policy_rules_tab.dart |
| 1091 | features/candidate_review/presentation/screens/candidate_review_screen.dart |
| 1079 | features/dashboard/presentation/screens/admin_dashboard_view.dart |
| 934 | features/settings/presentation/attendance_rules/attendance_rules_screen.dart |
| 864 | features/employees/presentation/widgets/employee_attendance_tab.dart |

`attendance_screen.dart` and `my_attendance_screen.dart` duplicate logic, for example the identical time-formatting at `attendance_screen.dart:1904` and `my_attendance_screen.dart:1908`.

## 9. Lifecycle and memory

- [F] **Camera, ML Kit and TFLite:** `FaceCaptureController._teardown()` stops the image stream, disposes the camera and closes the detector (`face_capture_controller.dart:507-518`). The embedder has `dispose()`. The provider is AutoDispose.
- [F] **Voice:** `voice_command_controller.dart:102-110` creates SpeechToText, AudioPlayer and AudioRecorder, and disposes the player and recorder in `onDispose`. AnimationControllers in `animated_voice_assistant.dart` are disposed.
- [F] **Timers:** every file that creates a Timer also cancels one. The `.listen(` uses that lack `cancel()` are all `ref.listen`, which Riverpod manages, so this is fine.
- [F] **Small leaks:**
  - Dialog-local `TextEditingController()` instances are never disposed in `separation_approval_section.dart:53`, `leave_dashboard_tab.dart:112`, `leave_approvals_tab.dart:80`, `approve_reject_dialog.dart:19`, `leave_request_detail_sheet.dart` and `separation_clearance_section.dart`.
  - `branch_location_selector.dart:169` creates `TextEditingController(text: branchCode)` **inside build**, which leaks a controller on every rebuild and resets the cursor.
- [F] **Biometric residue:** the face still JPEG from `takePicture()` (`face_capture_controller.dart:315-350`) is never deleted after the embedding is computed, so it stays in the app cache directory.

## 10. Environment config and build variants

- [F] **`core/config/api_config.dart`:**
  - `enum Environment { local, production }`, with `current = Environment.production`.
  - `resolvedEnvironment` forces production when `kReleaseMode`, which is a good safety net.
  - A hardcoded LAN IP is committed as `localBaseUrlNative` (192.168.0.x), alongside `localhost:8000` for web and the production URL `https://royalhrms.com/api/`. The production URL has a trailing slash and the local URLs do not. Dio normalises this, but it is inconsistent.
  - There is no `--dart-define`, no `.env` and **no flavors** in Gradle or Xcode schemes. Staging requires a code edit.
- [F] **`android/app/build.gradle.kts`:**
  - `applicationId`/`namespace` is `com.royalhrms.app`.
  - `minSdk`, `targetSdk`, `compileSdk`, `versionCode` and `versionName` all come from Flutter defaults.
  - The release `signingConfig` uses `key.properties` (present locally and git-ignored, along with `*.jks` and `*.keystore`). **It silently falls back to the debug signing config** if the file is missing, so a CI or new-machine build would produce a debug-signed "release".
  - No explicit R8 or obfuscation settings (Flutter defaults). No `--split-debug-info`/`--obfuscate` config is visible.
- [F] **AndroidManifest (main):**
  - Permissions: INTERNET, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, RECORD_AUDIO.
  - CAMERA is not declared explicitly. [A] It is merged from the camera plugin's manifest.
  - `enableOnBackInvokedCallback="false"`.
  - No `usesCleartextTraffic`, so the default for target >=28 applies and cleartext is blocked in release.
  - No `android:allowBackup`/`dataExtractionRules`, so backup defaults to on. This includes the `.cookies/` files. [A] It may also cause restore issues with EncryptedSharedPreferences on a new device.
- [F] **Debug manifest:** `networkSecurityConfig` with `<base-config cleartextTrafficPermitted="true"/>` for **all domains**. This is debug-only and documented.
- [F] **iOS:**
  - `PRODUCT_BUNDLE_IDENTIFIER = com.example.mobileApp`. This is still the Flutter template id, it does not match Android, and it would block App Store submission.
  - Deployment target 15.5.
  - Info.plist has NSLocationWhenInUse, NSMicrophone and NSSpeechRecognition usage descriptions. **NSCameraUsageDescription is missing**, even though the camera is used for Face ID and `ImageSource.camera`. iOS terminates the app on first camera access without it.
  - There is no NSPhotoLibraryUsageDescription. [A] This is acceptable if only PHPicker is used.

## 11. Security summary

| Item | Where | Assessment |
|---|---|---|
| Access/refresh JWT | flutter_secure_storage (EncryptedSharedPreferences / Keychain first_unlock) | Good |
| Session cookies (incl. refresh cookie) | `PersistCookieJar` plain files in app Documents `/.cookies/` | **Weak.** Unencrypted, and included in iOS backup and Android auto-backup. This is the **only** working credential store, because the backend sends tokens only as cookies (see Corrections §1). The secure-storage token slots are never populated. |
| Cached user (role, permissions, PII) | secure storage `royal_hrms_user_data` | Good, but never revalidated |
| Release logging | debug-only interceptor, no bodies or headers, 0 prints | Good |
| Cleartext | debug-only, all domains; release HTTPS | Acceptable |
| Certificate handling | no `badCertificateCallback` override (good). No pinning. | Acceptable for an HRMS. Consider pinning later. |
| Face data | Embedding computed on-device (MobileFaceNet TFLite, `presentation/capture/face_embedding_model_io.dart`). Only the vector is POSTed (`facial_recognition_remote_datasource.dart:52,138`). It is not stored locally. | Good design. **The captured JPEG is not deleted** (see section 9). [A] The project memory note says embeddings are server-side dlib, but the current code and the pubspec comment say on-device. Confirm which is authoritative. |
| Forced password change | `mustChangePassword` parsed, never enforced | Gap |
| Unguarded routes | `/employees/bulk-import`, `/interview-list/bulk-import` | Gap (low impact) |

## 12. Testability

- [F] `test/widget_test.dart` contains only `test('placeholder', () => expect(true, isTrue));`. There are **zero real tests**. `analysis_options.yaml` is stock `flutter_lints` with no added rules.
- [F] **DI seams exist and are good:**
  - Everything is reachable through Riverpod providers: `dioProvider`, `cookieJarProvider` (already overridden in `main.dart`), `secureStorageProvider`, the `*RemoteDataSourceProvider`s and `*RepositoryProvider`s.
  - The group A repository interfaces allow `ProviderScope(overrides: [...])` fakes without mocking Dio.
  - Group C features would need Dio-level fakes, for example an `HttpClientAdapter` stub.
- [F] **Hard-to-test spots:**
  - `SecureStorageService` uses a `static const _storage`, so it can only be faked through the provider.
  - The AppColors mutable statics.
  - The 1,000+ line screens.

---

## Verdict

**Keep the architecture and improve it selectively. Do not rewrite it.**

The foundation is sound and modern:
- Riverpod AsyncNotifier with autoDispose by default.
- A datasource in every feature.
- A typed exception hierarchy.
- Release-safe logging and a release-forced production URL.
- A single-flight refresh that tolerates network failures.
- Documented back handling.

The problems are uneven adoption of the good patterns, a few concrete correctness and security defects, and large screen files.

## Incremental recommendations (priority order)

**P0: correctness and release blockers (small diffs)**
1. Fix the refresh-retry deadlock in `auth_interceptor.dart`. Tag the retried request in `extra` and bypass the queue for it. Treat a 401 on the retry as session expired. Settle non-Dio errors in `_resolvePending`.
2. iOS: add `NSCameraUsageDescription` and set a real bundle id that matches `com.royalhrms.app`.
3. Gradle: fail the release build when `key.properties` is missing, instead of falling back to debug signing.
4. Delete the face capture JPEG after computing the embedding (try/finally).
5. Enforce `mustChangePassword` in the router redirect, or document that it is out of scope.

**P1: consistency (mechanical refactors)**
6. Add one shared `ApiResponse` helper in `core/network` (`unwrapData`, `unwrapList`, `unwrapPage`) and replace the 24 `_unwrap` copies.
7. Make every datasource catch `DioException` and throw `parseDioException(e)`. Providers then catch `AppException` and use `userFriendlyMessage`. Remove `package:dio` imports from presentation, except for FormData builders, which should move into datasources.
8. Move the 2 widget-level Dio calls into their datasources (`add_candidate_sheet.dart:69`, `awaiting_approval_screen.dart:38`).
9. Move the guard to a list of protected prefixes, or nest the bulk-import routes under `/dashboard` or `/settings`. Optionally add a permission map for routes.
10. Store the theme preference outside secure storage, or exclude its key from `deleteAll`, so logout does not reset it. Persist the last-used company_code for login pre-fill.

**P2: security hardening**
11. *(Amended, see Corrections §1.)* **Keep** the PersistCookieJar, because it is the only working credential store. Move it to the application-support/no-backup directory, add `android:allowBackup="false"` or `dataExtractionRules`, and remove the dead Bearer/secure-storage token code, or keep it only behind an approved backend change.
12. At startup, revalidate the cached user with `/me` in the background so changes to role, permissions or onboarding status take effect.
13. Move the LAN IP and environment selection to `--dart-define`. Consider flavors (dev, staging, prod) once staging exists.

**P3: maintainability and performance (opportunistic, when touching the file)**
14. Split the god-files, starting with `attendance_screen.dart` (3.5k lines) and `my_attendance_screen.dart`, which share logic. Extract tabs and sections into widgets.
15. Promote the duplicated widgets to `shared/widgets`: `StatusBadge` (9 copies), `BranchDropdown` (3), and the dashboard cards (2 each). Promote `EmployeePickerOption`, branch, department and designation lookups to `shared/models`.
16. Replace the hard-coded `page_size: 100/200` lists with the existing `loadMore` pattern (leave and separation are the templates), starting with interview list, candidate review and attendance.
17. Bundle Poppins (or set `GoogleFonts.config.allowRuntimeFetching=false`) and cache the `TextStyle`s.
18. Make `id` casts tolerant (`as int?` / `toString()`) in the settings models.
19. Dispose dialog `TextEditingController`s, and move the in-build controller in `branch_location_selector.dart:169` into state.
20. Tests: start with unit tests for `AuthInterceptor` (fake adapter: 401, refresh, retry, queue, deadlock case), for `parseDioException`, and for the router redirect matrix. Then add provider tests for leave and separation using repository overrides. Add `riverpod_lint` and stricter lints.

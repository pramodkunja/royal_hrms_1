# Royal HRMS — Mobile App Development Journal

> This file is the daily development log for the Flutter mobile app.
> **Never overwrite previous entries. Always append new entries below.**

---

## Session 1

**Date:** 2026-06-26
**Time:** (Session start)
**Developer:** Pramod Kunja

### Module Worked On
- Project Foundation & Architecture Setup
- Authentication Module (complete)

### Completed Tasks
1. Configured `pubspec.yaml` with all enterprise dependencies:
   - `flutter_riverpod` — state management
   - `go_router` — declarative navigation
   - `dio` + `dio_cookie_manager` + `cookie_jar` — HTTP client with cookie-based auth
   - `flutter_secure_storage` — encrypted local user session storage
   - `path_provider` — persistent cookie jar directory
   - `google_fonts` — Poppins typeface (matches web frontend)
   - `connectivity_plus` — network monitoring

2. Built **Core Layer**:
   - `core/constants/api_constants.dart` — all API endpoints + platform-aware base URL (Android emulator uses `10.0.2.2`, iOS uses `localhost`)
   - `core/constants/app_constants.dart` — secure storage keys, OTP config, validation constants
   - `core/error/exceptions.dart` — typed exception hierarchy (NetworkException, UnauthorizedException, RateLimitException, etc.)
   - `core/security/secure_storage.dart` — FlutterSecureStorage wrapper with platform-specific options
   - `core/network/api_client.dart` — Dio instance with CookieManager + typed error parsing
   - `core/network/auth_interceptor.dart` — silent 401 → token refresh interceptor with request queuing
   - `core/theme/app_colors.dart` — full color palette mirroring the web CSS design system
   - `core/theme/app_text_styles.dart` — Poppins-based typescale (h1–h4, body, label, caption, button)
   - `core/theme/app_theme.dart` — Material 3 ThemeData with matching input, button, card, AppBar styles
   - `core/router/app_router.dart` — GoRouter with auth-driven redirect logic

3. Built **Shared Layer**:
   - `shared/widgets/app_button.dart` — tri-variant button (filled, outline, ghost) with loading state
   - `shared/widgets/app_text_field.dart` — labeled form field with full customisation
   - `shared/widgets/app_loading_widget.dart` — loading spinner + overlay
   - `shared/validators/form_validators.dart` — email, password, confirmPassword, OTP, required validators
   - `shared/extensions/context_extensions.dart` — MediaQuery helpers + SnackBar shorthand

4. Built **Auth Feature — Domain Layer** (Clean Architecture):
   - `domain/entities/user_entity.dart` — core UserEntity with permission helper
   - `domain/repositories/auth_repository.dart` — abstract repository contract
   - `domain/usecases/login_usecase.dart`
   - `domain/usecases/logout_usecase.dart`
   - `domain/usecases/forgot_password_usecase.dart`
   - `domain/usecases/verify_otp_usecase.dart`
   - `domain/usecases/reset_password_usecase.dart`

5. Built **Auth Feature — Data Layer**:
   - `data/models/user_model.dart` — UserModel extends UserEntity with JSON serialization
   - `data/models/login_request_model.dart`
   - `data/models/login_response_model.dart`
   - `data/models/forgot_password_models.dart` — ForgotPasswordRequest, VerifyOtpRequest, ResetPasswordRequest
   - `data/datasources/auth_remote_datasource.dart` — Dio API calls with typed exception mapping
   - `data/repositories/auth_repository_impl.dart` — implementation with SecureStorage caching + cookie clearing on logout

6. Built **Auth Feature — Presentation Layer**:
   - `presentation/states/auth_state.dart` — simple, equality-comparable auth state
   - `presentation/states/forgot_password_state.dart` — 4-step flow state (email → OTP → reset → success)
   - `presentation/controllers/auth_notifier.dart` — AsyncNotifier with session restore on startup
   - `presentation/controllers/forgot_password_notifier.dart` — step controller with error handling
   - `presentation/providers/auth_providers.dart` — provider declarations
   - `presentation/widgets/otp_input_widget.dart` — 6-box OTP input with paste support
   - `presentation/widgets/login_form.dart` — form with validation + error banner + forgot password link
   - `presentation/widgets/forgot_password_form.dart` — 4-step form (email, OTP, reset, success)
   - `presentation/screens/splash_screen.dart` — auto-redirects based on session state
   - `presentation/screens/login_screen.dart` — responsive login card with branding
   - `presentation/screens/forgot_password_screen.dart` — step indicator + back navigation

7. Added **Dashboard Placeholder** (`features/dashboard/presentation/screens/dashboard_screen.dart`)

8. Wired up **`lib/app/app.dart`** and **`lib/main.dart`**:
   - `main()` initialises `PersistCookieJar` from app documents directory
   - `ProviderScope` overrides `cookieJarProvider` with the initialised instance
   - Portrait orientation locked until tablet layout module is added

### Files Created
```
lib/
  main.dart (updated)
  app/app.dart
  core/
    constants/api_constants.dart
    constants/app_constants.dart
    error/exceptions.dart
    security/secure_storage.dart
    network/api_client.dart
    network/auth_interceptor.dart
    theme/app_colors.dart
    theme/app_text_styles.dart
    theme/app_theme.dart
    router/app_router.dart
  shared/
    validators/form_validators.dart
    extensions/context_extensions.dart
    widgets/app_button.dart
    widgets/app_text_field.dart
    widgets/app_loading_widget.dart
  features/
    auth/
      domain/entities/user_entity.dart
      domain/repositories/auth_repository.dart
      domain/usecases/login_usecase.dart
      domain/usecases/logout_usecase.dart
      domain/usecases/forgot_password_usecase.dart
      domain/usecases/verify_otp_usecase.dart
      domain/usecases/reset_password_usecase.dart
      data/models/user_model.dart
      data/models/login_request_model.dart
      data/models/login_response_model.dart
      data/models/forgot_password_models.dart
      data/datasources/auth_remote_datasource.dart
      data/repositories/auth_repository_impl.dart
      presentation/states/auth_state.dart
      presentation/states/forgot_password_state.dart
      presentation/controllers/auth_notifier.dart
      presentation/controllers/forgot_password_notifier.dart
      presentation/providers/auth_providers.dart
      presentation/widgets/otp_input_widget.dart
      presentation/widgets/login_form.dart
      presentation/widgets/forgot_password_form.dart
      presentation/screens/splash_screen.dart
      presentation/screens/login_screen.dart
      presentation/screens/forgot_password_screen.dart
    dashboard/
      presentation/screens/dashboard_screen.dart
pubspec.yaml (updated)
teamcontextfile.md (created)
```

### Files Modified
- `pubspec.yaml`
- `lib/main.dart`

### Pending Tasks
- [ ] Dashboard module — full implementation (stats cards, announcements, navigation rail)
- [ ] Employee module
- [ ] Attendance module
- [ ] Leave module
- [ ] Payroll module
- [ ] Profile module
- [ ] Settings module
- [ ] Notifications module
- [ ] Tablet/landscape responsive layout
- [ ] Dark mode support

### Architecture Notes
- **Cookie-based auth**: Django backend uses httpOnly JWT cookies. Mobile replicates this using Dio + `PersistCookieJar`. Cookies persist between app restarts via `FileStorage` in the app documents directory.
- **Android emulator base URL**: `http://10.0.2.2:8000` — change this for physical device testing to the host machine's LAN IP.
- **Session restore**: `AuthNotifier.build()` reads cached user from `FlutterSecureStorage` on startup to avoid forcing re-login after app restart.
- **No `build_runner` required**: Architecture is fully hand-written — no code generation step needed for compilation.

---

## Session 2

**Date:** 2026-06-26
**Developer:** Pramod Kunja

### Bug Fixed
**`LateInitializationError: Field '_login' has not been initialized`**

Root cause: `AuthNotifier` and `ForgotPasswordNotifier` declared `late final` use-case fields initialised inside `build()`. Riverpod disposes a provider when it has no active `ref.watch` listeners — this happens during the splash → login transition because `SplashScreen` uses `ref.read` (not `ref.watch`). When the provider is recreated for `LoginScreen`, the new notifier instance starts `build()` asynchronously but the `late` fields are unset until `build()` runs. Calling `login()` before `build()` sets them throws `LateInitializationError`.

### Fixes Applied

1. **`auth_notifier.dart`** — Removed all `late final` fields. Added `AuthRepository get _repository => ref.read(authRepositoryProvider)` computed getter. Added `ref.keepAlive()` in `build()` to prevent disposal between screen transitions.

2. **`forgot_password_notifier.dart`** — Same fix: removed `late final` fields, use `ref.read(authRepositoryProvider)` getter. Added `_friendlyMessage()` helper.

3. **`login_form.dart`** — Added `ref.listen<AsyncValue<AuthState>>(authStateProvider, ...)` in `build()` to reactively navigate to `/dashboard` the moment auth state becomes authenticated. (Previously `_submit()` awaited `login()` but never navigated.) Added `_formatError()` mapping typed exceptions to user-readable strings.

4. **`api_client.dart`** — Added `extra: {'withCredentials': true}` to `BaseOptions` so the web platform's `XMLHttpRequest` sends cookies in CORS requests. Ignored on native platforms.

### Verification
- `flutter analyze --no-pub` → **No issues found**

### Files Modified
```
lib/
  core/network/api_client.dart
  features/auth/
    presentation/controllers/auth_notifier.dart
    presentation/controllers/forgot_password_notifier.dart
    presentation/widgets/login_form.dart
```

---

## Session 3

**Date:** 2026-06-27
**Developer:** Pramod Kunja

### Module Worked On
- Settings — UI redesign (Roles, Email Templates, Settings Hub)
- Settings — Provider architecture (auto-dispose)

---

### Completed Tasks

#### 1. Settings Screen — Tab Bar Navigation

**File:** `features/settings/presentation/settings_hub/settings_screen.dart`

Replaced the old pill-chip filter row with a proper horizontal tab bar with 5 categories:

| Tab | Screens shown |
|---|---|
| All Settings | Everything |
| Company | Company Info, Employee Code Format |
| Modules | Departments & Designations |
| Communication | SMTP, Email Templates |
| System | Roles & Permissions, Audit Log |

Active tab: `Color(0xFF1B3A6B)` navy background, white text + icon, subtle shadow.
Inactive tab: transparent, `Colors.grey[600]` text.
`_TabBar` lives inside a `Color(0xFFF0F2F5)` pill container with 4 px padding. `_TabItem` uses `AnimatedContainer` for smooth transitions.

Section metadata uses Dart 3 switch expressions returning records `({String label, IconData icon, Color color})` to avoid the `const` + `Color` incompatibility at compile time.

#### 2. All Settings Providers → autoDispose

**File:** `features/settings/presentation/providers/settings_providers.dart`

Converted all settings data providers to `.autoDispose` variants. Previously, a provider loaded on first visit and served stale data on every subsequent visit (Riverpod keeps providers alive while any widget is subscribed, and the navigation stack kept them alive permanently).

With `.autoDispose`, the provider is destroyed when the screen pops, so every re-entry triggers a fresh backend fetch.

| Provider | Change |
|---|---|
| `companyProvider` | `AsyncNotifierProvider` → `.autoDispose` |
| `employeeCodeProvider` | `AsyncNotifierProvider` → `.autoDispose` |
| `smtpListProvider` | `AsyncNotifierProvider` → `.autoDispose` |
| `emailTemplateCategoriesProvider` | `FutureProvider` → `.autoDispose` |
| `emailTemplatesProvider` | `AsyncNotifierProvider` → `.autoDispose` |
| `departmentsProvider` | `AsyncNotifierProvider` → `.autoDispose` |
| `designationsProvider` | `AsyncNotifierProvider` → `.autoDispose` |
| `allPermissionsProvider` | `FutureProvider` → `.autoDispose` |
| `rolesProvider` | `AsyncNotifierProvider` → `.autoDispose` |
| `auditFiltersProvider` | `StateProvider` → `.autoDispose` |
| `auditLogProvider` | `AsyncNotifierProvider` → `.autoDispose` |

`settingsDataSourceProvider` kept as non-autoDispose — it is a stateless factory.

#### 3. Email Templates Screen — Banner-Card Fusion

**Files:** `email_templates/email_templates_screen.dart`, `email_templates/widgets/template_card.dart`

Replaced standalone floating `_SectionHeader` banner widgets with a fused banner-top-of-card design.

Key pattern: wrap the card in `Container(clipBehavior: Clip.antiAlias, decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)))`. Any colored child drawn at the top of the inner `Column` is automatically clipped to the outer card's rounded corners — no manual `BorderRadius` on the banner itself.

Added `flat: bool = false` parameter to `TemplateCard`. When `flat: true` (inside a group card), only the content column is returned without any outer container decoration — avoids double-border nesting.

#### 4. Roles Screen — Full Card Redesign + Banner-Card Fusion

**File:** `features/settings/presentation/roles/roles_screen.dart`

Removed the horizontally-scrollable Permission Matrix table. Built two proper group-card sections using the same banner-card fusion pattern:

**`_RolesGroupCard`** — navy banner (`Color(0xFF1B3A6B)`) fused to card top. Each role row (`_RoleRow`) shows: gradient icon, name + slug + badge on top row, action count + user count + edit + toggle on bottom row.

**`_PermissionMatrixSection`** → `_ModuleGroupCard` — one card per permission module. Teal banner (`Color(0xFF0D6B4A)`). `_PermBadge` inside each card shows Full(N), partial action chips, or `—` for no access. `_StatChip` shows permission count and user count.

### Key Architecture Pattern — Banner Fused to Card

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: AppColors.border),
    boxShadow: AppColors.cardShadow,
  ),
  clipBehavior: Clip.antiAlias,     // clips all children to outer radius
  child: Column(children: [
    Container(color: bannerColor),  // no BorderRadius needed — clipped by parent
    // ... rows with Divider(height: 1) separators
  ]),
)
```

### Files Modified
```
lib/features/settings/presentation/
  settings_hub/settings_screen.dart          full rewrite — tab bar
  providers/settings_providers.dart          all providers → autoDispose
  roles/roles_screen.dart                    full rewrite — card layout + banner fusion
  email_templates/
    email_templates_screen.dart              added _GroupCard, removed floating _SectionHeader
    widgets/template_card.dart              added flat: bool parameter
```

### Pending Tasks (carried to Session 4)
- Convert all Add/Edit bottom sheet forms to centered dialog popups

---

## Session 4

**Date:** 2026-06-29
**Developer:** Pramod Kunja

### Module Worked On
- Settings — All Add/Edit forms converted from `showModalBottomSheet` to `showDialog`
- Core Auth — 401 / session expiry fix (major rewrite of interceptor + router + auth notifier)

---

### Part 1: Bottom Sheet → Dialog Popup Conversion

Every Add / Edit form in the settings modules previously used `showModalBottomSheet` (slides up from the bottom of the screen). All six form widgets and four screen call-sites have been converted to centered `showDialog` popups.

#### Screen-level changes

`showModalBottomSheet<void>(isScrollControlled: true, ...)` replaced with:

```dart
showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => Dialog(
    insetPadding: EdgeInsets.symmetric(horizontal: H, vertical: V),
    backgroundColor: Colors.transparent,
    elevation: 0,
    child: <FormWidget>(...),
  ),
);
```

| Screen | Call sites changed | insetPadding |
|---|---|---|
| `smtp_screen.dart` | `_openForm()` | h:12, v:16 |
| `departments_screen.dart` | `_openDeptEdit()`, `_openDesigEdit()` | h:20, v:80 |
| `email_templates_screen.dart` | `_openEditor()` (barrierDismissible: false), `_openPreview()` (barrierDismissible: true) | h:12/v:16, h:16/v:40 |
| `roles_screen.dart` | `_openForm()` | h:10, v:16 |

#### Form widget changes

All form widgets had `DraggableScrollableSheet`, drag handle bars, and old header widgets removed. New standard structure:

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(20),
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _DlgHeader(icon: ..., title: ..., subtitle: ..., onClose: () => Navigator.pop(context)),
      Flexible(
        child: Container(
          color: AppColors.background,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 12, 16,
              MediaQuery.viewInsetsOf(context).bottom + 24),
            child: Column(children: [...fields, submitButton]),
          ),
        ),
      ),
    ],
  ),
)
```

`_DlgHeader` design: `AppColors.primary` navy background, `BorderRadius.vertical(top: Radius.circular(20))`, white frosted icon box, white title + subtitle, `IconButton` close on right.

Role form uses `ListView(shrinkWrap: true)` inside `Flexible` instead of `SingleChildScrollView` to handle the expandable permission tree accordion.

Simple forms (Dept, Desig) use a plain `Container` body (not `Flexible`) since content is short.

#### Files modified (10 total)
```
lib/features/settings/presentation/
  smtp/
    smtp_screen.dart
    widgets/smtp_form_sheet.dart
  departments/
    departments_screen.dart
    widgets/dept_form_sheet.dart
    widgets/desig_form_sheet.dart
  email_templates/
    email_templates_screen.dart
    widgets/template_editor_sheet.dart
    widgets/template_preview_sheet.dart
  roles/
    roles_screen.dart
    widgets/role_form_sheet.dart
```

---

### Part 2: Auth 401 / Session Expiry — Complete Fix

#### Root Cause Analysis

The app used `PersistCookieJar` + `CookieManager` (Dio interceptor) as the sole auth mechanism. Three bugs caused the observed 401 loop with no recovery:

**Bug 1 — Pending requests hung forever**
When a 401 arrived while a token refresh was already in flight, the old interceptor queued `RequestOptions` but never stored the corresponding `ErrorInterceptorHandler`. When the refresh failed, the queue was cleared but no handler was ever called — every queued caller's `Future` completed never.

**Bug 2 — No session-expiry auto-logout**
When the refresh endpoint itself returned 401 (both tokens expired), the interceptor propagated the error to the screen. Nothing cleared `SecureStorage`, nothing cleared cookies, nothing navigated to login. The user saw a permanent 401 error screen with no recovery path.

**Bug 3 — Router never re-evaluated redirect on auth state change**
`appRouterProvider` used `ref.read(authStateProvider)` inside GoRouter's `redirect`. GoRouter only calls `redirect` on explicit navigation events — not on state changes. So when `logout()` changed `authStateProvider` to `AuthState.initial()`, the router never fired, the user stayed on the protected screen, and every API call kept returning 401.

**Bug 4 — Cookie jar as sole auth mechanism (fragile)**
If the cookie jar was empty (reinstall, emulator reset, cookies not persisted correctly), there was no fallback. Every request returned 401 immediately — even with a valid session — because no auth credential was being sent.

#### Fixes Applied

**`core/constants/app_constants.dart`**
Added `static const String keyAccessToken = 'royal_hrms_access_token'` — the `SecureStorage` key for the access token.

**`core/network/api_client.dart`**
Added:
```dart
final sessionExpiredProvider = StateProvider<bool>((ref) => false);
```
This is a one-way signal bus: `AuthInterceptor` writes `true` when refresh fails; `AuthNotifier` listens and calls `logout()`. No circular dependency — the interceptor only writes, never reads this as a dependency.

**`core/network/auth_interceptor.dart`** — Complete rewrite

Added `_Pending` class holding both `RequestOptions` AND `ErrorInterceptorHandler`. Pending requests can now be properly resolved or rejected.

Added `onRequest` override: on non-web platforms, reads `royal_hrms_access_token` from `SecureStorage` and injects `Authorization: Bearer <token>` header. This makes auth work even when the cookie jar is empty.

On refresh failure: `_rejectPending()` calls `handler.next(DioException(...))` on every queued request, then `_signalSessionExpired()` sets `sessionExpiredProvider = true`.

Added logout path to the interceptor skip list alongside `/token/refresh/` — prevents logout POST from re-triggering the refresh+expiry loop when both tokens are expired.

After successful refresh: extracts new `access` token from backend response body (`data.data.access`) and writes to `SecureStorage` so `onRequest` picks it up immediately.

**`core/router/app_router.dart`**

Added:
```dart
class _RouterRefreshNotifier extends ChangeNotifier {
  void refresh() => notifyListeners();
}
```
Inside `appRouterProvider`:
```dart
final notifier = _RouterRefreshNotifier();
ref.listen(authStateProvider, (_, __) => notifier.refresh());
ref.onDispose(notifier.dispose);
return GoRouter(refreshListenable: notifier, ...);
```
Now GoRouter re-evaluates `redirect` on every auth state change — login and logout both trigger correct navigation.

**`features/auth/presentation/controllers/auth_notifier.dart`**

Added inside `build()`:
```dart
ref.listen<bool>(sessionExpiredProvider, (_, expired) {
  if (!expired) return;
  ref.read(sessionExpiredProvider.notifier).state = false;
  logout();
});
```
Auto-logout fires whenever `AuthInterceptor` signals session expiry.

**`features/auth/data/models/login_response_model.dart`**

Added `final String? accessToken` field, parsed from `data['access']` in the backend response envelope.

**`features/auth/data/repositories/auth_repository_impl.dart`**

In `login()`: after `_cacheUser()`, writes `response.accessToken` to `SecureStorage`:
```dart
if (response.accessToken != null && response.accessToken!.isNotEmpty) {
  await _storage.write(AppConstants.keyAccessToken, response.accessToken!);
}
```
`clearSession()` already calls `_storage.deleteAll()` which removes `keyAccessToken` automatically.

#### Backend Changes Required (ask backend team)

Two one-line changes needed in `backend/apps/accounts/views.py`:

1. **`LoginAPIView.post()`** — add `'access': str(refresh.access_token)` to the `data={}` dict in the `success()` call.
2. **`TokenRefreshAPIView.post()`** — change `data={}` to `data={'access': serializer.validated_data['access']}`.

Without these, `login_response_model.dart` will parse `accessToken` as `null`, `SecureStorage` will not be written, and the Bearer header fallback will not activate.

#### Complete Auth Flow (after backend changes)

```
LOGIN
  Backend: Set-Cookie (httpOnly access + refresh) + response body: {data: {access: "...", user: {}}}
  Flutter: SecureStorage.write(keyAccessToken, token) + CookieManager stores httpOnly cookies

EVERY REQUEST (native)
  AuthInterceptor.onRequest → SecureStorage.read(keyAccessToken) → Authorization: Bearer <token>
  Backend: authenticates via Bearer header (also accepts Cookie as fallback)

ACCESS TOKEN EXPIRES (15 min)
  401 → AuthInterceptor queues request, fires POST /token/refresh/ (refresh cookie auto-sent)
  Backend: new access token in response body + new Set-Cookie
  Flutter: SecureStorage updated, queued requests retried → 200 OK

BOTH TOKENS EXPIRED (7 days) OR POST-REINSTALL
  POST /token/refresh/ → 401
  _rejectPending() + _signalSessionExpired()
  AuthNotifier.ref.listen → logout() → SecureStorage.deleteAll() + cookie jar cleared
  authStateProvider → AuthState.initial()
  _RouterRefreshNotifier fires → GoRouter re-runs redirect → /login
```

### Files Modified
```
lib/
  core/
    constants/app_constants.dart
    network/api_client.dart                   added sessionExpiredProvider
    network/auth_interceptor.dart             complete rewrite
    router/app_router.dart                    added _RouterRefreshNotifier + refreshListenable
  features/
    auth/
      data/models/login_response_model.dart   added accessToken field
      data/repositories/auth_repository_impl.dart  writes token to SecureStorage on login
      presentation/controllers/auth_notifier.dart  added sessionExpiredProvider listener
```

### Pending Tasks
- [ ] Backend team: add `access` token to login response body + token refresh response body
- [ ] Hot-restart app after backend change, log in fresh — verify all 4 auth cookies visible in DevTools
- [ ] Employee module implementation
- [ ] Attendance module
- [ ] Leave module
- [ ] Payroll module

---

## Session 5

**Date:** 2026-06-29
**Developer:** Pramod Kunja

### Module Worked On
- Employees — full screen + card + profile redesign
- Announcements — stat card layout update

---

### Part 1: Employee Card Redesign

**File:** `features/employees/presentation/widgets/employee_card.dart`

Replaced previous design with a professional card using a colored left accent strip pattern:

**Structure:**
```
Container (white, radius 16, AppColors.border border, cardShadow)
  clipBehavior: Clip.antiAlias
  IntrinsicHeight > Row:
    ├─ 4px left accent strip (employee.avatarColor, topLeft/bottomLeft radius 16)
    └─ Expanded body (padding fromLTRB(14,14,14,12))
         ├─ Top: Avatar (52px circle, tinted) + name/ID/designation + _StatusBadge pill
         ├─ Middle: Info box (AppColors.background bg, border, radius 10)
         │    └─ BRANCH | vertical divider | DEPT  (_InfoItem: icon + label + value)
         └─ Bottom: "View Profile" (outline) + "Edit Details" (filled) buttons (_ActionBtn)
```

**Key widget specs:**
- `_Avatar`: 52×52 circle, `avatarColor.withValues(alpha:0.15)` bg, `avatarColor.withValues(alpha:0.30)` border 1.5px, colored initials (not white)
- `_StatusBadge`: pill (radius 20), sentence-case labels, uses `AppColors.successContainer / warningContainer / errorContainer` bg
- `_InfoItem`: `Icon(13px, textHint)` + `Column(9px label + 12px value)`
- `_ActionBtn`: `GestureDetector > Container`, filled=true → primary bg + white text, filled=false → transparent + 30% primary border

---

### Part 2: Employees Screen Redesign

**File:** `features/employees/presentation/employees_screen.dart`

#### Stats Grid — 2×2 layout
`_StatsGrid` uses `Column(Row, Row)` with 12px gaps (not a single 4-in-a-row `Row`).

Each `_StatCard` format:
```dart
Container(
  padding: EdgeInsets.fromLTRB(16, 14, 14, 14),
  decoration: BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.border),
    boxShadow: AppColors.cardShadow,
  ),
  child: Row([
    Container(44×44, radius 12, color.withValues(alpha:0.10))  // icon box
      child: Icon(22px, color),
    SizedBox(12),
    Expanded(Column([
      Text('$count', 26px w800 textPrimary),
      Text(label, 11px w500 textSecondary),
    ])),
  ]),
)
```

Cards: Total Employees (primary), Active (success), Onboarding (warning), Departments (`Color(0xFF7C3AED)`)

#### Filter bar
`_FilterBar` — horizontal scrollable row of filter chips (All / Active / Onboarding / Inactive) using `AnimatedContainer` for active state.

#### Results count
Text `'${list.length} employee(s)'` shown above the list when data is loaded.

#### Employee list
`ListView.separated` with `EmployeeCard` items, 12px separators, `RefreshIndicator`.

---

### Part 3: Employee Profile Screen Redesign

**File:** `features/employees/presentation/screens/employee_profile_screen.dart`

**Profile card (`_ProfileCard`):**
- Gradient header: `[AppColors.primary, Color(0xFF2A6ACC)]` matching home screen
- 68×68 white semi-transparent avatar circle with initials
- Employee name, ID, status badge in white
- 3-column info row: JOINED | LOCATION | DEPT (`_InfoCell`)
- Active/Inactive toggle using `Switch.adaptive(activeTrackColor: AppColors.success)`

**Tab bar:**
`TabController(length: 5)` with tabs: Profile / Salary / Payroll / Leave / Attendance.
Implemented via `NestedScrollView` + `SliverPersistentHeader` for pinned tab bar.

**Profile tab (`_ProfileTab`):**
3 sub-tab pills (Basic Detail / Employee Detail / Personal Detail) with a section card body.
Section card header: 4px primary left border, primary-tinted background, icon chip + title.

**Sub-tab content — all fields use `_DisplayField` in `_FieldRow` pairs (2-column layout):**

| Tab | Fields (pair rows) |
|---|---|
| Basic Detail | EmpCode/FirstName, MiddleName/LastName, Gender/Category, ProfTax/DOB, DOJ/ESI, Metro/ESIDispensary, ContractPeriod (full-width) |
| Employee Detail | Dept/Designation, Branch/ReportingMgr, EmpType/WorkLocation, CostCentre/ProbationEnd, ConfirmStatus/Grade, Band/EmpStatus, SelfServiceRole (full-width) |
| Personal Detail | MaritalStatus/SpouseName, Nationality/Religion, BloodGroup/DifferentlyAbled, PersonalEmail/MobileNumber, PAN/Aadhaar, LoginEmail (full-width) |

**`_FieldRow`:** `Padding(bottom:14) > Row([Expanded(_DisplayField), SizedBox(12), Expanded(_DisplayField)])`
**`_DisplayField`:** label + optional `*` + bordered container (background tint, border, radius 8, padding 10h/11v, 13px value text). Added `padBottom` parameter to control bottom spacing when used inside `_FieldRow`.

**Backend note:** Backend `_employee_dict()` only exposes: `id, employee_id, first_name, last_name, full_name, email, phone, department, designation, branch, role, role_display, date_of_joining, date_joined, is_active, status`. Fields not yet on backend (gender, DOB, category, ESI, PAN, etc.) display `'—'` until backend adds them.

**Lint fixes applied during this session:**
- `activeColor` deprecated → replaced with `activeTrackColor: AppColors.success` on `Switch.adaptive`
- Added `const` to `_FieldRow` and `_DisplayField` instantiations where all args are literals
- Added `const` to `Icon()` usages in section header chips
- Changed `TextStyle()` for stat count to `const TextStyle(...)` since `AppColors.textPrimary` is const

---

### Part 4: Announcements Screen — Stat Cards Update

**File:** `features/announcements/presentation/announcements_screen.dart`

Updated `_StatsRow` and `_StatCard` to match the employees screen format exactly.

**Before:** 4 cards in a single `Row` with tinted-header + colored count style (icon + dot in colored strip header, large colored count, tiny grey label).

**After:** 2×2 grid (`Column` of two `Row`s, 12px gaps) with icon-box + dark count style.

New `_StatCard` matches employees format:
- White bg, `AppColors.border` border, `AppColors.cardShadow`
- 44×44 icon box (`color.withValues(alpha:0.10)`, radius 12)
- Count: 26px, w800, `AppColors.textPrimary` (dark, not colored)
- Label: 11px, w500, `AppColors.textSecondary`

Cards: Total Posts (primary), Pinned (`Color(0xFFC99A2E)`), Reactions (`Color(0xFFD4487B)`), Total Views (`Color(0xFF0D7490)`)

---

### Files Modified
```
lib/features/
  employees/
    presentation/
      employees_screen.dart                 stats grid 2×2, filter bar, results count
      widgets/employee_card.dart            full redesign — left accent strip
      screens/employee_profile_screen.dart  full redesign — gradient header, 5 tabs, profile sub-tabs
  announcements/
    presentation/
      announcements_screen.dart             stat cards → 2×2 grid, employees format
```

### Pending Tasks
- [ ] Backend: expose additional profile fields (gender, DOB, category, ESI, PAN, Aadhaar, marital status, nationality, etc.) from `_employee_dict()` or a dedicated profile endpoint
- [ ] Salary tab content
- [ ] Payroll tab content
- [ ] Leave tab content (leave balance + history)
- [ ] Attendance tab content
- [ ] Employee create / edit form (currently opens empty modal)
- [ ] Attendance module screen
- [ ] Leave module screen
- [ ] Payroll module screen

---

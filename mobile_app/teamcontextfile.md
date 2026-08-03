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

## Session 6

**Date:** 2026-06-29
**Developer:** Vignesh Kumar Saka

### Module Worked On
- Branch Management — full Clean Architecture implementation

---

### Completed Tasks

#### Feature: Branch Management (`lib/features/branches/`)

Implemented the complete Branch Management feature following the exact same Clean Architecture pattern as the `settings` feature (domain / data / presentation layers). All providers use `.autoDispose`.

#### 1. Domain Layer

**`domain/entities/branch_entity.dart`**
Four immutable entity classes:
- `StateEntity` — id, name, code
- `CityEntity` — id, name, stateId, stateName
- `BranchEntity` — full branch data (id, branchCode, branchName, address, stateId/Name, cityId/Name, employeesCount, status, isHeadquarter). Computed getter `isActive` returns `status == 'active'`.
- `BranchStatsEntity` — totalBranches, totalActiveBranches, totalInactiveBranches, totalCities, totalEmployees

**`domain/repositories/branch_repository.dart`**
Abstract repository contract with 8 methods: getStates, getCities, previewBranchCode, getStats, getBranches, createBranch, updateBranch, deleteBranch.

#### 2. Data Layer

**`data/models/branch_model.dart`**
Model classes extending entities: `StateModel`, `CityModel`, `BranchModel`, `BranchStatsModel`. All with `fromJson` factories parsing exact backend field names (`branch_code`, `branch_name`, `employees_count`, `is_headquarter`, `state_name`, `city_name`).

**`data/datasources/branch_remote_datasource.dart`**
Uses the shared `Dio` instance. Parses the `{success, message, data}` envelope via `_unwrap()`. Handles paginated branch list response (`data['results']`).

**`data/repositories/branch_repository_impl.dart`**
Thin implementation delegating to datasource. Maps method params to backend JSON field names (`city`, `state`, `branch_name`, `address`, `status`, `is_headquarter`).

#### 3. Presentation Layer

**`presentation/providers/branch_providers.dart`**
Six `.autoDispose` providers:
- `branchDataSourceProvider` — stateless factory (non-autoDispose)
- `branchRepositoryProvider` — repo
- `branchStatsProvider` — `AsyncNotifier` with `refresh()`
- `branchListProvider` — `AsyncNotifier` with `create()`, `edit()`, `remove()`, `refresh()`
- `statesProvider` — `AsyncNotifier` for states list
- `citiesProvider(stateId)` — `autoDispose.family` `AsyncNotifier` for per-state cities

**`presentation/screens/branches_screen.dart`**
`ConsumerStatefulWidget` with:
- **Stats row** — horizontal `ListView` of 4 `_StatCard` widgets (Total Branches, Total Workforce, Cities Covered, Active Branches) with colored icon boxes and big numbers
- **"+ Add Branch" FilledButton** top right
- **Branch grid** — `SliverGrid` with `maxCrossAxisExtent: 300` (auto-adapts: 2 columns on tablet, 1 on narrow mobile)
- **Delete confirmation** — `showDialog` with "Are you sure you want to delete this branch?" + Cancel/OK
- **Employee Distribution section** — custom bar chart using `Stack`/`Container` (no external charting dependency). Navy filled bars, proportional to max count. Shows branch name + count. Navy banner header fused to card top (same pattern as Session 3).
- Pull-to-refresh via `RefreshIndicator`
- Loading state: shimmer placeholder cards (grey containers)
- Error state: retry button with `ref.invalidate`

**`presentation/widgets/branch_card.dart`**
`BranchCard` widget taking `BranchEntity`, `onEdit`, `onDelete` callbacks:
- Navy icon box with `Icons.business_outlined`
- Branch name bold, branch code in grey caption
- Gold "HQ" badge if `isHeadquarter`
- City row (`Icons.location_on_outlined`) + State row (`Icons.flag_outlined`)
- Divider + employees count + Active/Inactive status badge with colored dot
- Edit (left) / Delete (right, red) buttons separated by `VerticalDivider`

**`presentation/widgets/branch_form_dialog.dart`**
`StatefulWidget` dialog (matched `DeptFormSheet` pattern from Session 4):
- `_DlgHeader` — navy top header with white icon, title, subtitle, close button
- Add mode: "Add New Branch" / "Create Branch"
- Edit mode: "Edit Branch: {name}" / "Save Changes"
- Fields: State dropdown → City dropdown (disabled until state selected, loads via `citiesProvider(stateId)`) → Branch Code (read-only, auto-fetched via `previewBranchCode` API when city selected) → Branch Name → Address (3 lines) → Status dropdown → HQ checkbox
- Uses `initialValue:` + `ValueKey` pattern (instead of deprecated `value:`) for reactive `DropdownButtonFormField` updates
- Full validation with per-field error text
- On success: closes dialog + refreshes stats provider

#### 4. Modified Files

**`lib/core/constants/api_constants.dart`**
Added 6 branch constants: `branchStates`, `branchCities(int)`, `branchPreviewCode`, `branchStats`, `branches`, `branchDetail(int)`. Also removed unused `dart:io` import.

**`lib/core/router/app_router.dart`**
- Added `BranchesScreen` import
- Replaced `PlaceholderScreen(title: 'Branch Management', ...)` route with `BranchesScreen()`

### Files Created
```
lib/features/branches/
  domain/
    entities/branch_entity.dart
    repositories/branch_repository.dart
  data/
    models/branch_model.dart
    datasources/branch_remote_datasource.dart
    repositories/branch_repository_impl.dart
  presentation/
    providers/branch_providers.dart
    screens/branches_screen.dart
    widgets/branch_card.dart
    widgets/branch_form_dialog.dart
```

### Files Modified
```
lib/
  core/
    constants/api_constants.dart    added branch endpoints, removed unused import
    router/app_router.dart          wired BranchesScreen, removed PlaceholderScreen
```

### Analysis Result
`flutter analyze --no-pub` → **No issues found**

### Key Architecture Notes
- **No `value:` deprecated param** — all `DropdownButtonFormField` instances use `initialValue:` + `ValueKey` to force widget rebuild on state change (matching Session 3 pattern from `desig_form_sheet.dart`)
- **No fl_chart dependency** — employee distribution chart built with `Stack`/`Container` bars using `LayoutBuilder` for proportional widths. No `pubspec.yaml` change needed.
- **citiesProvider family** — `AutoDisposeFamilyAsyncNotifier<List<CityEntity>, int>` — one provider per `stateId` arg, auto-disposed when form closes
- **Stats refresh after mutations** — `create`, `edit`, `remove` in `BranchListNotifier` all trigger `branchStatsProvider.notifier.refresh()` to keep stats in sync

### Pending Tasks
- [ ] Backend team: add `access` token to login response body + token refresh response body (carried from Session 4)
- [ ] Employee module implementation
- [ ] Attendance module
- [ ] Leave module
- [ ] Payroll module

---

## Session 7

**Date:** 2026-06-29
**Developer:** Vignesh Kumar Saka

### Module Worked On
- Branch Management — bug fixes, UI polish, and widget refactor
- Git remote setup (Sriainfotech org repo)
- VS Code Pyrefly interpreter fix

---

### Part 1: Branch Management Bug Fixes

#### Bug 1 — 404 on all branch API calls

**Root cause:** All API constants used `/branches/` as prefix (e.g. `/branches/branches/stats/`) but the Django root `urls.py` mounts the branch app at `/api/branch/`.

**Fix:** Changed all 6 constants in `api_constants.dart`:

| Before | After |
|--------|-------|
| `/branches/states/` | `/branch/states/` |
| `/branches/states/{id}/cities/` | `/branch/states/{id}/cities/` |
| `/branches/branches/preview-code/` | `/branch/branches/preview-code/` |
| `/branches/branches/stats/` | `/branch/branches/stats/` |
| `/branches/branches/` | `/branch/branches/` |
| `/branches/branches/{id}/` | `/branch/branches/{id}/` |

#### Bug 2 — RenderFlex overflow 172px in screen header

**Root cause:** `Row(children: [Text(...), Spacer(), FilledButton(...)])` — `Text` had no flex constraint so it expanded to its natural width on narrow viewport, leaving no room for the button.

**Fix:** Wrapped `Text` in `Flexible(child: Text(..., overflow: TextOverflow.ellipsis))` and replaced `Spacer()` with `const SizedBox(width: 8)`.

#### Bug 3 — Delete dialog crashes the app

**Root cause:** `Navigator.pop(context, false)` inside the dialog used the page-level `context` captured from `build()`. GoRouter owns that navigator stack — popping it threw *"You have popped the last page off of the stack"*.

**Fix:** Used the dialog's own context from the builder parameter:
```dart
builder: (dialogContext) => AlertDialog(
  actions: [
    TextButton(onPressed: () => Navigator.pop(dialogContext, false), ...),
    FilledButton(onPressed: () => Navigator.pop(dialogContext, true), ...),
  ],
)
```

#### Bug 4 — Extra blank space between location and employee rows on card

**Root cause:** A stray `Spacer()` inside the card's `Column` pushed the bottom content down.

**Fix:** Removed the `Spacer()` between the location section and the employee row.

#### Bug 5 — Extra space below Edit/Delete buttons on every card

**Root cause:** `Column(mainAxisSize: MainAxisSize.max)` expanded the card content to fill the fixed grid cell height, leaving white space between the last data row and the action buttons.

**Fix:** Set `mainAxisSize: MainAxisSize.min` on the card's `Column`.

#### Bug 6 — HQ badge card overflows by ~1px

**Root cause:** `SliverGrid` with a fixed `maxCrossAxisExtent` forced every card in a row to the same computed height. Cards with the HQ badge were ~1px taller than that computed height.

**Fix:** Replaced `SliverGrid` with `SliverList` + `IntrinsicHeight` rows:
```dart
SliverList(
  delegate: SliverChildBuilderDelegate((_, rowIndex) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: BranchCard(...)),
            const SizedBox(width: 12),
            right < branches.length
                ? Expanded(child: BranchCard(...))
                : const Expanded(child: SizedBox()),
          ],
        ),
      ),
    );
  }, childCount: rowCount),
)
```
Each row auto-sizes to the tallest card. The shorter card's `Spacer()` (before the Divider) fills the height difference so Edit/Delete stay at the bottom of both cards.

---

### Part 2: Branch Management UI Polish

#### Stats Row — redesigned from horizontal scroll to 2×2 grid

Replaced `ListView.builder` (horizontal scroll of 4 stat cards) with `GridView.count(crossAxisCount: 2, childAspectRatio: 2.5)` inside a `SliverToBoxAdapter`. Stats no longer scroll off screen; all 4 are always visible.

#### Branch Card — full visual redesign

| Element | Before | After |
|---------|--------|-------|
| Top bar | None | 4px accent bar (primary if active, textHint if inactive) |
| Icon | Plain navy box | Gradient box (primary → primary 75% opacity) with `BorderRadius.circular(12)` |
| Branch code | Plain text | Pill badge with `backgroundMid` fill |
| HQ indicator | Text label | Gold pill badge with `Icons.star_rounded`, border |
| Location | Two bare text rows | Grouped `Container` with `background` fill + border |
| Status | Text only | Dot + text pill badge (green/grey) |
| Actions | Flat row | Divider separator + `Spacer()` pushes them to card bottom |

#### Widget files extracted (to keep each file under 300 lines)

| New file | Extracted from |
|----------|---------------|
| `branch_stats_row.dart` | `branches_screen.dart` |
| `branch_list_states.dart` (`BranchEmptyView`, `BranchErrorView`) | `branches_screen.dart` |
| `employee_distribution.dart` | `branches_screen.dart` |
| `branch_dlg_header.dart` | `branch_form_dialog.dart` |
| `branch_location_selector.dart` | `branch_form_dialog.dart` |

`branch_location_selector.dart` exposes a public `BranchLocationSelectorState` class so the parent form dialog can call `_locationKey.currentState?.validate()` via a `GlobalKey<BranchLocationSelectorState>`.

---

### Part 3: Git Remote Setup

Added a second git remote for the Sriainfotech organisation repository:

```
sriai → https://github.com/Sriainfotech/Royal-HRMS.git
origin → https://github.com/pramodkunja/royal_hrms_1.git  (mobile_app only)
```

Pulled `backend/` and `frontend/` folder trees from `sriai/demo` branch.
`origin` (`pramodkunja/royal_hrms_1`) remains the tracking remote for `mobile_app/`.

---

### Part 4: VS Code Python Interpreter Fix

Created `.vscode/settings.json` at the repo root to point Pyrefly and the Python extension to the project's virtual environment:

```json
{
  "python.defaultInterpreterPath": "/Users/vigneshkumarsaka/royal_hrms_1/backend/venv/bin/python",
  "python.pythonPath":             "/Users/vigneshkumarsaka/royal_hrms_1/backend/venv/bin/python",
  "pyrefly.pythonInterpreter":     "/Users/vigneshkumarsaka/royal_hrms_1/backend/venv/bin/python"
}
```

This eliminated the false *"Import could not be resolved"* errors Pyrefly was showing for Django, DRF, and other installed packages (it was using system Python 3.9 which had none of these).

---

### Files Created
```
mobile_app/lib/features/branches/presentation/widgets/
  branch_stats_row.dart
  branch_list_states.dart
  employee_distribution.dart
  branch_dlg_header.dart
  branch_location_selector.dart
.vscode/settings.json
```

### Files Modified
```
mobile_app/lib/
  core/constants/api_constants.dart         corrected branch URL prefix /branches/ → /branch/
  features/branches/presentation/
    screens/branches_screen.dart            overflow fix, SliverGrid → SliverList+IntrinsicHeight
    widgets/branch_card.dart                full visual redesign (accent bar, gradient icon, etc.)
    widgets/branch_form_dialog.dart         extracted header + location selector to own files
    widgets/branch_stats_row.dart           2×2 GridView layout
```

### Analysis Result
`flutter analyze` → **No issues found**

### Pending Tasks (carried to Session 7)
- [ ] Document Center module
- [ ] Backend team: add `access` token to login + refresh response bodies (from Session 4)
- [ ] Employee module
- [ ] Attendance, Leave, Payroll modules

---

## Session 8

**Date:** 2026-06-29
**Developer:** Vignesh Kumar Saka

### Module Worked On
- Document Center (`HR OPS → Document Center`) — full Clean Architecture implementation with backend API integration

---

### Feature Overview

Implemented the complete Document Center screen matching the web UI design (3 screens: list, upload dialog, detail dialog). All files under 300 lines. All providers use `.autoDispose`.

**Backend API endpoints used:**

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/documents/stats/` | 4 stat counts |
| GET | `/api/documents/?category=&search=` | Paginated document list |
| POST | `/api/documents/` | Multipart file upload |
| GET | `/api/documents/<id>/` | Document detail |
| DELETE | `/api/documents/<id>/` | Soft delete (sets `is_active=False`) |

Files are stored on Cloudinary. The `file_url` field in every `DocumentEntity` is a 2-hour signed URL — used directly for Preview and Download by opening in the system browser.

---

### New Packages Added to `pubspec.yaml`

| Package | Version | Purpose |
|---------|---------|---------|
| `file_picker` | `^8.1.2` | Device file browser — supports PDF, DOC, XLS, PPT, images, TXT, CSV |
| `url_launcher` | `^6.3.0` | Opens signed Cloudinary URLs in browser for Preview / Download |

Run `flutter pub get` — packages are already installed (done during this session).

---

### Domain Layer

**`domain/entities/document_entity.dart`**
- `DocumentEntity` — id, title, description, category, categoryDisplay, fileUrl, fileName, fileType, fileSize, fileSizeDisplay, branchName?, uploadedByName, uploadedAt, isActive
- `DocumentStatsEntity` — total, policy, form, template, other

**`domain/repositories/document_repository.dart`**
Abstract contract: `getStats`, `getDocuments`, `createDocument`, `deleteDocument`.

---

### Data Layer

**`data/models/document_model.dart`**
`DocumentModel` and `DocumentStatsModel` with `fromJson` factories. `DocumentStatsModel` reads `json['by_category']` map for per-category counts.

**`data/datasources/document_remote_datasource.dart`**
Uses shared `Dio` instance. Parses `{success, message, data}` envelope via `_unwrap()`. File upload uses `FormData.fromMap` with `MultipartFile.fromFile`:
```dart
final formData = FormData.fromMap({
  'file': await MultipartFile.fromFile(filePath, filename: fileName),
  'title': title,
  'description': description,
  'category': category,
});
await _dio.post(ApiConstants.documents, data: formData,
    options: Options(contentType: 'multipart/form-data'));
```

**`data/repositories/document_repository_impl.dart`**
Thin delegation to datasource.

---

### Presentation Layer — Providers

**`presentation/providers/document_providers.dart`**

| Provider | Type | Description |
|----------|------|-------------|
| `documentDataSourceProvider` | `Provider` | Stateless factory (non-autoDispose) |
| `documentRepositoryProvider` | `Provider` | Repository |
| `documentStatsProvider` | `AsyncNotifierProvider.autoDispose` | Loads stats, exposes `refresh()` |
| `documentListProvider` | `AsyncNotifierProvider.autoDispose` | Full list with `upload()`, `remove()`, `refresh()` |
| `documentFilterProvider` | `StateProvider.autoDispose<String>` | Active filter: `'all'`, `'policy'`, `'form'`, `'template'` |
| `documentSearchProvider` | `StateProvider.autoDispose<String>` | Search query string |
| `filteredDocumentsProvider` | `Provider.autoDispose` | Derived — client-side filter + search applied to list |

Client-side filtering is used (documents loaded once, filtered in memory). This avoids extra API calls when the user switches filter tabs — the document count is small.

---

### Presentation Layer — Screen & Widgets

**`presentation/screens/documents_screen.dart`** (224 lines)
`ConsumerWidget` with `CustomScrollView` + `RefreshIndicator`. Structure:
1. Title row ("Document Center") + "Upload" `FilledButton`
2. Stats 2×2 grid (shimmer while loading)
3. `DocumentFilterBar` (search + filter chips)
4. Document grid via `_DocumentGrid` (SliverList + IntrinsicHeight — same pattern as branches)
5. Empty/error state handling

**`presentation/widgets/document_stats_row.dart`** (153 lines)
2×2 `GridView.count` with 4 stat cards (Total Documents, Policies, Forms, Templates). `DocumentStatsRowShimmer` shows grey placeholders during load.

**`presentation/widgets/document_filter_bar.dart`** (141 lines)
`ConsumerStatefulWidget`. Contains:
- `TextField` for search (writes to `documentSearchProvider`, shows clear button when non-empty)
- Horizontal `SingleChildScrollView` with 4 animated `_FilterChip` buttons

**`presentation/widgets/document_card.dart`** (197 lines)
Tap-to-open-detail card design:
- 3px top accent bar in file-type colour
- Coloured icon box (file type icon) + document title + file type badge
- File size + upload date row
- Uploader name row
- `Spacer()` + category pill badge at bottom
- File type colours: PDF=red, DOC=blue, XLS=green, PPT=orange, images=purple, TXT/CSV=grey

**`presentation/widgets/document_type_helpers.dart`** (57 lines)
Shared utility functions used by both `document_card.dart` and `document_detail_dialog.dart`:
- `documentTypeColor(String type) → Color`
- `documentTypeIcon(String type) → IconData`
- `formatDocDate(DateTime dt) → String`

**`presentation/widgets/document_upload_dialog.dart`** (249 lines)
`ConsumerStatefulWidget` dialog:
- Navy header: "Upload Document" + subtitle + close button
- `DocumentFilePicker` widget (tap-to-select, shows file name + size after selection)
- Document Name `TextFormField`
- Description `TextFormField` (3 lines, optional)
- Category `DropdownButtonFormField` (Policy / Form / Template / Other)
- Cancel + "Upload Document" buttons (spinner while uploading)

**`presentation/widgets/document_file_picker.dart`** (104 lines)
Extracted from upload dialog. Calls `FilePicker.platform.pickFiles()` with allowed extensions list. Shows cloud-upload icon + "Tap to select file" when empty; shows file name + size + green tick when a file is picked. Error text displayed in red if user tries to submit without selecting.

**`presentation/widgets/document_detail_dialog.dart`** (300 lines)
`ConsumerStatefulWidget` dialog:
- Navy header: document title + close button
- File preview card: large file-type icon (64px), file name, "PDF · 1.2 MB" subtitle
- Metadata card: Category, Uploaded by, Upload date, Access ("All Employees") — each row has icon + left label + right value
- Action row: Delete (red FilledButton, triggers confirm dialog + `remove()`) | Preview (outlined, opens fileUrl) | Download (navy FilledButton, opens fileUrl)
- Delete confirmation uses `dialogContext` (not outer context) — same GoRouter-safe pattern as branches

**`presentation/widgets/document_list_states.dart`** (85 lines)
`DocumentEmptyView` (folder icon + "No Documents Yet" + Upload button) and `DocumentErrorView` (error icon + message + Retry button).

---

### API Constants Added

```dart
// lib/core/constants/api_constants.dart
static const String documentStats  = '/documents/stats/';
static const String documents      = '/documents/';
static String documentDetail(int id) => '/documents/$id/';
```

### Router Updated

```dart
// lib/core/router/app_router.dart
// was: PlaceholderScreen(title: 'Document Center', icon: Icons.folder_outlined)
// now:
GoRoute(
  path: AppRoutes.documents,
  pageBuilder: (_, __) => const NoTransitionPage(child: DocumentsScreen()),
),
```

---

### Files Created
```
mobile_app/lib/features/documents/
  domain/
    entities/document_entity.dart
    repositories/document_repository.dart
  data/
    models/document_model.dart
    datasources/document_remote_datasource.dart
    repositories/document_repository_impl.dart
  presentation/
    providers/document_providers.dart
    screens/documents_screen.dart
    widgets/
      document_stats_row.dart
      document_card.dart
      document_filter_bar.dart
      document_upload_dialog.dart
      document_file_picker.dart
      document_detail_dialog.dart
      document_list_states.dart
      document_type_helpers.dart
```

### Files Modified
```
mobile_app/
  pubspec.yaml                              added file_picker ^8.1.2, url_launcher ^6.3.0
  pubspec.lock                              updated (flutter pub get run)
  lib/
    core/constants/api_constants.dart      added documentStats, documents, documentDetail(id)
    core/router/app_router.dart            wired DocumentsScreen, removed PlaceholderScreen
```

### Analysis Result
`flutter analyze` → **No issues found**

### Architecture Notes
- **Client-side filtering**: `filteredDocumentsProvider` derives from `documentListProvider` — no extra API calls when switching tabs. Suitable because document count is small.
- **Multipart upload**: Dio's `FormData` + `MultipartFile.fromFile` handles multipart. The base `Content-Type: application/json` header in `api_client.dart` is overridden per-request with `Options(contentType: 'multipart/form-data')`.
- **Preview / Download**: Both use the same Cloudinary signed URL from `doc.fileUrl`. `url_launcher` opens it in the system browser. No local file caching needed for MVP.
- **`dialogContext` pattern**: Delete confirmation inside `_DocumentDetailDialogState` uses `this.context` (State's context, not a parameter) with `if (!mounted) return` after each await — same GoRouter-safe pattern established in branches.
- **Shared type helpers**: `document_type_helpers.dart` avoids duplicate switch statements for color/icon/date logic across card and detail dialog.

### Pending Tasks
- [ ] Backend team: add `access` token to login + refresh response bodies (from Session 4)
- [ ] Test Document Center end-to-end: upload a PDF, view detail, preview, delete
- [ ] Employee module implementation
- [ ] Attendance module
- [ ] Leave module
- [ ] Payroll module

---

## Session 9

**Date:** 2026-06-29
**Developer:** Pramod Kunja

### Module Worked On
- Branch Management — single-column list layout + FAB + card layout fix
- Document Center — single-column list layout + FAB + card layout fix

---

### Part 1: Branch Management — Layout Changes

**File:** `features/branches/presentation/screens/branches_screen.dart`

#### Change 1 — "Add Branch" moved to FAB

Removed the inline `FilledButton.icon` from the header `Row`. Header is now just the `Text('Branch Management')` title.

Added `FloatingActionButton.extended` to the `Scaffold`:
```dart
floatingActionButton: FloatingActionButton.extended(
  onPressed: () => _openForm(context, null),
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  icon: const Icon(Icons.add),
  label: const Text('Add Branch', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
),
```

#### Change 2 — Cards changed from 2-column to single-column list

`_BranchGrid` previously used `SliverList` + `IntrinsicHeight` rows pairing two `BranchCard` widgets per row. Rewritten to one card per row:

```dart
// Before: rowCount = (branches.length / 2).ceil(), two cards per IntrinsicHeight row
// After:
SliverPadding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),  // 96px bottom = FAB clearance
  sliver: SliverList(
    delegate: SliverChildBuilderDelegate(
      (_, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: BranchCard(branch: branches[index], onEdit: ..., onDelete: ...),
      ),
      childCount: branches.length,
    ),
  ),
)
```

`_loadingGrid` updated to show 3 single full-width shimmer placeholders (height 180) instead of 2 paired rows.

---

### Part 2: Branch Card — RenderFlex Fix

**File:** `features/branches/presentation/widgets/branch_card.dart`

**Root cause of blank screen:** `BranchCard`'s outer `Column` had `mainAxisSize: MainAxisSize.max` combined with a `Spacer()` between the employees row and the `Divider`. This required a bounded height from the parent — `IntrinsicHeight` provided that in the 2-column layout. In a `ListView` (unbounded height), Flutter throws a `RenderFlex` overflow and renders nothing.

**Fix:**
```dart
// Before
Column(mainAxisSize: MainAxisSize.max, children: [
  ...
  const Spacer(),
  const Divider(height: 1, color: AppColors.border),
  ...
])

// After
Column(mainAxisSize: MainAxisSize.min, children: [
  ...
  const SizedBox(height: 10),
  const Divider(height: 1, color: AppColors.border),
  ...
])
```

---

### Part 3: Document Center — Layout Changes

**File:** `features/documents/presentation/screens/documents_screen.dart`

#### Change 1 — "Upload" moved to FAB

Removed the inline `FilledButton.icon` from the header `Row`. Header is now just `Text('Document Center')`.

Added `FloatingActionButton.extended` to the `Scaffold`:
```dart
floatingActionButton: FloatingActionButton.extended(
  onPressed: () => _openUpload(context),
  backgroundColor: AppColors.primary,
  foregroundColor: Colors.white,
  icon: const Icon(Icons.upload_file_outlined),
  label: const Text('Upload', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
),
```

#### Change 2 — Cards changed from 2-column to single-column list

`_DocumentGrid` rewritten from `IntrinsicHeight` paired rows to one card per row:
```dart
SliverPadding(
  padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
  sliver: SliverList(
    delegate: SliverChildBuilderDelegate(
      (_, index) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: DocumentCard(document: documents[index], onTap: () => onTap(documents[index])),
      ),
      childCount: documents.length,
    ),
  ),
)
```

`_loadingGrid` updated to 3 single full-width shimmer placeholders (height 140).

---

### Part 4: Document Card — RenderFlex Fix

**File:** `features/documents/presentation/widgets/document_card.dart`

Same root cause as Branch card: `mainAxisSize: MainAxisSize.max` + `Spacer()` requires bounded height.

**Fix:**
```dart
// Before
Column(mainAxisSize: MainAxisSize.max, children: [
  ...uploader row...
  const Spacer(),
  const SizedBox(height: 8),
  // category badge
])

// After
Column(mainAxisSize: MainAxisSize.min, children: [
  ...uploader row...
  const SizedBox(height: 8),
  // category badge
])
```

### Key Pattern — Spacer in ListView Cards

`Spacer()` inside a `Column` requires a bounded height. Two patterns provide bounded height:
- `IntrinsicHeight` (used in 2-column grid rows — computes intrinsic height from children)
- Fixed-height parent (e.g., `SizedBox(height: 200)`)

`ListView` children have **unbounded** height. If a card's `Column` contains a `Spacer()` and is placed directly in a `ListView`, Flutter throws `RenderFlex overflow` and the widget renders nothing.

**Rule:** Never use `Spacer()` inside a card `Column` unless the card is always wrapped in `IntrinsicHeight` or a fixed-height container.

### Files Modified
```
mobile_app/lib/features/
  branches/
    presentation/
      screens/branches_screen.dart    FAB, single-column list, shimmer fix
      widgets/branch_card.dart        mainAxisSize.min, Spacer → SizedBox(10)
  documents/
    presentation/
      screens/documents_screen.dart   FAB, single-column list, shimmer fix
      widgets/document_card.dart      mainAxisSize.min, Spacer removed

```

### Pending Tasks
- [ ] Backend team: add `access` token to login + refresh response bodies (from Session 4)
- [ ] Test Document Center end-to-end: upload a PDF, view detail, preview, delete
- [ ] Employee profile — Salary / Payroll / Leave / Attendance tab content
- [ ] Employee create / edit form (currently opens empty modal)
- [ ] Attendance module screen
- [ ] Leave module screen
- [ ] Payroll module screen

---

## Session 10 — Organisation Chart Screen + My Profile Screen

**Date:** 2026-06-29
**Developer:** Vignesh Kumar Saka
**Branch:** demo

---

### Overview

Two new screens implemented and wired into the router:
1. **Organisation Chart** — live data from backend employees API, rendered as a mobile tree layout
2. **My Profile** — static screen matching the web design with 5 card sections

---

### 1. Organisation Chart Screen

#### What Was Built
A full org chart feature using **clean architecture** (domain / data / presentation layers). No dedicated backend endpoint exists, so the chart is built client-side from the employees list API.

#### How It Works
- Fetches all employees from `/api/employees/?page_size=200`
- Fetches company name from `/api/settings/company/`
- Identifies the Managing Director by designation keywords (`managing director`, `chief executive`, `ceo`, `md`)
- Groups remaining employees by their `department` text field
- For each department, picks a head using designation keywords (`manager`, `director`, `head`, `lead`, `admin`, `supervisor`, `chief`)
- Assigns colors from an 8-color palette cycling by department index
- Displays MD card at top, then department cards in a tree layout with connector lines

#### Files Created
```
mobile_app/lib/features/org_chart/
  domain/
    entities/org_chart_entity.dart              OrgMemberEntity, DepartmentNodeEntity, OrgChartEntity
    repositories/org_chart_repository.dart      abstract interface
  data/
    datasources/org_chart_remote_datasource.dart fetchEmployees(), fetchCompanyName()
    repositories/org_chart_repository_impl.dart  _build(), _isMD(), _isHead(), color palette
  presentation/
    providers/org_chart_providers.dart           orgChartProvider (AutoDisposeAsyncNotifier)
    screens/org_chart_screen.dart               OrgChartScreen, _OrgTree, _DeptRow, _BranchPainter
    widgets/org_md_card.dart                    Managing Director card
    widgets/org_dept_card.dart                  Department card with colored accent bar + members
```

#### Files Modified
```
mobile_app/
  lib/core/constants/api_constants.dart   added: employees = '/employees/'
  lib/core/router/app_router.dart         wired OrgChartScreen, removed PlaceholderScreen
```

#### Key Technical Patterns
- **`_BranchPainter`** (`CustomPainter`): draws vertical line top-to-branch, optional vertical continuation for non-last items, horizontal branch right to card. `branchY = 32.0` aligns with the card's natural top padding.
- **`IntrinsicHeight` + `Row(crossAxisAlignment: CrossAxisAlignment.stretch)`**: allows variable-height dept cards while tree connector spans full card height.
- **8-color palette**: Orange, Blue, Green, Purple, Teal, Pink, Blue-grey, Red — cycling by `i % 8` so departments always get distinct colors.
- **`autoDispose` AsyncNotifier**: provider auto-clears when user leaves the screen — no stale data.
- **Pull-to-refresh**: `RefreshIndicator` wraps `CustomScrollView`; calls `notifier.refresh()` which sets `AsyncLoading` then re-fetches.

#### Analysis Result
`flutter analyze lib/features/org_chart/` → **No issues found**

#### Line Counts (all under 300-line rule)
| File | Lines |
|------|-------|
| org_chart_screen.dart | 254 |
| org_chart_repository_impl.dart | 122 |
| org_dept_card.dart | 112 |
| org_chart_remote_datasource.dart | 43 |
| org_chart_entity.dart | 43 |
| org_md_card.dart | 47 |
| org_chart_providers.dart | 29 |
| org_chart_repository.dart | 5 |

---

### 2. My Profile Screen

#### What Was Built
A fully static profile screen matching the web UI design with 5 card sections. No API calls — uses static/hardcoded data appropriate for an MVP. `TextEditingController`s are pre-filled with demo values.

#### Screen Sections
| Section | Content |
|---|---|
| **Personal Information** | Circle avatar (initials "SA"), name, username, "Change photo" button, 3 paired field rows: First/Last Name · Email/Phone · Role (read-only) / User ID (read-only) |
| **Change Password** | Current password field + New/Confirm side-by-side + "Update Password" outlined button |
| **Address** | Street address (full width) + City/PIN side-by-side + State/Country side-by-side |
| **Bank Details** | Bank Name/Account Number + IFSC Code/PAN Number |
| **Documents** | Static list: Aadhaar Card, PAN Card, Degree Certificate, Offer Letter — each with eye icon |

#### Files Created
```
mobile_app/lib/features/profile/
  presentation/
    screens/profile_screen.dart                  ProfileScreen (StatefulWidget, 258 lines)
    widgets/profile_widgets.dart                 ProfileSectionCard, ProfileField, ProfileFieldRow, ProfileDocumentItem
    widgets/profile_sections.dart                ProfileAddressSection, ProfileBankSection, ProfileDocumentsSection
```

#### Files Modified
```
mobile_app/
  lib/core/router/app_router.dart   wired ProfileScreen at /dashboard/profile, removed PlaceholderScreen
```

#### Key Technical Patterns
- **Split into 3 files** to stay under the 300-line rule: main screen (258), shared widgets (190), section widgets (131)
- **`ProfileSectionCard`**: reusable card wrapper with icon + title header, divider, and padded content — used across all 5 sections
- **`ProfileFieldRow`**: wraps two `Expanded` fields in a `Row` with 12px gap — used for all paired field layouts
- **Read-only fields**: `Role` and `User ID` use `readOnly: true` with `AppColors.backgroundLow` fill to visually indicate non-editable
- **18 `TextEditingController`s** all disposed in a single loop in `dispose()` — no memory leaks
- **"Save Changes"** button shows a `SnackBar` — placeholder for future API integration
- **"Update Password"** button is an `OutlinedButton.icon` with primary color border matching web design

#### Analysis Result
`flutter analyze lib/features/profile/` → **No issues found**

#### Line Counts (all under 300-line rule)
| File | Lines |
|------|-------|
| profile_screen.dart | 258 |
| profile_widgets.dart | 190 |
| profile_sections.dart | 131 |

---

### Pending Tasks (updated)
- [ ] Connect My Profile screen to real API (GET /profile/, PATCH /profile/, POST /change-password/)
- [ ] Connect Documents section in profile to real employee documents API
- [ ] Backend team: add `access` token to login + refresh response bodies (from Session 4)
- [ ] Test Document Center end-to-end: upload a PDF, view detail, preview, delete
- [ ] Employee module implementation
- [ ] Attendance module
- [ ] Leave module
- [ ] Payroll module

---

## Session 9 — Interview List Screen (Full API Integration)

**Date:** 2026-06-30
**Developer:** Vignesh Kumar Saka
**Branch:** demo

---

### Overview

Complete Interview List screen implemented with live API integration — matching the web UI design. Includes candidate listing, stat cards, search/filter, status changes, activity logs, add candidate form, and send-portal-login action.

---

### Features Implemented

| Feature | Detail |
|---|---|
| **Stat cards** | Total · Pending · Selected · Rejected — fetched from `/api/recruitment/candidates/stats/` |
| **Info banner** | Blue pipeline tip (matches web design) |
| **Search** | Live client-side search by name / email / position / branch |
| **Status filter chips** | All · Pending · Selected · Rejected — re-fetches on tap |
| **Candidate cards** | Avatar initials · name · email · status badge · position/branch/date/mode meta chips |
| **Status change** | 3-dot popup menu → valid transitions → `PATCH /recruitment/candidates/{id}/status/` |
| **Activity Log dialog** | Icon-coloured timeline (info/success/warn/error) → `GET /recruitment/candidates/{id}/` |
| **Send Login** | `POST /recruitment/candidates/{id}/send-portal-login/` — shown for `selected` candidates |
| **Add Candidate sheet** | Bottom sheet with full validation — branch dropdown (live from `/api/branch/branches/`), date picker, mode selector → `POST /recruitment/candidates/` |
| **Pull-to-refresh** | Refreshes both list and stats simultaneously |

---

### Files Created

```
mobile_app/lib/features/interview_list/
  domain/
    entities/candidate_entity.dart               CandidateEntity, CandidateLogEntity, CandidateStatsEntity
  data/
    models/candidate_model.dart                  CandidateModel, CandidateLogModel, CandidateStatsModel
    datasources/interview_datasource.dart        fetchStats, fetchCandidates, fetchCandidate, createCandidate, updateStatus, sendPortalLogin, resendPortalLogin
  presentation/
    providers/interview_providers.dart           candidateStatsProvider, candidateListProvider, filteredCandidatesProvider, candidateDetailProvider
    screens/interview_list_screen.dart           InterviewListScreen (part file — uses interview_list_widgets.dart)
    widgets/
      interview_list_widgets.dart                _Header, _InfoBanner, _StatsRow, _StatCard, _StatsShimmer, _SearchFilter, _EmptyView, _ErrorView (part of screen)
      interview_status_badge.dart                CandidateStatusBadge, candidateStatusColor(), candidateStatusLabel(), interviewModeLabel()
      candidate_card.dart                        CandidateCard, _MetaChip, _LogsButton, _StatusChangeButton, _PortalActionButton
      activity_log_dialog.dart                   ActivityLogDialog, _LogList, _LogItem
      add_candidate_sheet.dart                   AddCandidateSheet (part file — uses add_candidate_form.dart)
      add_candidate_form.dart                    _AddCandidateFormContent, _DropdownField<T>, _inputDec()
```

### Files Modified

```
mobile_app/
  lib/
    core/constants/api_constants.dart   added 6 recruitment candidate endpoints
    core/router/app_router.dart         wired InterviewListScreen at /dashboard/interview-list
```

---

### Bug Fixed — 404 on Candidates API

**Symptom:** Screen showed `DioException [bad response]: 404` on load.

**Root Cause:** API constants used `/candidates/` instead of `/recruitment/candidates/`. The Django root URL config mounts the recruitment app at `/api/recruitment/` (not `/api/`), as confirmed in `backend/config/urls.py`:
```python
path('api/recruitment/', include('apps.recruitment.urls')),
```

**Fix:** All 6 candidate API constants updated to use `/recruitment/candidates/` prefix.

**Commit:** `00725f0` — fix(mobile): correct recruitment API base path

---

### Architecture Notes

- **`part`/`part of` pattern**: `interview_list_screen.dart` declares `part '../widgets/interview_list_widgets.dart'` so private (`_`-prefixed) widget classes can be shared across the two files without making them public. Same pattern used for `add_candidate_sheet.dart` ↔ `add_candidate_form.dart`.
- **`autoDispose` providers**: Both `candidateListProvider` and `candidateStatsProvider` auto-dispose when the user leaves the screen — prevents stale data on re-entry.
- **`filteredCandidatesProvider`**: Derived provider — client-side search filter on top of the fetched list; no extra API calls.
- **`candidateDetailProvider`**: `FutureProvider.autoDispose.family<CandidateEntity, int>` — fetches full candidate with logs only when Activity Log dialog opens; auto-disposes when dialog closes.
- **Status action logic** (`_PortalActionButton`):
  - `converted` → static "Employee" teal chip
  - `portalCredentialsSent == true` or `offer_sent` → static "Login Sent" grey chip
  - `selected` and not sent → active "Send Login" button → `POST /send-portal-login/`
- **`_DropdownField<T>`** generic widget: wraps `DropdownButton` in a styled `Container` — avoids the deprecated `value` parameter on `DropdownButtonFormField` (deprecated after Flutter v3.33).
- **Branches in Add Candidate**: fetched from `/api/branch/branches/?page_size=100` in `initState` of the sheet — not a provider, because the sheet is short-lived and branches rarely change.

### Analysis Result
`flutter analyze lib/features/interview_list/` → **No issues found**

### Line Counts (all under 300-line rule)

| File | Lines |
|------|-------|
| interview_list_screen.dart | 105 |
| interview_list_widgets.dart | 291 |
| interview_status_badge.dart | 81 |
| candidate_card.dart | 262 |
| activity_log_dialog.dart | 183 |
| add_candidate_sheet.dart | 193 |
| add_candidate_form.dart | 288 |
| interview_providers.dart | 116 |
| interview_datasource.dart | 70 |
| candidate_model.dart | 85 |
| candidate_entity.dart | 69 |

---

### Pending Tasks (updated)
- [ ] Interview List: test Send Login flow end-to-end
- [ ] Connect My Profile screen to real API (GET /profile/, PATCH /profile/, POST /change-password/)
- [ ] Connect Documents section in profile to real employee documents API
- [ ] Backend team: add `access` token to login + refresh response bodies (from Session 4)
- [x] Employee Onboarding Wizard — implemented (Session 10)
- [ ] HR Candidate Review / Onboarding Approval screen (HR-side)
- [ ] Email Logs screen implementation
- [ ] Attendance module
- [ ] Leave module
- [ ] Payroll module

---

## Session 10

**Date:** 2026-06-30
**Developer:** Vignesh Kumar Saka

### Module Worked On
- Employee Onboarding Wizard (full implementation)
- Auth entity update (onboarding_status)
- Router redirect logic for onboarding flow

### Flow Implemented

```
Candidate receives portal login credentials via email
       ↓
Employee logs in → login response includes onboarding_status
       ↓
Router redirect logic (app_router.dart):
  pending / draft  →  /onboarding        (wizard, resumes from saved step)
  submitted        →  /onboarding/awaiting-approval  (waiting screen, no dashboard)
  complete         →  /dashboard          (full employee access)
```

### Screens Created

#### `/onboarding` — OnboardingScreen
- 5-step wizard with animated step indicator + progress bar
- Step labels: Personal, Education, Bank, Emergency, Documents
- Each step saves via `PATCH /api/onboarding/profile/step/{step}/`
- Resume capability: fetches profile on load, restores `currentStep` from server
- App bar shows "Step X of 5 — {StepName}" + Logout button
- Part file pattern: `onboarding_screen.dart` + `onboarding_steps.dart`

#### `/onboarding/awaiting-approval` — AwaitingApprovalScreen
- Full-screen static screen shown after submission
- Large hourglass illustration with animated pulse rings
- 3-step timeline: Profile Submitted (done) → HR Review → Account Activation
- Logout button — no dashboard access until HR approves

### Step Details

| Step | Widget | Fields | API |
|------|--------|--------|-----|
| 0 | `_PersonalStep` | First/Last name, DOB (date picker), Gender, Blood Group, Nationality, Marital Status, Father's Name, Phone, Address (line1, line2, city, state, pincode, country) | `PATCH /onboarding/profile/step/0/` |
| 1 | `_EducationStep` | Qualification (dropdown), Institution, Specialization, Year of Passing, Grade | `PATCH /onboarding/profile/step/1/` |
| 2 | `_BankStep` | Bank Name, Account Number (obscured), IFSC Code, Account Type, Branch Name + orange warning banner | `PATCH /onboarding/profile/step/2/` |
| 3 | `_EmergencyStep` | Contact Name, Relationship (dropdown), Phone, Email, Address | `PATCH /onboarding/profile/step/3/` |
| 4 | `_DocumentsStep` | Upload: Aadhaar, PAN, Passport Photo, Resume, Education Certificate, Other; delete uploaded docs; Submit button with confirm dialog | `POST /onboarding/documents/` + `POST /onboarding/submit/` |

### Files Created

```
mobile_app/lib/features/onboarding/
  domain/
    entities/onboarding_entity.dart    OnboardingProfileEntity, OnboardingPersonalEntity, OnboardingEducationEntity, OnboardingBankEntity, OnboardingEmergencyEntity, OnboardingDocEntity
  data/
    models/onboarding_model.dart       Model classes with fromJson/toJson for all entities
    datasources/onboarding_datasource.dart  fetchProfile, saveStep, uploadDocument, deleteDocument, submitProfile
  presentation/
    providers/onboarding_providers.dart    onboardingProfileProvider (AsyncNotifier), onboardingStepProvider (StateProvider)
    screens/
      onboarding_screen.dart           OnboardingScreen (5-step wizard host, part file)
      awaiting_approval_screen.dart    AwaitingApprovalScreen (static waiting screen)
    widgets/
      step_indicator.dart              OnboardingStepIndicator (animated dots + progress bar)
      onboarding_steps.dart            _PersonalStep, _EducationStep, _BankStep, _EmergencyStep, _DocumentsStep, _StepFormWrapper, _DropdownInput, _DocTypeCard, _UploadedDocRow (part of onboarding_screen.dart)
```

### Files Modified

```
mobile_app/lib/
  features/auth/domain/entities/user_entity.dart   added onboardingStatus field, needsOnboarding, awaitingApproval, onboardingComplete getters
  features/auth/data/models/user_model.dart         parse onboarding_status from JSON, include in toJson
  core/constants/api_constants.dart                 added 5 onboarding endpoints
  core/router/app_router.dart                       added /onboarding + /onboarding/awaiting-approval routes; updated redirect logic for onboarding status
```

### API Constants Added

```dart
static const String onboardingProfile = '/onboarding/profile/';
static String onboardingStep(int step) => '/onboarding/profile/step/$step/';
static const String onboardingDocuments = '/onboarding/documents/';
static String onboardingDocumentDetail(int id) => '/onboarding/documents/$id/';
static const String onboardingSubmit = '/onboarding/submit/';
```

### Router Redirect Logic

```dart
if (user.needsOnboarding)    → /onboarding             (pending/draft)
if (user.awaitingApproval)   → /onboarding/awaiting-approval  (submitted)
// complete or null          → normal dashboard routing
```

### Architecture Notes

- **No GoRouter redirect loop**: onboarding/awaiting paths are outside `/dashboard`, so existing `path.startsWith('/dashboard')` guard remains intact.
- **Step resume**: `onboardingProfileProvider` fetches profile on build; `currentStep` is synced from `profile.currentStep` so employees pick up where they left off.
- **File upload stub**: `onUpload` in `_DocumentsStep` calls provider but actual `MultipartFile` construction requires `file_picker` package (not yet installed) — wire up when file_picker is added.
- **Submit flow**: After `POST /onboarding/submit/`, app navigates directly to `/onboarding/awaiting-approval` — no auth refresh needed. On next login, router reads updated `onboarding_status` from login response.
- **`_DropdownInput`**: Same pattern as `_DropdownField<T>` from Interview List — uses raw `DropdownButton` inside `InputDecorator` to avoid deprecated `value` parameter.

### Analysis Result
`flutter analyze` → **No issues found** (full project)

### Pending (Backend team)
- [ ] Implement `GET /api/onboarding/profile/` → returns profile with `status`, `current_step`, nested `personal`, `education`, `bank`, `emergency`, `documents`
- [ ] Implement `PATCH /api/onboarding/profile/step/{step}/` → accepts step data, updates `current_step`
- [ ] Implement `POST /api/onboarding/documents/` → multipart upload
- [ ] Implement `DELETE /api/onboarding/documents/{id}/`
- [ ] Implement `POST /api/onboarding/submit/` → sets status to `submitted`
- [ ] Login response must include `onboarding_status` field in user data
- [ ] HR Approval endpoint: `PATCH /api/onboarding/{candidate_id}/approve/` → sets status to `complete`, converts candidate to employee

---

## Session 11 — Onboarding Wizard Fixes + AwaitingApproval Polling + File Uploads

**Date:** 2026-06-30
**Developer:** Vignesh Kumar Saka
**Branch:** demo

---

### Overview

Multiple bug fixes and feature completions for the Employee Onboarding Wizard implemented in Session 10.

---

### Fix 1 — Step 5 Button Row Overflow

**File:** `features/onboarding/presentation/widgets/onboarding_steps.dart`

**Problem:** "Previous", "Save Draft", and "Submit for Approval" were all in a single `Row`, causing 39px overflow on narrow screens.

**Fix:** Restructured into two rows:
- Row 1: "Previous" button aligned left
- Row 2: `Row(Expanded("Save Draft"), SizedBox(12), Expanded("Submit for Approval"))` — both action buttons take equal width

---

### Fix 2 — Submit Error Message Extraction

**Files:** `features/onboarding/data/datasources/onboarding_datasource.dart`, `features/onboarding/presentation/providers/onboarding_providers.dart`

**Problem:** Backend returns `{"success": false, "message": "Please upload..."}` but the catch blocks returned `e.toString()` which gave raw `DioException [bad response]: ...` to the user.

**Fix in datasource:** Added `DioException` catch in both `submitProfile` and `uploadDocument`:
```dart
on DioException catch (e) {
  final data = e.response?.data;
  if (data is Map && data['message'] is String) {
    throw Exception(data['message'] as String);
  }
  rethrow;
}
```

**Fix in provider:** Strip `"Exception: "` prefix before returning error string to UI:
```dart
final raw = e.toString();
return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
```

---

### Fix 3 — `document_type` Field Name

**File:** `features/onboarding/data/datasources/onboarding_datasource.dart`

**Problem:** Datasource was sending `doc_type` in the multipart form body but backend `EmployeeDocumentSerializer` expects `document_type`.

**Fix:** Changed multipart key from `'doc_type'` to `'document_type'`.

---

### Feature 4 — File Picker for Document Uploads (Flutter Web / Chrome)

**Files:** `features/onboarding/presentation/screens/onboarding_screen.dart`, `features/onboarding/presentation/widgets/onboarding_steps.dart`

**Problem:** "Upload" buttons on Step 5 did nothing — `onUpload` was a stub that never picked a file.

**Implementation:**
- Added `file_picker` and `dio` imports to `onboarding_screen.dart` (host file — `onboarding_steps.dart` is a `part of` file and cannot have its own imports)
- Changed `onUpload` lambda signature: `Future<String?> Function(String docType, PlatformFile file)`
- In `onboarding_screen.dart`, `onUpload` creates `MultipartFile.fromBytes(file.bytes!, filename: file.name)` — `withData: true` ensures `bytes` is populated on Flutter Web where no file path exists
- In `_DocumentsStepState`, added `_pickAndUpload(String docType)`:
  - Calls `FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf','jpg','jpeg','png'], withData: true)`
  - Validates 5MB max size
  - Shows spinner on the card's Upload button while uploading via `_uploading = <String>{}` set
  - Shows `SnackBar` on error

**Key technical note:** `part` files share the library host file's imports. Any package import needed in `onboarding_steps.dart` must be declared in `onboarding_screen.dart`.

---

### Feature 5 — AwaitingApprovalScreen with Polling

**File:** `features/onboarding/presentation/screens/awaiting_approval_screen.dart`

**Rewrite:** Full rewrite as `ConsumerStatefulWidget`.

**Polling:** `Timer.periodic(Duration(seconds: 30))` in `initState` polls `GET /api/onboarding/profile/` every 30 seconds. Cancelled in `dispose()`.

**Approval detection:** When `status == 'complete'`, sets `_approved = true` which switches the UI.

**Waiting view:** Hourglass icon, 3-step timeline (Profile Submitted → HR Review → Account Activation), "Check Status" (manual poll) + "Logout" buttons.

**Approved view:** Green checkmark, "Application Approved!" heading, full green timeline, "Go to Dashboard" button.

**"Go to Dashboard"** calls:
```dart
ref.read(authStateProvider.notifier).updateOnboardingStatus('complete');
```
This triggers the router redirect via `_RouterRefreshNotifier`.

---

### Fix 6 — `UserEntity.operator==` Not Detecting Status Change

**File:** `features/auth/domain/entities/user_entity.dart`

**Problem:** The Riverpod `ref.listen` in `appRouterProvider` never fired when `onboarding_status` changed from `'submitted'` to `'complete'` because `UserEntity.operator==` only compared `id`. Two objects with same ID but different `onboardingStatus` were treated as equal.

**Fix:**
```dart
@override
bool operator ==(Object other) =>
    identical(this, other) ||
    other is UserEntity && other.id == id && other.onboardingStatus == onboardingStatus;

@override
int get hashCode => Object.hash(id, onboardingStatus);
```

Also added `copyWith({String? onboardingStatus})` method.

---

### Feature 7 — `AuthNotifier.updateOnboardingStatus()`

**File:** `features/auth/presentation/controllers/auth_notifier.dart`

Added method to update auth state with new onboarding status without full re-login:
```dart
void updateOnboardingStatus(String status) {
  final user = state.value?.user;
  if (user == null) return;
  state = AsyncData(AuthState(user: user.copyWith(onboardingStatus: status)));
}
```
The fixed `operator==` ensures this state change propagates to the router listener.

---

### Files Modified

```
mobile_app/lib/
  features/
    auth/
      domain/entities/user_entity.dart               copyWith(), operator==, hashCode — include onboardingStatus
      presentation/controllers/auth_notifier.dart    added updateOnboardingStatus() method
    onboarding/
      data/datasources/onboarding_datasource.dart    DioException handling, document_type field name fix
      presentation/
        providers/onboarding_providers.dart          error string prefix stripping, MultipartFile param type change
        screens/
          onboarding_screen.dart                     file_picker + dio imports, onUpload wired to MultipartFile
          awaiting_approval_screen.dart              full rewrite — polling, approved state, router trigger
        widgets/
          onboarding_steps.dart                      button overflow fix (two-row layout), file picker integration, isUploading per-card spinner
```

### Key Architecture Notes

- **`part` file imports**: A `part of` file cannot declare its own `import` statements — imports must be in the host library file. Any package needed in `onboarding_steps.dart` (a part file) must be imported in `onboarding_screen.dart`.
- **Flutter Web file picking**: Use `withData: true` in `FilePicker.platform.pickFiles()` — this populates `PlatformFile.bytes`, required on web since no file path is available. `MultipartFile.fromBytes(bytes, filename: name)` then works on both web and native.
- **Riverpod state equality**: If `operator==` only compares `id`, state changes to other fields are invisible to `ref.listen` and `ref.watch`. Always include all fields that should trigger re-evaluation.
- **Backend status**: No `rejected` status exists in backend — status machine is `pending → draft → submitted → complete`. Rejected screen is not implementable without backend support.

### Pending Tasks (updated)
- [ ] Connect My Profile screen to real API
- [ ] Backend team: add `access` token to login + refresh response bodies (from Session 4)
- [ ] Test Document Center end-to-end
- [ ] Employee module
- [ ] Attendance module
- [x] Leave module — fully wired (Session 12)
- [ ] Payroll module

---

## Session 12 — Leave Module Full Backend Integration

**Date:** 2026-07-01
**Developer:** Pramod Kunja

### Module Worked On
- Leave Management — complete backend connection for all 5 tabs

### Root Cause Fixes

**1. Wrong API path prefix (`api_constants.dart`)**
All 7 leave endpoints used `/leaves/...` but the backend serves them at `/leave/...`.
Fixed every constant and removed the stale `leaveTeam` path (backend has no team endpoint — uses `leaveCalendar`):
```dart
static const String leaveTypes    = '/leave/policy/';
static const String leaveBalances = '/leave/balance/';
static const String leaveStats    = '/leave/stats/';
static const String leaves        = '/leave/requests/';
static const String leaveCalendar = '/leave/calendar/';
static String leaveDetail(dynamic id) => '/leave/requests/$id/';
static String leaveAction(dynamic id) => '/leave/requests/$id/approve/';
```

**2. Wrong field names in every model (`leave_models.dart`)**
Backend serializer field names did not match what the models expected:

| Model | Old (wrong) field | Correct field |
|---|---|---|
| `LeaveTypeModel` | `type_code` | `leave_type` |
| `LeaveTypeModel` | `display_name` | `leave_type_display` |
| `LeaveTypeModel` | `max_days` | `annual_days` |
| `LeaveBalanceModel` | `leave_type_id` (int) | `leave_type` (String code) |
| `LeaveBalanceModel` | `used` | `used_days` |
| `LeaveBalanceModel` | `total` | `total_days` |
| `LeaveRequestModel` | `employee` | `employee_name` |
| `LeaveRequestModel` | `dept` | `employee_dept` |
| `LeaveRequestModel` | `from_date` | `start_date` |
| `LeaveRequestModel` | `to_date` | `end_date` |

**3. UUID primary key on LeaveRequest**
Backend `LeaveRequest.id` is a `UUIDField`. The model was casting `json['id'] as num` → crash at runtime.
Fixed `LeaveRequestEntity.id` from `int` to `String` throughout entity → model → repository → datasource → providers.

**4. LeaveBalance has no integer ID**
`LeaveBalanceEntity` previously carried a `leaveTypeId: int`. The backend returns only the string code (`leave_type: 'CL'`). Removed the integer field; the code string is now the sole key.

**5. Wrong POST body for applyLeave (`leave_remote_datasource.dart`)**
```dart
// Before (wrong)
'leave_type_id': leaveTypeId,  // int
'from_date': fromDate,
'to_date': toDate,

// After (correct)
'leave_type':  leaveTypeCode,  // 'CL', 'EL', etc.
'start_date':  fromDate,
'end_date':    toDate,
'duration':    duration,       // 'full_day' | 'half_day_morning' | 'half_day_afternoon'
```

### Widget Rewrites

**`leave_dashboard_tab.dart`** → `ConsumerStatefulWidget`
- Watches `leaveBalancesProvider` (horizontal scroll of balance cards)
- Watches `leaveRequestsProvider` (request list with approve/reject buttons)
- Pull-to-refresh invalidates both providers
- Branch filter applied client-side on `request.branch`
- ISO date formatter `_fmtIso()` converts `'YYYY-MM-DD'` → `'D MMM'`
- Approve/reject dialogs call `leaveRequestsProvider.notifier.approveRequest(id)` / `rejectRequest(id, reason)`

**`leave_approvals_tab.dart`** → `ConsumerStatefulWidget`
- Same provider wiring as dashboard
- Pending/History sub-tabs filter `isPending` client-side
- Real approve/reject wired to notifier methods with `String id` (UUID)

**`apply_leave_type_selector.dart`** — dynamic data support
- `LeaveTypeOption.fromEntities(LeaveTypeEntity, LeaveBalanceEntity?)` factory
- `LeaveTypeOption.listFromEntities(types, balances)` static builder
- `_colorForCode(String code)` helper maps 'CL'→primary, 'EL'→success, etc.
- `LeaveTypeSelector` now accepts `List<LeaveTypeOption> types` parameter (no more `kLeaveTypes` const)

**`apply_leave_tab.dart`** → `ConsumerStatefulWidget`
- Watches `leaveTypesProvider` + `leaveBalancesProvider` → builds `LeaveTypeOption` list
- `ref.listen(leaveTypesProvider, ...)` auto-selects first type once data loads
- `_EmployeeBanner` reads `authStateProvider` — shows real `fullName`, `employeeId`, `designation`, `department`
- `_submit()` calls `leaveRequestsProvider.notifier.applyLeave(leaveTypeCode: ..., duration: ...)` then invalidates balance + stats providers
- Duration enum maps: `fullDay` → `'full_day'`, `halfMorning` → `'half_day_morning'`, `halfAfternoon` → `'half_day_afternoon'`

**`leave_analytics_tab.dart`** → `ConsumerWidget`
- Watches `leaveStatsProvider` for the 4 KPI cards (total / pending / approved / rejected)
- Department breakdown + monthly trend + top takers remain mock (no backend endpoint for these aggregations yet)
- Pull-to-refresh invalidates `leaveStatsProvider`

**`leave_screen.dart`** → `ConsumerStatefulWidget`
- `_openBranchSheet()` reads `branchListProvider.valueOrNull` → maps `b.branchName` → passes as `branches:` to `_BranchSheet`
- `_BranchSheet` now accepts `branches: List<String>` instead of the removed `_kBranches` const
- Empty state shown if provider hasn't loaded yet

### Architecture Notes
- `leaveRequestsProvider` is a single provider for all roles — pending/history split is client-side only
- `leaveStatsProvider` is autoDispose; invalidate after apply/approve/reject to keep KPIs fresh
- `branchListProvider` is imported from `features/branches/presentation/providers/branch_providers.dart`
- `BranchEntity.branchName` is the display field (not `.name`)

### Files Modified
```
mobile_app/lib/
  core/constants/api_constants.dart
  features/leave/
    domain/entities/leave_entity.dart
    domain/repositories/leave_repository.dart
    data/models/leave_models.dart
    data/datasources/leave_remote_datasource.dart
    data/repositories/leave_repository_impl.dart
    presentation/
      providers/leave_providers.dart
      screens/leave_screen.dart
      widgets/
        leave_dashboard_tab.dart
        leave_approvals_tab.dart
        apply_leave_type_selector.dart
        apply_leave_tab.dart
        leave_analytics_tab.dart
```

### Pending Tasks (updated)
- [ ] Connect My Profile screen to real API
- [ ] Backend team: add `access` token to login + refresh response bodies (from Session 4)
- [ ] Test Document Center end-to-end
- [ ] Employee module — attendance tracking
- [ ] Payroll module
- [ ] Wire team calendar tab to real calendar API (`/leave/calendar/`)
- [ ] Leave history side-cards in apply form (replace mock `_kLeaveHistory` with real requests)

---

## Session 13 — Payroll Static UI: Run Payroll Wizard, Payslips, Payroll Rules

**Date:** 2026-07-01
**Developer:** Vignesh Kumar Saka

### Overview
This session completed four major static UI screens — Run Payroll 8-step Wizard, Payroll Rules Settings, My Payslips, and wired them all into the router. All screens are 100% static (no API calls); they demonstrate the complete UX flow with interactive state toggles. A recurring overflow crash caused by the app theme's `ElevatedButton` minimumSize was also fixed.

---

### 1. Run Payroll — 8-Step Wizard (`run_payroll_screen.dart`)

**File:** `lib/features/payroll/presentation/screens/run_payroll_screen.dart`

**Trigger:** "Run Payroll" button in `PayrollScreen` header — now navigates via `Navigator.push(MaterialPageRoute(...))`.

**Architecture:**
- `RunPayrollScreen` is a `StatefulWidget` with a single `int _step` (0–7) and per-step state booleans: `_calculated`, `_issueStates` (List of 3), `_approvalComplete`, `_payslipsGenerated`.
- A shared `_StepperBar` widget at the top of the AppBar renders 8 step circles connected by lines — green check for completed, filled navy for current, grey for future.
- Footer row: Back (OutlinedButton) + Continue/Finish Payroll (ElevatedButton) — both use `minimumSize: const Size(0, 44)` to avoid theme crash.
- Step 8 "Finish Payroll" button pops the navigator back to the Payroll screen.

**Step-by-step breakdown:**

| Step | Widget | Interactive |
|---|---|---|
| 1 · Period Setup | 6 dropdowns (Month, Year, Branch, Dept, Employee Type, Payroll Type, Salary Date) + employee count info banner (248 employees) | Static |
| 2 · Earn. & Deduct. | Horizontally scrollable Earnings table (7 cols × 5 employees + totals row) + Deductions table (9 cols × 5 employees + totals row) | Static |
| 3 · Reimb. & Bonuses | Reimbursements table (7 cols × 5 employees) + Bonuses & Incentives table (6 cols × 5 employees) | Static |
| 4 · Calculation | 4 stat cards (Gross/Deductions/Net/Employees) + pre-state empty view with "Calculate All Salaries" button → post-state shows 5-employee salary list | Button toggles `_calculated` |
| 5 · Validation | Red/amber error banner + 3 issue cards (1 critical, 2 warning) each with Fix/Ignore buttons; Continue disabled until all issues are fixed or ignored | Fix/Ignore toggle `_issueStates` |
| 6 · Approval | 3-level approval timeline (Rajan Pillai approved, Divya Krishnan pending with textarea + Approve/Reject/Send Back buttons, CEO Office pending) → tapping Approve sets `_approvalComplete` true, all 3 show approved | Button toggles `_approvalComplete` |
| 7 · Payslips | 5-employee table with Pending/Generated status badges + download/email/preview icons (grey until generated); "Generate All" button + 0/5 counter | Button toggles `_payslipsGenerated` |
| 8 · Bank Transfer | Bank/Account/IFSC/NetPay/Status table + per-row tap-to-mark-paid toggle + "Mark All Paid" button; Generate Bank File + Export Excel (OutlinedButtons); total row ₹3,01,283 | Per-row `_paidRows` list + Mark All |

**Shared helpers in this file:**
- `_card()` — standard white rounded card builder
- `_tableHeader()` / `_tableRow()` — flex-ratio column table helpers
- `_empAvatar()` — circular avatar from `_Emp` data
- `_kEmps` — shared list of 5 static employees used across Steps 2–8

---

### 2. Payroll Rules Settings Screen (`payroll_rules_screen.dart`)

**File:** `lib/features/settings/presentation/payroll_rules/payroll_rules_screen.dart`

**Route:** `/settings/payroll-rules` — pushed from Settings hub (Modules → Payroll Rules tile, previously "Soon", now tappable).

**Screen structure:**
- `SettingsAppBar` with "Payroll Rules" title + **Save All Changes** button (navy, `minimumSize: Size(0, 34)`).
- AppBar `bottom:` = `TabBar(isScrollable: true)` with 3 tabs: Earnings Rules | Deduction Rules | Payroll Run Settings.
- 4 live stat chips below AppBar (count updates as toggles change):
  - **10** Earning Components · **9** Deduction Rules · **5** Statutory Rules · **17** Active Rules

**Tab 1 — Earnings Rules:**
- 10 components: Basic Salary (40% of CTC), HRA (50% of Basic), DA (15%), Special Allow. (10%), Conveyance (₹1,600/mo), Medical (₹1,250/mo), Travel (₹2,000/mo), Internet (₹500/mo, disabled), Incentives (Variable), Overtime (Variable).
- Each row: component name + `_typeBadge` (Percentage=blue, Fixed Amount=grey, Variable=green, Slab-based=amber) + value + `Switch` toggle + effective date chip + applies-on chip + edit icon.
- Internet Allowance starts disabled (grey row).

**Tab 2 — Deduction Rules:**
- 9 components: PF (12%), ESI (0.75%), Professional Tax (₹200), Income Tax/TDS (slab-based), Labour Welfare Fund (₹25), Loan EMI (variable), Salary Advance Recovery (variable), LOP (variable), Other Deductions (disabled).
- Same row structure as Earnings; statutory rows (PF, ESI, PT, TDS, LWF) additionally show a purple "Statutory" chip.

**Tab 3 — Payroll Run Settings:**
- 4 rows of 2-column form using real `DropdownButtonFormField` and `TextField` widgets:
  - Pay Frequency (Monthly) | Payroll Lock Date (25)
  - Pay Day (28) | ESI Ceiling Gross ₹ (21000)
  - PT State (Karnataka) | LOP Calculation (Working Days)
  - Auto-approve Threshold (0) | Employer PF % (12)
- **Save Run Settings** button (navy, `minimumSize: Size(0, 44)`, aligned right).

**Bug fixed in this screen:**
- `Transform.scale(scale: 0.78)` on `Switch` inside a `SizedBox(width: 56)` caused a 4px RenderFlex overflow on every row because `Transform` does not affect layout box size — the Switch's native ~60px width overflowed the 56px container.
- **Fix:** Removed the `SizedBox`/`Row` wrapper. Used `Transform.scale(scale: 0.78, alignment: Alignment.centerRight)` directly, letting the switch occupy its native layout width without constraint.

---

### 3. My Payslips Screen (`my_payslip_screen.dart`)

**File:** `lib/features/payroll/presentation/screens/my_payslip_screen.dart`

**Route:** `/dashboard/my-payslip` (was `PlaceholderScreen`, now replaced).

**Screen structure (single scrollable column inside dashboard shell):**

**Page header row:**
- "My Payslips" title + subtitle
- **Email** OutlinedButton + **Download PDF** ElevatedButton (both `minimumSize: Size(0, 34)`)

**Employee card:**
- Navy gradient banner (LinearGradient 1B3A6B→2A5298) with circular avatar "AM" + name/role/emp-code pill
- 4-column detail row below: Department | Date of Join | PAN | UAN

**Month selector:**
- `SELECT MONTH` label + horizontally scrollable chip row
- 4 months: June 2026 (default selected, navy), May, April, March 2026
- Each chip: month name + salary date + green "Paid" badge
- Tapping a chip calls `setState(() => _selectedMonth = i)` — rebuilds the payslip document below

**Payslip document (white card, rounded, full-width):**

| Section | Details |
|---|---|
| Company header | Navy gradient — "Royal Staffing Services LLP" + address + CIN on left; "PAYSLIP" badge + month + salary date on right |
| Employee meta | 4-column row: Employee ID (EMP-0042) · Bank (HDFC Bank) · Account No. (XXXX4521) · IFSC Code (HDFC0001234) |
| Stats row | 3 equal blocks with VerticalDividers: **26** Working Days in June 2026 · **26** Paid Days (days credited) · **0** Loss of Pay (no LOP) |
| Earnings | 6 line items (Basic ₹45k, HRA ₹18k, DA ₹4.5k, Special Allow. ₹6k, Bonus ₹5k, OT ₹2k) + highlighted **Gross Earnings ₹80,500** row |
| Deductions | Red-tinted container — 4 items (PF ₹5,400 · PT ₹200 · TDS ₹3,500 · Loan EMI ₹5,000) + **Total Deductions ₹14,100** in red |
| Reimbursements | Icon + total ₹4,000 + 4 blue chips: TRAVEL ₹2,000 · MEDICAL ₹500 · INTERNET ₹500 · FOOD ₹1,000 |
| Net Salary | Formula chips (Gross ₹80,500 − Ded. ₹14,100 + Reimb. ₹4,000) + navy gradient bar showing **₹70,400** + LinearProgressIndicator (87.4% of gross) |
| Footer | "Computer-generated payslip" disclaimer text |

---

### 4. Router & Navigation Updates

**File:** `lib/core/router/app_router.dart`

Changes made this session:
- Added import: `payroll/presentation/screens/run_payroll_screen.dart`
- Added import: `payroll/presentation/screens/my_payslip_screen.dart`
- Added import: `settings/presentation/payroll_rules/payroll_rules_screen.dart`
- Added route constant: `static const String settingsPayrollRules = '/settings/payroll-rules'`
- `/dashboard/my-payslip` → replaced `PlaceholderScreen` with `MyPayslipScreen()`
- `/settings/payroll-rules` → new `GoRoute` → `PayrollRulesScreen()`
- `RunPayrollScreen` is NOT a GoRouter route — it is pushed via `Navigator.push(MaterialPageRoute(...))` from the Run Payroll button in `PayrollScreen`, keeping it outside the shell.

**File:** `lib/features/settings/presentation/settings_hub/settings_screen.dart`
- Payroll Rules tile: added `route: AppRoutes.settingsPayrollRules` (was `null`, tile was showing "Soon" badge and was non-tappable)

---

### 5. Critical Bug — ElevatedButton Infinite Width in Rows

**Root cause (documented for the whole codebase):**
`AppTheme` sets `minimumSize: const Size.fromHeight(48)` on all `ElevatedButton`. `Size.fromHeight(48)` resolves to `Size(double.infinity, 48)`. When an `ElevatedButton` is placed inside a `Row` (unbounded horizontal), Flutter's `_InputPadding` ConstrainedBox applies `minWidth: double.infinity` which cannot be satisfied → crash: *"BoxConstraints forces an infinite width"*.

**Rule:** Every `ElevatedButton` or `OutlinedButton` placed inside a `Row` MUST override with:
```dart
style: ElevatedButton.styleFrom(minimumSize: const Size(0, 36), ...)
```

This was applied to all buttons in Row widgets in `PayrollScreen`, `RunPayrollScreen`, `MyPayslipScreen`, and `PayrollRulesScreen`.

---

### Files Created This Session
```
lib/features/payroll/presentation/screens/
  run_payroll_screen.dart    (NEW — 8-step Run Payroll wizard)
  my_payslip_screen.dart     (NEW — My Payslips screen)

lib/features/settings/presentation/payroll_rules/
  payroll_rules_screen.dart  (NEW — Payroll Rules settings screen)
```

### Files Modified This Session
```
lib/core/router/app_router.dart
  — added 3 imports, 1 new route constant, 1 new GoRoute, replaced 1 PlaceholderScreen

lib/features/payroll/presentation/screens/payroll_screen.dart
  — added import run_payroll_screen.dart
  — Run Payroll button onPressed: now Navigator.push to RunPayrollScreen

lib/features/settings/presentation/settings_hub/settings_screen.dart
  — Payroll Rules tile route: null → AppRoutes.settingsPayrollRules
```

### Pending Tasks (updated)
- [ ] Connect My Profile screen to real API
- [ ] Backend team: add `access` token to login + refresh response bodies (from Session 4)
- [ ] Test Document Center end-to-end
- [ ] Wire team calendar tab to real calendar API (`/leave/calendar/`)
- [ ] Leave history side-cards in apply form (replace mock `_kLeaveHistory` with real requests)
- [ ] My Payslips — wire month selector to real payslip API (currently all static data)
- [ ] Run Payroll wizard — wire Period Setup to real employees/branches/departments providers
- [ ] Run Payroll wizard — wire Calculation step to real payroll calculation API
- [ ] Run Payroll wizard — wire Bank Transfer step to real disbursement API
- [ ] Payroll Rules — wire toggles + Save buttons to real settings API
- [ ] Payroll Run Settings — wire Save Run Settings to real API
- [ ] Add "My Requests" screen (currently PlaceholderScreen)
- [ ] Add "Approvals" screen (currently PlaceholderScreen)
- [ ] Add "Separation & FnF" screen (currently PlaceholderScreen)
- [ ] Add "Reports" screen (currently PlaceholderScreen)

---

## Session 14 — Settings: Leave Policy + Credit Rules Merged Into Tabbed Screen

**Date:** 2026-07-01
**Developer:** Pramod Kunja

### Module Worked On
- Settings → Leave Policy — merged the separate "Leave Policy" and "Leave Credit Rules" screens into one tabbed screen (matching web mockup screenshots), fixed Credit Rules visual design, wired a real backend action that was previously unused.

### What Changed

**1. Tabbed screen (`leave_policy_screen.dart`)**
- `LeavePolicyScreen` now hosts a `TabController` with 2 tabs — "Policy" and "Credit Rules" — via `SettingsAppBar(bottom: TabBar(...))`.
- The standalone Credit Rules route/screen was removed; `CreditRulesTab` is now a tab body (`ConsumerStatefulWidget`, no own Scaffold/AppBar) shown inside a `TabBarView`.
- `floatingActionButton` shows "Add Rule" (FAB) only while the Credit Rules tab is active, driven by `GlobalKey<CreditRulesTabState>` + `_tabController.index == 1` — reverted from an inline header button per direct feedback that it should stay a FAB.

**2. Real backend action discovered and wired**
- `POST /leave/balance/credit/` (`LeaveBalanceView.post` in `apps/hrms/views/leave.py`, permission `leave.approve`) credits every active employee's annual leave balance for a year from each policy's `annual_days`. It existed on the backend and even had a dead constant in the web frontend (`endpoints.ts: balanceCredit`), but no UI anywhere called it.
- Added `SettingsRemoteDataSource.creditLeaveBalances({year, employeeId})`, `LeavePoliciesNotifier.creditAnnualLeave()`, and `CreditBalancesResult` model. Wired to a real "Credit Annual Leave" card in the Credit Rules tab with a year field + confirm dialog + snackbar result — this is a genuine, working backend call, not a preview.

**3. Local-only "preview" mode for what the backend can't do**
- Confirmed via repo-wide grep (`accrual|creditrule|credit_rule|encash`) that the backend has **zero** support for per-type accrual rules or custom leave types — `LeavePolicy.leave_type` is a fixed 6-choice enum with no create endpoint.
- "Add Leave Type" (Policy tab) and the accrual "Credit Rules" list are therefore local-only, in-memory previews: `LeavePolicyModel.isPreview` / grey color + amber "PREVIEW" badge instead of a real leave-type color, and an "AUTOMATION COMING SOON" pill on the rules list. Per explicit instruction, these are placeholders for backend wiring the user will add later — not fake data dressed up as real.

**4. Bug fixes**
- DRF serializes `DecimalField`s (e.g. `annual_days`) as JSON **strings** (`"12.0"`), not numbers — `as num?` casts were throwing and silently killing the whole list parse. Added a shared tolerant `_toDouble()` parser in `leave_policy_model.dart`.
- Dialog overflow in both `LeavePolicyFormSheet` and `CreditRuleFormSheet`: `SingleChildScrollView` in an unbounded `Column` doesn't scroll. Fixed with `ConstrainedBox(maxHeight: 85%) → Column[header, Flexible(scrollable body)]`.
- "Credit All Employees" button was cramped next to a fixed-width year field in a `Row`; changed to a stacked layout (full-width year field, then full-width button).

### Files Added
```
mobile_app/lib/features/settings/
  data/models/
    leave_policy_model.dart          (LeavePolicyModel + isPreview, LeavePolicyFormData, CreditBalancesResult)
    leave_credit_rule_model.dart     (local-preview accrual rule model, kSeedCreditRules)
  presentation/leave_policy/
    leave_policy_screen.dart         (tabbed screen, _PolicyTab, _StatsRow, _PolicyCard)
    widgets/leave_policy_form_sheet.dart
  presentation/leave_credit_rules/
    leave_credit_rules_screen.dart   (CreditRulesTab — real Credit Annual Leave card + preview rules list)
    widgets/credit_rule_form_sheet.dart
```

### Files Modified
```
mobile_app/lib/
  core/constants/api_constants.dart              leavePolicyDetail(), leaveBalanceCredit
  features/settings/
    data/datasources/settings_remote_datasource.dart   fetchLeavePolicies, updateLeavePolicy, creditLeaveBalances
    presentation/providers/settings_providers.dart      LeavePoliciesNotifier.updatePolicy/creditAnnualLeave
    presentation/settings_hub/settings_screen.dart      single "Leave Policy" tile (desc covers credit/encashment)
```

### Architecture Notes
- Real-vs-preview is now an explicit, labeled distinction in this codebase: never let a locally-added item look identical to a backend-persisted one (color, badge, or explanatory text must differ).
- `LeaveTypeColors` (`features/leave/domain/entities/leave_entity.dart`) is the single source of truth for the 6 fixed leave-type codes/colors/labels, reused by both the Leave feature and this Settings screen.
- `GlobalKey<State>` is the established pattern here for a parent screen's FAB to trigger a method on a specific `TabBarView` child.

### Pending Tasks (updated)
- [ ] Backend: real create/delete support for custom leave types, if the business actually needs more than the fixed 6
- [ ] Backend: an accrual/credit-rule model — the Credit Rules list is local-only preview until this exists
- [ ] Wire `LeaveBalanceAdjustView` (per-balance PATCH) to a mobile UI — currently unused, like `balance/credit/` was

## Session 15 — Approvals Screen, Auth Background/Branding, Overflow Fixes, Auth Error Handling

**Date:** 2026-07-02
**Developer:** Pramod Kunja

### Module Worked On
- New "Approvals" feature (`/dashboard/approvals`, previously a `PlaceholderScreen` stub).
- Auth screens (Login, Forgot Password/OTP/Reset) — background image, branding, layout, and real error-message handling.
- Overflow/crash fixes across Payroll (Dashboard, Reports, Payroll Rules) and Settings → Leave Policy.

### What Changed

**1. Approvals screen — ported from web's `app/dashboard/approvals/page.tsx`**
- Web has a standalone, aggregated Approvals page (distinct from the Leave module's own Approvals tab) with two sections — "My Requests" (own Leave/Expense requests + quick-create) and "Team Approvals" (pending items awaiting the current user's action) — composed client-side from the existing `/leave/requests/` and `/expenses/` endpoints; no backend aggregation endpoint exists for this.
- Built `lib/features/approvals/` (providers + screen + widgets) reusing the existing `leaveRepositoryProvider` / `expenseDataSourceProvider` — no duplicated networking.
- Backend fix: `ExpenseListCreateView.get` (`apps/hrms/views/expenses.py`) had no way to force "my expenses only" for a user with `expenses.approve` — added `?scope=own`, mirroring the pattern leave already had. Verified live: approving a real pending expense through the app's exact API call correctly dropped it out of the pending queue.
- Fixed a pre-existing bug found in the process: `ExpenseModel` read a nonexistent `id` field (the backend's `ExpenseSerializer` never returns one) — switched to the real identifier, `expense_number`.
- "Team Approvals" is hidden entirely for users with neither `leave.approve` nor `expenses.approve` (same reasoning as hiding the Leave module's own Approvals tab for employees — a queue that only ever shows your own request is a dead end).
- Registered in `app_router.dart`, replacing the `PlaceholderScreen` for `AppRoutes.approvals`.

**2. Auth screens — background image + branding**
- New `lib/shared/widgets/auth_background.dart`: full-bleed `Image.asset('assets/images/login.jpg')` + a light primary-color gradient tint, with `cacheWidth` capped to the device's physical width (source is 4912×4912 / ~14MB — no reason to decode full-res for a backdrop) and a graceful fallback to a solid color if the asset is ever missing.
- Declared `assets/images/` in `pubspec.yaml`; added `mobile_app/assets/images/login.jpg` and `Royal_logo.png`.
- Login screen: wrapped in `AuthBackground`; logo badge now shows `Royal_logo.png` (was a 👑 emoji, kept as an `errorBuilder` fallback); header text turned white with a subtle drop-shadow for legibility regardless of what's behind it.
- Forgot Password screen: same `AuthBackground`; removed the step title ("Forgot Password" / "Verify OTP" / "New Password") from the `AppBar` and moved it to a centered white heading above the card (matching the login screen's header treatment) instead of living in the app bar; app bar is now just a transparent back button.
- Tuned the background tint down from ~0.8/0.7 opacity to ~0.5/0.22 — the original was strong enough that the photo was barely visible ("looked like a flat blue screen").

**3. Auth error handling — show the backend's real message**
- `core/network/api_client.dart` `parseDioException`: previously hardcoded a fixed message for 401/404/429 and discarded the backend's own `message` field entirely for those. Now always prefers the server's message for every status code, falling back to a generic client message only when there's genuinely no response (e.g. connection dropped).
- `login_form.dart`: was further overriding `UnauthorizedException`/`RateLimitException` with its own hardcoded text on top of the above — now shows `error.message` directly. Verified against the live backend that "Invalid email or password.", "Invalid or expired reset token.", etc. now reach the screen unmodified.
- `forgot_password_notifier.dart` needed no change — it already fell back to `error.toString()` (`AppException.toString() => message`), so it picked up the real backend message automatically once `parseDioException` was fixed.

**4. Auth interceptor bug — wrong-password login could hang or show the wrong error**
- `core/network/auth_interceptor.dart` `onError` excluded `/token/refresh/` and `/logout/` from its silent-refresh-and-retry logic, but not `/login/` (or `/forgot-password/`, `/verify-otp/`, `/reset-password/`). A 401 from `/login/` (wrong credentials) was being treated as "session expired": the interceptor tried to silently refresh a token that never existed (itself failing), fired a `logout()` side effect via `sessionExpiredProvider`, and only then re-threw — as a synthetic `DioException` with no `response` attached, so `parseDioException` couldn't read the real status/message. This raced against `AuthNotifier`'s own state write and was the cause of "wrong password shows no error and stays loading."
- Fixed by excluding all pre-session endpoints (`login`, `forgotPassword`, `verifyOtp`, `resetPassword`, plus the already-excluded `tokenRefresh`/`logout`) from the refresh-retry path — a 401 from any of them can only mean "these credentials are wrong," never "the existing session expired," since there is no session yet.

**5. Reset password — missing `confirm_password` field**
- Backend's `ResetPasswordSerializer` requires `reset_token`, `new_password`, **and** `confirm_password`; the mobile app's `ResetPasswordRequestModel` only sent the first two even though the UI already collected and validated a confirm-password field locally. Threaded `confirmPassword` through `ResetPasswordRequestModel` → `AuthRepository`/`AuthRepositoryImpl` → `ResetPasswordUseCase` → `ForgotPasswordNotifier.resetPassword` → the form's submit call. Verified against the live backend that the "confirm_password required" error is gone.

**6. Overflow / crash fixes** (all confirmed via `flutter analyze`, 0 errors)
- **Leave Policy screen** (`leave_policy_screen.dart`): `_PolicyCard`'s tag `Wrap` had a `Flexible(child: Text(...))` for the policy note — `Flexible`/`Expanded` are only valid as direct children of a `Row`/`Column`/`Flex`, never a `Wrap`, which threw "Incorrect use of ParentDataWidget" for any policy with a non-empty note (i.e. almost all of them). Fixed by using a plain `Text` (a `Wrap` already width-constrains its children). Also moved "+ Add Leave Type" out of the section header into a `FloatingActionButton.extended`, matching the Credit Rules tab's existing FAB pattern (`GlobalKey<_PolicyTabState>` + a new public `openAdd()`).
- **Payroll Dashboard tab**: two section headers (`Payroll Calendar`, `Recent Payroll Runs`) had an unwrapped `Text` title sitting between an icon and a `Spacer()`+badge/button — wrapped titles in `Expanded`+ellipsis. `_PayrollRunRow`'s STATUS column only got 20% of the row's width but had to fit a badge + icon — rebalanced column flex (`EMP` 2→1, `STATUS` 2→3) and wrapped the badge in `Flexible`. Calendar legend row converted from `Row` to `Wrap`.
- **Payroll Reports tab**: Statutory Reports / Payroll Summary were a 2-column `GridView` — each card's action-button row (`Export PDF`/`Export Excel`) didn't have enough width for icon+text at half-width, causing the overflow. Changed to one full-width card per row (per explicit request) via a `for` loop instead of `GridView.builder`; this also required removing an `Expanded` around the description `Text` that only worked inside the old grid's bounded-height cell.
- **Payroll Rules screen**: `_StatChip`'s inner `Row` (icon + count/label `Column`) had no `Expanded` on the `Column`, so it sized to its natural (unbounded) width instead of the ~70px actually available — fixed. Both `_EarningsTab`/`_DeductionsTab` section headers had a long hint sentence after a `Spacer()` with no `Flexible` — same fix as the Payroll Dashboard headers.
- **OTP input** (`otp_input_widget.dart`): 6 boxes at a fixed `width: 46` (276px total) in a `Row` with `spaceBetween` overflowed a 271px-wide parent before any gap was even added. Changed to `Expanded` boxes with fixed 8px gaps, so the row always exactly fits whatever width it's given.

### Files Added
```
mobile_app/
  assets/images/login.jpg, Royal_logo.png
  lib/shared/widgets/auth_background.dart
  lib/features/approvals/
    presentation/providers/approvals_providers.dart
    presentation/screens/approvals_screen.dart
    presentation/widgets/my_requests_tab.dart
    presentation/widgets/team_approvals_tab.dart
    presentation/widgets/new_leave_request_sheet.dart
```

### Files Modified
```
mobile_app/
  pubspec.yaml                                                  assets/images/ declared
  lib/core/constants/api_constants.dart                         expenseCategories, expenseStatusList, expenseDetail()
  lib/core/network/api_client.dart                               parseDioException always prefers server message
  lib/core/network/auth_interceptor.dart                         excluded pre-session endpoints from refresh-retry
  lib/core/router/app_router.dart                                ApprovalsScreen wired in place of PlaceholderScreen
  lib/features/auth/
    data/models/forgot_password_models.dart                      ResetPasswordRequestModel.confirmPassword
    data/repositories/auth_repository_impl.dart                  resetPassword(confirmPassword)
    domain/repositories/auth_repository.dart                     resetPassword(confirmPassword)
    domain/usecases/reset_password_usecase.dart                  resetPassword(confirmPassword)
    presentation/controllers/forgot_password_notifier.dart       resetPassword(confirmPassword)
    presentation/screens/login_screen.dart                       AuthBackground, Royal_logo.png, white header + shadow
    presentation/screens/forgot_password_screen.dart              AuthBackground, heading moved out of AppBar
    presentation/widgets/forgot_password_form.dart                passes confirmCtrl.text through
    presentation/widgets/login_form.dart                          shows error.message instead of hardcoded text
    presentation/widgets/otp_input_widget.dart                    Expanded boxes instead of fixed width
  lib/features/expenses/
    data/datasources/expense_remote_datasource.dart               status/scope filters, updateExpenseStatus, categories/status options
    data/models/expense_model.dart                                expenseNumber/expenseRef instead of nonexistent id
  lib/features/leave/
    data/datasources/leave_remote_datasource.dart                 optional scope param
    data/repositories/leave_repository_impl.dart                  optional scope param
    domain/repositories/leave_repository.dart                     optional scope param
    presentation/screens/leave_screen.dart                        Approvals tab hidden for employee role
  lib/features/payroll/presentation/screens/payroll_screen.dart   overflow fixes (see above)
  lib/features/settings/presentation/leave_policy/leave_policy_screen.dart   Wrap/Flexible crash fix, FAB
  lib/features/settings/presentation/payroll_rules/payroll_rules_screen.dart  overflow fixes (see above)

web_frontend_backend/Royal-HRMS/backend/apps/hrms/views/expenses.py   ExpenseListCreateView scope=own support
```

### Architecture Notes
- `Flexible`/`Expanded` are `ParentDataWidget`s valid **only** as direct children of `Row`/`Column`/`Flex` — never `Wrap`. This bug pattern (and the "Expanded needs a bounded-height/width ancestor" variant) accounted for essentially every overflow/crash fixed this session; when converting a `GridView`/2-column layout to a single-column list, always re-check whether children relied on the grid cell's bounded size.
- `parseDioException` (`core/network/api_client.dart`) is the single source of truth for turning a `DioException` into a typed `AppException` for the **auth** feature — always prefer the backend's `message` field there before adding any new hardcoded client-side copy. (Other features — Leave, Expenses, Settings, etc. — still use an older, separate `_friendly(e.toString())` string-matching pattern per file; not touched this session, flagged as a possible future cleanup.)
- Any endpoint that can be called *before* a session exists (login, forgot-password, verify-otp, reset-password, token-refresh, logout) must be excluded from `AuthInterceptor`'s silent-refresh-retry logic — a 401 from one of these is never "your session expired."
- `AuthBackground` (`lib/shared/widgets/`) is the shared backdrop for all auth screens now — add new auth-flow screens through it rather than duplicating the `Image.asset` + gradient.

### Pending Tasks (updated)
- [ ] Backend: real create/delete support for custom leave types, if the business actually needs more than the fixed 6
- [ ] Backend: an accrual/credit-rule model — the Credit Rules list is local-only preview until this exists
- [ ] Wire `LeaveBalanceAdjustView` (per-balance PATCH) to a mobile UI — currently unused, like `balance/credit/` was
- [ ] Backend: leave approval routing config (`ApprovalWorkflowRule`) has a role-string mismatch (`reporting_manager`/`hr_manager` vs the resolver's expected `rm`/real role names) — every leave request's `l1_approver`/`l2_approver` resolve to `null`. Flagged, not fixed (out of mobile scope).
- [ ] Sweep the older `_friendly(e.toString())` error-message pattern in Leave/Expenses/Settings/Announcements/Branches/Documents/Employees providers to the same "always show the backend message" standard applied to auth this session.

---

## Session 16 — Assessments Screen (Full Backend Integration), Overflow Fixes, Navigator Crash Fix

**Date:** 2026-07-03
**Developer:** Pramod Kunja

### Module Worked On
- New "Assessments" feature (`/dashboard/assessments` on web) — HR admin assessment management, ported to `lib/features/assessments/`.
- Overflow/layout fixes on the new Assessments screen.
- Crash fix: delete-confirmation dialogs were popping the wrong Navigator inside a `ShellRoute`.

### What Changed

**1. Assessments — new feature, full backend integration**
- Ported the web's `/dashboard/assessments` (HR admin management page) — not the separate `/onboarding/assessments` candidate-taking portal, which has no nav entry and is a different feature entirely.
- Real backend integration against `/api/assessments/...`: list/create/edit/delete assessments; list/create/edit/delete video-or-quiz items per assessment; assign to a candidate (`POST /assessments/assign/`); candidate lookup for the assign dropdown via `/recruitment/candidates/review/`.
- `AssessmentsRemoteDataSource` follows the same `_unwrap`/`_toList` envelope-handling pattern used in `SettingsRemoteDataSource` — the assessment list is paginated (`{count, results}`), the items endpoint returns a bare array.
- Client-side validation copy matches the web app's `page.tsx`/`ItemsModal.tsx` exactly: "Title is required.", "Video URL is required.", "Question is required.", "At least options A and B are required." — checked in the same order, so the same first-failing-check always wins on both platforms.
- Error handling: routed through `parseDioException()` (`core/network/api_client.dart`) instead of copying the older `_friendly(e.toString())` string-matching pattern used by Leave/Expenses/Settings/etc. (flagged as a cleanup candidate in Session 15's notes) — so backend messages like "Assessment already assigned to this candidate." (409) and "Cannot delete an assessment with active candidate assignments." (409) reach the user verbatim instead of a generic fallback.
- Nav item added to `nav_config.dart` (Recruitment section, between "Review & Onboarding" and "Email Logs"), gated by `assessments.view` permission — matches the web sidebar's permission string exactly. Route registered in `app_router.dart` inside the dashboard `ShellRoute`.

**2. Overflow fixes**
- `_OverallStatsRow` (top-of-screen stat cards): fixed `SizedBox(height: 84)` plus a `Spacer()`-based `Column` was a few px short of its actual content height under Poppins' line-height metrics — a real (if minor) render overflow. Bumped to `104` and replaced `Spacer()` with explicit `SizedBox` gaps so it no longer depends on flex math matching font metrics exactly.
- `AssessmentCard` title: was a bare `Text` inside a `Wrap` — a `Wrap` does not constrain a child's width, so a long, unbroken assessment title could overflow past the card edge instead of wrapping. Changed to `Expanded` + `maxLines: 2` + ellipsis, with the Active/Default badges wrapping separately on the right.
- Per-assessment mini-stats grid (Items/Assigned/Pending/In Progress/Completed, shown when "Results" is expanded): was a `Wrap` of fixed 78px tiles that split into an uneven 3+2 layout on narrower phones — looked cramped/"shrunk." Changed to a `Row` of `Expanded` tiles so the 5 stats always divide the card's actual width evenly in a single row.
- Results/Items/Assign actions: were auto-sized chips in a `Wrap`. Rebuilt as a real segmented tab bar (`ActionTabs`/`_TabButton`, one `Expanded` per tab) so they always fill the row width evenly and can't wrap unpredictably; Edit/Delete stayed as compact icon buttons alongside it.

**3. Crash fix — delete confirmation popped the wrong Navigator**
- Both delete-confirmation `AlertDialog`s (`assessments_screen.dart`'s "Delete Assessment?", `items_manager_dialog.dart`'s "Remove Item?") were written as `showDialog(builder: (_) => AlertDialog(...))`, discarding the builder's own context and calling `Navigator.pop(context, true/false)` with the **enclosing screen's** context instead.
- `AssessmentsScreen` is registered inside the dashboard `ShellRoute`, which owns its own nested `Navigator` — separate from the root `Navigator` that `showDialog` pushes onto by default. Resolving `Navigator.of(context)` from the outer screen's context found the shell's nested `Navigator` (not the root one hosting the dialog), so tapping Delete popped the actual page route instead of the dialog. Since it was the only page on that nested stack, go_router threw `"You have popped the last page off of the stack, there are no pages left to show"` and crashed.
- The same `builder: (_) => AlertDialog(... Navigator.pop(context) ...)` pattern exists in `departments_screen.dart`'s `_showDeleteDialog` too — it "works" there only because `DepartmentsScreen` is registered as a **standalone route outside the ShellRoute**, so the outer context's nearest Navigator happens to be the same root Navigator the dialog uses. Any screen inside the `ShellRoute` copying that exact pattern will hit the same crash — worth a sweep if more ShellRoute screens add inline `AlertDialog` confirmations. Fixed here by naming the builder's context (`dialogContext`) and popping with that instead.

### Files Added
```
mobile_app/lib/features/assessments/
  data/
    models/assessment_model.dart
    datasources/assessments_remote_datasource.dart
  presentation/
    providers/assessments_providers.dart
    screens/assessments_screen.dart
    widgets/
      assessment_card.dart
      assessment_card_tabs.dart
      assessment_results_section.dart
      assessment_form_dialog.dart
      items_manager_dialog.dart
      item_row.dart
      item_form.dart
      assign_dialog.dart
```

### Files Modified
```
mobile_app/lib/
  core/constants/api_constants.dart               assessments + candidatesReview endpoints
  core/router/app_router.dart                     AppRoutes.assessments + GoRoute registration
  features/dashboard/presentation/navigation/nav_config.dart   Assessments NavItem + page title
```

### Architecture Notes
- Any screen registered inside the dashboard `ShellRoute` must use the `showDialog` **builder's own context** for `Navigator.pop` in inline confirmation dialogs — never the enclosing screen's `context`. The ShellRoute's nested Navigator and the root Navigator hosting the dialog are different, and popping the wrong one can pop the actual page route instead of the dialog (crashes with go_router's "popped the last page" assertion). `departments_screen.dart` has the same risky pattern but is only safe because it happens to be a non-ShellRoute standalone route.
- `parseDioException()` is now used by two features (Auth since Session 15, Assessments since this session) as the "always show the backend's real message" error path. The older per-file `_friendly(e.toString())` pattern is still used everywhere else (Leave, Expenses, Settings, Announcements, Branches, Documents, Employees) — still flagged from Session 15 as a sweep candidate.
- The Assessments backend has no time limits, no file uploads, and fully server-side auto-grading (`pass_score` per quiz item, `max_score` frozen at assign time) — none of that logic needed porting for the admin management screen, only for the separate candidate-taking portal (`/onboarding/assessments`), which was intentionally left un-ported.

### Pending Tasks (updated)
- [ ] Manual on-device pass for the Assessments item-form and results-table layouts on a small physical screen (only verified via `flutter analyze`, not a running device, in this session)
- [ ] `/onboarding/assessments` candidate-taking portal — not yet ported to mobile (separate feature: video/quiz item player, per-item respond/complete/retry flow, no nav entry)
- [ ] Sweep the older `_friendly(e.toString())` error pattern in Leave/Expenses/Settings/Announcements/Branches/Documents/Employees to the `parseDioException()` standard (carried over from Session 15)
- [ ] Audit other ShellRoute screens for the `showDialog(builder: (_) => AlertDialog(... Navigator.pop(context) ...))` context bug found this session

---

## Session 17 — Attendance Module (Full Backend Integration), Holiday Calendar Settings Screen (New)

**Date:** 2026-07-03
**Developer:** Pramod Kunja

### Module Worked On
- Attendance — `my_attendance_screen.dart` (employee self-service) and `attendance_screen.dart` (HR admin) wired to the real backend, all static/mock data removed.
- New "Holiday Calendar" settings screen — full UI port from the web frontend.
- Several runtime bugs found and fixed via live testing on Flutter Web, not just `flutter analyze`.

---

### Part 1: Attendance — Full Backend Integration

**Important environment note first:** the repo contains a stray, git-**untracked** duplicate backend at `web_frontend_backend/Royal-HRMS/backend` that is missing newer code (no `serializers_hr.py`, `services_hr*.py`, or the HR-attendance migrations). The real backend is `backend/` at the repo root. Two research passes were burned researching the wrong copy before this was caught — **always confirm via `git status` which backend path is actually tracked before trusting its contents.**

**My Attendance (employee self-service)** — new `lib/features/attendance/` data/domain/provider layer (following the same Clean Architecture shape as `leave`/`branches`), wired to the real, pre-existing endpoints:
- `POST /attendance/punch/`, `GET /attendance/today/`, `GET /attendance/stats/`, `GET /attendance/summary/`, `GET /attendance/calendar/`, `POST /attendance/correction/`.
- Clock-in captures real GPS via the new `geolocator` dependency (`lib/core/location/location_service.dart`) — added `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` (Android) and `NSLocationWhenInUseUsageDescription` (iOS) permissions.
- Correction request dialog validates against the backend's exact `CorrectionWriteSerializer` rules and reason codes (`biometric_error`, `forgot_to_punch`, `field_work`, `system_downtime`, `other`).

**HR Attendance Management (admin `attendance_screen.dart`)** — confirmed via direct backend code reading (not just endpoint testing) that these DO have real backend support: org-wide attendance list (`/attendance/records/`), dashboard stats (`/attendance/dashboard/`), OT entries list+create (`/attendance/overtime/`, `/attendance/overtime/create/` — no approve/reject endpoint exists despite the model supporting a status field), un-punches queue (`/attendance/un-punches/`) with fix-via-correction-review (`/attendance/corrections/`, `PATCH /attendance/corrections/<id>/review/`). **Invalid Punches** (`/attendance/invalid-punches/`) has no persisted model or fix action at all — it's a read-only, computed-on-the-fly heuristic — so the mobile UI has no "Fix" button for it, by design, not an oversight.

#### Bugs found and fixed (in order of discovery)

1. **`ot_hours` in Monthly Summary always showed "0.0h"** — backend returns it as a pre-formatted display string (`"9h 07m"`), not a number; `double.tryParse` silently failed and defaulted to 0. Fixed the entity/model to treat it as `String`.
2. **Calendar showed no status-color dots at all** — `AttendanceDashboardService.get_calendar()`/`get_history()` return `status` as the human display label (`"On Leave"`, `"Half Day"`), not a lowercase key. The color lookup map used lowercase keys and never matched. Fixed the map to use the exact display labels.
3. **"View" button 404'd for any employee with no attendance record that day** (Absent, Weekly Off, etc.) — the backend route is `records/<uuid:pk>/`; Django's `<uuid:pk>` URL converter rejects non-UUID path segments at the routing layer, so the "fall back to employee_id" idea could never work. Fixed by only enabling "View" when a real `record_id` exists.
4. **Punch log showed a duplicated location string** — backend's `location` field already bakes in the source (`"Chennai HQ · Mobile"`); code was appending `attendanceMode` again on top.
5. **`Platform._operatingSystem` crash on clock-in (web only)** — called `Platform.isAndroid`/`Platform.operatingSystem` unconditionally; `dart:io`'s `Platform` throws on web. Guarded with `kIsWeb`, matching the existing documented convention in `api_client.dart` that should have been followed the first time.
6. **Scrollbar/ScrollController crash across all 4 admin tabs (web only)** — each tab's `ListView` had no explicit `primary`, so it implicitly inherited the single `PrimaryScrollController` the enclosing `NestedScrollView` provides to its `TabBarView` body. Silent on native (no interactive `Scrollbar` rendered there), but web's `Scrollbar` requires exactly one attached `ScrollPosition` and throws when multiple tabs' `ListView`s share the controller. Fixed with `primary: false` on all four.
7. **GoRouter "popped the last page off the stack" crash tapping a calendar day** — `_showDayDetail`'s `showDialog(builder: (_) => AlertDialog(...))` discarded the dialog's own context and the Close button's `Navigator.pop(context)` used the **screen's** context instead. `MyAttendanceScreen` sits inside a `ShellRoute` with its own nested Navigator, distinct from the root Navigator `showDialog` targets by default — popping with the wrong context popped the actual page. Same bug class as Session 16's Assessments fix; fixed the same way (`builder: (dialogContext) => ...`, pop with `dialogContext`).
8. **Stale Django dev server processes serving 404s for real routes** — not a code bug. Found 4 separate `manage.py runserver` processes bound to port 8000 (one dating back to the prior Thursday); whichever one actually owned the socket was serving attendance URLs from before the HR-attendance routes existed. Killed all 4, started one fresh server — `/attendance/dashboard/`, `/attendance/records/`, and the previously-500ing `/api/employees/` all returned correct responses afterward. **Lesson: when a route that clearly exists in the code 404s, check for duplicate/stale `runserver` processes before assuming a code bug.**

### Files Created (Attendance)
```
mobile_app/lib/
  core/location/location_service.dart
  features/attendance/
    domain/entities/attendance_entity.dart
    domain/repositories/attendance_repository.dart
    data/models/attendance_models.dart
    data/datasources/attendance_remote_datasource.dart
    data/repositories/attendance_repository_impl.dart
    presentation/providers/attendance_providers.dart
```

### Files Modified (Attendance)
```
mobile_app/
  pubspec.yaml                                                   added geolocator
  android/app/src/main/AndroidManifest.xml                       location permissions
  ios/Runner/Info.plist                                          NSLocationWhenInUseUsageDescription
  lib/core/constants/api_constants.dart                          all /attendance/... endpoints (My Attendance + HR)
  lib/features/attendance/presentation/screens/my_attendance_screen.dart   full rewrite — real data, GPS punch, correction dialog
  lib/features/attendance/presentation/screens/attendance_screen.dart      full rewrite — real data for Attendance/OT/Un-punches; Invalid Punches read-only
```

---

### Part 2: Holiday Calendar — New Settings Screen

Ported the web's `/dashboard/settings/holiday-calendar` page. Important: **the reference web screen has no backend of its own** — it's a `useState` array with a `setTimeout(400ms)` faking a save, confirmed by reading both the page component and the full backend (no `Holiday` model/serializer/view/urls anywhere, and the `holiday` status on `AttendanceRecord` is dead/unreachable enum code, never actually assigned by anything). Per explicit user decision, built a faithful UI port using local Riverpod state (seed data) rather than inventing a backend contract that doesn't exist — same reasoning as the Credit Rules tab (Session 15) being local-only.

Every field, filter, view, and dialog from the reference page was ported: year navigator, branch filter, search, 5 stat cards (Total/National/Regional/Company/Optional), filter tabs with counts, List/Calendar view toggle, secondary Type/Month filters + Clear Filters, pagination, empty state, month-grid calendar with a "Holidays in {Month}" list, Add/Edit dialog (name, date, type, applicable branches, optional toggle, active toggle) with the reference's exact validation copy ("Holiday name is required.", "Date is required."), read-only View dialog, and delete confirmation with the exact "will be permanently removed" copy.

**Mobile-specific layout adaptations** (explicitly requested — avoid overflow, proper design, not a pixel port of the desktop table):
- Stat cards and filter tabs use horizontal-scrolling rows instead of the web's fixed grid/tab row.
- Secondary filters use `Wrap` so they reflow instead of clipping.
- Pagination uses Prev/Next + "Page X of Y" instead of the web's un-truncated row of page-number buttons.
- Everything lives in one `SingleChildScrollView` (no nested `TabBarView`/`NestedScrollView`) — avoids the exact `PrimaryScrollController` conflict fixed in Part 1, item 6.

**Bug found post-delivery:** the Add/Edit form dialog's outer `Column` (`mainAxisSize: MainAxisSize.min`) overflowed by 8px on shorter viewports — the scrollable body wasn't wrapped in `Flexible`, so it sized to the `SingleChildScrollView`'s full natural content height instead of being capped at the dialog's actual available space. Fixed by wrapping the body `Container` in `Flexible`.

### Files Created (Holiday Calendar)
```
mobile_app/lib/features/settings/
  data/models/holiday_model.dart
  presentation/holiday_calendar/
    holiday_calendar_providers.dart
    holiday_styles.dart
    holiday_calendar_screen.dart
    widgets/holiday_form_dialog.dart
    widgets/holiday_view_dialog.dart
```

### Files Modified (Holiday Calendar)
```
mobile_app/lib/
  core/router/app_router.dart                                     AppRoutes.settingsHolidayCalendar + GoRoute
  features/settings/presentation/settings_hub/settings_screen.dart  new tile under Modules
```

### Architecture Notes
- **Two backends can exist side-by-side in this repo** (one git-tracked at `backend/`, one stray untracked copy under `web_frontend_backend/`) — always verify with `git status` before trusting research against either. This cost real rework this session.
- **A route existing in `urls.py` on disk doesn't mean it's live** — Django's `runserver` autoreloader can fail silently, and duplicate/stale processes can bind the same port. A 404 on a route you can see in the code is a server-process problem to check first, not necessarily a code bug.
- **DRF `Serializer` classes in a views file aren't proof they're actually applied to the response** — some of this codebase's HR endpoints (`services_hr.py`, `services_hr_ops.py`, `services_hr_audit.py`) return raw dicts directly to `success()`/`error()` without ever calling `.data` on the documented Read serializer classes. Always trace the actual service function's return dict for ground truth on field names/types, not just the serializer class sitting in the same directory.
- **Any screen inside a `ShellRoute` must use the `showDialog` builder's own context for `Navigator.pop`** in inline dialogs (confirmation, detail views) — this is now the 3rd occurrence of the same bug class (Session 16's Assessments, this session's My Attendance day-detail dialog) — worth the audit already flagged in Session 16's pending tasks.
- **`primary: false` on `ListView`s inside a `TabBarView` that itself lives inside a `NestedScrollView`** — otherwise every tab's list implicitly shares the single inherited `PrimaryScrollController`, which is silent on native (no `Scrollbar` rendered) but throws on web/desktop.
- Local-only mock features (Holiday Calendar this session, Credit Rules from Session 15) should stay local rather than being wired to an invented API contract — build the real integration only once the backend team actually ships the model/endpoints.

### Pending Tasks (updated)
- [ ] Backend: Invalid Punches has no persisted model and no fix/resolve action — flagged, not built (explicit user decision to scope this session to what already has real backend support).
- [ ] Backend: OT entries have no approve/reject endpoint despite `AttendanceOvertime.status` supporting it, and `ot_amount` is hardcoded to `Decimal('0')` server-side (no salary/rate lookup wired up) — both backend gaps, not mobile bugs.
- [ ] Backend: if Holiday Calendar is ever meant to affect real attendance processing, `AttendanceRecord.STATUS_HOLIDAY` needs an actual writer in `AttendanceProcessorService` — currently unreachable dead code — plus a real `Holiday` model/API to replace this session's local mock state.
- [ ] Audit other ShellRoute screens for the `showDialog(builder: (_) => AlertDialog(... Navigator.pop(context) ...))` context bug (carried over from Session 16 — now 3 confirmed occurrences of this exact pattern).
- [ ] Manual on-device pass for both the Attendance screens and Holiday Calendar on a small physical screen (verified via `flutter analyze` + live web testing this session, not a native device).

---

## Session 18 — Dashboard, Referrals, Settings (3 new screens), My Attendance polish, HR Attendance & Time catch-up

**Date:** 2026-07-08
**Developer:** Pramod Kunja

### Module Worked On
- Dashboard (home screen) — new backend-connected sections
- Referrals — full new feature (employee + HR admin views)
- Settings — 3 new screens: Attendance Rules, Referral Rules, Assessment Config
- Attendance — My Attendance (employee self-service) sync + Attendance Mode selector rebuild
- Attendance — HR Admin "Attendance & Time" screen brought fully up to date with backend/web

---

### Part 1: Dashboard — New Backend-Connected Sections

**File:** `lib/features/dashboard/presentation/screens/home_screen.dart`

Added four new sections, all wired to real endpoints (no mock data): **Today's Attendance** (clock-in/out card, mirrors `attendancePunch`/`attendanceToday`), **Leave Balance**, **Recent Leave Requests**, and a **Birthdays** card gated behind a permission check (only rendered when the current user actually has the required permission, rather than always rendering and letting the API 403).

Bug fixed: `hrmsBirthdays` endpoint was initially set to `/hrms/birthdays/`; live testing surfaced a raw `DioException` dump in the Birthdays card. Root cause — `apps.hrms.urls` is mounted at bare `/api/`, not `/api/hrms/`. Fixed to `/birthdays/`, and hardened the HRMS error helper so unmapped status codes never leak raw exception text to the UI again.

Verified via Playwright against the real Django backend: screen renders without overflow/clipping, and all four new sections degrade to sensible loading/error/empty states when data is unavailable.

---

### Part 2: Referrals — Full New Feature

**Files created:** `lib/features/referrals/` (entities, models, datasource, providers, widgets, screen) — full Clean Architecture layer matching the `branches`/`leave` shape.

Providers: `myReferralsProvider`, `allReferralsProvider` (HR admin, requires `recruitment.view`), `referralRulesProvider`, `referralRulesAdminProvider`.

Went through several rounds of UI/UX polish based on direct feedback while building:
- FAB (not a header button) to open "Refer a Candidate"
- `showDialog` popup (not a bottom sheet) for the refer-candidate form
- Stat cards row made horizontally scrollable (`_StatsRow`, 136×128 cards) instead of a fixed row that clipped on narrow screens
- Tabs given icon + text labels (`_TabLabel`) with `tabAlignment: TabAlignment.start`
- Colored left-border section heading matching the rest of the app's card convention
- Explicit instruction from the user: don't copy web's own bugs into mobile. Web has a live bug where the branch field is sent as `Number(NaN)` on the refer-candidate form; fixed properly on mobile by resolving the branch **name** to its numeric ID via `branchListProvider` — but that call itself requires `branches.view`, a permission most users (even `hr_admin`, confirmed via a Django shell query) don't have. Fixed by gating the resolution attempt (and the pre-fetch) behind an explicit `permissions.contains('branches.view')` check, falling back to omitting the optional field otherwise.
- `IntrinsicHeight` + `CrossAxisAlignment.stretch` fix so the "Bonus Breakdown" boxes on the referral rule cards render at equal heights.

**API constants added** (`api_constants.dart`): `referrals`, `referralsAll`, `referralRules`, `referralRuleDetail(id)`.

---

### Part 3: Settings — 3 New Screens + Professional Design Pass

**Files created:**
- `lib/features/settings/presentation/attendance_rules/attendance_rules_screen.dart` — 6 sections (Working Hours, Weekly Off, Punch Rules, Overtime, Late Mark, Absence Alert), each `_SectionCard` given a distinct accent color. Backed by the real singleton `GET/PUT/PATCH /attendance/settings/` endpoint (confirmed live and current — not one of several dead legacy per-policy endpoints that were also found on the backend during research but are not the one the current web UI actually uses).
- `lib/features/settings/presentation/referral_rules/referral_rules_settings_screen.dart` — full CRUD for referral bonus rules.
- `lib/features/settings/presentation/assessment_config/assessment_config_screen.dart` — backed by the real singleton `GET/PUT /assessments/settings/` endpoint.
- `lib/features/settings/presentation/widgets/settings_page_header.dart` — new shared `SettingsPageHeader` (gradient banner, icon+title+subtitle, mirrors the Settings hub's own header) and `SettingsSectionHeading` (icon chip + bold label), applied to all three new screens for a consistent, "professional" look after explicit user feedback that the initial versions looked unfinished.

Bug flagged by the user as a regression during the design pass: the Referral Rules screen was missing its "Configured Rules (N)" heading — fixed by adding a `SettingsSectionHeading` above the list, shown even in the empty state.

**Settings hub updated** (`settings_hub/settings_screen.dart`): the pre-existing "Attendance Rules" tile (previously `route: null`, badged "Soon") now points at a real screen; two new tiles added for "Referral Rules" and "Assessment Config".

**API constants added:** `attendanceSettings`, `settingsAssessmentConfig`.

**Router:** `AppRoutes.settingsAttendanceRules`, `settingsReferralRules`, `settingsAssessmentConfig` + matching `GoRoute`s.

---

### Part 4: My Attendance — Sync to Current Web + Attendance Mode Selector Rebuild

**File:** `lib/features/attendance/presentation/screens/my_attendance_screen.dart` (~1390 lines)

Brought the employee self-service screen in line with current web/backend behavior:
- Added an **Attendance Mode** selector (`office` / `wfh` / `field` / `client_location` / `remote_office` — matching `AttendancePunch.attendance_mode` choices exactly). Clock-in now only fetches GPS when mode is `office`.
- `_CorrectionDialog` refactored to take a **locked date** from context (the calendar day being regularized) instead of letting the user freely pick a date — matches the backend's actual regularization model, where a correction is always for a specific already-known day.
- Calendar rebuilt with a Calendar/History tab switcher; the "next month" nav arrow is disabled once you reach the current month; added a `_HistoryRow`-based list view (late arrivals highlighted in red when clock-in is after `09:15`) using calendar data (`AttendanceHistoryRowEntity`) that the backend was already sending but the UI never rendered.
- Added a "Regularize" action directly from the day-detail dialog.

**Two rounds of live-testing bug fixes on the Attendance Mode selector**, both caught by the user:
1. **Invisible dropdown** — root cause was the global `InputDecorationTheme` (`app_theme.dart`) forcing `filled: true, fillColor: AppColors.surface` (white) onto any custom-styled dropdown/text field behind it, painting over the intended dark background with white text on white.
2. **Wrong popup style** — first fix used a bottom sheet; user explicitly wanted "there only like a popup dialog," so it was rebuilt as an anchored `PopupMenuButton` (the app's existing convention for this kind of control — see `candidate_card.dart`'s `_StatusChangeButton`), verified live via screenshot.

---

### Part 5: HR Admin "Attendance & Time" — Full Catch-Up to Current Web/Backend

**File:** `lib/features/attendance/presentation/screens/attendance_screen.dart` — the 4-tab HR-admin management screen (Attendance / OT Entry / Invalid Punches / Un-punches), distinct from Part 4's employee self-service screen.

Comparing the mobile screen against the current backend (`apps/attendance/views/hr_attendance.py`, `views/hr_audit_actions.py`) and current web (`app/dashboard/attendance/`) surfaced real gaps — some outright wrong assumptions baked into the old mobile code, some backend capability that was simply never wired up.

**Fixed a real bug, not a design choice:** a comment on the Invalid Punches tab claimed there was "no persisted model or fix action on backend, by design" (recorded as such in Session 17's notes). Direct backend reading proved this false — `InvalidPunch` + 3 action endpoints (`assign`/`discard`/`convert`) are fully implemented and live on web. Built the missing UI: per-row **Assign** (HR-user picker via the new `GET /employees/hrs/` endpoint), **Convert** (punch type + target time), and **Discard** (optional remarks) dialogs, each posting to `/attendance/invalid-punches/<id>/assign|discard|convert/` and refreshing the list + dashboard on success.

**Kept mobile's existing Un-punches tab as-is and *added* the general Corrections inbox alongside it**, rather than copying web's version — web's own "Un-punches" tab turned out to be dead-in-spirit (it just renders the general `CorrectionsTab` under a different name; the real `/attendance/un-punches/`-backed types are unreferenced dead code on the web frontend). Mobile's existing un-punch queue is genuinely more useful (shows expected-out time, whether a correction is already pending) and was left untouched; a new status-filterable (`All`/`Pending`/`Approved`/`Rejected`) Corrections inbox section was added below it, reusing an already-fully-implemented-but-never-called repository method (`getHrCorrections`).

**Other gaps closed:**
- **Date filter** — new `hrAttendanceDateFilterProvider`, threaded through the dashboard, records, OT list, invalid punches, and un-punches providers (all datasource methods already accepted an optional `date` param — this was a provider/UI wiring gap only).
- **Summary chips** — replaced a client-side status tally (computed from whatever page of rows happened to be loaded) with the backend's own `summary_chips`, which the model was already decoding but the UI never read. This also pre-empts a correctness bug the client tally would have hit the moment real pagination was added below.
- **Real pagination** — Attendance and OT Entry lists changed from a blunt `page_size: 100` single fetch to proper `page`/`page_size: 20` with Prev/Next controls, matching the backend's actual `{count, page, page_size, total_pages, results}` envelope (confirmed both list endpoints already paginate server-side).
- **CSV Export** — `GET /attendance/export/`, downloaded via `file_picker`'s `saveFile(bytes: ...)` (already a dependency, no new package needed).
- **CSV Import** — `POST /attendance/import/` (multipart, `file` field, `MultipartFile.fromBytes` for web/mobile parity since Flutter Web can't read a picked file by path), with a two-step dialog: pick → upload → success/failed row-count summary with the first few per-row errors, matching web's required-columns copy exactly (`employee_id, date, punch_in, punch_out — CSV only, max 5 MB`).
- **Record detail dialog** — extended with a **Correction Requests** section (client-side filtered by employee_id + date, matching web's own approach since the backend has no server-side filter for that combination) and an **Audit History** timeline (`GET /attendance/records/<id>/audit/`) — both previously entirely missing from the dialog.

All new backend contract details (exact field names, request/response shapes, required CSV columns, success-toast copy) were confirmed by direct reading of `apps/attendance/services_invalid_punch.py`, `services_hr_ops.py`, `views/hr_audit_actions.py`, and `apps/accounts/views.py`'s `HRListView` — not guessed from the plan alone.

#### New API constants (`api_constants.dart`)
`attendanceInvalidPunchAssign(id)`, `attendanceInvalidPunchDiscard(id)`, `attendanceInvalidPunchConvert(id)`, `attendanceExport`, `attendanceImport`, `attendanceRecordAudit(id)`, `employeesHrList`.

#### New entities/models (`attendance_entity.dart` / `attendance_models.dart`)
`HrUserEntity`, `AttendanceAuditEntryEntity`, `ImportRowErrorEntity`, `ImportResultEntity`, generic `PaginatedListEntity<T>` (+ a `parsePaginated<T>()` helper for the `{count, page, page_size, total_pages, results}` envelope shape).

#### Provider changes (`attendance_providers.dart`)
- `invalidPunchesProvider` converted from a plain `FutureProvider` to an `AsyncNotifierProvider` (`InvalidPunchesNotifier`) with `assign()`/`discard()`/`convert()`, following the same `Future<String?>` convention as the existing `OvertimeListNotifier`/`UnpunchesNotifier`.
- `attendanceRecordsProvider` / `overtimeListProvider` state type changed to `PaginatedListEntity<T>`; new `attendanceRecordsPageProvider` / `overtimePageProvider` page-state providers, reset to `1` whenever a branch/department/date filter changes.
- New `hrAttendanceDateFilterProvider`, `hrCorrectionsStatusFilterProvider` + `hrCorrectionsProvider` (`HrCorrectionsNotifier`, with its own `reviewCorrection()`), `hrUsersProvider`, `attendanceRecordAuditProvider` (family by record id), `attendanceRecordCorrectionsProvider` (family by employee+date), `attendanceImportActionProvider`.

### Files Modified (Session 18, all parts)
```
mobile_app/lib/
  core/constants/api_constants.dart
  core/router/app_router.dart
  features/dashboard/presentation/screens/home_screen.dart
  features/referrals/                                    (new feature, full tree)
  features/settings/presentation/
    attendance_rules/attendance_rules_screen.dart          (new)
    referral_rules/referral_rules_settings_screen.dart     (new)
    assessment_config/assessment_config_screen.dart        (new)
    widgets/settings_page_header.dart                      (new)
    settings_hub/settings_screen.dart
    data/models/attendance_settings_model.dart             (new)
    data/models/assessment_config_model.dart               (new)
    data/datasources/settings_remote_datasource.dart
    presentation/providers/settings_providers.dart
  features/attendance/
    domain/entities/attendance_entity.dart
    domain/repositories/attendance_repository.dart
    data/models/attendance_models.dart
    data/datasources/attendance_remote_datasource.dart
    data/repositories/attendance_repository_impl.dart
    presentation/providers/attendance_providers.dart
    presentation/screens/my_attendance_screen.dart
    presentation/screens/attendance_screen.dart
```

### Verification
- `flutter analyze` — zero errors project-wide throughout every part of this session (only pre-existing, unrelated info/warning-level lint items).
- `flutter build web` — succeeds cleanly.
- Live Playwright pass against the real Django backend (`hradmin@royal.com`) for Part 5: all 4 tabs render with no overflow; date filter / Export / Import controls appear correctly; the Un-punches tab shows both the existing queue and the new Corrections inbox; the record detail dialog pulled real audit history and correctly reported "no pending corrections" for a record with none. Assign/Convert/Discard dialogs were not exercised against live data since the seeded demo data had zero invalid punches to act on that day.

### Architecture Notes
- **Environment gotcha, recurring:** orphaned `flutter_tools_chrome_device.*` / stale `flutter run --web-port=...` processes from earlier turns (or from other concurrent sessions on the same machine) cause a fresh headless-Chrome Playwright session to load a permanently blank page (`document.body.innerHTML.length` stuck under 500 bytes) even though `flutter analyze`/`flutter build web` are clean and the dev server itself serves valid HTML. Diagnostic: check `document.body.innerHTML.length` after a generous wait; if still blank with zero console errors, it's almost always process contention, not a code bug — kill everything bound to the port and relaunch `flutter run -d chrome` fresh.
- **Backend rate-limits login** — repeated live-verification logins in a short window return "Request was throttled. Expected available in N seconds." Wait out the cooldown rather than retrying immediately; consolidate verification into as few login passes as possible per session.
- **Don't copy web's own bugs or dead code into mobile** — recurring theme this session (Referrals' `Number(NaN)` branch bug, web's degraded "Un-punches" tab). Always verify a component is actually reachable from a live route's real import graph before treating its behavior as current spec.
- A DRF list view returning a paginated envelope doesn't mean every mobile call site was actually using `page`/`page_size` — `fetchRecords`/`fetchOvertimeList` were quietly capped at `page_size: 100` and ignoring the `count`/`total_pages` the backend was already sending back.

### Pending Tasks (updated)
- [ ] Manual on-device pass for all of this session's screens (Referrals, the 3 new Settings screens, My Attendance's rebuilt calendar/mode selector, HR Attendance & Time's new dialogs) on a small physical screen — verified via `flutter analyze` + live web testing only.
- [ ] Sweep the older `_friendly(e.toString())` error pattern to `parseDioException()`/`friendlyAttendanceError()` style helpers across Leave/Expenses/Documents/Employees (carried over from Sessions 15–17 — still not done).
- [ ] Live-exercise the Invalid Punch Assign/Convert/Discard dialogs against a day that actually has invalid punches (none existed in the seeded demo data used for this session's verification pass).
- [ ] `/onboarding/assessments` candidate-taking portal — still not ported (carried over from Session 17).
- [ ] Backend: `Holiday` model/API still doesn't exist for real — Holiday Calendar remains local-only mock state (carried over from Session 17).

---

## Session 19 — Dashboard Header (Dark Mode + Notifications), Approval Rules Settings Screen, Release Build Debugging, App-Wide Overflow Sweep

**Date:** 2026-07-15
**Developer:** Pramod Kunja

### Module Worked On
- Dashboard — top bar rebuilt to match web (dark mode toggle, real notifications bell), side-menu regression fix
- Core — app-wide dark mode theming infrastructure (new)
- Notifications — full new feature, backend-connected (new)
- Settings — Approval Rules screen (new), Depts & Designations overflow fixes + professional redesign pass
- Release build — first APK handed to the team; found and fixed a missing Android permission and a wrong hosted API URL
- Bug fixes — top bar status-bar overflow, Candidate Review action button, Attendance summary-grid overflow + count-up animation

---

### Part 1: Dashboard Top Bar — Dark Mode Toggle + Real Notifications

Web's dashboard header shows a moon/sun toggle and a notifications bell next to the logout icon; mobile's `AppTopBar` had neither. Ported both.

**Dark mode — genuinely app-wide, not a header cosmetic.** `AppColors` (`core/theme/app_colors.dart`) was a class of `static const Color` fields referenced in ~2,650 places across ~132 files. Web's own dark mode is just a CSS variable swap (`body.dark-mode` in `globals.css`) — there's no equivalent free lunch in Flutter. Converted every field to a mutable `static Color` with light/dark hex pairs (dark values mapped 1:1 from web's `body.dark-mode` vars; fields web's dark mode doesn't define — container tints, hint text, strong border — were derived to preserve the same relationship they have to their sibling color in light mode) plus `AppColors.applyMode(bool dark)` to swap all of them at once. New `core/theme/theme_mode_provider.dart` (`themeModeProvider`, `ThemeModeNotifier`) persists the choice via the existing `SecureStorageService` (web doesn't persist its own toggle — deliberately added persistence here since resetting to light on every restart would be worse UX). `main.dart` loads the persisted value and calls `AppColors.applyMode()` *before* `runApp` so there's no light-mode flash on startup for users who last chose dark.

Forcing the toggle to actually re-render the whole app was the hard part: most widgets read `AppColors.x` as a plain static value (no `Theme.of(context)` dependency-tracking), and almost every `go_router` route is built with `const XScreen()` — so a normal ancestor rebuild would get short-circuited by Flutter's identical-const-widget skip and never reach most of the tree. Fixed by keying `MaterialApp.router` itself on the theme flag (`app/app.dart`) — `ValueKey('app-theme-$isDark')` forces a full teardown/remount of the entire visible subtree on toggle, guaranteeing fresh reads of the now-swapped static colors regardless of any `const` optimization along the way. `GoRouter` itself lives in a separate provider outside this subtree, so the current route/location survives the remount even though in-page widget state (scroll position, unsaved form input) does not — an accepted, minor cost for a rarely-used settings action. `AppTheme.themeFor(bool)` replaces the old single `AppTheme.light` getter, built fresh from the already-switched `AppColors` fields each time (not cached, since caching a `light`/`dark` pair up front would read the same live static fields twice).

Converting `AppColors` to non-const broke every `const` expression referencing it — 101 files, ~600 individual compile errors (`invalid_constant`, `non_constant_list_element`, etc.). Fixed via 5 parallel background agents (dashboard/payroll/attendance, leave/approvals, employees, settings, everything-else — the last one further split itself into its own sub-agents), each given the same mechanical fix patterns: drop the offending `const`; for `static const` field declarations holding an `AppColors` reference, change to `static final`; for the 2 cases where a widget's *default parameter value* referenced `AppColors.x` (Dart requires parameter defaults to be literally constant, so `const` can't just be dropped there), made the parameter nullable with a `null` default and resolved it via `??` inside `build()`. Final `dart analyze lib`: 0 errors, same 122 pre-existing info-level lints as the pre-session baseline.

Header toggle icon swaps moon ⇄ sun exactly like web (moon = tap to go dark, sun = tap to go light) — matches the reference screenshot the user supplied of web's light-mode header.

**Notifications — real backend, not a stub.** Backend already had a full `notifications` Django app (`Notification` model, `GET /notifications/`, `GET /notifications/unread-count/`, `PATCH /notifications/<id>/read/`, `PATCH /notifications/read-all/`) that mobile had never wired up (`onNotificationsTap` was a no-op comment). Built the full feature: `features/notifications/data/models/notification_model.dart`, `data/datasources/notifications_remote_datasource.dart`, `presentation/providers/notification_providers.dart` (`unreadNotificationCountProvider` polls every 60s while the shell is mounted, matching web's `POLL_INTERVAL_MS`; `notificationsProvider` fetches the list on-demand only when the panel opens, also matching web), `presentation/widgets/notification_bell_button.dart` + `notification_panel.dart`. Row tap marks read + navigates via a `_kModuleRoutes` map ported directly from web's `NotificationBell.tsx` `MODULE_ROUTES`.

The notification panel's presentation went through several rounds of direct user correction before landing:
1. First built as a bottom sheet (`DraggableScrollableSheet`) — user asked for "a dropdown popup showing under the notification icon" instead.
2. Rebuilt as an overlay anchored under the bell via `RenderBox`/`Overlay` position math (`showGeneralDialog` + `Positioned`) — user then asked to center it on screen instead.
3. Rebuilt again as a centered `Center(child: ...)` dialog — user reversed course, "that pop up should be under the notification icon only," so it went back to the anchored version.
4. Live testing then showed the anchored panel hugging the *left* screen edge, barely under the bell at all: the fixed 340px width, right-aligned to the bell's own right edge (not the screen's), simply didn't fit on a normal phone once you account for the logout icon sitting after the bell in the row. Fixed by computing an explicit `left` position from the bell's actual anchor point and clamping it to a 12px minimum margin, with the panel's width capped to `min(340, screenWidth - 24)` — it now shrinks/shifts to always stay on-screen instead of overflowing left.

`NotificationBellButton` owns its own tap handling (not threaded through `DashboardShell`/`AppTopBar` as a callback) since it needs its own `RenderBox` to compute the anchor position — this made `AppTopBar` simpler, not more complex (no more `onNotificationsTap`/`unreadCount` params to thread through).

**Regression caught and fixed:** "My Referrals" (removed from the drawer nav earlier per explicit user request) had silently reappeared in `nav_config.dart`'s working tree — `git diff` showed it as *added* relative to the last commit, meaning it was never actually committed removed. Removed it again (both the `NavItem` and its `kPageTitles` entry).

**Side menu dynamic-permissions check (no code change needed):** user asked to "manage side menu as per the permissions getting in the response and manage it dynamically." Investigated `AppSidebar`/`buildNav` — it already watches `authStateProvider` reactively (`ConsumerWidget` + `ref.watch`) and filters via `buildNav(permissions)` against the live login-response permission list on every rebuild. Verified `permissions` is parsed straight from the JSON auth response into `UserEntity` (not cached/stale). Confirmed against web's own `navConfig.ts`/`proxy.ts` that the mechanism (and even the permission-string list, including two — `branches.view`, `assessments.view` — that don't actually exist in the backend's 46 seeded permissions, a pre-existing web-side gap, not something to "fix" unilaterally on mobile since it'd break web/mobile parity) already matches exactly. No code change was needed for this half of the request.

#### Files created
```
lib/core/theme/theme_mode_provider.dart
lib/features/notifications/data/models/notification_model.dart
lib/features/notifications/data/datasources/notifications_remote_datasource.dart
lib/features/notifications/presentation/providers/notification_providers.dart
lib/features/notifications/presentation/widgets/notification_bell_button.dart
lib/features/notifications/presentation/widgets/notification_panel.dart
```

#### Files modified (major)
```
lib/core/theme/app_colors.dart              rewritten — mutable light/dark palette + applyMode()
lib/core/theme/app_theme.dart                AppTheme.light → AppTheme.themeFor(bool)
lib/main.dart                                preload persisted theme before runApp
lib/app/app.dart                             theme-keyed MaterialApp.router remount
lib/features/dashboard/presentation/widgets/app_top_bar.dart
lib/features/dashboard/presentation/screens/dashboard_shell.dart
lib/features/dashboard/presentation/navigation/nav_config.dart   (My Referrals re-removed)
core/network/api_client.dart                 (see Part 5 — parseDioException detail fallback)
+ ~101 files app-wide with const-keyword-only fixes from the AppColors mutability change
```

---

### Part 2: Settings — Approval Rules Screen (New)

Web's Settings has a small, fixed 4-row "Approval Rules" table (Leave/Expense/Resignation/Loan → who approves at L1/L2), backed by a singleton-per-workflow-type Django model (`ApprovalWorkflowRule`, `workflow_type` DB-unique) — distinct from the *different*, per-employee "Approval Matrix" override feature already on the employee profile screen. Ported the Settings one: `GET/PATCH /settings/approval-rules/` (PATCH targets the same collection URL; the row to update is identified by `workflow_type` in the body, not a path segment — matches web exactly, including the fixed 4-row/no-add/no-delete UX).

**Notable backend quirk carried over deliberately:** this endpoint gates both GET and PATCH on `CanManageRoles` (hard-coded role check: `hr_admin`/`system_admin`), *not* a `settings.view`/`settings.edit` permission codename like every sibling settings screen — matches an actual backend inconsistency, not a mobile bug. Edit button gated on `role == 'hr_admin' || role == 'system_admin'` (the exact idiom already used at `employee_profile_screen.dart:1236` for the same role pair, reused rather than reinvented).

**Fixed a real, shared gap while in `parseDioException`:** a 403 from this endpoint (or any other DRF-native permission rejection) previously fell back to a generic `"Access denied."`, because the parser only ever checked the app's normal `{message: ...}` envelope, never DRF's raw `{"detail": "..."}` shape that a bare `permission_classes` rejection returns. `api_client.dart`'s `serverMessage` extraction now falls back to `body['detail']` when `message` is absent — additive, doesn't change behavior for any response that already had a `message` field, benefits every future DRF-raw-shape 403 app-wide, not just this screen.

#### Files created
```
lib/features/settings/data/models/approval_rule_model.dart
lib/features/settings/data/datasources/approval_rules_remote_datasource.dart
lib/features/settings/presentation/providers/approval_rules_providers.dart
lib/features/settings/presentation/approval_rules/approval_rules_screen.dart
```

#### Files modified
```
lib/core/constants/api_constants.dart        settingsApprovalRules
lib/core/router/app_router.dart              AppRoutes.settingsApprovalRules + GoRoute
lib/core/network/api_client.dart             parseDioException detail-fallback
lib/features/settings/presentation/settings_hub/settings_screen.dart   new tile
```

---

### Part 3: Depts & Designations — Overflow Fixes + Professional Redesign Pass

User hit a live `RenderFlex` overflow opening the Add/Edit Department dialog. Root cause: `DeptFormSheet`/`DesigFormSheet` built their form body as a fixed-size `Column` with keyboard-inset bottom padding but **no scrollable wrapper** — when the dialog's available height shrank (keyboard open, or a smaller phone), the fields had nowhere to go. Per the user's follow-up ask ("fix this type of overflow issue all over the app"), swept every file using the same `ClipRRect → Column(mainAxisSize.min)` dialog-root pattern (`grep` for `ClipRRect` files lacking any `SingleChildScrollView`/`ListView`, then manually distinguished true dialog-root hits from decorative/unrelated `ClipRRect` uses like rounded avatars). Found and fixed 5 total: `DeptFormSheet`, `DesigFormSheet`, `AssignDialog` and `AssessmentFormDialog` (assessments), and `HolidayViewDialog` (view-only, lower risk but fixed defensively for consistency) — all now wrap their body in `Flexible + SingleChildScrollView`, matching the pattern already correctly used by every *other* dialog in the app (verified — all 10 other files using the same `MediaQuery.viewInsetsOf(...).bottom` keyboard-inset pattern were already properly scrollable).

Also asked to make the Depts & Designations screen "professional as like other pages" — added the same gradient `SettingsPageHeader` banner used on every other Session-18-and-later settings screen (Referral Rules, Approval Rules) to its top; the existing stat cards, search bar, and expandable department/designation cards were already well-designed (gradient avatars, colored accent chips) so those were left as-is.

#### Files modified
```
lib/features/settings/presentation/departments/departments_screen.dart          + SettingsPageHeader
lib/features/settings/presentation/departments/widgets/dept_form_sheet.dart      + Flexible/SingleChildScrollView
lib/features/settings/presentation/departments/widgets/desig_form_sheet.dart     + Flexible/SingleChildScrollView
lib/features/assessments/presentation/widgets/assign_dialog.dart                + Flexible/SingleChildScrollView
lib/features/assessments/presentation/widgets/assessment_form_dialog.dart       + Flexible/SingleChildScrollView
lib/features/settings/presentation/holiday_calendar/widgets/holiday_view_dialog.dart  + Flexible/SingleChildScrollView
```

---

### Part 4: Release Build — First APK to the Team, Two Real Deployment Bugs Found

First `flutter build apk --release` handed to the team surfaced two genuine deployment bugs, neither a Flutter code bug in the usual sense:

**Bug 1 — missing `INTERNET` permission.** `android/app/src/main/AndroidManifest.xml` had `ACCESS_FINE_LOCATION`/`ACCESS_COARSE_LOCATION` but no `<uses-permission android:name="android.permission.INTERNET"/>` at all. Without it, Android blocks *every* network call at the OS level regardless of backend — this alone would fail 100% of requests on any installed release APK. Added it.

**Bug 2 — wrong hosted API URL.** `ApiConstants.baseUrl`'s release branch pointed at `https://api.royalhrms.com/api`. Confirmed via `dig`/`curl` from this environment that `api.royalhrms.com` has **no DNS record at all** (`NXDOMAIN`) — not a device/network issue, the subdomain was simply never created (the root `royalhrms.com` domain does resolve, to what looks like a registrar parking page). User then pasted the server's actual nginx config and `.env`, revealing the real deployed hostname is `royalhrms.nxsys.in` (nginx `location /api/` proxies to Django on `127.0.0.1:8008` there). The user's own manual edit in between (via `nano`) had also dropped the `/api` suffix — verified this would silently route requests to the Next.js frontend's catch-all instead of Django (HTML 404 instead of JSON), and corrected it. Verified live: `GET https://royalhrms.nxsys.in/api/login/` → `405 Method Not Allowed` (correct — login is POST-only, confirms the route is live and correctly reaching Django). `ApiConstants.baseUrl` now unconditionally returns `https://royalhrms.nxsys.in/api` (the `kDebugMode`-conditional localhost branch was removed by the user's own edit; left as the user set it).

**Also flagged, not fixed (backend team's call):** the pasted `.env` had `DEBUG=True` and `ALLOWED_HOSTS=*` on what appears to be the production deployment — a real security concern (stack traces/settings exposure) but out of scope for a mobile-app session.

#### Files modified
```
android/app/src/main/AndroidManifest.xml     + INTERNET permission
lib/core/constants/api_constants.dart        baseUrl → https://royalhrms.nxsys.in/api
```

---

### Part 5: Misc Bug Fixes

**`AppTopBar` status-bar overflow.** Hardcoded `height: 56` didn't account for the device's actual status bar inset — `SafeArea` inside that fixed box just ate into the same 56px, cramming the icon row into whatever was left, clipping/overflowing on phones with a taller status bar/notch than whatever it was tested on. Fixed to read `MediaQuery.of(context).padding.top` and grow the container to `kToolbarHeight + topPadding`, matching the same convention Flutter's own built-in `AppBar` uses internally (and matching how Scaffold itself computes the app-bar slot's max height).

**Candidate Review — "Send Back for Corrections" button.** Was an outlined red-bordered button; changed to a solid filled red (`AppColors.error` background, white text) for clearer visual weight as a destructive/negative action, and the label now wraps across 2 lines (`"Send Back for\nCorrections"`, center-aligned, smaller font) instead of risking overflow in the tight half-width space next to "Approve & Activate ✓".

**Employee/My Attendance — Monthly Summary grid overflow + count-up animation.** `GridView.count(childAspectRatio: 1.6)` ties cell height to column width — 3 columns leaves little width per cell on narrower phones, and the locked aspect ratio shrinks height right along with it, so the label + number no longer fit (live `RenderFlex` overflow reported by the user, `_SummaryCell` constraints `w=69.3, h=39.1`). Fixed in both `employee_attendance_tab.dart` and the identical grid in `my_attendance_screen.dart` by switching to `GridView.builder` + `SliverGridDelegateWithFixedCrossAxisCount(mainAxisExtent: 64)` — a fixed, width-independent cell height. Also added a count-up animation to each cell's number (`TweenAnimationBuilder<double>`, 0 → target over 700ms, `Curves.easeOutCubic`) per explicit user request, gracefully falling back to a static `Text` for values that aren't a clean integer (OT Hours is a formatted string like `"12h 30m"`, not a number — can't be meaningfully animated as a count).

#### Files modified
```
lib/features/dashboard/presentation/widgets/app_top_bar.dart
lib/features/candidate_review/presentation/screens/candidate_review_screen.dart
lib/features/employees/presentation/widgets/employee_attendance_tab.dart
lib/features/attendance/presentation/screens/my_attendance_screen.dart
```

---

### Verification
- `dart analyze lib` after every part of this session: 0 errors throughout, holding steady at the same 122 pre-existing info-level lints (`prefer_const_constructors`, `deprecated_member_use`) as the pre-session baseline — never regressed.
- `flutter build apk --release` succeeded after every change in this session; the final build was verified against the corrected live hosted backend (`https://royalhrms.nxsys.in/api/login/` → confirmed reachable and correctly routed).

### Architecture Notes
- **Dark mode in a codebase built on static `AppColors` reads (not `Theme.of(context)`) requires a full-subtree remount to guarantee correctness**, not just an ancestor `ref.watch` rebuild — `const`-declared route screens (the app's own convention, used almost everywhere for perf) silently block a plain rebuild cascade via Flutter's identical-widget skip. `ValueKey`-ing the app root is the reliable fix; the cost is losing in-page transient state on toggle, which is acceptable for a rarely-used settings action.
- **`parseDioException` only reads `body['message']`, never `body['detail']`** — any endpoint whose 403/permission rejection comes from bare DRF `permission_classes` (not the app's own `error()` envelope helper) previously surfaced a generic, unhelpful message. Now fixed centrally; worth remembering for any *new* endpoint that relies on a raw DRF permission class rather than `core/responses.py`'s helpers.
- **A release APK's `baseUrl` should be verified reachable (DNS + a real route round-trip) before handing a build to anyone** — "the backend is already hosted" and "the hostname actually resolves to it" are not the same claim; this session's build pointed at a domain with zero DNS records for at least one full round of team testing.
- **Don't assume `flutter build apk` uses your dev backend** — it's a release build (`kDebugMode == false`) unless `--debug` is passed explicitly, and even a debug build's `localhost` branch means the *device itself*, not the dev machine, unless using the Android emulator's `10.0.2.2` alias or LAN-IP + port-forwarding for a physical device.

### Pending Tasks (updated)
- [ ] Confirm with whoever manages `royalhrms.nxsys.in`'s deployment that `DEBUG=True`/`ALLOWED_HOSTS=*` in production `.env` is intentional or needs tightening (flagged this session, not mobile's call to fix).
- [ ] Manual on-device dark-mode pass across every screen — verified via `dart analyze` + targeted rebuilds only, not yet a full visual sweep of all ~132 touched files in actual dark mode on a device.
- [ ] Sweep the older `_friendly(e.toString())` error pattern to `parseDioException()`-style helpers across Leave/Expenses/Documents/Employees (carried over from Sessions 15–18 — still not done).
- [ ] `/onboarding/assessments` candidate-taking portal — still not ported (carried over from Session 17).
- [ ] Backend: `Holiday` model/API still doesn't exist for real — Holiday Calendar remains local-only mock state (carried over from Session 17).


---

## Session 20 — Dashboard: Role-Specific Ports for Employee, Admin, and HR (New)

**Date:** 2026-07-20
**Developer:** Pramod Kunja

### Module Worked On
- Dashboard — full new `apps/dashboard` backend integration: role-specific Employee/Admin/HR dashboards replacing the single generic layout (new)
- Dashboard — Admin dashboard visual-fidelity pass against reference screenshots (System Console header, Pending Approvals, Employee Lifecycle, Audit Logs)
- Dashboard — Employee dashboard full redesign to match web's actual `EmployeeDashboard.tsx` layout pixel-for-pixel
- Shared bug fix — `KpiGrid`'s fixed tile height was too short for a 2-line label, affecting all three role dashboards

---

### Part 1: Dashboard — Full Role-Specific Port (New)

Web's dashboard (a prior, already-merged web commit — `git diff` confirmed nothing changed in it during this session) replaced one generic dashboard page with 4 role-specific ones — `AdminDashboard.tsx`, `HRDashboard.tsx`, `EmployeeDashboard.tsx`, `ManagerDashboard.tsx` — backed by ~20 new `apps/dashboard` endpoints. Mobile had none of this: one `HomeScreen` for every role, zero `apps/dashboard` endpoints wired up, and the existing Leave Balance / Recent Requests cards pulled from unrelated general-purpose endpoints (`/leave/stats/`, `/leave/requests/`) instead.

Read every backend view directly (`apps/dashboard/views/overview.py`, `people.py`) rather than trusting the web frontend's own TypeScript types — the frontend defensively aliases several fields (e.g. `LifecycleEmployee` declares `id?/employee_id?`, `name?/full_name?/employee_name?` all at once) that don't reflect what the backend actually, concretely returns; the mobile models were built off the real backend field names instead (e.g. audit log entries: backend returns `user`, never `actor`/`actor_name`/`ip` as the frontend type speculatively declares).

Built a full new data layer under `features/dashboard/`: models split by role (`dashboard_common_models.dart` for shapes shared across roles — `TodayAttendanceSnapshot`, `DashboardAnnouncement`, `DashboardBirthdayEmployee`, `DeptHeadcount`; `employee_dashboard_models.dart`, `admin_dashboard_models.dart`, `hr_dashboard_models.dart`), one `DashboardRemoteDataSource` covering all ~20 endpoints, and `dashboard_providers.dart` (all `FutureProvider.autoDispose`, plus a shared `friendlyDashboardError` mapper). Extracted three widgets previously private to the old `home_screen.dart` into shared public files so all three role screens could reuse them: `widgets/dashboard_section.dart` (`SectionCard`/`SectionMessage`/`SectionError`/`KpiTile`/`KpiGrid`/`BarRow`), `widgets/quick_access.dart` (role → Quick Actions arrays + `resolveRoleCategory()`, matching web's `resolveRole()` in `app/dashboard/page.tsx` exactly), and `widgets/clock_in_card.dart` (the real interactive punch card, since web embeds the same clock button on both the Employee and HR dashboards).

`home_screen.dart` became a thin role router: `employee` → `EmployeeDashboardView`, `admin` → `AdminDashboardView`, `hr` → `HrDashboardView`, everything else (Manager) → the previous generic layout, kept as-is. **Manager deliberately excluded from the port** — read `ManagerDashboard.tsx` and confirmed every stat/list on it (team size, pending approvals, attendance %, activity feed) is hardcoded mock data with no real backend behind it at all (only its birthday widget is real) — there was nothing genuine to port for that role.

Built the Admin and HR dashboard screens via two parallel background agents (each given exact provider names, model fields, and the shared-widget API up front so their output would compile against what the other was building concurrently), while building the Employee dashboard and the role-router wiring directly. All three passed `dart analyze` clean on first integration; a couple of naming collisions (`employeeAttendanceSummaryProvider` existing in both the attendance feature and the new dashboard feature) were resolved with an explicit `hide` on import.

**Admin dashboard sections:** System Overview KPI+health strip, Pending Approvals, Department Headcount (a `BarRow` list — no chart library in this project's `pubspec.yaml`, so this stands in for web's chart), Latest Announcement, Employee Lifecycle (New Joiners/Notice Period/Work Anniversaries), Birthdays, Audit Logs.

**HR dashboard sections:** HR KPI strip, Today's Attendance Summary (org-wide snapshot counts — a different shape from the Employee dashboard's *monthly* attendance summary despite both being called "attendance summary" in the backend's own naming), Action Queue, Recruitment Funnel, the shared Clock In/Out card, Employee Lifecycle, Department Headcount, Birthdays.

**Employee dashboard sections (first pass):** KPI strip, Clock In/Out, Leave Balances (switched to the dashboard-app's own endpoint — `remaining`/`carried_forward` fields — instead of the old `/leave/stats/`-backed card, which used a different shape entirely with no `carried_forward`), monthly Attendance Summary, Action Items (tap-to-navigate mapped by `action_type`, not the backend's raw `navigation_url` string — mobile's route structure doesn't mirror web's 1:1, e.g. self-service attendance is `/dashboard/my-attendance` here, not `/dashboard/attendance`), Recent Requests (a real mixed leave/expense/attendance-correction feed, replacing the old leave-only card), Announcement, plus the pre-existing Birthdays/Quick Links cards kept since they already worked correctly.

#### Files created
```
lib/features/dashboard/data/models/dashboard_common_models.dart
lib/features/dashboard/data/models/employee_dashboard_models.dart
lib/features/dashboard/data/models/admin_dashboard_models.dart
lib/features/dashboard/data/models/hr_dashboard_models.dart
lib/features/dashboard/data/datasources/dashboard_remote_datasource.dart
lib/features/dashboard/presentation/providers/dashboard_providers.dart
lib/features/dashboard/presentation/widgets/dashboard_section.dart
lib/features/dashboard/presentation/widgets/quick_access.dart
lib/features/dashboard/presentation/widgets/clock_in_card.dart
lib/features/dashboard/presentation/screens/employee_dashboard_view.dart
lib/features/dashboard/presentation/screens/admin_dashboard_view.dart
lib/features/dashboard/presentation/screens/hr_dashboard_view.dart
```

#### Files modified
```
lib/core/constants/api_constants.dart        ~20 apps/dashboard endpoint paths
lib/features/dashboard/presentation/screens/home_screen.dart   rewritten as role router + generic/Manager fallback
```

---

### Part 2: Admin Dashboard — Visual-Fidelity Pass Against Reference Screenshots

User supplied screenshots of web's actual Admin dashboard rendering (System Console header, Pending Approvals card, Employee Lifecycle tabs, Audit Logs table) and asked for the mobile port to match. Rebuilt section-by-section:

**System Console header.** Web's `KpiConsole` is a dark navy hero card (icon badge + "SYSTEM CONSOLE" eyebrow + "Welcome back, {name}", inline health pills for API/DB/Mail/Storage, a 4-stat row below a divider) — not the boxed-tile `SectionCard` originally built. Rebuilt as a bespoke gradient container matching this exactly.

**Pending Approvals.** Reference image shows a distinct light-tinted footer band ("View all pending approvals →") with rounded bottom corners bleeding to the card's full width — not achievable with the shared `SectionCard`'s single uniform padded body, so this card was rebuilt as its own bespoke shell instead of using `SectionCard`. Also connected every row to a real destination: Leave Requests → `/dashboard/leave`, Expense Claims → `/dashboard/expenses`, Separation Requests → `/dashboard/separation` (an existing, if placeholder, route), and Onboarding Reviews → the Employees list pre-filtered to `status: onboarding` (via `employeeFiltersProvider`) since no dedicated onboarding-review screen exists in the app yet — the closest genuine destination rather than a dead link.

**Employee Lifecycle.** Added a real 3-tab selector (New Joiners/Notice Period/Anniversaries, matching web's tab bar with counts and an active-tab underline) instead of three stacked always-visible sections; rows now navigate to the real employee profile route.

**Audit Logs.** Rebuilt as pill-styled ACTION badges + actor/IP icon rows + a module tag + formatted time (`"20 Jul, 01:27 pm"`, hand-rolled — no `intl` package in this project's dependencies), plus a working module-filter dropdown and a functional "Load more" that paginates against the real endpoint (a `FutureProvider.autoDispose.family<AuditLogsResponse, ({int offset, String module})>` backing the first page reactively, with imperative appends for subsequent pages) — not just decorative UI. Added a "View all" link beside the filter, pointed at the pre-existing full-featured Settings → Audit Log screen (`/settings/audit`, `AuditScreen`) rather than duplicating its filters here — that screen already has real search/date-range/pagination against a *different* backend endpoint (`/settings/audit/`, actor_name/actor_email/actor_role shape) than the dashboard summary card's endpoint (`/dashboard/system-admin/audit-logs/`, just `user`) — confirmed these are two genuinely distinct backend views before treating one as a substitute for the other.

**Announcement empty state.** User reported the "No announcements yet" message+icon wasn't displaying. Hardened the empty-state check in both the Admin and Employee announcement cards to treat a blank/malformed announcement (empty `title`) as "no announcement" too, not just a strict `null` — guards against ever silently rendering a blank card if the backend ever returns an empty object instead of a clean `null`.

#### Files modified
```
lib/features/dashboard/presentation/screens/admin_dashboard_view.dart
lib/features/dashboard/presentation/providers/dashboard_providers.dart   auditLogsProvider → auditLogsPageProvider (family)
```

---

### Part 3: Shared `KpiGrid` Overflow Bug (found during unrelated web-diff re-verification)

Asked to re-check whether web's Employee dashboard had changed since the Part 1 port — a full `git diff` between the commit that introduced the dashboard feature and current `HEAD` on every relevant file (component, sub-components, hooks, types, both backend view files) came back byte-for-byte identical. Nothing had changed; no port work was actually needed there.

Used the opportunity to stress-test the existing implementation instead of reporting back empty-handed, and found a real, pre-existing bug: the shared `KpiTile`/`KpiGrid` widget (used by all three role dashboards' KPI strips) was sized to a 92dp `mainAxisExtent`, but the actual content — icon + a single-line value + a label that can wrap to 2 lines (e.g. "Pending Actions", "Active Branches") — needs roughly 106–108dp. Any tile whose label happened to wrap overflowed. Fixed by bumping `mainAxisExtent` to 116 in the one shared file, correcting it across Employee, Admin, and HR dashboards simultaneously rather than needing a per-screen patch.

#### Files modified
```
lib/features/dashboard/presentation/widgets/dashboard_section.dart   KpiGrid mainAxisExtent 92 → 116
```

---

### Part 4: Employee Dashboard — Full Redesign to Match Web Pixel-Level

User flagged the Employee dashboard "doesn't look like the web design." Read every one of web's actual Employee dashboard components directly (`EmpConsole.tsx`, `EmpLeaveBalances.tsx`, `EmpAttendanceSummary.tsx`, `EmpActionItems.tsx`, `EmpRecentRequests.tsx`, `EmpAnnouncement.tsx`, plus `ClockInButton.tsx` and `useClockWidget.ts`) rather than working from memory of the earlier Part 1 pass, and found the mobile version had drifted from what web actually does in several structural, not just cosmetic, ways:

- **Console header.** Web uses one dark hero card: greeting + inline Clock In/Out pill button + attendance-status pill, a divider, a *plain* 4-stat row (Days Present as a combined `"X / Y"` value, Absent Days, Action Items, Expense Claims — no boxed tiles, no separate "Working Days"/"Documents" tiles web doesn't show at all), another divider, then a Clock In/Clock Out/Working-hours strip. Mobile had this split across three separate boxed-tile cards showing 6 stats. Rebuilt as one console card matching web's structure, and wired `employeeAttendanceStatusProvider` into the new status strip — this provider was already being fetched in the Part 1 build but **never actually rendered anywhere**.
- **Leave Balances.** Switched from full-width stacked rows to web's 2-up grid-of-cells (small color swatch + label, large `remaining` number + "of N days" caption, thin progress bar, "N used · N carried forward" footer), and added the "Apply Leave" header button web has.
- **Attendance Summary.** Added the month picker (web has one; mobile was silently locked to the current month), the percentage progress bar with a "Working days: N" caption, and switched to web's exact 9-tile stat grid (mobile was missing "Attendance %" as its own tile). Backed by a new `employeeAttendanceSummaryForProvider` family provider keyed by `(month, year)` so switching months doesn't lose the previous month's cached data.
- **Action Items.** Added the "N pending" header count badge, the "All caught up!" checkmark empty state, "Done"/"Pending"/"Rejected" status-label remapping, and reduced opacity for completed items — all present on web, absent on mobile.
- **Recent Requests.** Added the "N pending" header badge and web's exact `"20 Jul"` day-plus-short-month date format.
- **Announcement — the biggest behavioral gap.** Web's `EmpAnnouncement` returns `null` (renders literally nothing) when there's no announcement or it's been dismissed — it's a lightweight dismissible inline banner, not a card with its own header/empty-state message. Mobile always showed an "Announcement" `SectionCard`, even empty. Rewired to match web exactly: no card chrome, `SizedBox.shrink()` when there's no data or the user dismissed it (local `_dismissed` state, resets on next app open — matches web's `useState`, which also doesn't persist across reloads), a "View →" link to the real Announcements screen, and a working dismiss (×) button.

Birthdays and Quick Links kept at the bottom of the screen — they aren't part of web's Employee dashboard at all, but they already worked correctly before this port and removing them wouldn't make the dashboard look any more like web, just remove a working feature.

#### Files modified
```
lib/features/dashboard/presentation/screens/employee_dashboard_view.dart   full rewrite
lib/features/dashboard/presentation/providers/dashboard_providers.dart     + employeeAttendanceSummaryForProvider (family)
```

---

### Verification
- `dart analyze lib` after every part of this session: 0 errors throughout, holding steady at the same 122 pre-existing info-level lints as the pre-session baseline — never regressed, across ~15 new/modified dashboard files.
- No APK rebuild performed this session — all work verified via `dart analyze` only; the user has twice declined an offered `flutter build apk --release` earlier in this project's history when testing via Flutter Web against a local backend, so one wasn't proactively triggered here either.

### Architecture Notes
- **When porting a web feature, read the actual backend view/serializer code, not the frontend's own TypeScript types** — this codebase's frontend types are written defensively (multi-aliased optional fields covering shapes the backend might return) rather than describing what it actually, concretely returns today. Building mobile models off the speculative frontend union types would have baked in the frontend's own uncertainty; the real backend `views.py`/`people.py` code is the source of truth.
- **A `git diff` between commits is worth running before assuming "the web changed"** — asked to re-port the Employee dashboard on the assumption something had changed there; a directory diff proved nothing had, and the actual value of that pass turned out to be an unrelated shared-widget sizing bug found by stress-testing the existing implementation instead.
- **Two backend views can serve conceptually-overlapping data with genuinely different shapes** — `apps/dashboard`'s audit-log summary endpoint (`user`, `ip_address`) and `apps/accounts`'s full settings audit-trail endpoint (`actor_name`/`actor_email`/`actor_role`) are not interchangeable; confirmed this by reading both view files before wiring a "View all" link between them, rather than assuming one could be swapped for the other.
- **A shared widget's fixed-size grid delegate needs headroom for the *worst-case* text wrap, not the common case** — `KpiGrid`'s `mainAxisExtent` was tuned against short 1-line labels and silently overflowed the moment a longer label (2 words, narrow column) wrapped to a second line. Any future shared tile/card component sized with a fixed `mainAxisExtent`/`childAspectRatio` should be checked against its longest realistic label, not just whatever was on screen during development.

### Pending Tasks (updated)
- [ ] Manual on-device pass of all three new role dashboards (Employee/Admin/HR) — verified via `dart analyze` and code-level cross-checking against web only, not yet visually confirmed on a running app/device this session.
- [ ] HR and Admin dashboards haven't had the same "match web pixel-for-pixel" scrutiny the Employee dashboard just got in Part 4 — Admin got a screenshot-driven pass in Part 2, but HR's dashboard has only ever been built once, against the field-level spec, never visually compared to a live web render.
- [ ] No dedicated onboarding-review screen exists in the app — Admin's "Onboarding Reviews" pending-approval row currently opens the Employees list filtered to `status: onboarding` as the closest real substitute; a purpose-built review screen (backend endpoint `/onboarding/approvals/` already exists and is unused by mobile) would be a cleaner long-term fix.
- [ ] Confirm with whoever manages `royalhrms.nxsys.in`'s deployment that `DEBUG=True`/`ALLOWED_HOSTS=*` in production `.env` is intentional or needs tightening (carried over from Session 19 — not mobile's call to fix).
- [ ] Manual on-device dark-mode pass across every screen (carried over from Session 19 — still not done).
- [ ] Sweep the older `_friendly(e.toString())` error pattern to `parseDioException()`-style helpers across Leave/Expenses/Documents/Employees (carried over from Sessions 15–18 — still not done).
- [ ] `/onboarding/assessments` candidate-taking portal — still not ported (carried over from Session 17).
- [ ] Backend: `Holiday` model/API still doesn't exist for real — Holiday Calendar remains local-only mock state (carried over from Session 17).

---

## Session 21 — Interview List / Employees / Attendance Parity Audit, Leave Policy Settings Restructure (Leave Types / Leave Policy / Credit Rules / Carry Forward), UI Polish Pass

**Date:** 2026-07-23
**Developer:** Pramod Kunja

### Module Worked On
- Interview List, Employees, Attendance — full field/validation parity audit against web + Django backend, gap fixes
- Settings — Leave Policy screen restructured from 2 tabs to 4, matching web's actual tab split
- Settings — Leave Policy — new Carry Forward tab (real API wiring against currently-nonexistent backend routes, mirroring web's own broken state)
- Settings — Leave Policy — UI polish pass (tab icons, section icon avatars, dropdown legibility, footer button redesign)

---

### Part 1: Interview List / Employees / Attendance — Web Parity Audit

Dispatched deep-research agents to read the web frontend and Django backend directly (models/serializers/views, not just the React components) for Interview List, Employees, Attendance, and Leave Policy settings, then diffed field-by-field and validation-by-validation against mobile's existing implementations. Confirmed all four modules were already fully built and backend-wired going into this session — this was a gap-fix pass, not a from-scratch port. Found and fixed 13 concrete gaps:

**Interview List (2):** branch wasn't locked to the user's own branch for non-`system_admin` users in Add/Edit (web locks it client-side since the backend doesn't enforce it server-side either); status→selected/rejected was an instant PATCH with no confirmation, no remarks capture, and no email — added `MarkCandidateSheet` (mirrors web's `MarkCandidateModal`: fixed template by status, remarks textarea, sends `candidate_selected`/`candidate_rejected` via the existing `send-email` endpoint) plus a first-schedule `interview_scheduled_candidate` email trigger on Edit, matching `EditCandidateModal.tsx` exactly — including deliberately reusing the candidate's *original* branch name in the email template vars, a real web quirk worth replicating rather than "fixing" silently.

**Employees (5):** Employee Type dropdown had `'Part-time'` where it should say `'Probation'`; branch/role weren't locked/filtered for non-admins in Add Employee (web excludes `system_admin` from the role list and locks branch); no client-side email format validation; the Edit sheet let HR rewrite Full Name/Phone/Date of Joining even though web treats those as read-only forever, and didn't require or age-validate (18–80) Date of Birth even though the backend does persist DOB.

**Attendance (6):** the Records tab was missing a manual Add/Edit/Reprocess action entirely, and was missing status filter/sort/search controls even though `AttendanceRemoteDataSource.fetchRecords` already accepted all those params — the UI/provider layer simply never used them; OT Entry had no client-side end-time > start-time check; GPS wasn't captured for non-office punch modes (only 'office' triggered a location fetch, though `LocationService.getCurrentPosition()` already fails gracefully to `null` and was safe to call unconditionally).

Two apparent Employees gaps turned out to be false positives once the backend was read directly rather than trusted from the web UI's apparent behavior: `EmployeeDetailView.put` (`backend/apps/accounts/views.py`) only ever persists 9 whitelisted keys (role/department/designation/branch/phone/full_name/date_of_joining/date_of_birth/hr_id/reporting_manager_id) — no bank/education/emergency-contact/document fields at all — and `EmployeeDocumentView.post` is hardcoded to `user=request.user` and blocked entirely once onboarding is complete, so HR can never upload a KYC document on another employee's behalf regardless of platform. Web's own "editable" Bank/Education/Emergency/Documents sections on the Employee Profile silently no-op on save for exactly this reason. Left mobile's read-only treatment of those sections as-is rather than building matching "editable" UI that would be fake functionality with nothing real behind it.

#### Files modified
```
lib/features/interview_list/data/datasources/interview_datasource.dart
lib/features/interview_list/presentation/providers/interview_providers.dart
lib/features/interview_list/presentation/widgets/add_candidate_sheet.dart
lib/features/interview_list/presentation/widgets/add_candidate_form.dart
lib/features/interview_list/presentation/widgets/candidate_card.dart
lib/features/interview_list/presentation/widgets/mark_candidate_sheet.dart   (new)
lib/features/employees/data/models/employee_model.dart
lib/features/employees/presentation/widgets/add_employee_sheet.dart
lib/features/attendance/data/datasources/attendance_remote_datasource.dart
lib/features/attendance/data/repositories/attendance_repository_impl.dart
lib/features/attendance/domain/repositories/attendance_repository.dart
lib/features/attendance/presentation/providers/attendance_providers.dart
lib/features/attendance/presentation/screens/attendance_screen.dart
lib/features/attendance/presentation/screens/my_attendance_screen.dart
lib/core/constants/api_constants.dart        attendanceRecordCreate, attendanceReprocess
```

---

### Part 2: Leave Policy Settings — Tab Restructure (2 → 3 tabs)

A follow-up ask flagged this specific screen's structure as wrong after the fact — Part 1's audit had checked every field existed *somewhere* on screen and concluded "zero gaps" for Leave Policy settings, but never checked the tab/navigation shape against web's actual `page.tsx`. Web's Leave Policy settings page has 4 tabs: **Leave Types** (a simple list + a lightweight quick-edit modal — annual days, carry-forward toggle/limit, note, active only), **Leave Policy** (a completely separate full-page rule editor with its own leave-type dropdown selector and ~25 fields across 6 rule sections), **Credit Rules**, and **Carry Forward** (role-gated). Mobile had merged the first two into one "Policy" tab — a card list whose Edit button opened one all-fields sheet covering everything at once.

Split `leave_policy_form_sheet.dart` back down to just the lightweight quick-edit (matching web's `PolicyTab.tsx` edit modal exactly) and built a new `leave_policy_rules_tab.dart`: a full-page tab with a leave-type dropdown selector at the top and all 6 rule sections (Leave Application Rules, Holiday & Week-off Rules, Eligibility Rules, Documentation Rules, Leave Restrictions, Additional Rules) plus a Carry Forward section holding only the 2 real fields (`can_carry_forward`, `max_carry_forward_days`) — the 3 phantom fields web's own `CarryForwardSettingsSection` edits (`carry_forward_type`/`carry_forward_mode`/`carry_forward_expiry_days`) don't exist on the backend `LeavePolicy` model at all (confirmed via grep of `apps/hrms/models.py`/`serializers.py`), so they were deliberately left out rather than built as inputs that silently discard whatever the user types, which is what web itself does. `LeavePolicyScreen`'s `TabController` went from a fixed `length: 2` to `3` (or `4`, see Part 3).

---

### Part 3: Leave Policy Settings — Carry Forward Tab (New)

User explicitly asked for the Carry Forward tab to be added too, overriding an earlier recommendation to skip it on the grounds that its backend routes (`/leave/carry-forward/years|preview|run|history/`) don't exist anywhere in `apps/hrms/urls.py` (confirmed by grep — zero hits). Built `leave_carry_forward_tab.dart` with full visual and functional parity to web's `CarryForwardTab.tsx`: From/To Year dropdowns, a Preview action (shows total-rows/pending/already-done counts plus a per-employee-leave-type breakdown), a Run action behind a confirmation dialog with a dismissible duplicate-run warning banner, and a paginated History list. Gated to `system_admin`/`hr_admin`/`hr` (`kCarryForwardRoles`) — the tab is hidden entirely for other roles, matching web's own tab-bar-level gate rather than showing a disabled tab.

Added real endpoint constants (`ApiConstants.carryForward*`), models (`CarryForwardYearsModel`/`PreviewModel`/`LogModel`/`HistoryModel` in `leave_policy_model.dart`, mirroring web's `types/leave.ts` interfaces field-for-field), datasource methods, and providers (`carryForwardYearsProvider`, `carryForwardHistoryProvider` + a page `StateProvider`) — genuine API wiring against the intended real endpoints, not a mock/seed-data stand-in. Every action here currently 404s against the live backend, exactly as it would against the live web app today; this is a faithful port of a frontend-only feature, not a mobile-specific stub, and needs zero further mobile changes once the backend grows those 4 routes + a `CarryForwardLog` model.

#### Files created
```
lib/features/settings/presentation/leave_policy/widgets/leave_policy_rules_tab.dart
lib/features/settings/presentation/leave_policy/widgets/leave_carry_forward_tab.dart
```

#### Files modified
```
lib/features/settings/presentation/leave_policy/leave_policy_screen.dart
lib/features/settings/presentation/leave_policy/widgets/leave_policy_form_sheet.dart   trimmed back to quick-edit only
lib/features/settings/data/models/leave_policy_model.dart                              + CarryForward* models
lib/features/settings/data/datasources/settings_remote_datasource.dart                 + carry-forward methods
lib/features/settings/presentation/providers/settings_providers.dart                   + carryForwardYears/HistoryProvider
lib/core/constants/api_constants.dart                                                  + carryForward* endpoints
```

---

### Part 4: UI Polish Pass (3 rounds of follow-up design feedback)

**Round 1 — tab icons + "make it beautiful" pass.** Added compact icon+label tabs via a custom `_iconTab()` helper (`Tab(child: Row([Icon, SizedBox, Text]))`) — a horizontal icon-then-label layout rather than Material's default stacked icon-above-text, to stay compact across 4 scrollable tabs. Pulled the "icon-avatar box + colored shadow" card style already established in `holiday_calendar_screen.dart`'s stat cards (the most polished existing reference screen in this app) and applied it consistently across the restructured screen: the Leave Types tab's stat row, each of the 7 `_RuleSection` headers in the new rules tab (each given its own distinct semantic color — primary/warning/info/secondary/error/success — instead of one repeated primary-blue icon), and the Carry Forward tab's scope banner plus Preview-card and History-card headers.

**Round 2 — dropdown clarity + page heading + button cleanup.** User reported the Leave Type dropdown in the new rules tab wasn't clearly visible and asked for a page heading (matching the Leave Types tab's own subtitle pattern) plus cleaner Save/Discard buttons. Fixed the dropdown with an explicit `dropdownColor`/`elevation`/`borderRadius` so its open popup renders with correct contrast; each item now shows a small colored dot matching that leave type's own color plus a checkmark on the current selection (previously plain unlabeled text with no visual differentiation); the closed field always shows bold, high-contrast text via `selectedItemBuilder` regardless of popup styling. Added a subtitle heading above the leave-type selector card, copying the Leave Types tab's exact heading style/spacing. Restructured Save/Discard from buttons that scrolled away at the end of a long list into a pinned footer (`Column` → `Expanded(ListView)` + fixed `_PolicyFooter`), matching the app's already-established form-footer pattern (`AddEmployeeSheet`'s `_Footer`: top border divider, subdued secondary action + prominent primary action at 2:1 width).

**Round 3 — footer buttons still not legible.** Root cause, once looked at more carefully: the Discard button was a plain `OutlinedButton` with a very light border (`AppColors.border`, `#D3DAE8`) and a transparent fill sitting on a white (`AppColors.surface`) footer — technically present but visually near-invisible, which is exactly what "not looking good, can't see clearly" was describing. Fixed by giving it a solid tonal fill (`AppColors.backgroundMid`) instead of transparency, a stronger border (`AppColors.borderStrong`), and dark bold text/icon (`AppColors.textPrimary`) so it reads as an unmistakable, clearly-bounded button instead of relying on a faint outline against a same-toned background. The Save button got an explicit `foregroundColor`/`disabledBackgroundColor` and a subtle colored shadow for depth, plus bold text.

#### Files modified (this part only)
```
lib/features/settings/presentation/leave_policy/leave_policy_screen.dart
lib/features/settings/presentation/leave_policy/widgets/leave_policy_rules_tab.dart
lib/features/settings/presentation/leave_policy/widgets/leave_carry_forward_tab.dart
```

---

### Verification
- `dart analyze` run after every change across all four parts of this session: 0 errors throughout — only the same pre-existing `prefer_const_constructors`/`deprecated_member_use` info-level lints as the pre-session baseline, never regressed.
- `dart format` run on `leave_policy_rules_tab.dart` after the footer restructure, to normalize indentation left by the manual `Column`/`Expanded` edit.
- No on-device/APK verification performed this session — all changes verified via `dart analyze` only; the UI-clarity feedback in Part 4 was iterative in-chat design feedback (no screenshot shared), addressed by reasoning about actual color/contrast values (`AppColors.border` vs `AppColors.surface`, etc.) rather than a visual diff.

### Architecture Notes
- **A fields/validation audit is not the same as a screen-structure audit.** Checking that every backend field is editable *somewhere* on a screen can still miss that the screen's tab/navigation shape itself has drifted from the reference (web merged into one tab vs. mobile's two). Both need to be checked explicitly.
- **Verify a "feature looks broken on web" read by grepping the backend directly, not by re-reading the frontend more carefully.** Carry Forward's 4 endpoints and the Credit Rules accrual table were both confirmed to have zero backend support via `grep` of `apps/hrms/urls.py`/`models.py`. The two Employees false-positive gaps in Part 1 were caught the same way — reading `EmployeeDetailView.put`'s actual whitelisted-key list and `EmployeeDocumentView.post`'s `user=request.user` hardcoding directly, rather than inferring backend capability from what the web form merely *displays* as editable.
- **A plain `OutlinedButton` can be technically present but functionally invisible.** When a secondary-action button's transparent fill sits on a container that's the same light color as its border, the border is the only visual cue it's a button at all — and a low-contrast theme border color (`#D3DAE8` on white) isn't enough on its own. A solid tonal fill is a more robust default for secondary actions in this app's light, mostly-white surface palette than relying on an outline.
- **`Tab(icon: ..., text: ...)` stacks vertically by default** and eats real vertical space across a 4-tab `isScrollable: true` bar. A custom `Tab(child: Row([Icon, Text]))` keeps each tab compact when horizontal space is tight and icons are wanted inline rather than stacked.

### Pending Tasks (updated)
- [ ] Manual on-device visual pass of the restructured Leave Policy screen (all 4 tabs) — every fix this session was reasoned about from code-level color/contrast values, not confirmed against a running app or screenshot.
- [ ] Carry Forward tab will 404 against the real backend until `apps/hrms` grows the 4 missing routes + a `CarryForwardLog` model — flagged for the backend team, not a mobile-side fix.
- [ ] Manual on-device pass of all three new role dashboards (Employee/Admin/HR) (carried over from Session 20 — still not done).
- [ ] HR and Admin dashboards haven't had the same "match web pixel-for-pixel" scrutiny the Employee dashboard got in Session 20 Part 4 (carried over from Session 20).
- [ ] No dedicated onboarding-review screen exists in the app (carried over from Session 20).
- [ ] Confirm with whoever manages `royalhrms.nxsys.in`'s deployment that `DEBUG=True`/`ALLOWED_HOSTS=*` in production `.env` is intentional or needs tightening (carried over from Session 19 — not mobile's call to fix).
- [ ] Manual on-device dark-mode pass across every screen (carried over from Session 19 — still not done).
- [ ] Sweep the older `_friendly(e.toString())` error pattern to `parseDioException()`-style helpers across Leave/Expenses/Documents/Employees (carried over from Sessions 15–18 — still not done).
- [ ] `/onboarding/assessments` candidate-taking portal — still not ported (carried over from Session 17).
- [ ] Backend: `Holiday` model/API still doesn't exist for real — Holiday Calendar remains local-only mock state (carried over from Session 17).

---

## Session 22 — Payroll Removed & Rebuilt (Employee-Facing Only), Voice Commands (New), Attendance Approval Restructure, Bulk Import, Leave Preview/Balance Import, Employee Reporting Relationships & Documents, Email Branding

**Date:** 2026-07-27 → 2026-08-03 (spans commit `e558822` "payroll removed" plus a large batch of changes still uncommitted in the working tree at time of writing)
**Developer:** Pramod Kunja

> Note on how this entry was reconstructed: no chat log for this stretch of work was available to read directly. This entry was written by diffing `HEAD` (`e558822`) against its parent and against the current uncommitted working tree, and reading the changed files in full — the same standard this journal has always held itself to (read the actual backend/model code, not just infer from screen behavior). Flag anything below that doesn't match your own memory of the work and it can be corrected.

### Module Worked On
- Payroll — old fully-mocked admin module (dashboard, Run Payroll wizard, Payroll Rules settings) deleted; a new, real-API "My Payslips" employee screen built in its place
- Settings — Company — new Financial Year section (org-wide FY start month, feeds Leave/Attendance/Payroll/Reports year math)
- Voice Commands — brand-new, app-wide voice assistant feature (speech-to-text → backend intent parsing → TTS/UI response), plus a typed-command fallback and a draggable mic bubble added on top
- Approvals — Attendance Approval tab rebuilt (payroll-cycle sign-off, not per-punch corrections) and then reworked again from single L1/L2 approver to per-manager multi-signoff; Team Approvals gained a third request type (Attendance Corrections) and a real team-scope bug fix
- Attendance — HR correction requests upgraded from single-stage to a two-stage Manager (L1) → HR (L2) approval chain, with the card extracted into a shared widget
- Bulk Import — new Employees and Candidates CSV/XLSX bulk-create flows, sharing one result model/widget, entered via a new expandable FAB
- Leave — server-side, holiday-aware Leave Preview wired into Apply Leave; new Leave Opening Balance & History bulk-import screen; department filter added to Team Approvals' leave queries; misc fixes
- Employees — Reporting Relationships quick-edit, HR-side document upload, new personal-detail fields, permission-based (not role-hardcoded) edit gating
- Settings — Email Templates — data-driven categories with inline creation, rich-text toolbar, pending-attachment support on create, live variable-chip detection, plus a new Email Branding card
- Expenses — tap-to-open expense detail dialog
- Misc — Employee dashboard "My Workspace" console compacted; `canManageTeam` field added to the user model (plumbing only, not yet consumed anywhere)

---

### Part 1: Payroll — Mock Admin Module Removed, Employee-Facing "My Payslips" Rebuilt

Commit `e558822` deleted four screens that had never been wired to any backend: `payroll_screen.dart` (1957 lines, admin payroll-run dashboard), `run_payroll_screen.dart` (1995 lines, an 8-step Run Payroll wizard), `my_payslip_screen.dart` (1026 lines, the original mock payslip view), and `settings/presentation/payroll_rules/payroll_rules_screen.dart` (1163 lines, earning/deduction component settings). All four were built entirely from hardcoded in-memory sample data (`_PayrollRun`, `_EmpPayroll`, a fixed 5-employee list, etc.) with zero API calls — confirmed by reading the deleted code and by the new replacement screen's own doc comment, which explicitly contrasts itself with "the original mock this replaced (hardcoded demo months/amounts, zero API calls)".

In its place, a narrower, real-API rebuild now exists at `mobile_app/lib/features/payroll/` — data + presentation layers only (no domain layer, following the same lighter pattern `expenses` uses rather than `leave`'s full Clean Architecture split):
- `data/datasources/payroll_remote_datasource.dart` — `fetchMyPayslips()` (`GET /payroll/my-payslips/`, handles both a raw list and a paginated `{results: []}` envelope) and `acknowledgePayslip(id)` (`POST /payroll/my-payslips/{id}/acknowledge/`).
- `data/models/payslip_model.dart` — `PayslipModel` mirroring the backend's `EmployeePayslipSerializer` (cycle dates, basic/HRA/special-allowance/other-earnings/reimbursements/bonus/gross, working/LOP days, PF/ESI/PT/LWF/total deductions, net pay, status, a payslip-PDF URL that's always null today since no backend view populates that field yet), with defensive Decimal-as-string parsing and a hand-copied status-label map (`draft/sent/acknowledged/queried/resolved/paid`, since no endpoint returns display labels).
- `presentation/providers/payroll_providers.dart` — `myPayslipsProvider` (`AsyncNotifierProvider.autoDispose`) with `refresh()` and an optimistic `acknowledge(id)`.
- `presentation/screens/my_payslip_screen.dart` (659 lines) — month-selector strip + detail card: company name/CIN, employee meta (name/ID/department/masked bank account/IFSC), working/paid/LOP-day stats, earnings/deductions breakdowns, a reimbursements line when nonzero, a gradient Net Pay banner with an earnings-vs-deductions ratio bar, an "Open PDF" button (dead today, gated on the always-null PDF URL), and an "Acknowledge Payslip" button shown only when status is `sent`. The screen's own doc comment lists three things deliberately left out because the backend doesn't support them yet: PAN/UAN, a TDS/Loan-EMI deduction line, and per-category reimbursement breakdown.

Fully wired, not orphaned: `app_router.dart` adds `AppRoutes.myPayslips = '/dashboard/my-payslip'` and a `GoRoute` to `MyPayslipScreen`; `nav_config.dart` adds a "My Payslips" nav item under the "My" section, gated on `permission: null` (visibility left purely to the backend's `payroll.view_own` permission, matching the existing My Attendance pattern and web's `navConfig.ts`). One loose end: `ApiConstants.payslipDetail(id)` (`/payroll/payslips/{id}/`) was added but is never called anywhere — likely staged for a future per-payslip deep-link view. The old admin-facing Run Payroll wizard and Payroll Rules settings have **not** been rebuilt at all as of this entry.

**Financial Year section (Company settings), added in the same commit.** `mobile_app/lib/features/settings/presentation/company/widgets/financial_year_section.dart` is a new card wired into `company_screen.dart` right after the logo block. It reads/writes `GET`/`PUT` `/settings/company/financial-year/` via a new `financialYearProvider`, shows an editable "Financial Year Starts In" month dropdown (edit gated to `system_admin`, both client- and server-side) plus three read-only chips (Previous/Current/Next Financial Year computed server-side from the start month). Its own intro text spells out why this exists: one shared setting that Leave Allocation, Carry Forward, Attendance, Payroll, and Reports all key their year math off, replacing an assumed Jan–Dec calendar year.

#### Files deleted
```
lib/features/payroll/presentation/screens/payroll_screen.dart
lib/features/payroll/presentation/screens/run_payroll_screen.dart
lib/features/payroll/presentation/screens/my_payslip_screen.dart (original mock version)
lib/features/settings/presentation/payroll_rules/payroll_rules_screen.dart
```

#### Files created
```
lib/features/payroll/data/datasources/payroll_remote_datasource.dart
lib/features/payroll/data/models/payslip_model.dart
lib/features/payroll/presentation/providers/payroll_providers.dart
lib/features/payroll/presentation/screens/my_payslip_screen.dart (rebuilt, real API)
lib/features/settings/presentation/company/widgets/financial_year_section.dart
```

#### Files modified
```
lib/core/router/app_router.dart                 AppRoutes.myPayslips + GoRoute
lib/features/dashboard/presentation/navigation/nav_config.dart   "My Payslips" nav item
lib/features/dashboard/presentation/widgets/quick_access.dart    "My Payslips" quick-access tile
lib/core/constants/api_constants.dart            myPayslips, acknowledgePayslip(id), payslipDetail(id) — unused
lib/features/settings/presentation/company/company_screen.dart  + FinancialYearSection
lib/features/settings/presentation/providers/settings_providers.dart  + financialYearProvider
```

---

### Part 2: Voice Commands — New App-Wide Voice Assistant

An entirely new feature, `mobile_app/lib/features/voice_commands/`. A user taps a floating mic bubble, speaks a command in natural language, and the backend (`POST /voice/parse/`, `apps/voice_commands` — a single endpoint, intent list lives server-side in `registry/intents_en.yaml`) parses it into an intent, executes it, and returns a message that's spoken back via TTS and shown in a floating conversation panel. All intent understanding happens server-side, one HTTP round trip per turn — the client only does speech-to-text (`speech_to_text: ^7.0.0`) and text-to-speech (`flutter_tts: ^4.2.2`, both added to `pubspec.yaml` in this same commit; `geolocator` was already present and is reused, not new).

**Clean-architecture layering:** `domain/entities/voice_result_entity.dart` (`VoiceResultEntity`: intent, confidence, result payload, message, conversational, awaitingInput, success — deliberately mirrors `backend/apps/voice_commands/conversation.py::_payload()` and the web app's own `VoiceParseResult` type) → `domain/repositories/voice_repository.dart` → `data/models/voice_result_model.dart` / `data/datasources/voice_remote_datasource.dart` / `data/repositories/voice_repository_impl.dart` (thin Dio passthrough) → `presentation/providers/voice_providers.dart`. `presentation/providers/voice_mute_provider.dart` persists a TTS mute toggle to secure storage.

**Conversation orchestration — `presentation/controllers/voice_command_controller.dart`** (a `Notifier<VoiceConversationState?>`, null = idle): `startListening()` initializes `speech_to_text`, stops any playing TTS first (so the mic doesn't hear its own confirmation), and listens for up to 60s with a 5s silence auto-stop. On stop, `submitTranscript()` calls the backend; if the result is a `clock_in`/`clock_out` rejected by the exact geofencing-rejection message the backend uses (voice never collects GPS up front), the controller silently fetches the device location and resubmits the identical transcript once with lat/long attached, sparing the user a repeat. `conversational` (a property of the intent itself — true for apply/approve/reject-leave on every turn) and `success` (did *this* turn's action work) are tracked as independent flags, matching the backend's own multi-turn design (conversation state lives server-side in Redis with a 120s TTL; the client just tracks a boolean `awaitingInput`).

**UI:** `presentation/widgets/voice_conversation_panel.dart` (phase-driven: listening → transcript → result, explicitly mirroring `frontend/hooks/useVoiceCommand.ts` / `VoiceConversationPanel.tsx`) and `presentation/widgets/voice_mic_overlay.dart`, mounted once in `app.dart`'s `MaterialApp.router` builder (inside its own nested `Overlay`, since tooltips need an `Overlay.of(context)` ancestor and this Stack sits outside the Navigator's own overlay) — so the mic is available on every authenticated screen, not one shell route. It hides itself when logged out, mid-onboarding, awaiting HR approval, or while any screen's own expandable FAB is open.

**Uncommitted follow-up work on top of the original commit** added two more things:
1. **A typed-command entry point.** A small keyboard-icon badge next to the mic bubble opens a new `VoicePanelPhase.typing` state (a plain text field + send button) — same backend call as speaking, just a different way to compose the transcript. Not to be confused with `submitTypedAnswer`, which answers a follow-up question mid-conversation.
2. **A draggable mic bubble.** `voice_mic_overlay.dart` was reworked so the idle bubble still *starts* in its default corner (above a screen's own FAB when one exists, via `AppRoutes.screensWithFab`), but is now user-draggable anywhere on screen via a new `_DraggableMicBubble` widget that owns the drag gesture and clamped position entirely on its own (so a drag only rebuilds that small subtree, not the parent's provider watches — keeps dragging smooth). The dragged position persists across every screen (the widget is never rebuilt on route change) until dragged again.
3. **`PayslipSummaryCard`** (`presentation/widgets/payslip_summary_card.dart`, new, untracked) — when a voice response's `result` payload matches a recognized payslip shape (`check_my_payslip` returns the payslip dict directly; `check_employee_payslip` nests it under `result.payslip` with the target name under `result.matched.employee_name`), the conversation panel now renders a compact card underneath the spoken message: subject name, status chip, period-ending date, gross/deductions/net-pay rows. `VoiceConversationState` gained a `dynamic result` field to carry the raw payload through for this without the controller needing to know about any specific intent.

#### Files created
```
lib/features/voice_commands/domain/entities/voice_result_entity.dart
lib/features/voice_commands/domain/repositories/voice_repository.dart
lib/features/voice_commands/data/models/voice_result_model.dart
lib/features/voice_commands/data/datasources/voice_remote_datasource.dart
lib/features/voice_commands/data/repositories/voice_repository_impl.dart
lib/features/voice_commands/presentation/providers/voice_providers.dart
lib/features/voice_commands/presentation/providers/voice_mute_provider.dart
lib/features/voice_commands/presentation/state/voice_conversation_state.dart
lib/features/voice_commands/presentation/controllers/voice_command_controller.dart
lib/features/voice_commands/presentation/widgets/voice_conversation_panel.dart
lib/features/voice_commands/presentation/widgets/voice_mic_overlay.dart
lib/features/voice_commands/presentation/widgets/payslip_summary_card.dart   (new, uncommitted)
```

#### Files modified
```
lib/app/app.dart                       mounts VoiceMicOverlay above the Navigator
lib/core/constants/api_constants.dart  voiceParse
mobile_app/pubspec.yaml                + speech_to_text, flutter_tts
```

---

### Part 3: Attendance Approval — Rebuilt Twice Over (Payroll-Cycle Sign-off, Then Per-Manager Multi-Signoff)

**What it is, concretely:** a payroll-cycle attendance sign-off — once a payroll cycle closes, its aggregate attendance (present/late/absent/half-day/LOP counts per employee) needs manager (L1) then HR (L2) sign-off before payroll can run. This is a distinct flow from "Attendance Correction" (an individual employee disputing one day's clock-in/out — see Part 3b).

**Why `my_requests_tab.dart` (529 lines) was deleted:** per a doc comment in `approvals_screen.dart`, this ports web's own 2026-07-21 change — web dropped its "My Requests" tab from Approvals because a standalone `/dashboard/my-requests` page already covers self-service leave/expense creation, making the duplicate tab redundant; mobile's equivalent self-service already lives in the Leave and Expenses modules.

**First rebuild (committed):** a new `attendance_approval_tab.dart` (409 lines) plus `attendance_approval_remote_datasource.dart`, `attendance_approval_models.dart` (`PayrollCycleModel`, `CycleAttendanceSummary`, `AttendanceSummaryRow`, `EmployeeDailyAttendance`), and `attendance_approval_providers.dart`, hitting `/payroll/cycles/pending-approval/`, `/payroll/cycles/{id}/attendance-summary/`, `/payroll/cycles/{id}/approve-attendance/`, and a per-employee daily-attendance endpoint — the same payroll-cycle endpoints the now-deleted admin Payroll module used, since attendance sign-off is gated on payroll cycles server-side regardless of whether mobile has an admin payroll UI. `approvals_screen.dart` was reduced to two tabs (Team Approvals, Attendance Approval).

**Second rework (uncommitted, on top):** the model shifted from a single L1/L2 approver to **per-manager multi-signoff** — `PayrollCycleModel` gained `managerApprovals` (a list of `ManagerApprovalRow`: id, name, approved-at), `mgrApprovedCount`/`mgrTotalCount`/`mgrAllApproved`, and `currentUserPending`; the old `l1ApproverName`/`l2ApprovedAt` fields are now documented as legacy fields only populated once *every* manager has signed off. `attendance_approval_tab.dart` now shows a progress bar and a `Wrap` of per-manager pill chips instead of a single approval-status row, and the "can I approve L1" gate changed from a hardcoded role check to a backend-computed `cycle.currentUserPending && !l1Done` flag — a manager sees the Approve button only if their own row says they're pending, not because their role matches a static list. Also fixed a missing "Half Day" stat badge and reordered "On Leave" before Absent/Incomplete.

**Team Approvals — a real bug fix and a new request type, same uncommitted pass:**
- Bug fix in `approvals_providers.dart`: `pendingLeaveApprovalsProvider` now passes `scope: 'team'` to `getLeaveRequests()`. Without it, the backend silently returned the *caller's own* leave requests regardless of role — the Team Approvals leave queue looked broken/empty for any manager/HR whose own request list happened to be empty.
- New: `ApprovalsRequestType.attendanceCorrection`, `teamCorrectionsStatusFilterProvider`, `teamCorrectionsProvider` — a third toggle in `team_approvals_tab.dart` (alongside Leave/Expense) for reviewing individual clock-in/out correction requests, hitting `/attendance/corrections/` and `/attendance/corrections/{id}/review/`. `approvals_screen.dart`'s tab-visibility logic now also checks `canApproveCorrections` (gated on `attendance.view`) and `canApproveAttendance` now reads a new `user.canManageTeam` flag OR (payroll permission AND not HR) — a comment notes HR's own attendance sign-off moved specifically to Leave Management.
- `team_approvals_tab.dart`'s leave-request card gained an employee-code line, an "Applied {date}" timestamp, and a status badge distinguishing "Pending Manager Approval" vs "Pending HR Approval" (the underlying provider mixes both stages in one list).

**Note:** this pass depends on two adjacent, also-uncommitted files outside `approvals/`: `auth/domain/entities/user_entity.dart` / `data/models/user_model.dart` (new `canManageTeam` field — see Part 8, this is plumbing-only elsewhere) and a brand-new `attendance/presentation/widgets/hr_correction_card.dart` (see Part 3b).

### Part 3b: Attendance — HR Corrections Become a Two-Stage (Manager → HR) Approval Chain

`HrCorrectionRowEntity`/`HrCorrectionModel` (in `attendance_entity.dart`/`attendance_models.dart`) gained `l1ApproverName`/`l1Status`/`l1Remarks`, `l2ApproverName`/`l2Status`/`l2Remarks`, and a server-computed `canAction` bool, turning a single-stage pending/approved/rejected correction request into a Manager (L1) → HR (L2) chain. A real JSON-key bug was fixed alongside it: `requestedInTime`/`requestedOutTime` were reading the wrong keys (`requested_in_time`/`requested_out_time` instead of the backend's actual `requested_in`/`requested_out`). The correction card itself was extracted out of `attendance_screen.dart` into a new standalone `presentation/widgets/hr_correction_card.dart` — its own doc comment explains it's now shared between the Attendance screen's own "Correction Requests" inbox and the Approvals screen's Team Approvals tab (Part 3), so it takes a plain `onReview` callback instead of reading a provider directly. It now renders per-stage status lines and an "Awaiting {name}" hint when the current viewer isn't the actor for the current stage. The attendance screen's status filter was updated from Pending/Approved/Rejected to Pending–Manager / Pending–HR / Approved/Rejected.

#### Files created
```
lib/features/approvals/data/datasources/attendance_approval_remote_datasource.dart
lib/features/approvals/data/models/attendance_approval_models.dart
lib/features/approvals/presentation/providers/attendance_approval_providers.dart
lib/features/approvals/presentation/widgets/attendance_approval_tab.dart
lib/features/attendance/presentation/widgets/hr_correction_card.dart
```

#### Files deleted
```
lib/features/approvals/presentation/widgets/my_requests_tab.dart
```

#### Files modified
```
lib/features/approvals/presentation/screens/approvals_screen.dart
lib/features/approvals/presentation/providers/approvals_providers.dart
lib/features/approvals/presentation/widgets/team_approvals_tab.dart
lib/features/attendance/data/models/attendance_models.dart
lib/features/attendance/domain/entities/attendance_entity.dart
lib/features/attendance/presentation/screens/attendance_screen.dart
lib/features/auth/data/models/user_model.dart              + canManageTeam (unconsumed elsewhere)
lib/features/auth/domain/entities/user_entity.dart          + canManageTeam
```

---

### Part 4: Bulk Import — Employees & Candidates

New CSV/XLSX bulk-create flows for both Employees and Interview List candidates, replacing one-by-one entry via the Add sheet for large batches:
- **Employees** — required columns: `first_name, last_name, email, role, department, designation, branch, date_of_joining`; optional: `phone, employee_type, gender, date_of_birth, blood_group, address`. Existing emails are skipped, not failed, so a corrected file can be safely re-uploaded.
- **Candidates** — required: `name, email, position_applied, branch_name`; optional: `phone, interview_date, interview_mode, notes`. `branch_name` must exactly match an existing branch name or code — branches are never auto-created.

Both share one result contract: `mobile_app/lib/shared/models/bulk_import_result.dart` (`BulkImportResult`: totalRows/created/skipped/failed plus per-row detail lists), deliberately shaped to match both Django views (`EmployeeBulkImportView`/`CandidateBulkImportView`) so one model parses both, and one shared `mobile_app/lib/shared/widgets/bulk_import_result_view.dart` (four stat chips + three collapsible per-row-detail sections). `EmployeeBulkImportScreen` and `CandidateBulkImportScreen` are structurally near-identical: file-picker card → required/optional-columns info card → Import button → the shared result view.

Both screens are entered via a new reusable `mobile_app/lib/shared/widgets/expandable_fab.dart` — a FAB that expands into a small labeled action stack (rotating its `+` icon 45°), wired as the `floatingActionButton` on both `employees_screen.dart` and `interview_list_screen.dart` with an "Add single" and a "Bulk import" action each. It exposes a shared `expandableFabOpenProvider` so the global Voice Commands mic overlay (Part 2) can step aside while any screen's FAB is expanded.

#### Files created
```
lib/features/employees/presentation/screens/employee_bulk_import_screen.dart
lib/features/interview_list/presentation/screens/candidate_bulk_import_screen.dart
lib/shared/models/bulk_import_result.dart
lib/shared/widgets/bulk_import_result_view.dart
lib/shared/widgets/expandable_fab.dart
```

#### Files modified
```
lib/features/employees/presentation/employees_screen.dart          + expandable FAB
lib/features/interview_list/presentation/screens/interview_list_screen.dart   + expandable FAB
lib/core/router/app_router.dart     AppRoutes.employeeBulkImport, candidateBulkImport
```

---

### Part 5: Leave — Server-Side Preview, Opening Balance & History Bulk Import, Team Department Filter

**Leave Preview (Apply Leave tab).** `apply_leave_tab.dart` now calls a `leavePreviewProvider` (server-side, holiday-aware day-count/LOP calculation) once a leave type and full date range are selected, and prefers its result over the pre-existing local `_workingDays()` estimate whenever it has loaded — because the local calculation excludes weekends but not company holidays, which the server-side preview does account for. The form still falls back to the local estimate while the request is in flight or on error, so it never blocks on this endpoint's availability. A new `_PreviewBreakdownNote` surfaces the preview's holiday/week-off exclusion counts and any policy warning (e.g. a max-consecutive-days-with-LOP rule) so the day count shown isn't a mystery.

**Leave Opening Balance & History bulk import (new).** A one-time historical-migration tool at `mobile_app/lib/features/settings/presentation/leave_policy/leave_balance_import_screen.dart` (662 lines, reached via an "Import Opening Balances" icon button on the Leave Policy screen's app bar, routed at `/settings/leave-policy/import-balances`). Backed by new `mobile_app/lib/features/settings/data/models/leave_import_model.dart`: a two-step validate-then-import flow against `LeaveOpeningBalanceValidateView`/`LeaveOpeningBalanceImportView` — each uploaded row is either a "balance" row (annual totals per employee/leave-type/financial-year) or a "history" row (individual leave dates), with per-row validity/error reporting in the preview step and a downloadable error-report CSV if the final import has failures. This is a distinct feature from Part 4's Employee/Candidate bulk import (different backend, different purpose — migrating in historical leave data, not creating new employee/candidate records).

**Team Approvals — department filter.** `fetchLeaveRequestsPage()` gained an optional `department` param (branch filtering is `system_admin`-only server-side; department only needs `leave.approve`), threaded through the repository and a new `LeaveTeamFilter` typedef (`({String branch, String department})`) replacing the old plain `String branch` provider key. `leave_approvals_tab.dart` adds a department dropdown gated to `system_admin`/`hr`/`hr_admin` (matching web's `canFilterDept`); `leave_dashboard_tab.dart` deliberately never applies one, per a comment noting web's own Dashboard has no such filter either, but still had to adopt the new `LeaveTeamFilter` record shape. Role-alias handling in `_scopeLabel()` was also tightened to treat `manager`/`manager__team_lead` and `hr`/`hr_admin` as equivalent.

**Smaller fixes, same pass:**
- `LeaveRequestModel`/`LeaveRequestEntity` gained an `employeeCode` field.
- `leave_screen.dart`'s `_BranchSheet` was converted from a plain `StatefulWidget` reading a one-time `ref.read()` snapshot of `branchListProvider` to a `ConsumerStatefulWidget` that watches it live — previously, opening the sheet while the (autoDispose) branch fetch was still in flight could permanently show "No branches loaded" since nothing else kept that provider warm.
- `FormValidators` (shared) gained candidate name/position/phone validators + an interview-date-not-in-the-past check (mirroring `backend/apps/recruitment/serializers.py`'s regexes exactly, for Add/Edit Candidate) and a leave-type-name validator (mirroring `apps/hrms/serializers.py`).

#### Files created
```
lib/features/settings/data/models/leave_import_model.dart
lib/features/settings/presentation/leave_policy/leave_balance_import_screen.dart
```

#### Files modified
```
lib/features/leave/presentation/widgets/apply_leave_tab.dart
lib/features/leave/presentation/widgets/leave_approvals_tab.dart
lib/features/leave/presentation/widgets/leave_dashboard_tab.dart
lib/features/leave/presentation/screens/leave_screen.dart
lib/features/leave/data/datasources/leave_remote_datasource.dart
lib/features/leave/data/models/leave_models.dart
lib/features/leave/data/repositories/leave_repository_impl.dart
lib/features/leave/domain/entities/leave_entity.dart
lib/features/leave/domain/repositories/leave_repository.dart
lib/features/leave/presentation/providers/leave_providers.dart
lib/features/settings/presentation/leave_policy/leave_policy_screen.dart   + Import Opening Balances button
lib/shared/validators/form_validators.dart
lib/core/router/app_router.dart    AppRoutes.settingsLeaveBalanceImport
```

---

### Part 6: Employees — Reporting Relationships, Document Upload, New Personal Fields, Permission-Based Gating

Three coherent additions to `employee_profile_screen.dart` / `add_employee_sheet.dart` / the employees data layer:
1. **New personal fields** — `gender`, `maritalStatus`, `fatherName`, `bloodGroup`, `currentAddress`, `permanentAddress` added to `EmployeeModel`/`EmployeeUpdateFormData`, with matching dropdowns/multiline fields in `add_employee_sheet.dart`.
2. **Reporting Relationships quick-edit** — a new `_ReportingRelationshipsCard`/`_RelationshipEditDialog` on the Approval Matrix tab, backed by new `patchReportingManager()`/`patchHr()` datasource calls against new endpoints `employeeReportingManager(id)`/`employeeHrAssign(id)`.
3. **Document upload** — a full flow on the Documents tab: `uploadEmployeeDocument()` (multipart POST, 5MB cap, PDF/JPG/PNG) against a new `employeeDocuments(id)` endpoint (distinct from the self-service onboarding upload endpoint), a document-type picker sheet, and a "Replace" action on each existing document card.

Also, the edit-permission gate for both the Reporting Relationships card and the Approval Matrix Override action was changed from a hardcoded role check (`role == 'hr_admin' || 'system_admin'`) to `hasPermission('settings.edit')` — a comment notes role slugs aren't a stable contract but permission codenames are. Profile tab read-only fields (Employee ID, Phone, Reporting Manager, HR Contact, Work Email) now render with a visually "locked" tint.

#### Files modified
```
lib/features/employees/data/datasources/employees_remote_datasource.dart
lib/features/employees/data/models/employee_model.dart
lib/features/employees/presentation/providers/employee_providers.dart
lib/features/employees/presentation/screens/employee_profile_screen.dart
lib/features/employees/presentation/widgets/add_employee_sheet.dart
lib/core/constants/api_constants.dart   employeeReportingManager(id), employeeHrAssign(id), employeeDocuments(id)
```

---

### Part 7: Settings — Email Templates: Data-Driven Categories, Rich-Text Toolbar, Email Branding Card

`template_editor_sheet.dart` gained: a data-driven category dropdown (`emailTemplateCategoriesProvider`-backed, with an inline "create new category" option via a new `createEmailTemplateCategory()` call) replacing a hardcoded type list (kept only as a loading/error fallback); a live `{VARIABLE}` tag auto-detector scanning subject+body so variable chips populate in both add and edit mode (previously edit-only); a basic rich-text toolbar (Bold/Italic/Underline/Bullet-list/Link, wraps selected text in HTML tags); and support for attaching files before a new template exists (queued locally, uploaded one-by-one right after creation, since the create endpoint itself doesn't accept files). `EmailTemplateFormData` gained an `availableVariables` list and slug validation.

A new, separate `email_branding_card.dart` now renders at the top of the Email Templates screen — shows the company logo/name/website/address wrapped around outgoing emails, with a full edit sheet reusing the existing `companyProvider` for logo upload and company-info fields.

#### Files created
```
lib/features/settings/presentation/email_templates/widgets/email_branding_card.dart
```

#### Files modified
```
lib/features/settings/data/datasources/settings_remote_datasource.dart
lib/features/settings/data/models/email_template_model.dart
lib/features/settings/presentation/email_templates/email_templates_screen.dart
lib/features/settings/presentation/email_templates/widgets/template_editor_sheet.dart
lib/features/settings/presentation/providers/settings_providers.dart
```

---

### Part 8: Misc — Expense Detail Dialog, Employee Dashboard Console Compaction, Announcement Sheet Fix

**Expense detail dialog (new).** `expense_list_item.dart` was wrapped in `Material`/`InkWell` so tapping an expense row now opens a new `expense_detail_dialog.dart` — full detail view (status badge, amount/category, employee/branch, description, tappable receipts via `url_launcher`) that shows already-known row data immediately, then refreshes via a new `expenseDetailProvider(expenseNumber)` (`GET /expenses/{expense_number}/`).

**Employee dashboard console compaction.** `employee_dashboard_view.dart`'s "My Workspace" card was reworked per an inline comment noting the old version stacked a header, clock button, a separate correction-request line, a two-row KPI grid, and a third section repeating the same clock in/out times. Merged into one `_ConsoleClockRow` + a single-row `_ConsoleKpiRow`; wrapped the clock button in `IntrinsicWidth` to fix a `Row`-gives-unbounded-width crash; bumped the leave-balance grid's `mainAxisExtent` 96→104 to stop a 6px overflow when a balance shows a "used" line.

**Announcement sheet.** `post_announcement_sheet.dart`'s scrollable body was wrapped in `Flexible` (previously unwrapped directly in the outer `Column`) — a small overflow-safety fix, not a feature change.

**`canManageTeam` on the user model.** A new boolean field (`can_manage_team`) was added to `UserModel`/`UserEntity` (see Part 3) but is not yet read anywhere else in the app — plumbing only, consumed so far only by the Attendance Approval tab-visibility gate.

#### Files created
```
lib/features/expenses/presentation/widgets/expense_detail_dialog.dart
```

#### Files modified
```
lib/features/expenses/presentation/widgets/expense_list_item.dart
lib/features/expenses/presentation/providers/expense_providers.dart
lib/features/expenses/data/datasources/expense_remote_datasource.dart
lib/features/dashboard/presentation/screens/employee_dashboard_view.dart
lib/features/announcements/presentation/widgets/post_announcement_sheet.dart
```

---

### Verification
- `dart analyze lib` (run against the current working tree while writing this entry): **0 errors, 0 warnings** — 84 info-level lints, all pre-existing `prefer_const_constructors`/`deprecated_member_use` style suggestions, none newly introduced.
- No on-device/APK build verification was performed while writing this entry — it's a documentation-only pass reconstructing what changed; the actual coding work should already have been verified at the time it was written (see the caveat at the top of this session).

### Architecture Notes
- **A journal entry reconstructed from diffs instead of chat history is still worth writing carefully** — reading full deleted/added files (not just diff stats) surfaced real distinctions a stat-only summary would have flattened: e.g. Attendance Approval (payroll-cycle sign-off) vs Attendance Correction (per-punch dispute) vs Leave team approvals are three different approval flows that all happen to converge on the same "Team Approvals" screen.
- **This app now has two independent bulk-import subsystems** that look superficially similar (both: pick file → validate/preview → import → shared result reporting) but serve different purposes and hit different backends: Employee/Candidate bulk-CREATE (`shared/models/bulk_import_result.dart`) vs Leave Opening-Balance/History bulk-MIGRATE (`leave_import_model.dart`, its own two-step validate/import pair). Don't assume one's result contract fits the other if either grows further.
- **The old mock Payroll module's removal is a net scope reduction, not yet a full replacement** — only the employee-facing "view my payslip" slice was rebuilt against a real API; an admin Run Payroll wizard and Payroll Rules settings screen do not exist in the app at all right now, unlike before this session's changes.
- **Voice Commands intentionally keeps zero intent-parsing logic on the client** — every "what can I say" question is answered server-side (`registry/intents_en.yaml`), and the client's only job is turning speech into text, forwarding it, and rendering whatever comes back. This means adding a new voice-capable action never requires a mobile release on its own, unless the response needs a new bespoke result-card renderer like `PayslipSummaryCard`.

### Pending Tasks (updated)
- [ ] Confirm with whoever committed this batch of work whether the uncommitted working-tree changes described in this entry (everything not part of `e558822`) are ready to commit, or still mid-edit — this entry was written directly against the live working tree, which may keep changing after this was written.
- [ ] Payroll: no admin-facing Run Payroll wizard or Payroll Rules settings screen exists yet — only "My Payslips" was rebuilt (new gap, this session).
- [ ] Payroll: `ApiConstants.payslipDetail(id)` is defined but never called — either wire it to a per-payslip detail view or remove it (new, this session).
- [ ] `canManageTeam` on the user model is unused outside the Attendance Approval gate — confirm this is intentional scope, not a half-finished wiring pass (new, this session).
- [ ] No manual on-device pass of Voice Commands, the reworked Attendance Approval multi-signoff UI, Bulk Import, or the Leave Balance Import screen — all verified via `dart analyze` and code reading only in this entry (new, this session).
- [ ] Manual on-device pass of all three role dashboards (Employee/Admin/HR) (carried over from Session 20 — still not done).
- [ ] No dedicated onboarding-review screen exists in the app (carried over from Session 20).
- [ ] Manual on-device dark-mode pass across every screen (carried over from Session 19 — still not done).
- [ ] Sweep the older `_friendly(e.toString())` error pattern to `parseDioException()`-style helpers across Leave/Expenses/Documents/Employees (carried over from Sessions 15–18 — still not done).
- [ ] `/onboarding/assessments` candidate-taking portal — still not ported (carried over from Session 17).
- [ ] Backend: `Holiday` model/API still doesn't exist for real — Holiday Calendar remains local-only mock state (carried over from Session 17).

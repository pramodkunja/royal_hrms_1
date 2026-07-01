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

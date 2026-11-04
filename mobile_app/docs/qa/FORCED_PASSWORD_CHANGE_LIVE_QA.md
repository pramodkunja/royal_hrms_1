# Forced Password Change: Live QA

**Date:** 2026-11-02
**Scope:** `must_change_password` enforcement and the voice assistant restriction (Task 1)

## Environment

- **App version:** 1.0.0+5 (`com.royalhrms.app`), arm64 debug build installed 2026-11-02 15:29
- **Android device/emulator:** `emulator-5554`, sdk_gphone64_arm64, Android 14 (API 34)
- **API environment:** production (`ApiConfig.current = Environment.production`). The device can reach the network.
- **Target account (masked):** `t***@gmail.com`, Employee role, demo company

## Results

| Test | Result | Evidence |
|---|---|---|
| Login redirect | BLOCKED | The account is not flagged (see Remaining blockers) |
| Back-navigation restriction | BLOCKED | Not run live; covered by an automated test |
| Microphone hidden | BLOCKED | Not run live; covered by an automated test |
| Typed commands blocked | BLOCKED | Not run live; covered by an automated test |
| Password validation | BLOCKED | Not run live; covered by an automated test |
| Successful password change | BLOCKED | Not run live; covered by an automated test |
| Session cleared | BLOCKED | Not run live; covered by an automated test |
| Fresh login | BLOCKED | Not run live; covered by an automated test |
| Voice Assistant restored | BLOCKED | For the flagged-then-cleared case. For an unflagged employee the voice assistant was verified live earlier on 2026-11-02 (Leave Balance returned correct figures). |
| Regression tests | PASS | `flutter test`: 104/104. The three focused files (forced password flow, auth redirect, voice access): 31/31. |
| Flutter analyze | PASS | 13 info messages, all pre-existing (`curly_braces_in_flow_control_structures`). No new issues. |

### Implementation review (code inspection)

| Requirement | Where it is handled |
|---|---|
| Login response reads `must_change_password` | `UserModel.fromJson`: boolean; absent or null is treated as false. The flag survives the cached-session round trip. |
| Flagged users are redirected; other screens are blocked | `resolveAuthRedirect` in `lib/core/router/app_router.dart` sends every path except `/change-password` and the splash screen to `/change-password`. |
| Back navigation cannot bypass | `PopScope(canPop: false)` in `force_change_password_screen.dart`. A pop is also redirected by the router. |
| Microphone hidden | `voice_mic_overlay.dart` watches `voiceAssistantAllowedProvider`. |
| Typed commands blocked | `voice_command_controller.dart`: `_ensureAllowed()` guards `openTypedCommand`. |
| Controller entry points protected | `_ensureAllowed()` also guards `startListening`, `_performSubmit` and `_attemptSilentFallback`. |
| Success clears local auth state | `_submit` calls `AuthNotifier.logout()`, which calls `clearSession()`. That clears secure storage and deletes the cookie jar entries for the API host. |
| The password is not kept | Fields are cleared on success. The login pre-fill holds only the company code, the email and a notice. |
| Fresh login gives normal access | The router allows the dashboard only when the new login response reports the flag as false. If it is still true, the user is sent back. |

## Issues discovered

None in the forced-password or voice-restriction code.

## Changes made

None for this verification. The only file added is this report.

## Remaining blockers

1. **The target account is not flagged.** On 2026-11-02, at about 15:10 and again at 15:31, this account signed in on this build and landed directly on the Employee Workspace. A flagged account is redirected to Change Password on this build, so the flag was false then. Its current state was not re-checked: doing so needs either an approved admin inspection method or the account's password. This QA brief forbids taking that password from the demo credentials, and no other source was provided.
2. **No authorization or temporary credentials.** No administrator has confirmed enabling the flag, and no temporary password has been supplied through an approved channel.
3. **Account choice.** The target is also the shared "employee" demo account. Completing Test D changes its password, which affects everyone who uses that demo login. A dedicated disposable account is the safer choice.

### Needed to continue

1. An administrator enables `must_change_password` on the target account (or, preferably, on a dedicated disposable test employee) through the web admin.
2. The tester receives the temporary password through an approved secure channel and stores it locally (for example as a line in `~/royal_demo_accounts.txt`, not in the repository).
3. The tester also stores the new password the test should set. It must meet the backend validators.
4. Written confirmation that changing this account's password on production is authorized.

## Final status

**BLOCKED**: the account state and authorization prevented the live forced-password test. Automated verification passes. Live verification of Tests A–E has not been performed.

# ROYAL HRMS — Live Code Demo Guide

**Written for:** you (the presenter), during screen sharing.
**Goal:** a fixed, linear route through the code, so you never jump randomly between files.

## The safety rules (read first)

1. **This demo is code-only.** You open files, diagrams and tests. You do **not** need to sign in to the app, and you must not.
2. **Never press** Clock In/Out, Apply, Approve, Reject, Save, Delete, Assign, Run, Credit or Import — on any server.
3. **Never show or open:** `android/key.properties`, any `.jks`/`.keystore`, `.env` files, terminals or logs containing tokens, `android/local.properties`, real employee screens, production admin consoles, your email or chat.
4. **Screenshots:** do not use any from `docs/qa/.../evidence/` unless you personally opened each one, confirmed it shows no real employee names, emails, salaries or tokens, **and** your lead approved it. The safe default is **no screenshots**.
5. **Proof that things work = fake-server tests**, shown as code (e.g. `test/core/network/auth_interceptor_test.dart`). Say plainly that they use simulated servers.
6. If the client asks to "try it live": *"I'd prefer to do that on a test company so we don't touch real employee records — can we schedule it?"*

> Paths are relative to `mobile_app/`. Line numbers are approximate; find methods by **name** with Go to Symbol (`Cmd+Shift+O`).

---

## 0. Setup (before the call)

1. Open VS Code on `mobile_app` only. Close every other tab and window.
2. Editor font size ≥ 16. Collapse the file tree except `lib/`.
3. Open these tabs in this order:

| # | File | Used in script section |
|---|---|---|
| 1 | `lib/main.dart` | 4 (code structure) |
| 2 | `lib/core/router/access_control.dart` | 3 (architecture) |
| 3 | `lib/core/network/api_client.dart` | 6 |
| 4 | `lib/core/router/app_router.dart` | **5 (live)** |
| 5 | `lib/features/auth/presentation/widgets/login_form.dart` | **5** |
| 6 | `lib/features/auth/presentation/controllers/auth_notifier.dart` | **5** |
| 7 | `lib/features/auth/data/datasources/auth_remote_datasource.dart` | **5** |
| 8 | `lib/features/attendance/presentation/clock/clock_punch_flow.dart` | **5** |
| 9 | `lib/features/attendance/presentation/providers/attendance_providers.dart` | **5** |
| 10 | `lib/features/attendance/data/datasources/attendance_remote_datasource.dart` | **5** |
| 11 | `lib/features/dashboard/presentation/widgets/attendance_ring_card.dart` | **5** |
| 12 | `lib/core/network/auth_interceptor.dart` | 6 |
| 13 | `test/core/network/auth_interceptor_test.dart` | 6 |

4. Diagrams: **exported PNG/PDF** of `05_ARCHITECTURE_DIAGRAMS.md` (or the PDF of document 01) in a separate window — not a live Mermaid preview.
5. Do Not Disturb on. Share **one window**, not the desktop.

---

## 1. How the demo fits the 45-minute script

| Script section | Minutes | Code you show | Time on code |
|---|---|---|---|
| 3. Architecture (8–15) | 7 | Diagram 2, 6, 4. Optionally flash `access_control.dart` (permission map) | ≤ 1 min |
| 4. Code structure (15–22) | 7 | Diagram 3, then `lib/` tree, then `main.dart` | ≈ 2 min |
| **5. Live code (22–30)** | **8** | **Core route below (Steps A–D)** | **8 min** |
| 6. API, security, testing (30–35) | 5 | `api_client.dart` (30 s), `auth_interceptor.dart` (60 s), `test/` folder (30 s) | ≈ 2 min |
| 7. Maintenance (35–40) | 5 | Diagram 10, `pubspec.yaml` version line, `build.gradle.kts` (not `key.properties`) | ≈ 1 min |

Anything marked "Extended" below is only for follow-up questions. **Do not add it to the plan or you will run over 45 minutes.**

---

## 2. Core live route — 8 minutes (script section 5)

### Step A — The router's rule-book (1.5 min) — `lib/core/router/app_router.dart`

- **Point at:** the function `resolveAuthRedirect(...)` and the numbered comment above it (1–4).
- **Say:** "Every screen has an address. This one function is the rule-book that decides who may go where: not signed in goes to login; a required password change comes first; unfinished onboarding is next; then permissions."
- **Do not:** scroll the long route list.

### Step B — Login, top to bottom (2 min)

1. `login_form.dart` → **point at** `_submit()`. "The form checks the fields, then asks the auth notifier to log in."
2. `auth_notifier.dart` → **point at** `login(...)`. "It sets *loading*, runs the login, and stores the result as the new state. The router is watching this state."
3. `auth_remote_datasource.dart` → **point at** `login(...)`. "This is the only place that makes the login web request — one call to `/login/`."
4. **Say:** "The answer includes who you are and what you may do. It is saved in the phone's protected storage."

### Step C — Clock-in recipe (3.5 min) — `clock_punch_flow.dart`

- **Point at:** `runClockPunch(...)`; read the numbered comment (steps 1–6) slowly.
- **Say:** "This one function is the whole recipe. Check the day is not already complete. Read the location. Check the allowed area. Check the face if the company requires it. Then send the attendance."
- **Point at:** `_captureFaceIfRequired` → "The face step only runs when the company made it mandatory."
- Open `attendance_providers.dart` → **point at** `punch(...)`: "On success the new attendance replaces the old state, so the screen refreshes. On failure we return a plain message."
- Open `attendance_remote_datasource.dart` → **point at** `punch(...)`: "This is the exact request sent to the server."
- **Say honestly (do not skip):** "The face check here runs on the phone. On the server, face matching currently runs for web and voice punches, not mobile punches. That's a known open item with the backend team. The location check is enforced on the server. I'm showing code and tests — I'm not clocking in on a live system."

### Step D — Back to the screen (1 min) — `attendance_ring_card.dart`

- **Point at:** the call `runClockPunch(ref, context, today)`.
- **Say:** "The button knows nothing about GPS, faces or HTTP. It calls the recipe and shows a message if something fails. Screens stay simple because the logic lives below."

**Core route total: 8 minutes.** If you are behind schedule, drop Step D into one sentence.

---

## 3. Extended stops (only if asked — not in the 45-minute plan)

- **`lib/app/app.dart`** — `MaterialApp.router`; global no-internet gate (`_ConnectivityGate`).
- **`lib/core/router/access_control.dart`** — `kRoutePermissions`, `kRouteModules`, `userHasPermission`. Say: "These decide what the app *shows*; the server enforces the real rules."
- **`lib/features/auth/data/repositories/auth_repository_impl.dart`** — what is saved at login and cleared at logout.
- **`lib/shared/widgets/app_error_state.dart`** — one error widget with Retry used everywhere.
- **`test/features/attendance/clock_punch_flow_test.dart`** — the clock-in order proved with a fake server.
- **Leave:** `leave/presentation/widgets/apply_leave_tab.dart` (2,097 lines — do **not** scroll it); show `leave_remote_datasource.dart → applyLeave` instead.

## 4. If asked "show me the backend"

The backend is a separate project (`web_frontend_backend/backend`) that the mobile team treats as read-only reference. Offer the verified summary in document 01 (sections 8 and 11) rather than opening files live. Add: "Where mobile needs a backend change, we raise a request; we don't change it ourselves."

## 5. Fallback plans

| Problem | Do this |
|---|---|
| Screen share fails | Rejoin. If > 2 minutes, send the PDF of document 01 and talk through its diagrams. |
| Mermaid/diagram preview fails | Use the exported images or the PDF appendix. |
| VS Code freezes | Reopen; `Cmd+Shift+T` restores tabs. |
| No internet in the room | Everything here is local files. Nothing in the demo calls a server. |
| A file shows something sensitive | Stop sharing, change window, continue. Tell your lead afterwards. |
| You lose your place | Open Diagram 2 and recap the layers; then resume at the next numbered step. |
| Client wants a live app demo | Decline politely as in the safety rules; offer a test-company session. An emulator is **not** needed for this walkthrough. |

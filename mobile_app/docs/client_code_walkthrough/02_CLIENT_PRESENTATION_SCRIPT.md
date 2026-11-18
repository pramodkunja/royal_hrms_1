# ROYAL HRMS — Client Code Walkthrough Speaking Guide

**Written for:** you, a Flutter developer giving your first client code walkthrough. Say these words in your own voice — change anything that feels unnatural.

**Total: 45 minutes.** About 35 minutes of talking, 10 minutes of questions and pauses.

| # | Section | Clock | Minutes |
|---|---|---|---|
| 1 | Introduction | 0–3 | 3 |
| 2 | Project overview | 3–8 | 5 |
| 3 | Architecture | 8–15 | 7 |
| 4 | Code structure | 15–22 | 7 |
| 5 | Live code walkthrough | 22–30 | 8 |
| 6 | API, security, testing | 30–35 | 5 |
| 7 | Maintenance and deployment | 35–40 | 5 |
| 8 | Questions and close | 40–45 | 5 |

**Your five rules:** speak slowly · one idea per sentence · never say "100% secure" or "fully tested" · if unsure, say *"I'll confirm and reply in writing"* · **this is a code walkthrough; you do not use any live system.**

Companion files: `01` facts · `03` file-by-file route · `04` questions · `05` diagrams · `06` rehearsal · `07` one-page cheat sheet.

Each section: **Show · Point at · Say · Transition.**

---

## 1. Introduction (0–3 min)

**Show:** Title slide, or Diagram 1 (system architecture).
**Point at:** Nothing yet. Look at the camera.

**Say:**
> "Good morning, everyone, and thank you for your time. I'm [Your Name], one of the Flutter developers on the Royal HRMS mobile app.
> Today I'll show you how the mobile app is built — what it does, how the parts fit together, how we protect it, how we test it, and how it is released.
> I'll show some real code, but you don't need to be a developer. I'll explain everything in simple words. I'll also be honest about what is finished and what is still in progress.
> Please stop me any time. We also have time for questions at the end."

**Transition:** "Let me start with the big picture."

---

## 2. Project overview (3–8 min)

**Show:** Diagram 1.
**Point at:** The three boxes: mobile app, web app, backend.

**Say:**
> "Royal HRMS helps a company manage its people — attendance, leave, approvals, work from home, training, payslips, recruitment and more.
> There are three parts. The web app, the mobile app, and the backend. The backend is the central server both apps talk to.
> Think of a bank. The web app and the mobile app are two branches. The backend is the vault and the rule-book. Whatever you do in one branch, the other branch sees — because there is only one vault.
> The mobile app is for daily tasks: attendance, applying for leave, approving requests, payslips and learning courses.
> A few things are on the web only, such as full payroll administration. On mobile, employees see their own payslips.
> Each company's data is kept in its own separate section of the database."

**Transition:** "Now let me open the box and show how the mobile app is organised."

---

## 3. Architecture (8–15 min)

**Show:** Diagram 2 (layers) → Diagram 6 (request path) → Diagram 4 (startup).
**Point at:** Diagram 2: Screen, Provider, Repository, Data source, in that order. Diagram 6: the "401 → refresh" branch. Diagram 4: the "Saved user?" decision.

**Say:**
> "The app is built with Flutter, which lets us write one codebase and use the phone's camera, location and secure storage.
> Every feature is built in layers. Think of a restaurant. The screen is the dining room — it shows things. The provider is the waiter — it keeps track of the order: loading, ready, or a problem. The repository is the kitchen manager. The data source is the delivery person who goes to the server.
> If the server changes, we change the delivery person, not every screen.
> Navigation has a rule-book: are you signed in, do you need to change your password, do you have permission for this screen?
> One important point: those permission checks in the app decide what we *show*. The server enforces the real rules on every request.
> When the app opens, it loads the saved theme, shows a short splash screen, and checks if you were already signed in. It doesn't call the server just for that."

**Transition:** "Now let me show where these layers live in the folders."

---

## 4. Code structure (15–22 min)

**Show:** Diagram 3, then VS Code with `lib/` collapsed, then `lib/main.dart`.
**Point at:** In `lib/`: `main.dart`, `core`, `features`, `shared`. In `main.dart`: the call `runApp(ProviderScope(...` at the bottom.

**Say:**
> "In the `lib` folder there are four places.
> `main.dart` is where the app starts. `core` is the foundation everyone shares: networking, navigation, security and the look of the app. `features` has one folder per business area — attendance, leave, approvals, training and so on; there are 29. `shared` holds small reusable pieces like buttons and error screens.
> Inside each feature you'll see `data`, `domain` and `presentation` — the layers I just described.
> All the server addresses the app uses are in one file. One setting decides which server we talk to, and a release build is always forced to the production server, so a test setting can't be shipped by mistake.
> This is `main.dart`. Before the first screen, it loads the saved theme and prepares storage, then starts the app."

**Transition:** "Now I'll follow one request through the real code."

---

## 5. Live code walkthrough (22–30 min)

**Show:** `03_LIVE_CODE_DEMO_GUIDE.md` core route, Steps A–D, in this order: `app_router.dart` → login files → `clock_punch_flow.dart` → providers/datasource → `attendance_ring_card.dart`.
**Point at:** The exact items named in file 03 for each step (`resolveAuthRedirect`, `_submit`, `login`, `runClockPunch`, `punch`).

**Say:**
> "This is the rule-book for navigation — one function that decides who may go where.
> Now login. The form checks the fields, then asks for a login. The result is saved as the app's state, and the router is watching it. The only place that makes the web request is this data source — one call.
> Now the clock-in feature. This one function is the recipe: check the day isn't already complete, read the location, check the allowed area, check the face if the company requires it, and only then send the attendance.
> On the screen, the button just calls this recipe and shows a message if something fails."

**Say this honestly (don't skip):**
> "The face check here runs on the phone. On the server, face matching currently runs for web and voice punches, but not for mobile punches. This is a known open item with the backend team. The location check is enforced on the server.
> I'm showing code today, not clocking in on a live system, so no real data is touched."

**Transition:** "Let me now cover how the app talks to the server, how it's kept safe, and how we test it."

---

## 6. API, security and testing (30–35 min)

**Show:** `api_client.dart` → `auth_interceptor.dart` → the `test/` folder (+ `auth_interceptor_test.dart`).
**Point at:** `dioProvider` (one shared client); `onRequest` and `onError` in the interceptor; the `test/core/network` folder.

**Say:**
> "All calls go through one shared client with a 30-second time limit. Every server error becomes a clear message in one place.
> After login, the session is kept in the phone's protected storage. Every request carries a pass, called a token, that lasts 15 minutes. When it expires, the app quietly gets a new one. If the server refuses that, you're signed out. On logout, the saved session is cleared.
> The face check turns your face into a list of numbers on the phone. We send those numbers, not your photo.
> The server gives each role a set of permissions. The app uses them to show or hide features, and the server checks again each time.
> For testing: we have 170 test files. Our latest recorded run — from our project records, not re-run for this meeting — shows about 2,800 passing and no analyzer errors. These tests use simulated servers, so they prove our logic, not behaviour on a live system.
> On a real phone we did read-only checks against the live system, for one role. Actions like submitting leave, approvals and clock-in still need a safe test environment, and that's on our list."

**Transition:** "Finally, how we release and how another developer can pick this up."

---

## 7. Maintenance and deployment (35–40 min)

**Show:** Diagram 10; the `version:` line in `pubspec.yaml`; `android/app/build.gradle.kts` (**never** `key.properties`).
**Point at:** In the diagram, the box "fails if key missing"; in the code, the `applicationId` line.

**Say:**
> "The app's package name is `com.royalhrms.app`. The version in the source is 1.0.2, build 10.
> A release build always uses the production server and must be signed with the company's upload key. If the key is missing, the build stops — it can't be signed with a test key by accident.
> I want to be open about two release items we're still closing: we must record exactly which source produced each release file, and we must confirm the version number and signing certificate in Google Play before uploading.
> To add a new screen, another developer follows the same recipe: add the server address, a data source, a provider, the screen, the route with its permission, and tests. We have a written checklist for it."

**Transition:** "That's the walkthrough. Let me summarise, then take your questions."

---

## 8. Questions and close (40–45 min)

**Show:** Diagram 1 as a backdrop, or `07_CLIENT_WALKTHROUGH_QUICK_REFERENCE.md` open privately on a second screen (not shared).
**Point at:** Nothing.

**Say — summary:**
> "In short: the mobile app is a Flutter client of the same backend as the web. It's built in clear layers, so it's easy to change and test. The app checks permissions on the phone, and the server enforces them.
> Most modules are built and tested with simulated servers. Three things are still open: face matching on the server for mobile punches, the permission scope for Branch Admins, and live testing of write actions with a test company. We're tracking all three.
> I'm happy to take your questions."

**Hard question?**
> "That's a good question. I don't want to guess. I'll confirm and send you a written answer by [day]."

**Closing statement:**
> "Thank you for your time. I'll send the architecture document and the list of open items after this call. Please email me anything else and I'll reply by [day]."

---

## Words to avoid

| Avoid | Say instead |
|---|---|
| "Everything is secure." | "These protections are in place, and these items are still open." |
| "All features are fully tested." | "Automated tests with simulated data cover most modules; live write testing is pending." |
| "It scales to any size." | "The backend supports many companies; we haven't run formal load tests." |
| "The face check protects attendance." | "The face check runs on the phone; server-side enforcement for mobile is an open item." |
| "Training is complete." | "Training screens are built and checked read-only; write actions need a test company." |
| Jargon (interceptor, notifier, DI) | A real-life comparison first, the term once (cheat sheet below). |

## Plain-words cheat sheet

- **API** — a waiter between the app and the server.
- **Token** — a temporary visitor pass. **Refresh** — getting a new pass without queuing again.
- **Provider / state** — the notice board every screen reads.
- **Interceptor** — a security gate every request passes through.
- **Geofence** — an invisible fence around the office.
- **Fake-server test** — a practice dummy.

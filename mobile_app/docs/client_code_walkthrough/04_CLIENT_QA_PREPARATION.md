# ROYAL HRMS — Client Q&A Preparation

**Written for:** you, answering a client's questions during the walkthrough.
Each answer is short and accurate against the source. **"If pressed"** gives a technical follow-up. **⚠ Careful** marks questions where a confident-sounding answer would be wrong or unproven.

Golden rule: if the answer is not in `01_...` or this file, say: *"I want to give you an accurate answer, so let me confirm and reply in writing by [day]."*

---

## A. Technology and architecture

**1. Why did you choose Flutter?**
Flutter lets us build the Android app from one codebase with a smooth native feel, and it can use the camera, GPS and secure storage that attendance needs. *If pressed:* one Dart codebase, `flutter_riverpod`, `go_router`, `dio`; the project config is in `pubspec.yaml`. We currently ship Android; the repo has iOS/other platform folders but only Google Play is the delivery target (**⚠** don't promise an iOS release date).

**2. Why this architecture (layers per feature)?**
So that screens stay simple and changes stay local. The screen shows, the provider manages state, the data source talks to the server. If an API changes we update one layer. *If pressed:* `features/<name>/{data,domain,presentation}`; not every small feature has all three folders.

**3. How does the mobile app communicate with the backend?**
Over HTTPS using JSON. One shared client (`dioProvider`) sends every request to `https://royalhrms.com/api/` in release builds, adding the user's token. *If pressed:* `core/network/api_client.dart`, `auth_interceptor.dart`, 30 s timeouts; endpoints listed in `core/constants/api_constants.dart`.

**4. Is the mobile app a separate system from the web app?**
No. They are two front-ends of the same backend, so data is always consistent. *If pressed:* the mobile endpoints mirror the web's. Some web features are deliberately not on mobile (admin payroll, platform admin, course/assessment creation parts).

**5. Can the application scale?**
The backend is built for many companies, with a separate database section per company. We have not performed formal load or performance testing, so I cannot give numbers. **⚠ Careful:** do not say "unlimited" or quote user counts. *If pressed:* django-tenants (schema per tenant), paginated lists in the app, Redis/Celery support in the backend settings; production infrastructure sizing is not something I verified.

## B. Security and permissions

**6. How are passwords and tokens protected?**
The app never stores your password. After login it keeps short-lived tokens in the phone's secure storage (Android encrypted storage). Access tokens last 15 minutes; on logout everything is deleted. *If pressed:* `flutter_secure_storage` with encrypted shared preferences; refresh token 7 days with rotation and blacklisting on the server; debug logs never print headers or bodies.

**7. How are permissions handled?**
The server gives each role a set of permission codes, such as "approve leave". The app uses them to show or hide screens and buttons, and the server checks again on every request. *If pressed:* `access_control.dart` (`userHasPermission`, `kRoutePermissions`), backend `core/permissions.py`.

**8. If the app hides a button, can someone still call the API?**
The app's hiding is a convenience, not security. The real check is on the server for every request. *If pressed:* the backend has module gating in middleware and per-view permission checks. I cannot claim every single view was audited line by line; the Branch Admin scope review is still open (see Q14).

**9. How are different employee roles handled?**
Roles are configured per company and carry permissions; the app never decides by role name. The home dashboard is chosen from permissions: admin, manager, HR or employee. *If pressed:* `resolveDashboardCategory` in `quick_access.dart`.

**10. What happens when a session expires?**
The app tries to renew quietly. If the server refuses the renewal, the user is signed out and sent to Login. A temporary network problem does not sign them out. *If pressed:* `AuthInterceptor`, covered by `test/core/network/auth_interceptor_test.dart`.

**11. How is face recognition implemented?**
The phone checks that a real person is present (a head turn), then converts the face into 128 numbers on the device. Only those numbers are sent, not a photo. The server stores and compares the numbers. *If pressed:* the web's face-api.js networks were converted to TFLite so mobile and web use the same number space (`assets/face_api/`, `face_api_pipeline.dart`); no photo fields on the backend face models.

**12. Is face verification enforced securely?** ⚠
Be honest: *"The phone performs the check. On the server, the face comparison currently runs for web and voice punches but not for mobile punches — the client chooses the punch source, so with Face ID mandatory a self-service punch can bypass it. That is our top open item (HO-01, P0), awaiting a backend fix or a documented risk acceptance. The location check is enforced on the server."* Do not say it is fixed or exploit-tested. *If pressed:* liveness is reported by the client; the server cannot independently verify it. Clock-in and face registration have not yet been run on a physical device.

**13. Can an employee fake their location?** ⚠
The server checks the coordinates against the branch's allowed radius, but the coordinates come from the phone; we have not found a mock-location detection mechanism. Don't claim it is tamper-proof.

**14. What is the Branch Admin issue?** ⚠
*"A Branch Admin should see only their branch. Our device review found a Branch Admin could open company-wide settings screens, and the backend source has since been tightened to scope data views to the branch. But Branch Admins can still use the settings screens, some list endpoints are not branch-scoped (HO-45), and we haven't confirmed production runs the updated backend. It is open and needs a product decision (HO-18)."* Don't promise a date or say it is fixed.

## C. Behaviour and reliability

**15. What happens when the API fails?**
The user sees a clear message and a Retry button — never technical text. Timeouts are 30 seconds. *If pressed:* `parseDioException`, `AppErrorState`.

**16. What if the phone has no internet?**
A full-screen "No internet" view appears and clears itself when the connection returns. *If pressed:* `_ConnectivityGate`; it detects network link, not confirmed internet. There is **no offline mode** — data is not cached for offline use (**⚠** don't suggest offline clock-in).

**17. How does a leave request get approved?**
The employee submits; the server checks the leave policy (notice, overlap, balance); the server assigns approvers; managers approve in the Approvals screen; the status updates. The balance is deducted at final approval. *If pressed:* `POST /leave/requests/`, then `/leave/requests/<id>/approve/`; two approval levels, delegation supported.

**18. Are notifications real-time on mobile?**
Not push. The app checks for unread notifications every 60 seconds. The web uses real-time WebSockets. **⚠** Do not claim push notifications.

## D. Quality and testing

**19. How is the application tested?**
Automated tests with simulated servers (170 test files; last recorded run, 18 Nov: 2,806 passing; analyzer 13 informational notes, 0 warnings, 0 errors), plus read-only checks on a real phone, in a **debug** build, against the live system. *If pressed:* the figures are from the project's handover records, not re-run for this meeting. One handover table still shows an older figure (2,701); the per-task lines show the latest.

**20. Has everything been tested on a real phone?** ⚠
No. *"Real-device checks were read-only and for one role. Submitting leave, clock-in, approvals and saves are covered by simulated tests only, and need a staging environment for live testing. Employee, HR and Manager roles are still to be tested."*

**21. Are there integration tests?**
There is no `integration_test` folder. We use unit and widget tests. Device checks were manual.

## E. Delivery and maintenance

**22. How are updates deployed?**
We build a signed Android App Bundle and upload it to Google Play. A release build always points to the production server and cannot be signed with a debug key. *If pressed:* `build.gradle.kts` checks `key.properties`. Before upload we must confirm the version code and certificate in Play Console. **⚠** Be candid that the existing release bundle's source state was not recorded (HO-32) and must be recorded or rebuilt first; no signed release build has been tested on a phone.

**23. What is currently incomplete?** ⚠
Give the list: Face enforcement for mobile punches (backend, HO-01); Branch Admin scope decision (HO-18/HO-45); recording the exact source of the release build (HO-32); live testing of write workflows, clock-in, and the Employee/HR/Manager roles; Training & Learning is partial (HO-25: screens built and checked read-only, writes mock-tested only, New Assessment web-only, un-archive unavailable); Reports (web-only by decision, hidden on mobile); voice commands not device-tested; accessibility not audited.

**24. How will future developers maintain the project?**
The layers and file naming are consistent; there is an onboarding checklist and recipes in `01` section 16, audit and QA documents in `docs/`, and 170 tests as a safety net. **⚠** `teamcontextfile.md` notes can be stale — verify against code.

**25. How do we add new features?**
Add the API path, a data source, a provider, the screen, the route with its permission and module, and tests. About a dozen well-defined steps; see `01` section 16.

**26. Which Android versions are supported?**
minSdk 24 (Android 7.0), target and compile SDK 36 — taken from Flutter 3.44.8's defaults, which the build file uses. Re-check on the actual release build before putting it in writing.

**27. Does it work in Hindi / other languages?**
The UI strings are in English. Voice commands support English and Hindi through the backend and the ID card PDF bundles a Devanagari font. There is no full app localisation in the source I reviewed (**unverified** beyond that).

**28. Is employee data stored on the phone?**
A cached copy of the signed-in user's profile and tokens is stored in secure storage and deleted on logout. Profile documents are viewed inside the app; temporary copies are removed at start and sign-out.

**29. Why does the app show a certain screen only for some users?**
Because the company's subscription may not include that module, or the user's role lacks that permission. Both come from the server's login response.

**30. Can you demo it with real data now?**
"I prefer to do that on a test environment so we do not create or change real employee records. Can we schedule a test-company session?"

---

## How to answer hard questions professionally

1. **Pause, then repeat the question** in your own words ("So you're asking whether…").
2. **Answer what you know** in one or two sentences.
3. **Separate fact from plan:** "Today the app does X. We have not verified Y."
4. **Never guess a number, date or guarantee.**
5. **Offer a written follow-up** with a day.
6. **Do not blame** another team: "That part is owned by the backend; we have raised it."
7. **If criticised:** thank, acknowledge, show the tracking ("It's on our open-items list as HO-xx").

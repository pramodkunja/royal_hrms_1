# Royal HRMS — Walkthrough Quick Reference (one page)

**Written for:** you, on a second screen (not shared). Code and diagrams only — **no live system, no sign-in, no writes.**

**Opening:** "Thank you for your time. I'll show how the Royal HRMS mobile app is built, how it's protected and tested, and how it's released — in plain words, and I'll be honest about what is finished and what's still open."

**Order (45 min):** Intro 3 → Overview 5 (Diagram 1) → Architecture 7 (D2, D6, D4) → Code structure 7 (D3, `main.dart`) → Live code 8 (router → login → clock-in → button) → API/security/tests 5 → Maintenance 5 (D10) → Questions 5.

**Key files:** `lib/main.dart` · `core/router/app_router.dart` (`resolveAuthRedirect`) · `core/router/access_control.dart` · `core/network/api_client.dart` · `core/network/auth_interceptor.dart` · `features/auth/…/auth_notifier.dart` · `features/attendance/…/clock_punch_flow.dart` (`runClockPunch`) · `…/attendance_providers.dart` · `test/core/network/auth_interceptor_test.dart`.

**Three explanations**
1. **Two apps, one backend:** web and mobile are two branches of a bank; the backend is the vault and rule-book. Each company's data sits in its own database section.
2. **Layers:** screen = dining room, provider = waiter (loading / ready / problem), repository = kitchen manager, data source = delivery person to the server.
3. **Permissions:** the app *shows or hides* features from the permissions the server granted; the **server** enforces the real rules on every request.

**Five likely questions**
1. *Why Flutter?* One codebase; native camera, GPS, secure storage.
2. *How are tokens protected?* Phone secure storage; 15-minute access token, silent refresh, cleared on logout.
3. *How does face recognition work?* Phone computes 128 numbers; no photo sent; **server matching is not applied to mobile punches (open).**
4. *How is it tested?* 170 test files, ~2,806 passing in the 18 Nov record (fake servers, not re-run); read-only phone checks on a debug build.
5. *What's incomplete?* See below.

**Known limitations (say them yourself)**
- **HO-01 (P0):** server skips face matching for mobile punches; client picks the punch source. Clock-in/face registration never run on a device.
- **HO-18/HO-45:** Branch Admin scope unresolved; production backend revision unconfirmed.
- **HO-32:** release bundle's source state unrecorded; no signed release build tested.
- **HO-25:** Training & Learning is partial — built, read-only checked, writes mock-tested only; New Assessment web-only.
- No live write testing; Employee/HR/Manager roles untested; voice not device-tested; no accessibility/performance audit.
- `must_change_password` is enforced by the app/web only. Notifications are polled every 60 s (no push).

**If you don't know:** "I don't want to guess — I'll confirm and reply in writing by [day]."

**Closing:** "Thank you. I'll send the architecture document and the open-items list after this call, and answer anything else by [day]."

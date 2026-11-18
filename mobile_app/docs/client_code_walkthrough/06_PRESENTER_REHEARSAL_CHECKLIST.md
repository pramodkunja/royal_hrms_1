# ROYAL HRMS — Presenter Training & Rehearsal Checklist

**Written for:** you, a first-time presenter of a client code walkthrough.

---

## 1. Before anything: your mindset

- The client is not testing you. They want confidence that the app is well built and that you are honest.
- **Honesty earns more trust than perfection.** Saying "that is an open item" sounds professional. Guessing sounds risky.
- You do not have to show every file. You have to tell a clear story: *request goes in → logic → server → answer → screen.*

## 2. How to start confidently (first 60 seconds)

1. Arrive 10 minutes early; join the call, test audio.
2. Water nearby. Phone on silent.
3. Say your opening from `02_...` Section 1 — memorise only the first two sentences.
4. Breathe, smile, slow down by 20% compared with how you normally speak.
5. State the agenda and invite questions: it takes pressure off you.

## 3. How to share the correct screen

1. Use **"Share Window"** (VS Code), not "Entire Screen". This prevents showing notifications or other apps.
2. In Teams/Zoom/Meet, choose the **VS Code window**. Check the preview before confirming.
3. Pre-open the 13 tabs listed in `03_...`. Put diagrams in a second window you can switch to (share that window only when needed — or use the PDF).
4. Close: email, Slack, password managers, terminals with secrets, `android/key.properties`, browser tabs with production.
5. Switch off notifications (Do Not Disturb).
6. After sharing, ask: "Can everyone see my screen clearly? Is the text big enough?"

## 4. How to explain code without reading every line

- **Pick one line, say what it means for the user.** Example: point at `if (today.dayCompleted) return kDayCompletedMessage;` → "If you have already clocked in and out today, we stop here."
- Use the **3-sentence rule**: What is this file for? What is the one important thing in it? What comes next?
- Highlight with the mouse; don't read imports or boilerplate.
- Say **"the important part is…"** to direct attention.
- Use comparisons from the jargon cheat sheet in `02_...`.

## 5. How to control the pace

- Pause after each file: "Does that make sense?"
- Never scroll quickly; use Go to Symbol (`Cmd+Shift+O`).
- Watch the clock: halfway through (≈22 min) you should be at Section 5. If late, skip Stops 2, 4 and 9 of the demo.
- If a question derails you, say "Let me finish this point, then come back to you."

## 6. Handling unexpected questions

1. Repeat the question.
2. Answer only what you know.
3. If it needs checking: "I want to give you an accurate answer. I will confirm and send it in writing by [day]."
4. Write it on a notepad ("Parking lot") so they see you captured it.

**What to say when you don't know:** "I don't have that detail with me and I don't want to guess. I'll verify it and reply by [day]."

## 7. Handling technical criticism

Example: "Why is that file 3,900 lines?"
1. Thank: "That's a fair observation."
2. Acknowledge: "Yes, `attendance_screen.dart` is large; it holds many HR tabs."
3. Show the plan or the tracking: "Splitting it is a maintainability improvement we can schedule."
4. Never argue, never blame the previous developer or another team.

Other likely criticisms and honest replies are in `04_...` (Q12–14, Q20, Q23).

## 8. Recovering when the demo fails

| Failure | Recovery sentence | Action |
|---|---|---|
| Client asks for a live app demo | "I'd prefer a test company so we don't touch real employee records — can we schedule that?" | Continue with code and diagrams |
| Backend slow/down | "The server isn't responding, so let me show the code path and the tests." | Show Stop 5–7 code + `auth_interceptor_test.dart` |
| Screen share breaks | "Give me one moment to reconnect." | Rejoin; if >2 min, send the PDF and talk through diagrams |
| You lose your place | "Let me step back and recap." | Open Diagram 2 and recap the layers |
| Wrong file opened | "That's not the one — here is the one I meant." | Move on; don't apologise at length |
| Sensitive data appears | Stop sharing immediately; "Let me change what I'm sharing." | Close it; continue; mention afterwards to your manager |

## 9. How to finish professionally

1. Summarise in 3 sentences (script in `02_...` Section 8).
2. State the open items **yourself**, before they do.
3. Promise one concrete follow-up: "I'll send the architecture document and the list of open items by [day]."
4. Thank them by name if possible.
5. Within 24 hours: send the follow-up email with answers to parked questions.

---

## 10. Ten-minute practice script (do this out loud, alone, with a timer)

| Time | Say / do |
|---|---|
| 0:00–0:45 | Introduce yourself and the agenda (opening, `02_` Section 1). |
| 0:45–2:00 | "Three parts: web, mobile, backend — one shared backend like a bank vault" (Diagram 1). |
| 2:00–3:30 | Layers with the restaurant example (Diagram 2). |
| 3:30–4:30 | Open `main.dart`: "This is where the app starts: theme, storage, then the app." |
| 4:30–5:30 | Open `app_router.dart`, `resolveAuthRedirect`: "One rule-book decides where you go." |
| 5:30–6:30 | Open `auth_notifier.dart` → `auth_remote_datasource.dart`: "Login: one request, one saved session." |
| 6:30–8:00 | Open `clock_punch_flow.dart`: read the six numbered steps, then the honest face-check sentence ("runs on the phone; server matching for mobile is an open item"). |
| 8:00–9:00 | "Tests: 170 files, simulated servers; real-phone checks were read-only." |
| 9:00–10:00 | Close: summary, open items, thanks. |

Record yourself (phone voice memo). Listen for: filler words, speed, reading code aloud, unexplained jargon.

---

## 11. Rehearsal checklist

**Content**
- [ ] I can explain the 3 parts (web, mobile, backend) in 30 seconds.
- [ ] I can explain the 4 layers with an example.
- [ ] I can trace login and clock-in without notes.
- [ ] I can state the open items calmly: HO-01 (face on server for mobile), HO-18/HO-45 (Branch Admin scope), HO-32 (release build record), HO-25 (training partial), no live write testing, Employee/HR/Manager untested.
- [ ] I know what is **not** on mobile (admin payroll, platform admin, Reports).
- [ ] I have read `01` sections 6, 8 and 17 twice.
- [ ] I can answer Q1–Q14 in `04_...` from memory.

**Files and tools**
- [ ] 13 tabs open in the order of `03_...`; font size ≥ 16.
- [ ] Diagrams **exported** to images/PDF (don't rely on Mermaid preview live).
- [ ] PDF of document 01 available on my laptop and phone.
- [ ] Verified that no secrets (`key.properties`, `.env`, keystore) are open or visible.
- [ ] Verified demo needs **no production writes**.
- [ ] I will **not** sign in to any live system during the walkthrough (code, diagrams and tests only).

**Environment**
- [ ] Share **window**, not desktop; notifications off.
- [ ] Meeting link, camera, microphone tested.
- [ ] Backup: second device with the PDF.
- [ ] Notepad for parking-lot questions.

**Practice**
- [ ] Ran the 10-minute script out loud ≥ 2 times.
- [ ] Ran the full 30–45-minute walkthrough once with a colleague acting as the client.
- [ ] Asked the colleague to ask the 5 hardest questions from `04_...`.
- [ ] Timed each section against the schedule in `02_...`.

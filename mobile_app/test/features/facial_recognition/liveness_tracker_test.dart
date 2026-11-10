import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/liveness_tracker.dart';

// Liveness parity with web lib/faceApi/liveness.ts: registration needs a blink
// AND a head turn (blink_and_turn); clock-in needs a head turn (turn_only) — a
// blink alone never passes either. Prompts and timeout messages are web's.

void blink(LivenessTracker t) {
  t.addSample(leftEyeOpen: 0.95, rightEyeOpen: 0.9);
  t.addSample(leftEyeOpen: 0.1, rightEyeOpen: 0.15);
  t.addSample(leftEyeOpen: 0.9, rightEyeOpen: 0.95);
}

void turn(LivenessTracker t, {double to = 20}) {
  t.addSample(yaw: to);
}

LivenessTracker started(LivenessMode m) => LivenessTracker(m)..addSample(yaw: 0); // baseline

void main() {
  group('registration (blink AND turn)', () {
    test('blink alone does not pass; then a turn passes', () {
      final t = started(LivenessMode.blinkAndTurn);
      blink(t);
      expect([t.blinkSeen, t.turnSeen, t.passed], [true, false, false]);
      expect(t.prompt, 'Blink ✓ — now turn your head slightly');
      turn(t);
      expect(t.passed, isTrue);
    });

    test('turn alone does not pass; then a blink passes (either order)', () {
      final t = started(LivenessMode.blinkAndTurn);
      turn(t, to: -18);
      expect(t.passed, isFalse);
      expect(t.prompt, 'Head turn ✓ — now blink naturally');
      blink(t);
      expect(t.passed, isTrue);
    });

    test('a half-closed eye that never recovers, or a small turn, is not enough', () {
      final t = started(LivenessMode.blinkAndTurn);
      t.addSample(leftEyeOpen: 0.1, rightEyeOpen: 0.1); // closed, never reopens
      turn(t, to: 14); // under 15°
      expect([t.blinkSeen, t.turnSeen, t.passed], [false, false, false]);
      expect(t.prompt, 'Please blink naturally AND turn your head slightly');
      expect(t.missingMessage, "Let's try once more — blink naturally, then turn your head slightly.");
    });

    test('timeout messages name what is missing (web livenessMissingMessage)', () {
      final b = started(LivenessMode.blinkAndTurn);
      blink(b);
      expect(b.missingMessage, 'Blink detected — now turn your head slightly to one side, then back.');
      final h = started(LivenessMode.blinkAndTurn);
      turn(h);
      expect(h.missingMessage, 'Head turn detected — now blink naturally, looking at the camera.');
    });
  });

  group('clock-in (turn only)', () {
    test('a blink alone never passes; a head turn does', () {
      final t = started(LivenessMode.turnOnly);
      blink(t);
      expect(t.passed, isFalse, reason: 'stricter than the old blink-OR-turn rule');
      turn(t);
      expect(t.passed, isTrue);
      expect(t.prompt, 'Slowly turn your head slightly to one side, then back');
    });

    test('timeout message', () {
      expect(started(LivenessMode.turnOnly).missingMessage,
          "Let's try once more — turn your head slightly to one side, then back.");
    });
  });

  test('turn is measured from the yaw when liveness started; score is informational 0..1', () {
    final t = LivenessTracker(LivenessMode.turnOnly)..addSample(yaw: 10);
    turn(t, to: 24); // 14° from baseline
    expect(t.passed, isFalse);
    turn(t, to: -6); // 16°
    expect(t.passed, isTrue);
    expect(t.score, closeTo(16 / 45, 1e-9));
    final both = started(LivenessMode.blinkAndTurn);
    blink(both);
    turn(both, to: 45);
    expect(both.score, inInclusiveRange(0, 1));
  });
}

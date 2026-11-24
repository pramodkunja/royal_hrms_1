import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_controller.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_state.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/liveness_tracker.dart';

const _upright = Size(480, 640);

Face _face({Rect? box, double? yaw = 0, double? left = 1, double? right = 1, int id = 1}) => Face(
      boundingBox: box ?? const Rect.fromLTWH(120, 180, 240, 300), // 0.5 width, centred
      landmarks: const {},
      contours: const {},
      headEulerAngleY: yaw,
      headEulerAngleX: 0,
      headEulerAngleZ: 0,
      leftEyeOpenProbability: left,
      rightEyeOpenProbability: right,
      smilingProbability: 0,
      trackingId: id,
    );

void main() {
  late ProviderContainer container;
  late FaceCaptureController c;
  late DateTime clock;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    c = container.read(faceCaptureControllerProvider.notifier);
    clock = DateTime(2026, 1, 1);
    c.clockForTest = () => clock;
  });

  FaceCaptureUiState st() => container.read(faceCaptureControllerProvider);

  Future<void> feed(List<Face> f, {FaceCapturePhase? phase}) => c.feedFacesForTest(f, _upright, phase: phase);

  Future<void> reachLiveness() async {
    await feed([_face()], phase: FaceCapturePhase.detecting);
    for (var i = 0; i < 12; i++) {
      clock = clock.add(const Duration(milliseconds: 150));
      await feed([_face()]);
    }
  }

  test('framing: centred 50% face passes; too far / too close / off-centre / turned each give their own hint', () async {
    await feed([_face(box: const Rect.fromLTWH(200, 280, 80, 100))], phase: FaceCapturePhase.detecting);
    expect(st().liveHint, 'Move closer to the camera.');
    await feed([_face(box: const Rect.fromLTWH(20, 100, 440, 440))]);
    expect(st().liveHint, 'Move back a little.');
    await feed([_face(box: const Rect.fromLTWH(0, 0, 150, 190))]);
    expect(st().liveHint, 'Centre your face in the oval.');
    await feed([_face(yaw: 30)]);
    expect(st().liveHint, 'Face the camera directly.');
    await feed([_face()]);
    expect(st().liveHint, isNull);
  });

  test('width ratio is measured against the upright width (a 0.19 face on a 640-wide raw frame is still too far)', () async {
    // 90 px / 480 upright = 0.1875 → too far. Against raw width 640 it would be 0.14 — also far; use 100/480=0.208
    // which passes on upright but would read 0.156 (too far) with the old raw-width denominator.
    await feed([_face(box: const Rect.fromLTWH(190, 270, 100, 125))], phase: FaceCapturePhase.detecting);
    expect(st().liveHint, isNot('Move closer to the camera.'));
  });

  test('liveness starts after stable frames and exposes progress + time left', () async {
    c.livenessModeForTest = LivenessMode.blinkAndTurn;
    await reachLiveness();
    expect(st().phase, FaceCapturePhase.livenessChecking);
    expect(st().blinkRequired, isTrue);
    expect(st().blinkSeen, isFalse);
    expect(st().turnSeen, isFalse);
    expect(st().livenessSecondsLeft, inInclusiveRange(8, 9));
    expect(st().liveHint, contains('blink'));
  });

  test('brief face loss during liveness keeps the challenge (no reset to detecting)', () async {
    c.livenessModeForTest = LivenessMode.blinkAndTurn;
    await reachLiveness();
    await feed([_face(yaw: 5, left: 0.1, right: 0.1)]); // eyes closed
    for (var i = 0; i < 5; i++) {
      await feed(const []); // face lost mid-blink / mid-turn
    }
    expect(st().phase, FaceCapturePhase.livenessChecking);
    expect(st().liveHint, 'Keep your face in the oval.');
    await feed([_face(yaw: 5, left: 0.9, right: 0.9)]); // eyes reopen → blink completes
    expect(st().blinkSeen, isTrue, reason: 'tracker survived the gap');
  });

  test('multiple faces during liveness gives the multiple-face hint but keeps the window', () async {
    await reachLiveness();
    await feed([_face(), _face()]);
    expect(st().phase, FaceCapturePhase.livenessChecking);
    expect(st().liveHint, contains('Multiple faces'));
  });

  test('sustained face loss (wall-clock, not frame count) restarts framing', () async {
    await reachLiveness();
    // 30 quick frames within 400 ms: still the same challenge, whatever the frame rate.
    for (var i = 0; i < 30; i++) {
      clock = clock.add(const Duration(milliseconds: 13));
      await feed(const []);
    }
    expect(st().phase, FaceCapturePhase.livenessChecking);
    // One slow frame after 1 s of loss: restart framing with a hint.
    clock = clock.add(const Duration(seconds: 1));
    await feed(const []);
    expect(st().phase, FaceCapturePhase.detecting);
    expect(st().liveHint, 'Keep your face in the oval.');
  });

  test('a different face (tracking id) after a gap does NOT inherit the challenge progress', () async {
    c.livenessModeForTest = LivenessMode.blinkAndTurn;
    await reachLiveness();
    await feed([_face(yaw: 5, left: 0.1, right: 0.1)]);
    await feed([_face(yaw: 5, left: 0.9, right: 0.9)]);
    expect(st().blinkSeen, isTrue);
    await feed(const []);
    await feed([_face(id: 2)]);
    expect(st().phase, FaceCapturePhase.detecting);
    expect(st().blinkSeen, isFalse);
    expect(st().liveHint, contains('different face'));
  });

  test('UI updates are throttled between transitions (no rebuild per camera frame)', () async {
    await reachLiveness();
    final seen = <FaceCaptureUiState>[];
    container.listen(faceCaptureControllerProvider, (_, n) => seen.add(n));
    for (var i = 0; i < 20; i++) {
      clock = clock.add(const Duration(milliseconds: 5)); // 200 fps burst
      await feed([_face()]);
    }
    expect(seen.length, lessThanOrEqualTo(2));
    clock = clock.add(const Duration(milliseconds: 150));
    await feed([_face()]);
    expect(seen.length, greaterThan(0));
  });

  test('liveness timeout fails with an actionable message (not stuck)', () async {
    c.livenessModeForTest = LivenessMode.blinkAndTurn;
    await reachLiveness();
    c.expireLivenessForTest();
    await feed([_face()]);
    expect(st().phase, FaceCapturePhase.livenessFailed);
    expect(st().message, isNotEmpty);
    expect(st().message, isNot(contains('Confirming')));
  });

  test('state carries geometry only (box + frame size), never pixels or descriptors', () async {
    await feed([_face()], phase: FaceCapturePhase.detecting);
    expect(st().uprightFrame, _upright);
    expect(st().faceBox, isNotNull);
    expect(st().embedding, isNull);
  });
}

import 'dart:math' as math;

// Liveness rules of the web app (frontend/lib/faceApi/liveness.ts
// LivenessTracker), on ML Kit's signals:
//  - registration (self and HR-assisted): "blink_and_turn" — a blink AND a
//    head turn must both be seen during the liveness window (any order);
//  - clock-in verification: "turn_only" — a head turn is required; a blink
//    alone never passes (web FaceVerificationModal livenessMode "turn_only").
// Signals (unchanged from the previous mobile check): a blink is the average
// eye-open probability dipping below 0.3 and recovering above 0.6; a head turn
// is the yaw moving more than 15° from where it was when liveness started.

enum LivenessMode { blinkAndTurn, turnOnly }

const kBlinkClosedThreshold = 0.3;
const kBlinkOpenThreshold = 0.6;
const kHeadTurnDegrees = 15.0;

class LivenessTracker {
  LivenessTracker(this.mode);
  final LivenessMode mode;

  bool _eyesClosed = false;
  bool _blink = false;
  bool _turn = false;
  double _minOpen = 1;
  double _maxTurnDegrees = 0;
  double? _baselineYaw;

  bool get blinkSeen => _blink;
  bool get turnSeen => _turn;

  /// Web getResult().passed: a head turn, plus a blink unless turn-only.
  bool get passed => _turn && (_blink || mode == LivenessMode.turnOnly);

  /// 0–1, informational only (the backend stores it, never gates on it):
  /// the mean of the blink and turn strengths when both were seen.
  double get score {
    final turnScore = math.min(1.0, _maxTurnDegrees / 45.0);
    final blinkScore = _blink ? (1 - _minOpen).clamp(0.0, 1.0) : 0.0;
    return _blink ? (blinkScore + turnScore) / 2 : turnScore;
  }

  /// One live frame. The first yaw reading is the "facing the camera" baseline.
  void addSample({double? leftEyeOpen, double? rightEyeOpen, double? yaw}) {
    if (leftEyeOpen != null && rightEyeOpen != null) {
      final open = (leftEyeOpen + rightEyeOpen) / 2;
      if (!_eyesClosed && open < kBlinkClosedThreshold) {
        _eyesClosed = true;
        _minOpen = open;
      } else if (_eyesClosed) {
        _minOpen = math.min(_minOpen, open);
        if (open > kBlinkOpenThreshold) {
          _eyesClosed = false;
          _blink = true;
        }
      }
    }
    if (yaw != null) {
      final base = _baselineYaw;
      if (base == null) {
        _baselineYaw = yaw;
      } else {
        _maxTurnDegrees = math.max(_maxTurnDegrees, (yaw - base).abs());
        if (_maxTurnDegrees > kHeadTurnDegrees) _turn = true;
      }
    }
  }

  /// Web FaceCaptureStage instructionFor("liveness_checking", progress, turnOnly).
  String get prompt {
    if (mode == LivenessMode.turnOnly) return 'Slowly turn your head slightly to one side, then back';
    if (_blink && !_turn) return 'Blink \u2713 \u2014 now turn your head slightly';
    if (_turn && !_blink) return 'Head turn \u2713 \u2014 now blink naturally';
    return 'Please blink naturally AND turn your head slightly';
  }

  /// Web livenessMissingMessage(progress, mode) — shown when the window ends.
  String get missingMessage {
    if (mode == LivenessMode.turnOnly) {
      return "Let's try once more \u2014 turn your head slightly to one side, then back.";
    }
    if (_blink && !_turn) return 'Blink detected \u2014 now turn your head slightly to one side, then back.';
    if (_turn && !_blink) return 'Head turn detected \u2014 now blink naturally, looking at the camera.';
    return "Let's try once more \u2014 blink naturally, then turn your head slightly.";
  }
}

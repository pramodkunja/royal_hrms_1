import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:mobile_app/features/facial_recognition/diagnostics/face_diagnostics.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_nets.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_controller.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_state.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/liveness_tracker.dart';

class _Nets implements FaceApiNets {
  @override
  Future<Float32List> detect(Float32List rgb224) async => Float32List(7 * 7 * 25);
  @override
  Future<Float32List> landmarks(Float32List rgb112) async => Float32List(136);
  @override
  Future<Float32List> describe(Float32List rgb150) async => Float32List(128);
  @override
  Future<void> dispose() async {}
}

Face _face(double yaw) => Face(
      boundingBox: const Rect.fromLTWH(120, 180, 240, 300),
      landmarks: const {},
      contours: const {},
      headEulerAngleY: yaw,
      headEulerAngleX: 0,
      headEulerAngleZ: 0,
      leftEyeOpenProbability: 1,
      rightEyeOpenProbability: 1,
      smilingProbability: 0,
      trackingId: 1,
    );

void main() {
  flowTests();
  test('diagnostics are off unless explicitly enabled', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(faceDiagnosticsEnabledProvider), isFalse);
  });

  test('only a debug build with an explicit dart-define can enable the panel (main.dart is the sole switch)', () {
    final main = File('lib/main.dart').readAsStringSync();
    expect(main, contains("(kDebugMode || kProfileMode) && const bool.fromEnvironment('FACE_DIAGNOSTICS')"));
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('lib/main.dart')) continue;
      expect(f.readAsStringSync().contains('faceDiagnosticsEnabledProvider.overrideWith'), isFalse, reason: f.path);
    }
  });

  test('the report carries the descriptor LENGTH and timings, never descriptor values', () {
    final emb = List<double>.generate(128, (i) => 0.123456 + i / 1000);
    final n = ProviderContainer();
    addTearDown(n.dispose);
    n.read(faceDiagnosticsProvider.notifier).recordCapture(FaceCaptureUiState(
      phase: FaceCapturePhase.ready,
      embedding: emb,
      timingsMs: const {'camera_ready': 640, 'descriptor_done': 4100, 'liveness_ms': 2300},
    ));
    n.read(faceDiagnosticsProvider.notifier).recordBackend(ms: 420, error: null);
    final text = n.read(faceDiagnosticsProvider).toCopyText();
    expect(text, contains('descriptor length: 128'));
    expect(text, contains('backend response: 420 ms'));
    expect(text, contains('total verification: 4520 ms'));
    expect(text, contains('liveness duration: 2300 ms'));
    expect(text, isNot(contains('0.1234')));
    expect(text, isNot(contains('token')));
  });

  test('backend refusals become fixed categories and the message text is discarded', () {
    expect(categorizeFaceFailure('Too many failed face verification attempts. Please wait 4m 5s before trying again.'),
        'server lockout / attempt cap');
    expect(categorizeFaceFailure("We couldn't match your face to your registered Face ID. You can try again"),
        'identity mismatch');
    expect(categorizeFaceFailure('Face verification failed and trying again right now won’t change the result.'),
        'low-confidence rejection (hard block)');
    expect(categorizeFaceFailure('Face ID registration is mandatory and you don’t have one yet.'),
        'registration unavailable');
    expect(categorizeFaceFailure('Cannot reach server. Check your connection.'), 'network failure');
    expect(categorizeFaceFailure('Something about Jane Doe jane@example.com'), 'other backend refusal');
    final n = ProviderContainer();
    addTearDown(n.dispose);
    n.read(faceDiagnosticsProvider.notifier).recordBackend(ms: 9, error: 'Jane Doe jane@example.com refused');
    expect(n.read(faceDiagnosticsProvider).toCopyText(), isNot(contains('Jane')));
  });

  test('closing the screen while descriptors are being produced leaves no stale result and no error', () async {
    final gate = Completer<FaceApiNets>();
    final c = ProviderContainer(overrides: [faceApiNetsProvider.overrideWith((ref) => gate.future)]);
    final ctrl = c.read(faceCaptureControllerProvider.notifier);
    ctrl.livenessModeForTest = LivenessMode.turnOnly;
    // Drive to liveness, then a turn → pass → pipeline waits on the nets.
    await ctrl.feedFacesForTest([_face(0)], const Size(480, 640), phase: FaceCapturePhase.detecting);
    for (var i = 0; i < 12; i++) {
      await ctrl.feedFacesForTest([_face(0)], const Size(480, 640));
    }
    final passing = ctrl.feedFacesForTest([_face(30)], const Size(480, 640));
    c.dispose(); // user cancels while the models are still loading
    gate.complete(_Nets());
    await passing; // must not throw (no state write on a disposed notifier)
  });
}

void flowTests() {
  test('flow timeline: marks are ms since pressed, ignored before start, numbers only', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(faceFlowProvider.notifier);
    n.mark('early'); // not started → ignored
    expect(c.read(faceFlowProvider), isEmpty);
    n.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    n.mark('gps_and_mode_done');
    final text = n.toCopyText();
    expect(c.read(faceFlowProvider).keys, containsAll(['pressed', 'gps_and_mode_done']));
    expect(c.read(faceFlowProvider)['gps_and_mode_done'], greaterThanOrEqualTo(15));
    expect(text, contains('gps_and_mode_done'));
    expect(text, isNot(contains('early')));
  });

  test('report prints framing, decoder and thread-equality lines when present, none of them with values of images', () {
    const r = FaceDiagnosticsReport(timingsMs: {
      'frames_received': 40,
      'frames_processed': 14,
      'frames_dropped_busy': 26,
      'stable_resets': 2,
      'thread_delta_max_e9': 3,
      'thread_delta_samples': 3,
      'native_decode_ms': 60,
      'dart_decode_ms': 270,
      'cmp_dims_equal': 1,
      'cmp_mean_x1000': 420,
      'cmp_max': 5,
      'cmp_pct_over2_x100': 130,
    });
    final t = r.toCopyText();
    expect(t, contains('dropped (busy) 26'));
    expect(t, contains('stability resets 2'));
    expect(t, contains('max descriptor delta 3 e-9 over 3 descriptors'));
    expect(t, contains('mean abs diff 0.420'));
  });
}

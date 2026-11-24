import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_nets.dart';
import 'package:mobile_app/features/facial_recognition/face_api/face_api_pipeline.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_controller.dart';

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

void main() {
  test('the three networks are loaded once and shared by every scan in the session', () async {
    var loads = 0;
    final c = ProviderContainer(overrides: [
      faceApiNetsProvider.overrideWith((ref) async {
        loads++;
        return _Nets();
      }),
    ]);
    addTearDown(c.dispose);
    final a = await c.read(faceApiNetsProvider.future);
    final b = await c.read(faceApiNetsProvider.future);
    await c.read(faceApiNetsProvider.future);
    expect(identical(a, b), isTrue);
    expect(loads, 1);
  });

  test('a cancelled capture stops asking the camera for more frames', () async {
    var taken = 0;
    var cancelled = false;
    final outcome = await FaceApiPipeline(_Nets()).capture(
      nextFrame: () async {
        taken++;
        cancelled = true; // user closes the screen after the first still
        return null;
      },
      framesToCapture: 3,
      interval: Duration.zero,
      isCancelled: () => cancelled,
    );
    expect(taken, 1);
    expect(outcome.descriptor, isNull);
  });
}

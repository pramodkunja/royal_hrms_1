import 'dart:math' as math;
import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'face_api_nets.dart';

// TFLite implementation of [FaceApiNets] (Android/iOS only — tflite_flutter
// needs dart:ffi; see face_embedding_model.dart's conditional export).

const kFaceApiModelDir = 'assets/face_api';

class TfliteFaceApiNets implements FaceApiNets {
  TfliteFaceApiNets._(this._det, this._lmk, this._rec, [this._recRef]);

  /// [threads] 1 keeps the library defaults untouched; >1 sets the CPU thread
  /// count on each interpreter (benchmark on a device before using it).
  ///
  /// [compareWithSingleThread] (diagnostics builds only) also loads a
  /// single-thread copy of the recognition net and records the largest
  /// distance between its descriptor and the multi-thread one for the same
  /// input in [faceApiNumericDiagnostics] — evidence for descriptor equality.
  static Future<TfliteFaceApiNets> load({int threads = 1, bool compareWithSingleThread = false}) async {
    Future<_Net> net(String file) async {
      final options = threads > 1 ? (InterpreterOptions()..threads = threads) : null;
      final interpreter = await Interpreter.fromAsset('$kFaceApiModelDir/$file', options: options);
      interpreter.allocateTensors();
      final isolate = await IsolateInterpreter.create(address: interpreter.address);
      return _Net(interpreter, isolate);
    }

    Future<_Net> single(String file) async {
      final interpreter = await Interpreter.fromAsset('$kFaceApiModelDir/$file');
      interpreter.allocateTensors();
      return _Net(interpreter, await IsolateInterpreter.create(address: interpreter.address));
    }

    return TfliteFaceApiNets._(
      await net('tiny_face_detector.tflite'),
      await net('face_landmark_68.tflite'),
      await net('face_recognition.tflite'),
      compareWithSingleThread && threads > 1 ? await single('face_recognition.tflite') : null,
    );
  }

  final _Net _det, _lmk, _rec;
  final _Net? _recRef;

  @override
  Future<Float32List> detect(Float32List rgb224) => _det.run(rgb224, 7 * 7 * 25);

  @override
  Future<Float32List> landmarks(Float32List rgb112) => _lmk.run(rgb112, 136);

  @override
  Future<Float32List> describe(Float32List rgb150) async {
    final out = await _rec.run(rgb150, 128);
    final ref = _recRef;
    if (ref != null) {
      final single = await ref.run(rgb150, 128);
      var sum = 0.0;
      for (var i = 0; i < 128; i++) {
        final d = out[i] - single[i];
        sum += d * d;
      }
      final delta = sum <= 0 ? 0.0 : math.sqrt(sum);
      final prev = faceApiNumericDiagnostics['thread_delta_max_e9'] ?? 0;
      faceApiNumericDiagnostics['thread_delta_max_e9'] = math.max(prev, (delta * 1e9).round());
      faceApiNumericDiagnostics['thread_delta_samples'] = (faceApiNumericDiagnostics['thread_delta_samples'] ?? 0) + 1;
    }
    return out;
  }

  @override
  Future<void> dispose() async {
    for (final n in [_det, _lmk, _rec, if (_recRef != null) _recRef]) {
      await n.close();
    }
  }
}

class _Net {
  _Net(this.interpreter, this.isolate);
  final Interpreter interpreter;
  final IsolateInterpreter isolate;

  // IsolateInterpreter silently skips a run while another is in flight, so
  // calls are chained one after another.
  Future<void> _queue = Future.value();

  Future<Float32List> run(Float32List input, int outputLength) {
    final result = _queue.then((_) async {
      final out = Float32List(outputLength);
      // Raw bytes in (no reshaping); ByteBuffer out (filled in place).
      await isolate.run(input.buffer.asUint8List(input.offsetInBytes, input.lengthInBytes), out.buffer);
      return out;
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<void> close() async {
    await isolate.close();
    interpreter.close();
  }
}

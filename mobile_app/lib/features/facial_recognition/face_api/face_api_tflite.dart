import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'face_api_nets.dart';

// TFLite implementation of [FaceApiNets] (Android/iOS only — tflite_flutter
// needs dart:ffi; see face_embedding_model.dart's conditional export).

const kFaceApiModelDir = 'assets/face_api';

class TfliteFaceApiNets implements FaceApiNets {
  TfliteFaceApiNets._(this._det, this._lmk, this._rec);

  static Future<TfliteFaceApiNets> load() async {
    Future<_Net> net(String file) async {
      final interpreter = await Interpreter.fromAsset('$kFaceApiModelDir/$file');
      interpreter.allocateTensors();
      final isolate = await IsolateInterpreter.create(address: interpreter.address);
      return _Net(interpreter, isolate);
    }

    return TfliteFaceApiNets._(
      await net('tiny_face_detector.tflite'),
      await net('face_landmark_68.tflite'),
      await net('face_recognition.tflite'),
    );
  }

  final _Net _det, _lmk, _rec;

  @override
  Future<Float32List> detect(Float32List rgb224) => _det.run(rgb224, 7 * 7 * 25);

  @override
  Future<Float32List> landmarks(Float32List rgb112) => _lmk.run(rgb112, 136);

  @override
  Future<Float32List> describe(Float32List rgb150) => _rec.run(rgb150, 128);

  @override
  Future<void> dispose() async {
    for (final n in [_det, _lmk, _rec]) {
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

// DEBUG-ONLY on-device check of the face-api.js TFLite models, through the
// app's own TfliteFaceApiNets (IsolateInterpreter, raw-buffer input/output):
//
//   1. copy inputs_150.f32 (24 × 150×150×3 float32, the same inputs the
//      face-api.js reference ran on) into the app's documents folder;
//   2. flutter run -d <device> -t lib/debug/face_api_check_main.dart
//   3. read face_api_check.json back from the documents folder.
//
// Reports model load time, per-network inference times and the 24 recognition
// descriptors. No camera, no network, no personal data. Not imported by
// lib/main.dart, so not part of the release app; refuses to run outside debug.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../features/facial_recognition/face_api/face_api_tflite.dart';

Future<Map<String, Object?>> _check() async {
  final dir = await getApplicationDocumentsDirectory();
  final sw = Stopwatch()..start();
  final nets = await TfliteFaceApiNets.load();
  final loadMs = sw.elapsedMilliseconds;

  final raw = await File('${dir.path}/inputs_150.f32').readAsBytes();
  final all = raw.buffer.asFloat32List(raw.offsetInBytes, raw.lengthInBytes ~/ 4);
  const per = 150 * 150 * 3;
  final n = all.length ~/ per;

  // Warm-up (first run allocates), then timed runs.
  await nets.describe(Float32List.fromList(all.sublist(0, per)));
  final descriptors = <List<double>>[];
  final recMs = <int>[];
  for (var i = 0; i < n; i++) {
    final input = Float32List.fromList(all.sublist(i * per, (i + 1) * per));
    sw.reset();
    final d = await nets.describe(input);
    recMs.add(sw.elapsedMilliseconds);
    descriptors.add(List<double>.from(d));
  }
  final detMs = <int>[], lmkMs = <int>[];
  final det = Float32List(224 * 224 * 3)..fillRange(0, 224 * 224 * 3, 128);
  final lmk = Float32List(112 * 112 * 3)..fillRange(0, 112 * 112 * 3, 128);
  await nets.detect(det);
  await nets.landmarks(lmk);
  for (var i = 0; i < 10; i++) {
    sw.reset();
    await nets.detect(det);
    detMs.add(sw.elapsedMilliseconds);
    sw.reset();
    await nets.landmarks(lmk);
    lmkMs.add(sw.elapsedMilliseconds);
  }
  await nets.dispose();
  double avg(List<int> v) => v.reduce((a, b) => a + b) / v.length;
  return {
    'platform': Platform.operatingSystemVersion,
    'loadMs': loadMs,
    'recognitionAvgMs': avg(recMs),
    'detectorAvgMs': avg(detMs),
    'landmarksAvgMs': avg(lmkMs),
    'descriptors': descriptors,
  };
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Debug builds only.')))));
    return;
  }
  runApp(const MaterialApp(home: _CheckPage()));
}

class _CheckPage extends StatefulWidget {
  const _CheckPage();
  @override
  State<_CheckPage> createState() => _CheckPageState();
}

class _CheckPageState extends State<_CheckPage> {
  String _status = 'Running face-api.js model check…';

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final r = await _check();
      final dir = await getApplicationDocumentsDirectory();
      await File('${dir.path}/face_api_check.json').writeAsString(jsonEncode(r));
      final summary = 'FACE_API_CHECK load=${r['loadMs']}ms rec=${r['recognitionAvgMs']}ms '
          'det=${r['detectorAvgMs']}ms lmk=${r['landmarksAvgMs']}ms n=${(r['descriptors'] as List).length}';
      debugPrint(summary);
      setState(() => _status = summary);
    } catch (e, s) {
      debugPrint('FACE_API_CHECK failed: $e\n$s');
      setState(() => _status = 'Failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
          body: Center(
              child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(_status, key: const Key('face-api-check-status')),
      )));
}

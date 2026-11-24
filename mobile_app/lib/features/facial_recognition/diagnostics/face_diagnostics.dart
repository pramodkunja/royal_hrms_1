import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/capture/face_capture_controller.dart' show lastFaceModelLoadMs;
import '../presentation/capture/face_capture_state.dart';

/// Whether the technical diagnostics panel exists at all. Always false here;
/// `main.dart` turns it on only for a debug build started with
/// `--dart-define=FACE_DIAGNOSTICS=true`, so a release build can never show it.
final faceDiagnosticsEnabledProvider = Provider<bool>((_) => false);

/// One verification attempt, reduced to non-sensitive technical facts:
/// stage durations in milliseconds, the descriptor LENGTH (never its values),
/// a sanitised failure category and a stage name. No images, descriptors,
/// tokens, names, ids or server messages are ever kept.
class FaceDiagnosticsReport {
  const FaceDiagnosticsReport({
    this.timingsMs = const {},
    this.descriptorLength,
    this.backendMs,
    this.stage = 'not started',
    this.failureCategory,
    this.modelLoadMs,
  });

  final Map<String, int> timingsMs;
  final int? descriptorLength;
  final int? backendMs;
  final String stage;
  final String? failureCategory;
  final int? modelLoadMs;

  int? get totalMs {
    final capture = timingsMs['descriptor_done'];
    if (capture == null) return null;
    return capture + (backendMs ?? 0);
  }

  FaceDiagnosticsReport copyWith({
    Map<String, int>? timingsMs,
    int? descriptorLength,
    int? backendMs,
    String? stage,
    String? failureCategory,
    int? modelLoadMs,
  }) =>
      FaceDiagnosticsReport(
        timingsMs: timingsMs ?? this.timingsMs,
        descriptorLength: descriptorLength ?? this.descriptorLength,
        backendMs: backendMs ?? this.backendMs,
        stage: stage ?? this.stage,
        failureCategory: failureCategory ?? this.failureCategory,
        modelLoadMs: modelLoadMs ?? this.modelLoadMs,
      );

  /// Plain `name: value` lines — safe to paste into a ticket.
  String toCopyText() {
    String ms(int? v) => v == null ? 'n/a' : '$v ms';
    final t = timingsMs;
    return [
      'Face ID diagnostics (technical timings only)',
      'stage: $stage',
      'failure category: ${failureCategory ?? 'none'}',
      'model initialisation: ${modelLoadMs == null ? 'cached (loaded earlier this session)' : ms(modelLoadMs)}',
      'camera lookup (from open): ${ms(t['camera_lookup'])}',
      'camera ready (from open): ${ms(t['camera_ready'])}',
      'image stream started (from open): ${ms(t['stream_started'])}',
      'first frame received (from open): ${ms(t['first_frame'])}',
      'first face detection result (from open): ${ms(t['first_detection_result'])}',
      'liveness duration: ${ms(t['liveness_ms'])}',
      'still capture (sum): ${ms(t['still_capture_total'])}',
      'image preprocessing (sum): ${ms(t['preprocess_total'])}',
      'detect+landmark+descriptor inference (sum): ${ms(t['inference_total'])}',
      'liveness started (from open): ${ms(t['liveness_started'])}',
      'liveness passed (from open): ${ms(t['liveness_passed'])}',
      'stop image stream: ${ms(t['stop_stream_ms'])}',
      'stills taken: ${t['stills_taken'] ?? 'n/a'} (first still ${ms(t['still_first'])}), frames analysed: ${t['frames_analysed'] ?? 'n/a'}',
      'worker: decode ${ms(t['decode_total'])}, scale ${ms(t['scale_total'])}, CLAHE ${ms(t['clahe_total'])}',
      'networks: detector ${ms(t['detect_total'])}, landmarks ${ms(t['landmarks_total'])}, descriptor ${ms(t['describe_total'])}',
      'quality gate ${ms(t['quality_total'])}, averaging ${ms(t['average_total'])}',
      'frames: received ${t['frames_received'] ?? 'n/a'}, processed ${t['frames_processed'] ?? 'n/a'}, dropped (busy) ${t['frames_dropped_busy'] ?? 'n/a'}, no-face ${t['no_face_frames'] ?? 'n/a'}, multi-face ${t['multi_face_frames'] ?? 'n/a'}, stability resets ${t['stable_resets'] ?? 'n/a'}',
      'face detector per frame: mean ${ms(t['detect_mean_ms'])}, max ${ms(t['detect_max_ms'])}; gap between results: mean ${ms(t['detect_gap_mean_ms'])}, max ${ms(t['detect_gap_max_ms'])}',
      'JPEG→RGBA convert (orientation): ${ms(t['convert_total'])}',
      if (t.containsKey('thread_delta_max_e9')) 'thread equality: max descriptor delta ${t['thread_delta_max_e9']} e-9 over ${t['thread_delta_samples']} descriptors',
      if (t.containsKey('native_decode_ms'))
        'decoder compare: native ${ms(t['native_decode_ms'])} vs dart ${ms(t['dart_decode_ms'])}; dims equal ${t['cmp_dims_equal']} (native ${t['cmp_native_w']}x${t['cmp_native_h']}, dart ${t['cmp_dart_w']}x${t['cmp_dart_h']}); mean abs diff ${t['cmp_mean_x1000'] == null ? 'n/a' : (t['cmp_mean_x1000']! / 1000).toStringAsFixed(3)}, max ${t['cmp_max'] ?? 'n/a'}, >2 levels ${t['cmp_pct_over2_x100'] == null ? 'n/a' : (t['cmp_pct_over2_x100']! / 100).toStringAsFixed(2)}%',
      'capture finished (from open): ${ms(t['descriptor_done'])}',
      'descriptor length: ${descriptorLength ?? 'n/a'}',
      'backend response: ${ms(backendMs)}',
      'total verification: ${ms(totalMs)}',
    ].join('\n');
  }
}

class FaceDiagnosticsNotifier extends Notifier<FaceDiagnosticsReport> {
  @override
  FaceDiagnosticsReport build() => const FaceDiagnosticsReport();

  void reset() => state = const FaceDiagnosticsReport(stage: 'face capture opened');

  /// From the capture result: timings, descriptor length and (if it failed
  /// before the backend) the category.
  void recordCapture(FaceCaptureUiState s) {
    state = FaceDiagnosticsReport(
      timingsMs: Map.of(s.timingsMs),
      descriptorLength: s.embedding?.length,
      stage: s.embedding != null ? 'captured, awaiting backend' : 'capture ended: ${s.phase.name}',
      failureCategory: switch (s.phase) {
        FaceCapturePhase.livenessFailed => 'liveness incomplete',
        FaceCapturePhase.qualityFailed => 'capture quality',
        FaceCapturePhase.cameraDenied => 'camera permission',
        FaceCapturePhase.error => 'camera or capture error',
        _ => null,
      },
      modelLoadMs: lastFaceModelLoadMs,
    );
  }

  void recordBackend({required int ms, required String? error}) {
    state = state.copyWith(
      backendMs: ms,
      stage: error == null ? 'backend accepted' : 'backend refused',
      failureCategory: error == null ? null : categorizeFaceFailure(error),
    );
  }
}

final faceDiagnosticsProvider =
    NotifierProvider<FaceDiagnosticsNotifier, FaceDiagnosticsReport>(FaceDiagnosticsNotifier.new);

/// Whole-flow timeline of one Clock In/Out (milliseconds since the button was
/// pressed): numbers only. Filled only when diagnostics are enabled.
class FaceFlowNotifier extends Notifier<Map<String, int>> {
  final Stopwatch _watch = Stopwatch();

  @override
  Map<String, int> build() => const {};

  void start() {
    _watch
      ..reset()
      ..start();
    state = const {'pressed': 0};
  }

  void mark(String name) {
    if (!_watch.isRunning) return;
    state = {...state, name: _watch.elapsedMilliseconds};
  }

  String toCopyText() {
    if (state.isEmpty) return 'whole flow: n/a';
    final lines = <String>['whole flow (ms since Clock In/Out pressed):'];
    for (final e in state.entries) {
      lines.add('  ${e.key}: ${e.value} ms');
    }
    return lines.join('\n');
  }
}

final faceFlowProvider = NotifierProvider<FaceFlowNotifier, Map<String, int>>(FaceFlowNotifier.new);

/// A server/refusal message reduced to a fixed category word. The message
/// itself is discarded, so nothing personal can reach the report.
String categorizeFaceFailure(String message) {
  final m = message.toLowerCase();
  if (m.contains('too many failed') || m.contains('please wait')) return 'server lockout / attempt cap';
  if (m.contains('trying again right now')) return 'low-confidence rejection (hard block)';
  if (m.contains('couldn\'t match your face') || m.contains('could not match')) return 'identity mismatch';
  if (m.contains('liveness')) return 'backend liveness rejection';
  if (m.contains('already used')) return 'replay rejection';
  if (m.contains('registration') && (m.contains('mandatory') || m.contains('don'))) {
    return 'registration unavailable';
  }
  if (m.contains('cannot reach server') || m.contains('connection')) return 'network failure';
  if (m.contains('server error')) return 'server error';
  if (m.contains('session expired')) return 'authentication';
  if (m.contains('cancelled')) return 'cancelled by user';
  return 'other backend refusal';
}

/// Debug-only sheet with the report and a Copy action.
Future<void> showFaceDiagnosticsSheet(BuildContext context, FaceDiagnosticsReport report, {String? flowText}) {
  final text = flowText == null ? report.toCopyText() : '${report.toCopyText()}\n$flowText';
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Face ID diagnostics (debug build)', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Flexible(child: SingleChildScrollView(child: SelectableText(text))),
            const SizedBox(height: 8),
            Row(
              children: [
                FilledButton.icon(
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Diagnostics'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: text));
                    if (ctx.mounted) {
                      ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(const SnackBar(content: Text('Diagnostics copied')));
                    }
                  },
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

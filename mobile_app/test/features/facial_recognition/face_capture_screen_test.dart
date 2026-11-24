import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_controller.dart';
import 'package:mobile_app/features/facial_recognition/presentation/capture/face_capture_state.dart';
import 'package:mobile_app/features/facial_recognition/presentation/widgets/face_capture_bottom_sheet.dart';

class _Fixed extends FaceCaptureController {
  _Fixed(this.initial);
  final FaceCaptureUiState initial;
  int starts = 0;
  @override
  FaceCaptureUiState build() => initial;
  @override
  Future<void> start({int? framesToCapture, livenessMode}) async => starts++;
  @override
  Future<void> retry() async => starts++;
}

Future<_Fixed> _open(
  WidgetTester t, {
  required FaceCaptureUiState state,
  Size size = const Size(393, 852),
  double scale = 1,
  String? consent,
  List<FaceCaptureSheetResult?>? results,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final fake = _Fixed(state);
  await t.pumpWidget(ProviderScope(
    overrides: [faceCaptureControllerProvider.overrideWith(() => fake)],
    child: MaterialApp(
      builder: (c, child) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: Builder(
        builder: (c) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () async {
                final r = await showFaceCaptureSheet(
                  c,
                  title: 'Verify',
                  subtitle: 'Verify it is you',
                  consentNoticeText: consent,
                );
                results?.add(r);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  ));
  await t.tap(find.text('open'));
  await t.pump();
  await t.pump(const Duration(milliseconds: 500));
  return fake;
}

void main() {
  const sizes = [Size(320, 640), Size(360, 740), Size(393, 852), Size(430, 932)];
  const states = {
    'initialising': FaceCaptureUiState(phase: FaceCapturePhase.initializingCamera),
    'detecting': FaceCaptureUiState(phase: FaceCapturePhase.detecting),
    'liveness': FaceCaptureUiState(
      phase: FaceCapturePhase.livenessChecking,
      liveHint: 'Please blink naturally AND turn your head slightly',
      blinkRequired: true,
      livenessSecondsLeft: 7,
    ),
    'liveness-failed': FaceCaptureUiState(
        phase: FaceCapturePhase.livenessFailed, message: 'Let\'s try once more — turn your head slightly to one side, then back.'),
    'denied': FaceCaptureUiState(phase: FaceCapturePhase.cameraDenied, message: 'Camera permission is required to continue.'),
    'error': FaceCaptureUiState(phase: FaceCapturePhase.error, message: 'Could not start the camera.'),
  };

  for (final size in sizes) {
    for (final scale in const [1.0, 1.5, 2.0]) {
      for (final e in states.entries) {
        testWidgets('${e.key} fits at ${size.width.toInt()}x${size.height.toInt()} @${scale}x text', (t) async {
          await _open(t, state: e.value, size: size, scale: scale);
          expect(t.takeException(), isNull, reason: 'no overflow / layout error');
          expect(find.text('Face ID Check'), findsOneWidget);
          expect(find.text('Cancel'), findsOneWidget);
        });
      }
    }
  }

  testWidgets('full-screen route, not a bottom sheet; Face ID Check title + back control', (t) async {
    await _open(t, state: states['detecting']!);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(find.byType(FaceCaptureScreen), findsOneWidget);
    expect(find.byType(BackButton).evaluate().isNotEmpty || find.byIcon(Icons.arrow_back_ios_new_rounded).evaluate().isNotEmpty,
        isTrue);
  });

  testWidgets('Cancel pops with null result and starts the camera once', (t) async {
    final results = <FaceCaptureSheetResult?>[];
    final fake = await _open(t, state: states['detecting']!, results: results);
    expect(fake.starts, 1);
    await t.tap(find.text('Cancel'));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(results, [null]);
    expect(find.byType(FaceCaptureScreen), findsNothing);
  });

  testWidgets('app-bar back also cancels', (t) async {
    final results = <FaceCaptureSheetResult?>[];
    await _open(t, state: states['detecting']!, results: results);
    await t.tap(find.byIcon(Icons.arrow_back_ios_new_rounded));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(results, [null]);
  });

  testWidgets('registration: consent first, camera does not start until acknowledged', (t) async {
    final fake = await _open(t, state: states['detecting']!, consent: 'We store a numeric signature.');
    expect(find.text('Biometric data consent'), findsOneWidget);
    expect(fake.starts, 0);
  });

  testWidgets('liveness shows step progress and time left', (t) async {
    await _open(t, state: states['liveness']!);
    expect(find.text('Blink'), findsOneWidget);
    expect(find.text('Turn head'), findsOneWidget);
    expect(find.text('7s left'), findsOneWidget);
  });

  testWidgets('failed liveness offers Try again (retry restarts the camera)', (t) async {
    final fake = await _open(t, state: states['liveness-failed']!);
    await t.tap(find.text('Try again'));
    await t.pump();
    expect(fake.starts, 2);
  });

  testWidgets('stage labels follow the real stage (no false success, no stuck "Confirming")', (t) async {
    await _open(t, state: const FaceCaptureUiState(phase: FaceCapturePhase.initializingCamera));
    expect(find.text('Opening camera…'), findsOneWidget);
  });

  testWidgets('liveness stage names the step still missing', (t) async {
    await _open(
      t,
      state: const FaceCaptureUiState(phase: FaceCapturePhase.livenessChecking, blinkRequired: true, blinkSeen: true),
    );
    expect(find.text('Turn your head slightly'), findsWidgets);
    expect(find.textContaining('Confirming'), findsNothing);
  });

  testWidgets('captured is not shown as success before the backend answers', (t) async {
    await _open(t, state: const FaceCaptureUiState(phase: FaceCapturePhase.extractingEmbedding));
    expect(find.textContaining('verified'), findsNothing);
    expect(find.textContaining('successful'), findsNothing);
  });
}

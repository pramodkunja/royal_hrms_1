import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/router/modal_route_tracker.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/voice_commands/presentation/controllers/voice_command_controller.dart';
import 'package:mobile_app/features/voice_commands/presentation/providers/voice_mute_provider.dart';
import 'package:mobile_app/features/voice_commands/presentation/state/voice_conversation_state.dart';
import 'package:mobile_app/features/voice_commands/presentation/widgets/animated_voice_assistant.dart';
import 'package:mobile_app/features/voice_commands/presentation/widgets/voice_mic_overlay.dart';

// Task C1 — HO-02 / HO-03 (device audit 17 Nov 2026): the voice robot is
// mounted ABOVE the router's Navigator (lib/app/app.dart builder Stack), so
// it was drawn over every dialog, date picker and bottom sheet and took
// their taps — on the phone, a date picker's OK started a microphone
// recording. It also sat over values and buttons on most screens.
// Now: it hides while any popup route is open (ModalRouteTracker observes
// the navigators), hides while the keyboard is up (idle only), releases the
// mic if a modal opens mid-recording, starts folded into a slim edge handle
// with a hide control and auto-collapse, never re-records on its own, and
// ignores a second start while already recording.
// The harness reproduces the app's real layering: Overlay above Navigator.

UserEntity _user() => const UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: ['leave.view'],
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthState(user: _user());
}

class _Muted extends VoiceMutedNotifier {
  @override
  bool build() => true;
}

/// Plugin channel calls seen during a test (speech, recorder, player).
final channelCalls = <String>[];
bool speechInitResult = true;

void _stubChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global', 'com.llfbandit.record/messages']) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
      channelCalls.add('$name:${call.method}');
      return null;
    });
  }
  messenger.setMockMethodCallHandler(const MethodChannel('plugin.csdcorp.com/speech_to_text'), (call) async {
    channelCalls.add('speech:${call.method}');
    if (call.method == 'initialize') return speechInitResult;
    if (call.method == 'listen') return true;
    if (call.method == 'has_permission') return true;
    return null;
  });
}

/// Calls that touch the microphone (construction/disposal of the plugin
/// objects is not recording).
List<String> micCalls() => [
      for (final c in channelCalls)
        if (c.startsWith('speech:') ||
            (c.startsWith('com.llfbandit.record') && !c.endsWith(':create') && !c.endsWith(':dispose')))
          c
    ];

/// A controller that is already mid-recording, to check what a modal does.
class _ListeningController extends VoiceCommandController {
  bool closed = false;
  @override
  // No super.build(): this fake never touches the speech/recorder plugins
  // (the guard in startListening returns first, close() is overridden), and
  // creating the shared speech_to_text singleton here would leave it
  // cancelled for later tests.
  VoiceConversationState? build() {
    return const VoiceConversationState(phase: VoicePanelPhase.listening);
  }

  @override
  void close() {
    closed = true;
    state = null;
  }
}

late ProviderContainer container;
DateTime? pickedDate;
int sheetTaps = 0;
int bottomRightTaps = 0;
int dialogOkTaps = 0;

Future<void> pumpApp(WidgetTester tester, {List<Override> extra = const []}) async {
  tester.view.physicalSize = const Size(720, 1640);
  tester.view.devicePixelRatio = 1.75;
  addTearDown(tester.view.reset);
  pickedDate = null;
  sheetTaps = 0;
  bottomRightTaps = 0;
  dialogOkTaps = 0;
  container = ProviderContainer(overrides: [
    authStateProvider.overrideWith(_Auth.new),
    voiceMutedProvider.overrideWith(_Muted.new),
    ...extra,
  ]);
  addTearDown(container.dispose);
  final tracker = container.read(modalRouteTrackerProvider);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      navigatorObservers: [tracker.newObserver()],
      // Same layering as lib/app/app.dart: the voice overlay ABOVE the Navigator.
      builder: (context, child) => Stack(children: [
        child!,
        Positioned.fill(child: Overlay(initialEntries: [OverlayEntry(builder: (_) => const VoiceMicOverlay())])),
      ]),
      home: Builder(
        builder: (context) => Scaffold(
          body: Column(children: [
            const SizedBox(height: 80),
            ElevatedButton(
              key: const Key('open-date'),
              onPressed: () async => pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime(2026, 11, 24),
                firstDate: DateTime(2026, 1, 1),
                lastDate: DateTime(2027, 12, 31),
              ),
              child: const Text('Pick date'),
            ),
            ElevatedButton(
              key: const Key('open-dialog'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Material(
                      child: TextButton(
                        key: const Key('dialog-ok'),
                        onPressed: () {
                          dialogOkTaps++;
                          Navigator.of(context).pop();
                        },
                        child: const Text('Dialog OK'),
                      ),
                    ),
                  ),
                ),
              ),
              child: const Text('Open dialog'),
            ),
            ElevatedButton(
              key: const Key('open-sheet'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                builder: (_) => SizedBox(
                  height: 200,
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: TextButton(
                      key: const Key('sheet-action'),
                      onPressed: () => sheetTaps++,
                      child: const Text('Sheet action'),
                    ),
                  ),
                ),
              ),
              child: const Text('Open sheet'),
            ),
            const TextField(key: Key('field')),
          ]),
          // A real screen action at the bottom-right, where the robot rests.
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('bottom-right-action'),
            onPressed: () => bottomRightTaps++,
            label: const Text('Save'),
          ),
        ),
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

final handle = find.byKey(const ValueKey('voice-mic-handle'));
final robot = find.byType(AnimatedVoiceAssistant);

Future<void> expandRobot(WidgetTester tester) async {
  await tester.tap(handle);
  await settle(tester);
  expect(robot, findsOneWidget);
}

Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    _stubChannels();
  });
  setUp(() {
    channelCalls.clear();
    speechInitResult = true;
  });

  group('collapse / hide (HO-03)', () {
    testWidgets('starts folded into a slim edge handle; no robot, no mic', (tester) async {
      await pumpApp(tester);
      expect(handle, findsOneWidget);
      expect(robot, findsNothing);
      final r = tester.getRect(handle);
      expect(r.right, closeTo(411.43, 0.5)); // flush with the right edge
      expect(r.width, lessThanOrEqualTo(20)); // inside the 16 dp page margin + 4
      expect(micCalls(), isEmpty);
      await unmount(tester);
    });

    testWidgets('accessibility: the handle and hide control are their own small nodes (not the whole screen)',
        (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(tester);
      final handleNode = tester.getSemantics(find.bySemanticsLabel('Show voice assistant'));
      expect(handleNode.rect.width * handleNode.rect.height, lessThan(30 * 70), reason: 'on device it spanned the screen');
      await tester.tap(handle);
      await settle(tester);
      final hideNode = tester.getSemantics(find.bySemanticsLabel('Hide voice assistant'));
      expect(hideNode.rect.width, lessThan(40));
      semantics.dispose();
      await unmount(tester);
    });

    testWidgets('HO-23: both robot controls are their own semantics containers (fails if container:true is dropped)',
        (tester) async {
      await pumpApp(tester);
      Semantics semanticsLabelled(String label) => tester.widget<Semantics>(find.byWidgetPredicate(
          (w) => w is Semantics && w.properties.label == label));
      // On the phone, without container:true the label merged into the
      // full-screen overlay node ([0,0][720,1640]); the test harness does not
      // reproduce that merge, so check the configuration that prevents it.
      expect(semanticsLabelled('Show voice assistant').container, isTrue);
      await tester.tap(handle);
      await settle(tester);
      expect(semanticsLabelled('Hide voice assistant').container, isTrue);
      await unmount(tester);
    });

    testWidgets('HO-03: a touch outside the expanded robot folds it away — and the touched control still works',
        (tester) async {
      await pumpApp(tester);
      await expandRobot(tester);
      await tester.tap(find.byKey(const Key('open-dialog')));
      await settle(tester);
      expect(find.byKey(const Key('dialog-ok')), findsOneWidget, reason: 'the tap reached the button');
      Navigator.of(tester.element(find.byKey(const Key('dialog-ok')))).pop();
      await settle(tester);
      expect(robot, findsNothing, reason: 'robot folded away');
      expect(handle, findsOneWidget);
      await unmount(tester);
    });

    testWidgets('HO-03: touching the robot itself does not fold it', (tester) async {
      await pumpApp(tester);
      await expandRobot(tester);
      final g = await tester.startGesture(tester.getCenter(robot));
      await tester.pump(const Duration(milliseconds: 50));
      await g.moveBy(const Offset(0, -40));
      await g.up();
      await settle(tester);
      expect(robot, findsOneWidget);
      await unmount(tester);
    });

    testWidgets('handle → robot; hide control → handle; tapping the handle never starts listening', (tester) async {
      await pumpApp(tester);
      await expandRobot(tester);
      expect(container.read(voiceCommandControllerProvider), isNull);
      expect(micCalls(), isEmpty);
      await tester.tap(find.byKey(const ValueKey('voice-mic-hide')));
      await settle(tester);
      expect(robot, findsNothing);
      expect(handle, findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an untouched robot folds itself away after the auto-collapse delay', (tester) async {
      await pumpApp(tester);
      await expandRobot(tester);
      await tester.pump(kVoiceBubbleAutoCollapse + const Duration(milliseconds: 100));
      await settle(tester);
      expect(robot, findsNothing);
      expect(handle, findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the folded handle leaves the bottom-right Save action tappable', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('bottom-right-action')));
      await settle(tester);
      expect(bottomRightTaps, 1);
      await unmount(tester);
    });

    testWidgets('taps outside the robot\'s bounds reach the screen underneath', (tester) async {
      await pumpApp(tester);
      await expandRobot(tester);
      final robotRect = tester.getRect(robot);
      final pick = tester.getRect(find.byKey(const Key('open-dialog')));
      expect(robotRect.overlaps(pick), isFalse);
      await tester.tap(find.byKey(const Key('open-dialog')));
      await settle(tester);
      expect(find.byKey(const Key('dialog-ok')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('modal UI always gets its own taps (HO-02)', () {
    testWidgets('date picker: robot and handle hidden while open; OK confirms the date; no recording', (tester) async {
      await pumpApp(tester);
      await expandRobot(tester);
      await tester.tap(find.byKey(const Key('open-date')));
      await settle(tester);
      expect(container.read(modalRouteTrackerProvider).isModalOpen, isTrue);
      expect(robot, findsNothing);
      expect(handle, findsNothing);
      await tester.tap(find.text('26'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await settle(tester);
      expect(pickedDate, DateTime(2026, 11, 26));
      expect(container.read(voiceCommandControllerProvider), isNull);
      expect(micCalls(), isEmpty);
      // Back after the picker closes.
      expect(container.read(modalRouteTrackerProvider).isModalOpen, isFalse);
      expect(robot.evaluate().isNotEmpty || handle.evaluate().isNotEmpty, isTrue);
      await unmount(tester);
    });

    testWidgets('dialog with its button exactly where the robot rests: the button gets the tap', (tester) async {
      await pumpApp(tester);
      await expandRobot(tester);
      final robotRect = tester.getRect(robot);
      await tester.tap(find.byKey(const Key('open-dialog')));
      await settle(tester);
      final ok = tester.getRect(find.byKey(const Key('dialog-ok')));
      expect(ok.overlaps(robotRect), isTrue, reason: 'the scenario seen on the phone');
      await tester.tap(find.byKey(const Key('dialog-ok')));
      await settle(tester);
      expect(dialogOkTaps, 1);
      expect(container.read(voiceCommandControllerProvider), isNull);
      await unmount(tester);
    });

    testWidgets('bottom sheet: hidden while open; the sheet\'s bottom-right action is tappable', (tester) async {
      await pumpApp(tester);
      await expandRobot(tester);
      await tester.tap(find.byKey(const Key('open-sheet')));
      await settle(tester);
      expect(robot, findsNothing);
      expect(handle, findsNothing);
      await tester.tap(find.byKey(const Key('sheet-action')));
      await settle(tester);
      expect(sheetTaps, 1);
      Navigator.of(tester.element(find.byKey(const Key('sheet-action')))).pop();
      await settle(tester);
      expect(container.read(modalRouteTrackerProvider).isModalOpen, isFalse);
      expect(robot.evaluate().isNotEmpty || handle.evaluate().isNotEmpty, isTrue);
      await unmount(tester);
    });

    testWidgets('a modal opening mid-recording releases the microphone', (tester) async {
      late _ListeningController fake;
      await pumpApp(tester, extra: [
        voiceCommandControllerProvider.overrideWith(() => fake = _ListeningController()),
      ]);
      expect(container.read(voiceCommandControllerProvider)?.phase, VoicePanelPhase.listening);
      await tester.tap(find.byKey(const Key('open-sheet')));
      await settle(tester);
      expect(fake.closed, isTrue);
      expect(container.read(voiceCommandControllerProvider), isNull);
      await unmount(tester);
    });
  });

  group('keyboard', () {
    testWidgets('idle assistant hidden while the keyboard is up, back when it closes', (tester) async {
      await pumpApp(tester);
      expect(handle, findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 500);
      await settle(tester);
      expect(handle, findsNothing);
      expect(robot, findsNothing);
      tester.view.resetViewInsets();
      await settle(tester);
      expect(handle, findsOneWidget);
      await unmount(tester);
    });
  });

  group('no accidental or repeated listening', () {
    testWidgets('a second start while already recording does not reopen the mic', (tester) async {
      await pumpApp(tester, extra: [voiceCommandControllerProvider.overrideWith(_ListeningController.new)]);
      await container.read(voiceCommandControllerProvider.notifier).startListening();
      expect(micCalls().where((c) => c == 'speech:initialize' || c == 'speech:listen'), isEmpty);
      await unmount(tester);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/voice_commands/presentation/controllers/voice_command_controller.dart';
import 'package:mobile_app/features/voice_commands/presentation/providers/voice_mute_provider.dart';
import 'package:mobile_app/features/voice_commands/presentation/state/voice_conversation_state.dart';

// Task C1 — HO-02: on the device, an accidental tap opened the mic, nothing
// was heard, and the assistant then recorded a SECOND clip by itself
// ("Listening again"). Now hearing nothing ends with "Didn't catch that"
// and no further recording; the user taps again if they meant it.
// Its own file: speech_to_text is a process-wide singleton, and a
// controller disposed by an earlier test in the same isolate leaves it
// cancelled. Plugin channels are stubbed; nothing records.

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'u1',
          email: 'u@example.test',
          fullName: 'Test User',
          role: 'employee',
          roleDisplay: 'Employee',
          mustChangePassword: false,
          permissions: ['leave.view'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

class _Muted extends VoiceMutedNotifier {
  @override
  bool build() => true;
}

final calls = <String>[];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global', 'com.llfbandit.record/messages']) {
      messenger.setMockMethodCallHandler(MethodChannel(name), (call) async {
        calls.add('$name:${call.method}');
        return null;
      });
    }
    messenger.setMockMethodCallHandler(const MethodChannel('plugin.csdcorp.com/speech_to_text'), (call) async {
      calls.add('speech:${call.method}');
      return call.method == 'initialize' || call.method == 'listen' || call.method == 'has_permission' ? true : null;
    });
  });

  testWidgets('hearing nothing ends with "Didn\'t catch that" — no automatic second recording', (tester) async {
    final container = ProviderContainer(overrides: [
      authStateProvider.overrideWith(_Auth.new),
      voiceMutedProvider.overrideWith(_Muted.new),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MaterialApp(home: SizedBox())));
    await container.read(authStateProvider.future);

    final controller = container.read(voiceCommandControllerProvider.notifier);
    await controller.startListening();
    expect(container.read(voiceCommandControllerProvider)?.phase, VoicePanelPhase.listening);

    // The speech engine reports it stopped with no result.
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      'plugin.csdcorp.com/speech_to_text',
      const StandardMethodCodec().encodeMethodCall(const MethodCall('notifyStatus', 'doneNoResult')),
      (_) {},
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 80));
    }

    final s = container.read(voiceCommandControllerProvider);
    expect(s?.phase, VoicePanelPhase.result);
    expect(s?.message, contains("Didn't catch that"));
    final recorderUse = calls.where((c) =>
        c.startsWith('com.llfbandit.record') && !c.endsWith(':create') && !c.endsWith(':dispose'));
    expect(recorderUse, isEmpty, reason: 'no fallback clip recorded');
    expect(calls.where((c) => c == 'speech:listen'), hasLength(1));

    // A second start while the first is still recording is ignored.
    controller.close();
    await controller.startListening();
    final listens = calls.where((c) => c == 'speech:listen').length;
    await controller.startListening(); // already listening → ignored
    expect(calls.where((c) => c == 'speech:listen').length, listens);
    controller.close();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}

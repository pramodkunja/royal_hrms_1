import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/voice_commands/domain/entities/voice_result_entity.dart';
import 'package:mobile_app/features/voice_commands/domain/entities/voice_transcribe_fallback_entity.dart';
import 'package:mobile_app/features/voice_commands/domain/repositories/voice_repository.dart';
import 'package:mobile_app/features/voice_commands/presentation/controllers/voice_command_controller.dart';
import 'package:mobile_app/features/voice_commands/presentation/providers/voice_access_provider.dart';
import 'package:mobile_app/features/voice_commands/presentation/providers/voice_mute_provider.dart';
import 'package:mobile_app/features/voice_commands/presentation/providers/voice_providers.dart';
import 'package:mobile_app/features/voice_commands/presentation/widgets/animated_voice_assistant.dart';
import 'package:mobile_app/features/voice_commands/presentation/widgets/voice_mic_overlay.dart';

UserEntity _user({bool mustChangePassword = false, String onboardingStatus = 'complete'}) => UserEntity(
      id: 'u-1',
      email: 'temp@example.com',
      fullName: 'Temp User',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: mustChangePassword,
      permissions: const ['attendance.view'],
      onboardingStatus: onboardingStatus,
      companyCode: 'ROYAL01',
    );

/// Counts every voice backend call. parse() answers a plain, finished result
/// so an allowed submission completes without needing audio or location.
class _FakeVoiceRepository implements VoiceRepository {
  final List<String> parsed = [];
  int transcribeCalls = 0;
  int speakCalls = 0;

  int get totalCalls => parsed.length + transcribeCalls + speakCalls;

  @override
  Future<VoiceResultEntity> parse({
    required String transcript,
    String lang = 'en',
    double? latitude,
    double? longitude,
    List<double>? faceEmbedding,
    bool? livenessPassed,
    double? livenessScore,
    String? captureSessionId,
    double? sttLanguageProbability,
    bool? sttUsedLanguageHint,
    String? sttDetectedLanguage,
  }) async {
    parsed.add(transcript);
    return const VoiceResultEntity(
      intent: 'check_leave_balance',
      confidence: 0.98,
      result: null,
      message: 'You have 12 days of casual leave.',
      conversational: false,
      awaitingInput: false,
      success: true,
      language: 'en',
    );
  }

  @override
  Future<VoiceTranscribeFallbackEntity> transcribeFallback({
    required Uint8List audioBytes,
    String filename = 'clip.wav',
    String contentType = 'audio/wav',
  }) {
    transcribeCalls++;
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> speak({required String text, required String languageCode}) async {
    speakCalls++;
    return Uint8List(0);
  }
}

/// Auth repository for the fresh-login scenario: the cached user and the
/// next login response are scripted.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.cached});

  UserEntity? cached;
  UserEntity? nextLogin;

  @override
  Future<UserEntity?> getCachedUser() async => cached;

  @override
  Future<UserEntity> login(String companyCode, String email, String password) async => nextLogin!;

  @override
  Future<void> logout() async => cached = null;

  @override
  Future<void> clearSession() async => cached = null;

  @override
  Future<void> forgotPassword(String companyCode, String email) => throw UnimplementedError();

  @override
  Future<String> verifyOtp(String companyCode, String email, String otp) => throw UnimplementedError();

  @override
  Future<void> resetPassword(String companyCode, String resetToken, String newPassword, String confirmPassword) =>
      throw UnimplementedError();
}

// Spoken replies are off so allowed submissions never reach audio playback.
class _MutedNotifier extends VoiceMutedNotifier {
  @override
  bool build() => true;
}

// VoiceCommandController creates its speech, audio-player and recorder
// plugins when built. flutter_test has no native side for them, so their
// channels answer with nothing — these tests never record or play audio.
void _stubVoicePluginChannels() {
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  for (final name in [
    'xyz.luan/audioplayers',
    'xyz.luan/audioplayers.global',
    'com.llfbandit.record/messages',
    'plugin.csdcorp.com/speech_to_text',
  ]) {
    messenger.setMockMethodCallHandler(MethodChannel(name), (_) async => null);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_stubVoicePluginChannels);

  group('isVoiceAssistantAllowed', () {
    test('a forced password change blocks voice, whatever else is true', () {
      expect(isVoiceAssistantAllowed(AuthState(user: _user(mustChangePassword: true))), isFalse);
    });

    test('the onboarding assessment gate blocks voice too (no way around it)', () {
      UserEntity gated({bool team = false, String assessment = 'pending'}) => UserEntity(
            id: 'u-1',
            email: 'temp@example.com',
            fullName: 'Temp User',
            role: 'employee',
            roleDisplay: 'Employee',
            mustChangePassword: false,
            permissions: const ['attendance.view'],
            onboardingStatus: 'complete',
            assessmentStatus: assessment,
            canManageTeam: team,
          );
      expect(isVoiceAssistantAllowed(AuthState(user: gated())), isFalse);
      // Released, or exempt from the gate: voice as usual.
      expect(isVoiceAssistantAllowed(AuthState(user: gated(assessment: 'complete'))), isTrue);
      expect(isVoiceAssistantAllowed(AuthState(user: gated(team: true))), isTrue);
    });

    test('a normal signed-in user may use voice', () {
      expect(isVoiceAssistantAllowed(AuthState(user: _user())), isTrue);
    });

    test('existing exclusions are unchanged: signed out, loading, onboarding, awaiting approval', () {
      expect(isVoiceAssistantAllowed(null), isFalse);
      expect(isVoiceAssistantAllowed(const AuthState.initial()), isFalse);
      expect(isVoiceAssistantAllowed(AuthState(user: _user(onboardingStatus: 'pending'))), isFalse);
      expect(isVoiceAssistantAllowed(AuthState(user: _user(onboardingStatus: 'submitted'))), isFalse);
    });
  });

  group('VoiceCommandController', () {
    late _FakeVoiceRepository voice;
    late _FakeAuthRepository auth;
    late ProviderContainer container;

    Future<VoiceCommandController> start({required UserEntity? cached}) async {
      voice = _FakeVoiceRepository();
      auth = _FakeAuthRepository(cached: cached);
      container = ProviderContainer(overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        voiceRepositoryProvider.overrideWithValue(voice),
        voiceMutedProvider.overrideWith(_MutedNotifier.new),
      ]);
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      return container.read(voiceCommandControllerProvider.notifier);
    }

    VoiceConversationStateSnapshot snapshot() =>
        VoiceConversationStateSnapshot(container.read(voiceCommandControllerProvider) != null);

    test('every entry point is refused while a password change is required', () async {
      final controller = await start(cached: _user(mustChangePassword: true));

      // Mic, keyboard, spoken transcript, typed answer / quick-action chip,
      // face-proof resubmission — none may open the panel or reach the API.
      await controller.startListening();
      controller.openTypedCommand();
      await controller.submitTranscript('clock me in');
      await controller.submitTranscript('clock me out', sourceIsVoice: false);
      controller.submitTypedAnswer('Clock In');
      await controller.submitFaceProofCapture(null);
      await Future<void>.delayed(Duration.zero);

      expect(snapshot().isOpen, isFalse);
      expect(voice.totalCalls, 0);
    });

    test('a normal user can still submit a voice command', () async {
      final controller = await start(cached: _user());

      await controller.submitTranscript('what is my leave balance');

      expect(voice.parsed, ['what is my leave balance']);
      expect(snapshot().isOpen, isTrue);
      controller.close();
    });

    test('voice becomes available only after a fresh login that clears the requirement', () async {
      final controller = await start(cached: _user(mustChangePassword: true));
      await controller.submitTranscript('clock me in');
      expect(voice.parsed, isEmpty);

      // The change ends the session; the user signs in again.
      final notifier = container.read(authStateProvider.notifier);
      await notifier.logout();
      expect(container.read(voiceAssistantAllowedProvider), isFalse);

      // A login that still reports the requirement keeps voice blocked.
      auth.nextLogin = _user(mustChangePassword: true);
      await notifier.login('ROYAL01', 'temp@example.com', 'Temp#Pass1');
      await controller.submitTranscript('clock me in');
      expect(voice.parsed, isEmpty);
      expect(container.read(voiceAssistantAllowedProvider), isFalse);

      // The login that confirms it is cleared restores voice.
      auth.nextLogin = _user();
      await notifier.login('ROYAL01', 'temp@example.com', 'N3w!Secure#Pass');
      expect(container.read(voiceAssistantAllowedProvider), isTrue);
      await controller.submitTranscript('clock me in');
      expect(voice.parsed, ['clock me in']);
      controller.close();
    });
  });

  group('VoiceMicOverlay', () {
    setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

    Future<void> pumpOverlay(WidgetTester tester, UserEntity user) async {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(cached: user)),
          voiceRepositoryProvider.overrideWithValue(_FakeVoiceRepository()),
          voiceMutedProvider.overrideWith(_MutedNotifier.new),
        ],
        child: const MaterialApp(home: Scaffold(body: Stack(children: [VoiceMicOverlay()]))),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets('the mic is hidden while a password change is required', (tester) async {
      await pumpOverlay(tester, _user(mustChangePassword: true));
      expect(find.byType(AnimatedVoiceAssistant), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the mic is shown for a normal signed-in user', (tester) async {
      await pumpOverlay(tester, _user());
      expect(find.byType(AnimatedVoiceAssistant), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}

/// Readable wrapper so assertions say "is the panel open", not "is state null".
class VoiceConversationStateSnapshot {
  const VoiceConversationStateSnapshot(this.isOpen);
  final bool isOpen;
}

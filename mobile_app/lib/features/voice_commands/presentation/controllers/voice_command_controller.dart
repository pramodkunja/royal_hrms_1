import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/network/api_client.dart' show parseDioException;
import '../providers/voice_mute_provider.dart';
import '../providers/voice_providers.dart';
import '../state/voice_conversation_state.dart';

// Silence-based auto-stop — same 5s window as
// frontend/hooks/useVoiceCommand.ts's SILENCE_TIMEOUT_MS, just delegated to
// speech_to_text's native pauseFor instead of a manual JS timer.
const _kPauseFor = Duration(seconds: 5);
const _kListenFor = Duration(seconds: 60);

// Fallback auto-close delays, used only when TTS is muted/unavailable and
// there's no speech completion to time dismissal to — mirrors web's
// IMMEDIATE_RESULT_AUTO_CLOSE_MS / CONVERSATION_AUTO_CLOSE_MS.
const _kImmediateAutoClose = Duration(milliseconds: 2500);
const _kConversationAutoClose = Duration(milliseconds: 4000);

const _kVoiceLang = 'en';
// en_IN, not en_US — the app's users are Indian-English speakers (seeded
// branches like Hyderabad, +91 phone formats throughout). Both Android's
// and iOS's speech engines ship a dedicated en-IN acoustic model that
// recognizes Indian-accented English far more accurately than en-US does;
// en_US was mis-transcribing common words/names as a result.
const _kVoiceLocale = 'en_IN';

// The two intents that ever hit PunchService.record_punch() server-side —
// only these can come back with the geofencing rejection below.
const _kClockIntents = {'clock_in', 'clock_out'};

// Verbatim match of backend/apps/attendance/services_geofencing.py's
// _validate_office rejection_message — the ONE rejection reason a
// client-side geolocation retry can actually fix. Matched exactly, not "any
// failure": other rejections from the same endpoint (outside the geofence,
// wrong branch, already clocked in, etc.) would just fail again identically
// with a fresh GPS reading.
const kGeofenceRequiredMessage =
    'Your location is required to clock in at this branch. '
    'Please allow location access in your browser and try again.';

const _kUnsupportedMessage = "Voice commands aren't supported on this device.";
const _kGenericErrorMessage = 'Could not process the voice command. Please try again.';

/// Drives the whole voice-command lifecycle: mic capture (speech_to_text),
/// submission to /api/voice/parse/, the reactive geolocation retry for
/// clock_in/clock_out, and spoken confirmation (flutter_tts). Conversation
/// state itself (which slot is still missing, etc.) lives server-side —
/// see backend/apps/voice_commands/conversation.py — this controller only
/// ever needs to know "is the last response awaiting a follow-up answer".
///
/// null state = idle, no panel shown. Non-null = the mic overlay renders its
/// expanded panel (see VoiceMicOverlay / VoiceConversationPanel).
class VoiceCommandController extends Notifier<VoiceConversationState?> {
  late final stt.SpeechToText _speech;
  late final FlutterTts _tts;
  bool _speechInitialized = false;
  Timer? _autoCloseTimer;

  @override
  VoiceConversationState? build() {
    _speech = stt.SpeechToText();
    _tts = FlutterTts();
    _tts.setLanguage(_kVoiceLocale.replaceAll('_', '-'));
    _tts.awaitSpeakCompletion(true);

    ref.onDispose(() {
      _autoCloseTimer?.cancel();
      _speech.cancel();
      _tts.stop();
    });

    return null;
  }

  Future<void> startListening() async {
    _autoCloseTimer?.cancel();

    if (!_speechInitialized) {
      _speechInitialized = await _speech.initialize(onStatus: _onSpeechStatus);
      if (!_speechInitialized) {
        _showTerminalError(_kUnsupportedMessage);
        return;
      }
    }

    // Stop any confirmation still playing before opening the mic — otherwise
    // recognition could pick up the assistant's own voice as input.
    await _tts.stop();

    state = const VoiceConversationState(phase: VoicePanelPhase.listening);

    await _speech.listen(
      onResult: _onSpeechResult,
      listenOptions: stt.SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
        listenFor: _kListenFor,
        pauseFor: _kPauseFor,
        localeId: _kVoiceLocale,
      ),
    );
  }

  void stopListening() {
    _speech.stop();
  }

  /// Opens the typed-command entry point (the keyboard badge next to the mic
  /// bubble) — a fresh command composed by text instead of speech, not to be
  /// confused with submitTypedAnswer, which answers a follow-up question
  /// mid-conversation. Same backend call either way (transcript is
  /// transcript); this only changes how the panel looks while composing it.
  void openTypedCommand() {
    _autoCloseTimer?.cancel();
    state = const VoiceConversationState(phase: VoicePanelPhase.typing);
  }

  void _onSpeechStatus(String status) {
    // 'done'/'notListening' fires once the engine itself stops — pauseFor
    // elapsed, listenFor elapsed, or a manual stopListening() — same trigger
    // point as web's recognition.onend. Submit whatever was captured.
    if (status != 'done' && status != 'notListening') return;

    final current = state;
    if (current == null || current.phase != VoicePanelPhase.listening) return;

    final transcript = current.transcript.trim();
    if (transcript.isEmpty) {
      state = null;
    } else {
      submitTranscript(transcript);
    }
  }

  void _onSpeechResult(SpeechRecognitionResult result) {
    final current = state;
    if (current == null || current.phase != VoicePanelPhase.listening) return;
    state = current.copyWith(
      transcript: result.recognizedWords,
      interimTranscript: result.recognizedWords,
    );
  }

  Future<void> submitTranscript(String transcript) async {
    state = VoiceConversationState(
      transcript: transcript,
      phase: VoicePanelPhase.transcript,
      isProcessing: true,
    );

    try {
      final repo = ref.read(voiceRepositoryProvider);
      var outcome = await repo.parse(transcript: transcript, lang: _kVoiceLang);

      // Voice never collects GPS up front — so an office-mode clock_in/
      // clock_out with no coordinates yet hits this exact rejection whenever
      // the employee's branch requires geofencing. Fetch location now and
      // silently resubmit the identical transcript once, rather than making
      // the user repeat the whole command.
      if (!outcome.success &&
          _kClockIntents.contains(outcome.intent) &&
          outcome.message == kGeofenceRequiredMessage) {
        final position = await _captureLocationOrNull();
        if (position != null) {
          outcome = await repo.parse(
            transcript: transcript,
            lang: _kVoiceLang,
            latitude: position.latitude,
            longitude: position.longitude,
          );
        }
      }

      state = VoiceConversationState(
        transcript: transcript,
        message: outcome.message,
        phase: VoicePanelPhase.result,
        conversational: outcome.conversational,
        awaitingInput: outcome.awaitingInput,
        resultStatus: outcome.success ? VoiceResultStatus.success : VoiceResultStatus.error,
        result: outcome.result,
      );

      await _speakThenMaybeClose(outcome.message, outcome.conversational, outcome.awaitingInput);
    } on DioException catch (e) {
      _showTerminalError(parseDioException(e).message, transcript: transcript);
    } catch (_) {
      _showTerminalError(_kGenericErrorMessage, transcript: transcript);
    }
  }

  void submitTypedAnswer(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    submitTranscript(trimmed);
  }

  Future<Position?> _captureLocationOrNull() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _speakThenMaybeClose(String message, bool conversational, bool awaitingInput) async {
    final muted = ref.read(voiceMutedProvider);
    if (!muted && message.isNotEmpty) {
      try {
        await _tts.speak(message);
      } catch (_) {
        // Nice-to-have layered on top of the panel text already visible —
        // a synthesis failure must never propagate as the command failing.
      }
    }

    if (awaitingInput) return; // still mid-dialogue — wait for the user's answer.
    _scheduleAutoClose(conversational ? _kConversationAutoClose : _kImmediateAutoClose);
  }

  void _showTerminalError(String message, {String transcript = ''}) {
    state = VoiceConversationState(
      transcript: transcript,
      message: message,
      phase: VoicePanelPhase.result,
      resultStatus: VoiceResultStatus.error,
    );
    unawaited(_speakThenMaybeClose(message, false, false));
  }

  void _scheduleAutoClose(Duration delay) {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(delay, () => state = null);
  }

  void close() {
    _autoCloseTimer?.cancel();
    _speech.cancel();
    _tts.stop();
    state = null;
  }
}

final voiceCommandControllerProvider =
    NotifierProvider<VoiceCommandController, VoiceConversationState?>(
  VoiceCommandController.new,
);

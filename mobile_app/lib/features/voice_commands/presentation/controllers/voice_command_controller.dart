import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import 'package:mobile_app/features/facial_recognition/presentation/widgets/face_capture_bottom_sheet.dart';

import '../../../../core/network/api_client.dart' show parseDioException;
import '../../domain/entities/voice_result_entity.dart';
import '../../domain/entities/voice_transcribe_fallback_entity.dart';
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

const _kNoMatchIntent = 'no_match';

// Fixed-duration re-capture for the Hindi-STT fallback retry — mirrors
// frontend/lib/voiceSttFallback.ts's RECORDING_DURATION_MS exactly (that
// file's own comment explains why a fixed duration was chosen over
// silence-detection: real ambient-noise floors varied too much between
// takes to threshold reliably).
const _kFallbackRecordingDuration = Duration(seconds: 5);
// Sarvam's own documented guidance ("works best with audio sampled at
// 16kHz") — same rate frontend/lib/voiceSttFallback.ts's getUserMedia call
// requests.
const _kFallbackSampleRate = 16000;

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
const _kNoSpeechMessage = "Didn't catch that — try again, or type your command instead.";

/// Drives the whole voice-command lifecycle: mic capture (speech_to_text),
/// submission to /api/voice/parse/, the reactive geolocation retry for
/// clock_in/clock_out, the Hindi-STT fallback retry (POST
/// /voice/transcribe-fallback/) for a voice-sourced transcript that comes
/// back as a final no_match, and spoken confirmation via the backend's own
/// bilingual TTS (POST /voice/speak/, played back locally). Conversation
/// state itself (which slot is still missing, etc.) lives server-side —
/// see backend/apps/voice_commands/conversation.py — this controller only
/// ever needs to know "is the last response awaiting a follow-up answer".
///
/// Every language decision (which language a transcript was in, which
/// language to reply in/speak) is read from backend responses
/// (VoiceResultEntity.language, VoiceTranscribeFallbackEntity.detectedLanguage)
/// — this controller never infers a language itself, per this app's "backend
/// is the single source of truth" convention.
///
/// null state = idle, no panel shown. Non-null = the mic overlay renders its
/// expanded panel (see VoiceMicOverlay / VoiceConversationPanel).
class VoiceCommandController extends Notifier<VoiceConversationState?> {
  late final stt.SpeechToText _speech;
  late final AudioPlayer _player;
  late final AudioRecorder _recorder;
  bool _speechInitialized = false;
  Timer? _autoCloseTimer;

  @override
  VoiceConversationState? build() {
    _speech = stt.SpeechToText();
    _player = AudioPlayer();
    _recorder = AudioRecorder();

    ref.onDispose(() {
      _autoCloseTimer?.cancel();
      _speech.cancel();
      _player.dispose();
      unawaited(_recorder.dispose());
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
    await _player.stop();

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
      // On-device recognition came back with literally nothing usable —
      // mirrors web's attemptSilentSpeechFallback: try the Hindi-STT retry
      // directly (there's no English transcript to submit first) rather
      // than silently closing the panel with no feedback at all.
      unawaited(_attemptSilentFallback());
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

  /// Submits a transcript for parsing. [sourceIsVoice] gates the Hindi-STT
  /// fallback retry — only ever attempted for a transcript that actually
  /// came from the mic (a typed command is already exactly what the user
  /// meant; a surprise re-recording would help nothing and would just
  /// capture the user typing, not speaking).
  Future<void> submitTranscript(String transcript, {bool sourceIsVoice = true}) {
    return _performSubmit(transcript, allowFallback: sourceIsVoice);
  }

  void submitTypedAnswer(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    unawaited(_performSubmit(trimmed, allowFallback: false));
  }

  Future<void> _performSubmit(
    String transcript, {
    required bool allowFallback,
    List<double>? faceEmbedding,
    bool? livenessPassed,
    double? livenessScore,
    String? captureSessionId,
    double? sttLanguageProbability,
    bool? sttUsedLanguageHint,
    String? sttDetectedLanguage,
  }) async {
    state = VoiceConversationState(
      transcript: transcript,
      phase: VoicePanelPhase.transcript,
      isProcessing: true,
    );

    try {
      final repo = ref.read(voiceRepositoryProvider);
      var outcome = await repo.parse(
        transcript: transcript,
        lang: _kVoiceLang,
        faceEmbedding: faceEmbedding,
        livenessPassed: livenessPassed,
        livenessScore: livenessScore,
        captureSessionId: captureSessionId,
        sttLanguageProbability: sttLanguageProbability,
        sttUsedLanguageHint: sttUsedLanguageHint,
        sttDetectedLanguage: sttDetectedLanguage,
      );

      outcome = await _maybeRetryWithLocation(transcript, outcome);

      // Hindi-STT fallback: only for a voice-sourced transcript, and only on
      // a genuine final no-match (both the rule engine and backend's LLM
      // fallback tier already declined it — see conversation.py's
      // handle_transcript). Mirrors useVoiceCommand.ts's submitTranscript
      // exactly. Exactly one retry — if it can't help either, everything
      // below behaves as if it had never been attempted.
      //
      // Recurses into _performSubmit (allowFallback: false, so this can
      // never chain a second retry) rather than inlining another repo.parse
      // call here — a Sarvam-resolved transcript that turns out to BE
      // clock_in/clock_out can hit the exact same geofence rejection an
      // English transcript would, and only going through the top of this
      // function again reapplies _maybeRetryWithLocation to it. It also
      // means the panel ends up showing the transcript that was actually
      // acted on (the Hindi/Hinglish text), not the original garbled
      // English one — inlining a second call here previously left `state`
      // showing the wrong transcript for whatever the fallback resolved to.
      if (allowFallback && !outcome.success && outcome.intent == _kNoMatchIntent) {
        final fallback = await _attemptHindiFallback();
        if (fallback != null) {
          return _performSubmit(
            fallback.transcript,
            allowFallback: false,
            sttLanguageProbability: fallback.languageProbability,
            sttUsedLanguageHint: fallback.wasLanguageHinted,
            sttDetectedLanguage: fallback.detectedLanguage,
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
        language: outcome.language,
      );

      // A face-proof turn must NOT auto-listen once speech finishes — it
      // needs the camera sheet next, not the mic, and VoiceMicOverlay's own
      // ref.listen opens that sheet reactively the instant phase becomes
      // faceProof (see its own doc comment) — including mid-speech, if this
      // were set any earlier than it already is below. So this is computed
      // here, BEFORE speech even starts, and passed down rather than
      // reordering the existing faceProof transition after it (which would
      // pop the camera up over the still-playing "taking facial proof" line).
      final isFaceProofTurn = outcome.awaitingInput && _isAwaitingFaceProof(outcome.result);

      await _speakThenMaybeClose(
        outcome.message,
        outcome.speechMessage,
        outcome.conversational,
        outcome.awaitingInput,
        outcome.language,
        autoListen: outcome.awaitingInput && !isFaceProofTurn,
      );

      // clock_in/clock_out asked for (or is re-asking for, after a mismatch)
      // a facial-proof capture — apps/voice_commands/conversation_clock_in_face.py's
      // AWAITING_FACE_PROOF_STAGE. Every attempt/give-up decision is backend's
      // alone: this just keeps opening the capture sheet for as long as
      // backend keeps asking for one, and stops the moment a response comes
      // back WITHOUT awaiting_face_proof (success — punch completed — or a
      // terminal failure — no registration, attempts exhausted, blocked).
      // No client-side attempt counter exists anywhere in this flow. Set
      // AFTER _speakThenMaybeClose returns, unchanged from before — the
      // capture sheet must only open once the "taking facial proof" message
      // has finished playing, never over it.
      if (isFaceProofTurn) {
        state = state?.copyWith(phase: VoicePanelPhase.faceProof);
      }
    } on DioException catch (e) {
      _showTerminalError(parseDioException(e).message, transcript: transcript);
    } catch (_) {
      _showTerminalError(_kGenericErrorMessage, transcript: transcript);
    }
  }

  /// True iff `result` carries the AWAITING_FACE_PROOF_STAGE marker
  /// (`{'awaiting_face_proof': true}`) conversation_clock_in_face.py's
  /// _payload() sets on both the first "taking facial proof" ask and every
  /// retry — mirrors web's useVoiceCommand.ts::isAwaitingFaceProof exactly.
  bool _isAwaitingFaceProof(dynamic result) =>
      result is Map && result['awaiting_face_proof'] == true;

  /// Called by VoiceMicOverlay once the facial_recognition capture sheet it
  /// opened (in reaction to phase becoming [VoicePanelPhase.faceProof]) has
  /// closed — either with a captured embedding, or null if the user
  /// cancelled. This controller has no BuildContext of its own to open that
  /// sheet itself (see VoiceMicOverlay's own doc comment on why that
  /// orchestration lives in the widget layer, not here).
  Future<void> submitFaceProofCapture(FaceCaptureSheetResult? result) async {
    final current = state;
    if (current == null) return;
    final embedding = result?.captured.embedding;
    if (embedding == null) {
      _showTerminalError(
        'Face verification was cancelled. You can try the voice command again, '
        'or use the manual Clock In button.',
        transcript: current.transcript,
      );
      return;
    }
    await _performSubmit(
      current.transcript,
      allowFallback: false, // this turn is answering a face-proof question, not a fresh command
      faceEmbedding: embedding,
      livenessPassed: result!.captured.livenessPassed,
      livenessScore: result.captured.livenessScore,
      captureSessionId: result.captured.captureSessionId,
    );
  }

  /// The mid-command Hindi-STT retry: records a fresh short clip and hands
  /// back whatever Sarvam transcribed (plus its confidence signals), or null
  /// on any failure — callers keep the original no_match outcome exactly as
  /// if this had never been attempted. Deliberately returns the raw
  /// [VoiceTranscribeFallbackEntity] rather than resubmitting to
  /// /voice/parse/ itself — see _performSubmit's own comment on why that
  /// resubmit has to go through the top of _performSubmit again (geofence
  /// retry needs a chance to apply to this newly-resolved transcript too).
  Future<VoiceTranscribeFallbackEntity?> _attemptHindiFallback() async {
    final previous = state;
    state = VoiceConversationState(
      phase: VoicePanelPhase.retrying,
      transcript: previous?.transcript ?? '',
    );
    try {
      final clip = await _recordFallbackClip();
      if (clip == null) return null;
      final repo = ref.read(voiceRepositoryProvider);
      final fallback = await repo.transcribeFallback(audioBytes: clip);
      return fallback.transcript.isEmpty ? null : fallback;
    } catch (_) {
      return null;
    }
  }

  /// Voice never collects GPS up front — so an office-mode clock_in/
  /// clock_out with no coordinates yet hits this exact rejection whenever
  /// the employee's branch requires geofencing. Fetches location and
  /// silently resubmits [transcript] once, rather than making the user
  /// repeat the whole command. Matches web's own resubmit here: the stt_*
  /// hints are NOT resent on this second call. Returns [outcome] unchanged
  /// for anything else (already succeeded, a different rejection, or a
  /// non-clock intent).
  Future<VoiceResultEntity> _maybeRetryWithLocation(
    String transcript,
    VoiceResultEntity outcome,
  ) async {
    if (outcome.success ||
        !_kClockIntents.contains(outcome.intent) ||
        outcome.message != kGeofenceRequiredMessage) {
      return outcome;
    }
    final position = await _captureLocationOrNull();
    if (position == null) return outcome;
    return ref.read(voiceRepositoryProvider).parse(
          transcript: transcript,
          lang: _kVoiceLang,
          latitude: position.latitude,
          longitude: position.longitude,
        );
  }

  /// On-device recognition returned nothing at all — no transcript ever
  /// reached /voice/parse/, so there's nothing to resubmit through the
  /// no_match branch above. Tries the Hindi-STT retry directly instead of
  /// silently giving up (mirrors web's attemptSilentSpeechFallback).
  Future<void> _attemptSilentFallback() async {
    state = const VoiceConversationState(phase: VoicePanelPhase.retrying);
    try {
      final repo = ref.read(voiceRepositoryProvider);
      final clip = await _recordFallbackClip();
      if (clip == null) {
        _showTerminalError(_kNoSpeechMessage);
        return;
      }
      final fallback = await repo.transcribeFallback(audioBytes: clip);
      if (fallback.transcript.isEmpty) {
        _showTerminalError(_kNoSpeechMessage);
        return;
      }
      await _performSubmit(
        fallback.transcript,
        allowFallback: false, // already used the one Sarvam attempt
        sttLanguageProbability: fallback.languageProbability,
        sttUsedLanguageHint: fallback.wasLanguageHinted,
        sttDetectedLanguage: fallback.detectedLanguage,
      );
    } on DioException catch (e) {
      _showTerminalError(parseDioException(e).message);
    } catch (_) {
      _showTerminalError(_kNoSpeechMessage);
    }
  }

  /// Records a short fixed-duration clip to a temp WAV file for the
  /// Hindi-STT fallback. Native-only (mirrors this app's existing
  /// native-vs-web-stub split for on-device capabilities, e.g.
  /// facial_recognition's face_embedding_model_stub.dart) — the `record`
  /// package's file-based API needs a real filesystem path, which web
  /// doesn't have; returning null here just means the fallback silently
  /// isn't offered on web, degrading to exactly today's no_match behavior.
  ///
  /// NOTE: unlike web (which opens a FRESH getUserMedia stream only after
  /// the browser's SpeechRecognition session has already fully ended — see
  /// frontend/lib/voiceSttFallback.ts's own MIC_HANDOFF_SETTLE_MS comment
  /// for why that ordering matters), this always runs after speech_to_text's
  /// session has already stopped (_onSpeechStatus only fires once the
  /// engine itself is done), so the two never contend for the mic
  /// simultaneously — but has not yet been verified on a real device across
  /// both platforms; confirm no residual-session audio artifacts before
  /// shipping.
  Future<Uint8List?> _recordFallbackClip() async {
    if (kIsWeb) return null;
    try {
      if (!await _recorder.hasPermission()) return null;
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_fallback_${DateTime.now().microsecondsSinceEpoch}.wav';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: _kFallbackSampleRate,
          numChannels: 1,
        ),
        path: path,
      );
      await Future.delayed(_kFallbackRecordingDuration);
      final resultPath = await _recorder.stop();
      if (resultPath == null) return null;
      final file = File(resultPath);
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      unawaited(file.delete().catchError((_) => file));
      return bytes.isEmpty ? null : bytes;
    } catch (_) {
      return null;
    }
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

  // Sarvam expects a BCP-47-ish code ("hi-IN"/"en-IN"), not this app's bare
  // "en"/"hi" — same convention backend views_transcribe.py's own
  // _PRIMARY_LANGUAGE_HINT/_SECONDARY_LANGUAGE_HINT and web's
  // voiceTts.ts::toSarvamLanguageCode already use for this exact pipeline.
  String _sarvamLanguageCode(String language) => language == 'hi' ? 'hi-IN' : 'en-IN';

  Future<void> _speakThenMaybeClose(
    String message,
    String? speechMessage,
    bool conversational,
    bool awaitingInput,
    String language, {
    // True only for an ordinary conversational continuation (VC-3) — the
    // caller excludes a face-proof turn (see _performSubmit's isFaceProofTurn),
    // which needs the capture sheet next, not the mic, and excludes every
    // terminal-error path too (_showTerminalError always passes false, since
    // awaitingInput is already false there and this only ever matters when
    // awaitingInput is true).
    bool autoListen = false,
  }) async {
    final muted = ref.read(voiceMutedProvider);
    // Speak the redacted stand-in when the backend provided one (confidentiality-
    // sensitive content, e.g. another employee's leave/salary details) — the
    // panel below always shows the full `message` regardless.
    final toSpeak = (speechMessage != null && speechMessage.isNotEmpty) ? speechMessage : message;
    if (!muted && toSpeak.isNotEmpty) {
      try {
        final repo = ref.read(voiceRepositoryProvider);
        final audioBytes = await repo.speak(
          text: toSpeak,
          languageCode: _sarvamLanguageCode(language),
        );
        await _playAudioAndWait(audioBytes);
      } catch (_) {
        // Nice-to-have layered on top of the panel text already visible —
        // a synthesis failure must never propagate as the command failing.
      }
    }

    if (awaitingInput) {
      // state != null re-checks the panel is still open right now, not
      // whatever it was when this call started — playback can take a couple
      // of seconds, long enough for the user to have tapped Close (state ->
      // null) while it was still running; without this check, startListening
      // would silently reopen a panel the user just explicitly dismissed.
      if (autoListen && state != null) await startListening();
      return; // still mid-dialogue — wait for the user's answer (or the mic just reopened above).
    }

    // Floor the auto-close delay at how long the DISPLAYED text (`message`)
    // takes to read (~200wpm, 1.5s minimum) — playback already blocks until
    // `toSpeak` finishes, but `toSpeak` can be the shorter redacted stand-in,
    // so speech finishing early must not cut off a reader who's still
    // working through the longer displayed message.
    final base = conversational ? _kConversationAutoClose : _kImmediateAutoClose;
    final readingFloor = _estimatedReadingTime(message);
    _scheduleAutoClose(base > readingFloor ? base : readingFloor);
  }

  /// Plays synthesized audio and waits for it to finish — mirrors the old
  /// flutter_tts awaitSpeakCompletion(true) behavior, now against
  /// audioplayers' own completion event instead. The 30s safety timeout
  /// guards against a platform quirk where onPlayerComplete never fires
  /// (e.g. a malformed/truncated stream) leaving the panel stuck mid-speech
  /// forever instead of just proceeding to auto-close.
  Future<void> _playAudioAndWait(Uint8List bytes) async {
    final completer = Completer<void>();
    late final StreamSubscription<void> sub;
    sub = _player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    try {
      await _player.play(BytesSource(bytes, mimeType: 'audio/wav'));
    } catch (e) {
      await sub.cancel();
      rethrow;
    }
    await completer.future.timeout(const Duration(seconds: 30), onTimeout: () {});
    await sub.cancel();
  }

  static const _kMinReadingTime = Duration(milliseconds: 1500);
  static const _kWordsPerMinute = 200;

  Duration _estimatedReadingTime(String text) {
    final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;
    final estimatedMs = (wordCount / _kWordsPerMinute * 60000).round();
    return estimatedMs > _kMinReadingTime.inMilliseconds
        ? Duration(milliseconds: estimatedMs)
        : _kMinReadingTime;
  }

  void _showTerminalError(String message, {String transcript = ''}) {
    state = VoiceConversationState(
      transcript: transcript,
      message: message,
      phase: VoicePanelPhase.result,
      resultStatus: VoiceResultStatus.error,
    );
    // A locally-constructed error string (no backend response, so no
    // backend `language` field to read) — always spoken in English, same as
    // this response's own display language.
    unawaited(_speakThenMaybeClose(message, null, false, false, 'en'));
  }

  void _scheduleAutoClose(Duration delay) {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(delay, () => state = null);
  }

  void close() {
    _autoCloseTimer?.cancel();
    _speech.cancel();
    _player.stop();
    unawaited(_recorder.cancel().catchError((_) {}));
    state = null;
  }
}

final voiceCommandControllerProvider =
    NotifierProvider<VoiceCommandController, VoiceConversationState?>(
  VoiceCommandController.new,
);

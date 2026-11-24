import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/utils/device_identifier.dart';
import '../../../facial_recognition/domain/entities/face_registration_entity.dart';
import '../../../facial_recognition/domain/entities/face_verification_status_entity.dart';
import '../../../facial_recognition/presentation/capture/face_capture_state.dart';
import '../../../facial_recognition/presentation/providers/facial_recognition_providers.dart';
import '../../../facial_recognition/presentation/widgets/face_capture_bottom_sheet.dart';
import '../../domain/entities/attendance_entity.dart';
import '../providers/attendance_mode_provider.dart';
import '../providers/attendance_providers.dart';
import '../../../facial_recognition/diagnostics/face_diagnostics.dart';
import 'face_lockout.dart';

/// Opens the face check and returns the capture, or null if it was
/// cancelled. A provider so tests can stand in for the camera sheet.
typedef FaceCapturePresenter = Future<FaceCaptureUiState?> Function(BuildContext context);

final faceCapturePresenterProvider = Provider<FaceCapturePresenter>((ref) => (context) async {
      // No consent text: clock-in verification never collects new biometric
      // data, so it never needs fresh consent (only registration does).
      final result = await showFaceCaptureSheet(
        context,
        title: 'Face ID Check',
        subtitle: 'Quick face check before clocking in.',
      );
      return result?.captured;
    });

const kFaceRegistrationMissingMessage = 'Face ID registration is mandatory and you don\'t have one yet. '
    'Contact your HR representative or manager to get registered.';
const kFaceCheckCancelledMessage = 'Face ID check was cancelled.';

/// Shown when the Face ID status or the employee's registration could not be read. The punch
/// stays blocked (fail closed): the app never guesses that a face check is not needed.
String faceCheckUnavailableMessage(Object error) =>
    'We couldn\'t check your Face ID status, so you can\'t clock in or out right now. '
    '${friendlyAttendanceError(error)} Please try again.';

/// Face capture, run only when the company's Face ID Verification setting is
/// mandatory — web's useClockWidget.ts gate. Mandatory without an approved
/// registration refuses the punch; a cancelled capture refuses it too; and if the status or
/// registration lookup itself fails, the punch is refused with a readable message (never a raw
/// error, and never a punch without the face check).
Future<FaceCaptureUiState?> _captureFaceIfRequired(WidgetRef ref, BuildContext context, FaceFlowNotifier? flow) async {
  final FaceVerificationStatusEntity status;
  final FaceRegistrationEntity? registration;
  try {
    status = await ref.read(faceVerificationStatusProvider.future);
    flow?.mark('face_status_done');
    // Only needed (and only fetched) when the check is mandatory.
    registration = status.isMandatory ? await ref.read(myFaceRegistrationProvider.future) : null;
    flow?.mark('registration_done');
  } catch (e) {
    throw faceCheckUnavailableMessage(e);
  }
  if (!status.isMandatory) return null;

  if (registration?.status != FaceRegistrationStatus.approved) {
    throw kFaceRegistrationMissingMessage;
  }

  if (!context.mounted) throw kFaceCheckCancelledMessage;
  flow?.mark('face_screen_opening');
  final captured = await ref.read(faceCapturePresenterProvider)(context);
  flow?.mark('face_done');
  if (captured?.embedding == null) throw kFaceCheckCancelledMessage;
  return captured;
}

// One punch at a time across every clock-in surface (dashboard card and My
// Attendance): a second tap while one is in flight is ignored.
bool _punchInFlight = false;

/// The single clock-in/clock-out flow used by the dashboard attendance card
/// and My Attendance. Returns null when the punch went through (or nothing
/// was sent because one is already in flight), otherwise the message to show.
///
/// Order (same as web and the voice flow):
///  1. completed-day guard — nothing is sent once today's In and Out exist;
///  2. GPS, read once and reused by both checks below;
///  3. attendance mode from today's approved WFH request ('wfh'/'office');
///  4. geofence pre-check with that mode — a refusal stops here, before any
///     face capture;
///  5. face check when mandatory;
///  6. the punch, carrying the same mode and the face data.
/// The server is the only match decision (backend `verify_for_punch`, for web, mobile and voice
/// alike): this app captures the face, sends the descriptor with the punch and shows the
/// server's answer — a mismatch, a missing face (400) or a block (403 with `retry_after_seconds`,
/// handled by the lockout) all come back as the punch's error message. The app never decides
/// that a face "matched", and never sends a punch without the capture when Face ID is required.
Future<String?> runClockPunch(WidgetRef ref, BuildContext context, TodayAttendanceEntity today) async {
  if (today.dayCompleted) return kDayCompletedMessage;
  // Web: while the server's face-verification lockout lasts, nothing starts —
  // no GPS, no face capture, no punch.
  final locked = ref.read(faceLockoutProvider.notifier).remainingSeconds();
  if (locked > 0) return faceLockoutMessage(locked);
  if (_punchInFlight) return null;
  _punchInFlight = true;
  ProviderSubscription<AsyncValue<FaceVerificationStatusEntity>>? statusHold;
  try {
    final diagnostics = ref.read(faceDiagnosticsEnabledProvider);
    final flow = diagnostics ? ref.read(faceFlowProvider.notifier) : null;
    flow?.start();
    // The face-status lookup does not depend on GPS or the geofence, so it
    // starts now and is simply awaited later (a refused geofence still stops
    // the flow before any camera). Its error is surfaced where it is awaited.
    statusHold = ref.listenManual(faceVerificationStatusProvider, (_, __) {}); // keeps the lookup alive

    // GPS and today's attendance mode are independent: read them together.
    final positionFuture = ref.read(locationServiceProvider).getCurrentPosition();
    final modeFuture = ref.read(todayAttendanceModeProvider.future)..ignore();
    final position = await positionFuture;
    final mode = await modeFuture;
    flow?.mark('gps_and_mode_done');
    final notifier = ref.read(todayAttendanceProvider.notifier);

    final geofenceError = await notifier.checkGeofence(
      attendanceMode: mode,
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
    );
    flow?.mark('geofence_done');
    if (geofenceError != null) return geofenceError;

    FaceCaptureUiState? face;
    try {
      if (!context.mounted) return null;
      face = await _captureFaceIfRequired(ref, context, flow);
    } catch (e) {
      return '$e';
    }

    if (diagnostics && face != null) ref.read(faceDiagnosticsProvider.notifier).recordCapture(face);
    final backendWatch = Stopwatch()..start();
    final error = await notifier.punch(
      isCurrentlyClockedIn: today.isClockedIn,
      attendanceMode: mode,
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
      // dart:io's Platform throws on web — guarded with kIsWeb, same
      // convention as core/network/api_client.dart.
      deviceName: kIsWeb
          ? 'Web'
          : Platform.isAndroid
              ? 'Android'
              : Platform.isIOS
                  ? 'iOS'
                  : null,
      operatingSystem: kIsWeb ? 'web' : Platform.operatingSystem,
      deviceId: await ref.read(deviceIdProvider.future),
      faceEmbedding: face?.embedding,
      livenessPassed: face?.livenessPassed,
      livenessScore: face?.livenessScore,
      captureSessionId: face?.captureSessionId,
    );
    flow?.mark('punch_done');
    flow?.mark('result_ready');
    if (diagnostics && face != null) {
      ref.read(faceDiagnosticsProvider.notifier).recordBackend(ms: backendWatch.elapsedMilliseconds, error: error);
      if (context.mounted) {
        await showFaceDiagnosticsSheet(context, ref.read(faceDiagnosticsProvider),
            flowText: ref.read(faceFlowProvider.notifier).toCopyText());
      }
    }
    return error;
  } finally {
    statusHold?.close();
    _punchInFlight = false;
  }
}

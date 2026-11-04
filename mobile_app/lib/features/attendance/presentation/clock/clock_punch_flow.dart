import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/utils/device_identifier.dart';
import '../../../facial_recognition/domain/entities/face_registration_entity.dart';
import '../../../facial_recognition/presentation/capture/face_capture_state.dart';
import '../../../facial_recognition/presentation/providers/facial_recognition_providers.dart';
import '../../../facial_recognition/presentation/widgets/face_capture_bottom_sheet.dart';
import '../../domain/entities/attendance_entity.dart';
import '../providers/attendance_mode_provider.dart';
import '../providers/attendance_providers.dart';

/// Opens the face check and returns the capture, or null if it was
/// cancelled. A provider so tests can stand in for the camera sheet.
typedef FaceCapturePresenter = Future<FaceCaptureUiState?> Function(
    BuildContext context);

final faceCapturePresenterProvider =
    Provider<FaceCapturePresenter>((ref) => (context) async {
          // No consent text: clock-in verification never collects new biometric
          // data, so it never needs fresh consent (only registration does).
          final result = await showFaceCaptureSheet(
            context,
            title: 'Face ID Check',
            subtitle: 'Quick face check before clocking in.',
          );
          return result?.captured;
        });

const kFaceRegistrationMissingMessage =
    'Face ID registration is mandatory and you don\'t have one yet. '
    'Contact your HR representative or manager to get registered.';
const kFaceCheckCancelledMessage = 'Face ID check was cancelled.';

/// Face capture, run only when the company's Face ID Verification setting is
/// mandatory — web's useClockWidget.ts gate. Mandatory without an approved
/// registration refuses the punch; a cancelled capture refuses it too.
Future<FaceCaptureUiState?> _captureFaceIfRequired(
    WidgetRef ref, BuildContext context) async {
  final status = await ref.read(faceVerificationStatusProvider.future);
  if (!status.isMandatory) return null;

  final registration = await ref.read(myFaceRegistrationProvider.future);
  if (registration?.status != FaceRegistrationStatus.approved) {
    throw kFaceRegistrationMissingMessage;
  }

  if (!context.mounted) throw kFaceCheckCancelledMessage;
  final captured = await ref.read(faceCapturePresenterProvider)(context);
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
/// The face check here is app-side only: the server's own face enforcement
/// for mobile punches is a separate backend matter.
Future<String?> runClockPunch(
    WidgetRef ref, BuildContext context, TodayAttendanceEntity today) async {
  if (today.dayCompleted) return kDayCompletedMessage;
  if (_punchInFlight) return null;
  _punchInFlight = true;
  try {
    final position =
        await ref.read(locationServiceProvider).getCurrentPosition();
    final mode = await ref.read(todayAttendanceModeProvider.future);
    final notifier = ref.read(todayAttendanceProvider.notifier);

    final geofenceError = await notifier.checkGeofence(
      attendanceMode: mode,
      latitude: position?.latitude,
      longitude: position?.longitude,
      accuracy: position?.accuracy,
    );
    if (geofenceError != null) return geofenceError;

    FaceCaptureUiState? face;
    try {
      if (!context.mounted) return null;
      face = await _captureFaceIfRequired(ref, context);
    } catch (e) {
      return '$e';
    }

    return await notifier.punch(
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
  } finally {
    _punchInFlight = false;
  }
}

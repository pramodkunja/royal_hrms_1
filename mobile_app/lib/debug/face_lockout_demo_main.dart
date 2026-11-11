// DEBUG-ONLY demo of the face-verification lockout countdown (Task 46) on the
// real dashboard attendance card and My Attendance screen, without signing in
// or calling a server:
//
//   flutter run -d <emulator> -t lib/debug/face_lockout_demo_main.dart
//
// Every request is answered in-process by [_DemoServer] in the production
// response shapes (AttendancePunchView: 403 {message, data: {blocked: true,
// retry_after_seconds: N}} once the attempt cap trips). GPS and the face
// capture are stand-ins that only log that they ran; the "embedding" is three
// made-up numbers — no camera, no image, no biometric data. Nothing leaves the
// device and no attendance is recorded anywhere. Each request is logged on
// screen and as "FAKE_SERVER ..." lines. Not imported by lib/main.dart, so not
// part of the release app; refuses to run outside debug builds.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/location/location_service.dart';
import '../core/network/api_client.dart';
import '../core/utils/device_identifier.dart';
import '../features/attendance/presentation/clock/clock_punch_flow.dart';
import '../features/attendance/presentation/clock/face_lockout.dart';
import '../features/attendance/presentation/screens/my_attendance_screen.dart';
import '../features/auth/domain/entities/user_entity.dart';
import '../features/auth/presentation/controllers/auth_notifier.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/auth/presentation/states/auth_state.dart';
import '../features/dashboard/presentation/widgets/attendance_ring_card.dart';
import '../features/facial_recognition/presentation/capture/face_capture_state.dart';

const _demoUser = UserEntity(
  id: 'demo',
  email: 'demo@example.test',
  fullName: 'Demo Employee',
  role: 'employee',
  roleDisplay: 'Employee',
  mustChangePassword: false,
  permissions: ['attendance.view', 'leave.view'],
  onboardingStatus: 'complete',
  assessmentStatus: 'complete',
);

class _DemoAuth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(user: _demoUser);
}

enum PunchMode { cap125, blockedNoRetry, mismatch, success }

const _capMessage = 'Too many failed face verification attempts. Please wait a few minutes before trying again, '
    'or contact HR if this keeps happening.';
const _replayMessage = 'That face capture looks like it was already used. Please capture a fresh photo and try again.';
const _mismatchMessage = 'Face verification failed. Please try again.';

final _log = ValueNotifier<List<String>>([]);
String? _lastLabel;
void _record(String line) {
  debugPrint('FAKE_SERVER $line');
  _log.value = [..._log.value, line];
}

class _DemoServer implements HttpClientAdapter {
  PunchMode mode = PunchMode.cap125;
  bool clockedIn = false;

  ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  ResponseBody _ok(Object data, [String message = 'ok']) =>
      _json(200, {'status': 'success', 'message': message, 'data': data});

  Map<String, dynamic> _today() => {
        'is_clocked_in': clockedIn,
        'day_completed': false,
        'punches': <Object>[],
        'total_seconds': 0,
        'session_seconds': 0,
        'date_display': 'Wednesday, 11 November 2026',
      };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    switch (o.path) {
      case '/attendance/today/':
        return _ok(_today());
      case '/wfh/requests/':
        return _ok({'count': 0, 'results': []});
      case '/attendance/face-verification/status/':
        return _ok({'is_mandatory': true});
      case '/attendance/face-registration/me/':
        return _ok({'id': 'demo-reg', 'status': 'approved'});
      case '/attendance/geofence-check/':
        _record('POST /attendance/geofence-check/');
        return _ok({'allowed': true});
      case '/attendance/calendar/':
        return _ok({
          'month': o.queryParameters['month'],
          'year': o.queryParameters['year'],
          'calendar': {'days': <String, dynamic>{}},
          'history': <Object>[],
        });
      case '/attendance/punch/':
        final type = (o.data as Map)['punch_type'];
        switch (mode) {
          case PunchMode.cap125:
            _record('POST /attendance/punch/ $type → 403 blocked, retry_after_seconds 125');
            return _json(403, {
              'status': 'error',
              'message': _capMessage,
              'data': {'blocked': true, 'retry_after_seconds': 125},
            });
          case PunchMode.blockedNoRetry:
            _record('POST /attendance/punch/ $type → 403 blocked (no retry_after_seconds)');
            return _json(403, {
              'status': 'error',
              'message': _replayMessage,
              'data': {'blocked': true},
            });
          case PunchMode.mismatch:
            _record('POST /attendance/punch/ $type → 403 mismatch (not blocked)');
            return _json(403, {'status': 'error', 'message': _mismatchMessage, 'data': {}});
          case PunchMode.success:
            clockedIn = type == 'IN';
            _record('POST /attendance/punch/ $type → 200');
            return _ok(_today(), type == 'IN' ? 'Clocked in successfully.' : 'Clocked out successfully.');
        }
    }
    return _ok(<String, dynamic>{});
  }

  @override
  void close({bool force = false}) {}
}

class _LoggedLocation extends LocationService {
  @override
  Future<Position?> getCurrentPosition() async {
    _record('GPS read (fake position)');
    return Position(
      latitude: 17.385,
      longitude: 78.4867,
      timestamp: DateTime(2026),
      accuracy: 12,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

Future<FaceCaptureUiState?> _fakeCapture(BuildContext _) async {
  _record('FACE CAPTURE opened (fake, no camera)');
  return const FaceCaptureUiState(
      embedding: [0.1, 0.2, 0.3], livenessPassed: true, livenessScore: 0.9, captureSessionId: 'demo-session');
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kDebugMode) {
    runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('Debug builds only.')))));
    return;
  }
  final server = _DemoServer();
  runApp(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_DemoAuth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://demo.invalid/api'))..httpClientAdapter = server),
      locationServiceProvider.overrideWithValue(_LoggedLocation()),
      faceCapturePresenterProvider.overrideWithValue(_fakeCapture),
      deviceIdProvider.overrideWith((ref) async => 'demo-device'),
    ],
    child: MaterialApp(debugShowCheckedModeBanner: false, home: _DemoPage(server: server)),
  ));
}

class _DemoPage extends StatefulWidget {
  const _DemoPage({required this.server});
  final _DemoServer server;
  @override
  State<_DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<_DemoPage> {
  int _screen = 0; // 0 dashboard card, 1 My Attendance, 2 elsewhere

  @override
  Widget build(BuildContext context) {
    final s = widget.server;
    Widget chip(String label, bool on, VoidCallback f) => ChoiceChip(
          label: Text(label, style: const TextStyle(fontSize: 11)),
          selected: on,
          visualDensity: VisualDensity.compact,
          onSelected: (_) => setState(f),
        );
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Wrap(spacing: 4, runSpacing: 0, children: [
            chip('Cap 125s', s.mode == PunchMode.cap125, () => s.mode = PunchMode.cap125),
            chip('Blocked, no N', s.mode == PunchMode.blockedNoRetry, () => s.mode = PunchMode.blockedNoRetry),
            chip('Mismatch', s.mode == PunchMode.mismatch, () => s.mode = PunchMode.mismatch),
            chip('Success', s.mode == PunchMode.success, () => s.mode = PunchMode.success),
          ]),
          Wrap(spacing: 4, children: [
            chip('Dashboard', _screen == 0, () => _screen = 0),
            chip('My Attendance', _screen == 1, () => _screen = 1),
            chip('Elsewhere', _screen == 2, () => _screen = 2),
          ]),
          const Divider(height: 1),
          // Evidence only: logs each distinct countdown value the buttons show
          // (same FaceLockoutBuilder + label function), with a timestamp.
          FaceLockoutBuilder(builder: (_, left) {
            final label = left == null ? 'unlocked' : faceLockoutButtonLabel(left);
            if (label != _lastLabel) {
              _lastLabel = label;
              debugPrint('LOCKOUT_LABEL ${DateTime.now().toIso8601String().substring(11, 23)} $label');
            }
            return const SizedBox.shrink();
          }),
          Expanded(
            child: switch (_screen) {
              0 => const SingleChildScrollView(padding: EdgeInsets.all(12), child: AttendanceRingCard()),
              1 => const MyAttendanceScreen(),
              _ => const Center(child: Text('Another screen (no clock button)')),
            },
          ),
          Container(
            width: double.infinity,
            color: const Color(0xFF102A43),
            padding: const EdgeInsets.all(6),
            child: ValueListenableBuilder<List<String>>(
              valueListenable: _log,
              builder: (_, lines, __) => Text(
                lines.isEmpty ? 'Fake server log: (nothing yet)' : lines.reversed.take(4).join('\n'),
                style: const TextStyle(color: Colors.white, fontSize: 10.5, fontFamily: 'monospace'),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/features/attendance/data/models/attendance_models.dart';
import 'package:mobile_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/punch_location_section.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 6: HR attendance record detail — Clock In / Clock Out punch location
// and GPS accuracy guidance, as web AttendanceDetailDrawer.tsx shows them from
// GET /attendance/records/<id>/ (services_hr.get_attendance_detail;
// classification and text from apps/attendance/location_accuracy.py: ≤100 m
// precise, ≤1,000 m approximate, beyond very approximate). Display only.
// Synthetic data; a stand-in server.

const recordId = '11111111-2222-3333-4444-555555555555';

/// Location fields for one punch, as the server sends them.
Map<String, dynamic> loc(
  String prefix, {
  Object? lat = 12.97159871,
  Object? lng = 77.59456312,
  String? label = 'Test Street, Test City',
  String? display,
  Object? accM = 17.0,
  String? accText = '±17 m',
  String? level = 'precise',
  bool office = false,
}) =>
    {
      '${prefix}_latitude': lat,
      '${prefix}_longitude': lng,
      '${prefix}_location_label': label,
      '${prefix}_accuracy_m': accM,
      '${prefix}_accuracy_text': accText,
      '${prefix}_accuracy_level': level,
      '${prefix}_location_display': display ?? label,
      '${prefix}_location_is_office': office,
    };

/// No punch (or no GPS) for this side: the server's all-null shape.
Map<String, dynamic> none(String prefix) => {
      '${prefix}_latitude': null,
      '${prefix}_longitude': null,
      '${prefix}_location_label': null,
      '${prefix}_accuracy_m': null,
      '${prefix}_accuracy_text': null,
      '${prefix}_accuracy_level': null,
      '${prefix}_location_display': null,
      '${prefix}_location_is_office': false,
    };

Map<String, dynamic> detail(Map<String, dynamic> inLoc, Map<String, dynamic> outLoc) => {
      'record_id': recordId,
      'employee_id': 'EMP-901',
      'name': 'Test Person',
      'department': 'QA',
      'branch': 'Test Branch',
      'date': '2026-11-05',
      'status': 'Present',
      'status_key': 'present',
      'clock_in': '09:02 AM',
      'clock_out': '06:10 PM',
      'total_hours': '9h 8m',
      'overtime': '0h 0m',
      'is_late': false,
      'is_early_exit': false,
      'note': '',
      'punches': [
        {'punch_type': 'IN', 'time': '09:02 AM', 'source': 'mobile', 'mode': 'office', 'is_geofence': true},
        {'punch_type': 'OUT', 'time': '06:10 PM', 'source': 'mobile', 'mode': 'office', 'is_geofence': true},
      ],
      ...inLoc,
      ...outLoc,
    };

AttendanceDetailModel parse(Map<String, dynamic> json) => AttendanceDetailModel.fromJson(json);

final opened = <Uri>[];

Future<void> pumpSection(WidgetTester tester, AttendanceDetailEntity d) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: PunchLocationSection(
          clockIn: d.clockInLocation,
          clockOut: d.clockOutLocation,
          openMap: (uri) async => opened.add(uri),
        ),
      ),
    ),
  ));
}

final inBlock = find.byKey(const Key('punch-location-in'));
final outBlock = find.byKey(const Key('punch-location-out'));
Finder within(Finder block, Finder f) => find.descendant(of: block, matching: f);

String accuracyLine(WidgetTester tester, Finder block) =>
    tester.widget<Text>(within(block, find.byKey(const Key('gps-accuracy-line')))).data!;
Color? accuracyColor(WidgetTester tester, Finder block) =>
    tester.widget<Text>(within(block, find.byKey(const Key('gps-accuracy-line')))).style?.color;

// ── Screen harness ─────────────────────────────────────────────────────────

ResponseBody _json(Object data) =>
    ResponseBody.fromString(jsonEncode({'status': 'success', 'message': 'ok', 'data': data}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class FakeServer implements HttpClientAdapter {
  FakeServer(this.detailJson);
  final Map<String, dynamic> detailJson;
  final methods = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    methods.add('${o.method} ${o.path}');
    if (o.path == ApiConstants.attendanceRecords) {
      return _json({
        'count': 1,
        'results': [
          {
            'record_id': recordId,
            'employee_id': 'EMP-901',
            'name': 'Test Person',
            'initials': 'TP',
            'department': 'QA',
            'branch': 'Test Branch',
            'clock_in': '09:02 AM',
            'clock_out': '06:10 PM',
            'total_hours': '9h 8m',
            'ot': '0h 0m',
            'status': 'Present',
            'status_key': 'present',
            'is_late': false,
          }
        ],
      });
    }
    if (o.path == ApiConstants.attendanceRecordDetail(recordId)) return _json(detailJson);
    if (o.path == ApiConstants.attendanceRecordAudit(recordId)) return _json([]);
    return _json({'results': [], 'count': 0, 'summary_chips': <String, int>{}});
  }

  @override
  void close({bool force = false}) {}
}

class _NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => const AuthState(
        user: UserEntity(
          id: 'hr1',
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr',
          roleDisplay: 'HR',
          mustChangePassword: false,
          permissions: ['attendance.view', 'attendance.edit'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

late FakeServer server;

Future<void> openDetail(WidgetTester tester, Map<String, dynamic> json) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = FakeServer(json);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: const MaterialApp(home: Scaffold(body: AttendanceScreen())),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('View').first);
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(opened.clear);

  group('parsing the detail response', () {
    test('clock_in_* and clock_out_* become two independent locations', () {
      final d = parse(detail(
          loc('clock_in'),
          loc('clock_out',
              lat: 13.0,
              lng: 77.5,
              label: 'Test Exit',
              level: 'approximate',
              accText: '±390 m',
              display: 'Location approximate (±390 m): Test Exit')));
      final i = d.clockInLocation!, o = d.clockOutLocation!;
      expect([i.latitude, i.longitude, i.placeName, i.accuracyText, i.accuracyLevel, i.isOffice],
          [12.97159871, 77.59456312, 'Test Street, Test City', '±17 m', GpsAccuracyLevel.precise, false]);
      expect([o.latitude, o.placeName, o.accuracyText, o.accuracyLevel],
          [13.0, 'Location approximate (±390 m): Test Exit', '±390 m', GpsAccuracyLevel.approximate]);
    });

    test('9/11. missing, wrong-typed and unknown values read as missing; older responses still parse', () {
      final d = parse(detail(
        loc('clock_in', lat: 'not a number', lng: double.nan, label: '  ', level: 'super_precise', accText: null),
        {'clock_out_latitude': '13.5', 'clock_out_longitude': 77, 'clock_out_location_is_office': 'yes'},
      ));
      final i = d.clockInLocation!, o = d.clockOutLocation!;
      expect([i.latitude, i.longitude, i.placeName, i.accuracyText, i.accuracyLevel], [null, null, null, null, null]);
      expect([o.latitude, o.longitude, o.isOffice, o.accuracyLevel], [13.5, 77.0, false, null]);
      final old = parse({'record_id': recordId, 'punches': []});
      expect(old.clockInLocation!.hasCoordinates, isFalse);
      expect(old.clockOutLocation!.hasCoordinates, isFalse);
    });
  });

  group('location section (web AttendanceDetailDrawer)', () {
    testWidgets('1/6. clock-in: place, precise accuracy (no warning), 8-decimal coordinates, map link', (tester) async {
      await pumpSection(tester, parse(detail(loc('clock_in'), none('clock_out'))));
      expect(within(inBlock, find.text('Clock In Location')), findsOneWidget);
      expect(within(inBlock, find.text('Test Street, Test City')), findsOneWidget);
      expect(accuracyLine(tester, inBlock), 'GPS accuracy: ±17 m');
      expect(accuracyColor(tester, inBlock), AppColors.textSecondary);
      expect(within(inBlock, find.byKey(const Key('gps-accuracy-warning'))), findsNothing);
      expect(within(inBlock, find.text('Latitude: 12.97159871')), findsOneWidget);
      expect(within(inBlock, find.text('Longitude: 77.59456312')), findsOneWidget);
      await tester.tap(within(inBlock, find.text('View on map')));
      expect(opened.single.toString(), 'https://www.google.com/maps?q=12.97159871,77.59456312');
    });

    testWidgets('2/7/11. clock-out only: approximate (amber + warning), clock-in shows "—"', (tester) async {
      await pumpSection(
          tester,
          parse(detail(
            none('clock_in'),
            loc('clock_out',
                label: 'Test Exit',
                display: 'Location approximate (±390 m): Test Exit',
                accText: '±390 m',
                level: 'approximate',
                accM: 384.2),
          )));
      expect(within(inBlock, find.text('—')), findsOneWidget);
      expect(within(inBlock, find.byKey(const Key('gps-accuracy-line'))), findsNothing);
      expect(within(outBlock, find.text('Clock Out Location')), findsOneWidget);
      expect(within(outBlock, find.text('Location approximate (±390 m): Test Exit')), findsOneWidget);
      expect(accuracyLine(tester, outBlock), 'GPS accuracy: ±390 m — location approximate');
      expect(accuracyColor(tester, outBlock), AppColors.warning);
      expect(within(outBlock, find.byKey(const Key('gps-accuracy-warning'))), findsOneWidget);
    });

    testWidgets('3/8. both independently: precise clock-in, very approximate (red) clock-out', (tester) async {
      await pumpSection(
          tester,
          parse(detail(
            loc('clock_in'),
            loc('clock_out',
                lat: 19.07,
                lng: 72.87,
                label: 'Test Far',
                display: 'Approximate location (±1.5 km): Test Far',
                accText: '±1.5 km',
                level: 'very_approximate',
                accM: 1450.0),
          )));
      expect(accuracyLine(tester, inBlock), 'GPS accuracy: ±17 m');
      expect(accuracyLine(tester, outBlock), 'GPS accuracy: ±1.5 km — location very approximate');
      expect(accuracyColor(tester, outBlock), AppColors.error);
      expect(within(outBlock, find.text('Approximate location (±1.5 km): Test Far')), findsOneWidget);
      expect(within(outBlock, find.text('Latitude: 19.07000000')), findsOneWidget);
    });

    testWidgets('4. no place name: italic "Location name unavailable"; display falls back to the label',
        (tester) async {
      await pumpSection(
          tester,
          parse(detail(
            loc('clock_in', label: null, display: null),
            {...loc('clock_out', label: 'Test Raw Label'), 'clock_out_location_display': null},
          )));
      final unnamed = tester.widget<Text>(within(inBlock, find.text('Location name unavailable')));
      expect(unnamed.style?.fontStyle, FontStyle.italic);
      expect(within(outBlock, find.text('Test Raw Label')), findsOneWidget);
    });

    testWidgets('5. a missing coordinate shows "—" for that side only', (tester) async {
      await pumpSection(tester, parse(detail(loc('clock_in', lng: null), loc('clock_out'))));
      expect(within(inBlock, find.text('—')), findsOneWidget);
      expect(within(inBlock, find.textContaining('Latitude')), findsNothing);
      expect(within(outBlock, find.text('Latitude: 12.97159871')), findsOneWidget);
    });

    testWidgets('5. no latitude on either side: no location section at all', (tester) async {
      await pumpSection(tester, parse(detail(none('clock_in'), loc('clock_out', lat: null))));
      expect(find.byKey(const Key('punch-location-section')), findsNothing);
    });

    testWidgets('9. missing or invalid accuracy: "GPS accuracy: unknown", neutral, no warning', (tester) async {
      await pumpSection(
          tester,
          parse(detail(
            loc('clock_in', accText: null, level: null, accM: null),
            loc('clock_out', accText: null, level: 'not_a_level', accM: -5),
          )));
      expect(accuracyLine(tester, inBlock), 'GPS accuracy: unknown');
      expect(accuracyLine(tester, outBlock), 'GPS accuracy: unknown');
      expect(accuracyColor(tester, inBlock), AppColors.textSecondary);
      expect(find.byKey(const Key('gps-accuracy-warning')), findsNothing);
    });

    testWidgets('10. office punch: place and coordinates shown, accuracy line hidden (as on web)', (tester) async {
      await pumpSection(
          tester,
          parse(detail(
            loc('clock_in', label: 'Office – Test HQ', accText: '±2.5 km', level: 'very_approximate', office: true),
            loc('clock_out', level: 'approximate', accText: '±390 m'),
          )));
      expect(within(inBlock, find.text('Office – Test HQ')), findsOneWidget);
      expect(within(inBlock, find.byKey(const Key('gps-accuracy-line'))), findsNothing);
      expect(within(inBlock, find.text('Latitude: 12.97159871')), findsOneWidget);
      expect(accuracyLine(tester, outBlock), 'GPS accuracy: ±390 m — location approximate');
    });
  });

  group('HR attendance detail dialog', () {
    testWidgets('12. the dialog shows the locations among its existing fields; only GETs are sent', (tester) async {
      await openDetail(
          tester,
          detail(loc('clock_in'),
              loc('clock_out', label: 'Test Exit', display: 'Test Exit', accText: '±390 m', level: 'approximate')));
      final dialog = find.byType(AlertDialog);
      Finder inDialog(Finder f) => find.descendant(of: dialog, matching: f);
      for (final t in [
        'Status: Present',
        'Clock In: 09:02 AM',
        'Clock Out: 06:10 PM',
        'Total Hours: 9h 8m',
        'Overtime: 0h 0m',
        'Punches',
        'Correction Requests',
        'Audit History',
      ]) {
        expect(inDialog(find.text(t)), findsWidgets, reason: t);
      }
      expect(inDialog(find.text('IN · 09:02 AM · office')), findsOneWidget);
      expect(inDialog(find.byKey(const Key('punch-location-section'))), findsOneWidget);
      expect(accuracyLine(tester, inBlock), 'GPS accuracy: ±17 m');
      expect(accuracyLine(tester, outBlock), 'GPS accuracy: ±390 m — location approximate');
      // Location section sits above the punch history, as in web's section.
      expect(tester.getTopLeft(inBlock).dy < tester.getTopLeft(inDialog(find.text('Punches'))).dy, isTrue);
      expect(inDialog(find.text('Edit')), findsOneWidget);
      expect(server.methods.where((m) => !m.startsWith('GET ')), isEmpty);
    });

    testWidgets('12. a record without any location keeps the dialog exactly as before', (tester) async {
      await openDetail(tester, detail(none('clock_in'), none('clock_out')));
      expect(find.byKey(const Key('punch-location-section')), findsNothing);
      expect(find.descendant(of: find.byType(AlertDialog), matching: find.text('Punches')), findsOneWidget);
    });
  });
}

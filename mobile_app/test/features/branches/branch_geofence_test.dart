import 'dart:async';
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
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/branches/data/models/branch_model.dart';
import 'package:mobile_app/features/branches/domain/branch_geofence.dart';
import 'package:mobile_app/features/branches/presentation/providers/branch_providers.dart';
import 'package:mobile_app/features/branches/presentation/widgets/branch_details_sheet.dart';
import 'package:mobile_app/features/branches/presentation/widgets/branch_form_dialog.dart';

// P1-10: branch geofencing edit, as web BranchManagement.tsx (local web
// branch; production cross-checks: BranchSerializer geofence fields + the
// "Set latitude and longitude before enabling geofencing." rule, audit C-B03):
// the Add/Edit Branch form carries "Enable Geofencing", Latitude *, Longitude *
// and "Allowed Radius (metres) *" (10-5000, default 150) and sends them in the
// branch POST / PATCH: enabled → numbers; disabled → latitude/longitude null,
// radius 150. Coordinates come back as DecimalField strings. Editing needs
// settings.edit in the UI (backend: branches.edit + branch scope).
// Mocked Dio, synthetic branches — no real branch is changed.

Map<String, dynamic> branchJson(int id, String name,
        {bool enabled = false, Object? lat, Object? lon, int? radius = 150}) =>
    {
      'id': id,
      'branch_code': 'BR-00$id',
      'branch_name': name,
      'address': '1 Test Road',
      'state': 1,
      'state_name': 'Test State',
      'city': 1,
      'city_name': 'Test City',
      'employees_count': 4,
      'status': 'active',
      'is_headquarter': false,
      'geofencing_enabled': enabled,
      'latitude': lat,
      'longitude': lon,
      if (radius != null) 'allowed_radius_meters': radius,
      'has_coordinates': lat != null && lon != null,
    };

String? dec(Object? v) => v == null ? null : (v as num).toStringAsFixed(8);

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> branches = [
    branchJson(1, 'North', enabled: true, lat: '19.07600000', lon: '72.87770000', radius: 200),
    branchJson(2, 'South'),
    branchJson(3, 'East', enabled: true), // enabled without coordinates
  ];
  final writes = <({String method, String path, Map<String, dynamic> body})>[];
  ({int status, String message})? refuse;
  Completer<void>? hold;
  int listGets = 0;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET' && o.path == ApiConstants.branches) {
      listGets++;
      return _json({
        'status': 'success',
        'data': {'count': branches.length, 'results': branches}
      });
    }
    if (o.method == 'PATCH' || o.method == 'PUT' || o.method == 'POST') {
      final body = Map<String, dynamic>.from(o.data as Map);
      writes.add((method: o.method, path: o.path, body: body));
      final gate = hold;
      if (gate != null) await gate.future;
      final r = refuse;
      if (r != null) return _json({'status': 'error', 'message': r.message, 'data': {}}, r.status);
      if (o.method == 'PATCH') {
        final id = int.parse(o.path.split('/').where((p) => p.isNotEmpty).last);
        final cur = branches.firstWhere((b) => b['id'] == id);
        // BranchSerializer: enabling needs coordinates (sent or saved)
        if (body['geofencing_enabled'] == true &&
            (body['latitude'] ?? cur['latitude']) == null) {
          return _json({'status': 'error', 'message': 'Set latitude and longitude before enabling geofencing.'}, 400);
        }
        final updated = {
          ...cur,
          ...body,
          if (body.containsKey('latitude')) 'latitude': dec(body['latitude']),
          if (body.containsKey('longitude')) 'longitude': dec(body['longitude']),
        };
        updated['has_coordinates'] = updated['latitude'] != null && updated['longitude'] != null;
        branches = [for (final b in branches) b['id'] == id ? updated : b];
        return _json({'status': 'success', 'message': 'Branch updated successfully.', 'data': updated});
      }
      if (o.method == 'POST') {
        final created = {...branchJson(9, '${body['branch_name']}'), ...body};
        return _json({'status': 'success', 'data': created}, 201);
      }
    }
    return _json({'status': 'success', 'data': []});
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
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

UserEntity user(List<String> perms) => UserEntity(
      id: 'u1',
      email: 'admin@example.test',
      fullName: 'Test Admin',
      role: 'system_admin',
      roleDisplay: 'Admin',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final admin = user(['settings.view', 'settings.edit', 'branches.view', 'branches.edit']);
final viewer = user(['settings.view', 'branches.view']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pump(WidgetTester tester, {Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(admin),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          if (ref.watch(authStateProvider).valueOrNull?.user == null) return const SizedBox();
          final list = ref.watch(branchListProvider).valueOrNull ?? const [];
          return ListView(children: [
            for (final b in list) ...[
              TextButton(
                key: Key('edit-${b.id}'),
                onPressed: () => showDialog<void>(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) => Dialog(child: BranchFormDialog(branch: b)),
                ),
                child: Text('Edit ${b.branchName}'),
              ),
              TextButton(
                key: Key('view-${b.id}'),
                onPressed: () => showBranchDetailsSheet(context, b),
                child: Text('View ${b.branchName}'),
              ),
            ],
          ]);
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> openEdit(WidgetTester tester, int id) async {
  await tester.tap(byKey('edit-$id'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(byKey('branch-geofence'));
  await tester.pumpAndSettle();
}

Future<void> save(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Save Changes'));
  await tester.tap(find.text('Save Changes'));
  await tester.pumpAndSettle();
}

String fieldText(WidgetTester tester, String key) => tester.widget<TextField>(byKey(key)).controller!.text;
String? fieldError(WidgetTester tester, String key) => tester.widget<TextField>(byKey(key)).decoration!.errorText;
bool toggleOn(WidgetTester tester) => tester.widget<SwitchListTile>(byKey('branch-geofence-toggle')).value;

Future<void> setToggle(WidgetTester tester, bool on) async {
  if (toggleOn(tester) != on) {
    await tester.tap(byKey('branch-geofence-toggle'));
    await tester.pumpAndSettle();
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('parsing and rules', () {
    test('coordinates arrive as DecimalField strings; radius defaults to the backend\'s 150', () {
      final b = BranchModel.fromJson(branchJson(1, 'N', enabled: true, lat: '19.07600000', lon: '-72.87770000', radius: 200));
      expect([b.latitude, b.longitude, b.allowedRadiusMeters, b.geofencingEnabled, b.hasCoordinates],
          [19.076, -72.8777, 200, true, true]);
      final noRadius = BranchModel.fromJson(branchJson(2, 'S', radius: null));
      expect([noRadius.latitude, noRadius.longitude, noRadius.allowedRadiusMeters], [null, null, 150]);
    });

    test('status label as web geofenceBadge: Disabled / No Coordinates / Active', () {
      expect(geofenceStatusLabel(BranchModel.fromJson(branchJson(2, 'S'))), 'Disabled');
      expect(geofenceStatusLabel(BranchModel.fromJson(branchJson(3, 'E', enabled: true))), 'No Coordinates');
      expect(geofenceStatusLabel(BranchModel.fromJson(branchJson(1, 'N', enabled: true, lat: '1', lon: '2'))), 'Active');
    });

    test('disabled → no checks; payload clears coordinates and resets the radius to 150 (web)', () {
      final r = validateBranchGeofence(enabled: false, latitude: 'junk', longitude: '', radius: '1');
      expect(r.errors, isEmpty);
      expect(r.value!.toPayload(),
          {'geofencing_enabled': false, 'latitude': null, 'longitude': null, 'allowed_radius_meters': 150});
    });

    test('a disabled geofence never sends stale coordinates or radius', () {
      const stale = BranchGeofence(enabled: false, latitude: 19.076, longitude: 72.8777, radiusMeters: 999);
      expect(stale.toPayload(),
          {'geofencing_enabled': false, 'latitude': null, 'longitude': null, 'allowed_radius_meters': 150});
    });

    test('enabled: web messages for missing / partial / invalid coordinates', () {
      expect(validateBranchGeofence(enabled: true, latitude: '', longitude: ' ', radius: '150').errors,
          {'latitude': 'Latitude and longitude are required to enable geofencing.'});
      expect(validateBranchGeofence(enabled: true, latitude: '19', longitude: '', radius: '150').errors,
          {'longitude': 'Both latitude and longitude must be provided together.'});
      expect(validateBranchGeofence(enabled: true, latitude: 'north', longitude: '7x', radius: '150').errors, {
        'latitude': 'Latitude must be a valid number.',
        'longitude': 'Longitude must be a valid number.',
      });
    });

    test('radius: required, 10-5000 inclusive, numeric', () {
      Map<String, String> e(String r) => validateBranchGeofence(enabled: true, latitude: '1', longitude: '2', radius: r).errors;
      expect(e(''), {'allowed_radius_meters': 'Allowed radius is required.'});
      for (final bad in ['9', '5001', 'far', '-10']) {
        expect(e(bad), {'allowed_radius_meters': 'Allowed radius must be between 10 and 5000 metres.'}, reason: bad);
      }
      for (final ok in ['10', '5000', '150']) {
        expect(e(ok), isEmpty, reason: ok);
      }
    });

    test('enabled payload: numbers in degrees and whole metres', () {
      final v = validateBranchGeofence(enabled: true, latitude: ' 19.0760 ', longitude: '-72.8777', radius: '250').value!;
      expect(v.toPayload(),
          {'geofencing_enabled': true, 'latitude': 19.076, 'longitude': -72.8777, 'allowed_radius_meters': 250});
      expect(v.toPayload()['allowed_radius_meters'], isA<int>());
    });
  });

  group('form (settings.edit)', () {
    testWidgets('an existing configuration is shown and prefilled', (tester) async {
      await pump(tester);
      await openEdit(tester, 1);
      expect(toggleOn(tester), isTrue);
      expect(fieldText(tester, 'branch-geofence-latitude'), '19.076');
      expect(fieldText(tester, 'branch-geofence-longitude'), '72.8777');
      expect(fieldText(tester, 'branch-geofence-radius'), '200');
    });

    testWidgets('a disabled branch shows the toggle off and no coordinate fields', (tester) async {
      await pump(tester);
      await openEdit(tester, 2);
      expect(toggleOn(tester), isFalse);
      expect(byKey('branch-geofence-latitude'), findsNothing);
      await setToggle(tester, true);
      expect(fieldText(tester, 'branch-geofence-radius'), '150', reason: 'default radius');
      expect(fieldText(tester, 'branch-geofence-latitude'), '');
    });

    testWidgets('saving sends PATCH with the branch fields and the geofence; the list reloads with the server values',
        (tester) async {
      await pump(tester);
      await openEdit(tester, 2);
      await setToggle(tester, true);
      await tester.enterText(byKey('branch-geofence-latitude'), '12.9716');
      await tester.enterText(byKey('branch-geofence-longitude'), '77.5946');
      await tester.enterText(byKey('branch-geofence-radius'), '300');
      await save(tester);

      final w = server.writes.single;
      expect(w.method, 'PATCH');
      expect(w.path, ApiConstants.branchDetail(2));
      expect(w.body, {
        'city': 1,
        'state': 1,
        'branch_name': 'South',
        'address': '1 Test Road',
        'status': 'active',
        'is_headquarter': false,
        'geofencing_enabled': true,
        'latitude': 12.9716,
        'longitude': 77.5946,
        'allowed_radius_meters': 300,
      });
      expect(find.byType(BranchFormDialog), findsNothing);
      // refreshed: the details sheet shows the server's values
      await tester.tap(byKey('view-2'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(Row, 'Geofencing'), findsOneWidget);
      expect(
          find.descendant(of: find.widgetWithText(Row, 'Geofencing'), matching: find.text('Active')), findsOneWidget);
      expect(find.text('300 m'), findsOneWidget);
      expect(find.text('Available'), findsOneWidget);
    });

    testWidgets('turning geofencing off sends null coordinates and radius 150 (web)', (tester) async {
      await pump(tester);
      await openEdit(tester, 1);
      await setToggle(tester, false);
      await save(tester);
      final b = server.writes.single.body;
      expect([b['geofencing_enabled'], b['latitude'], b['longitude'], b['allowed_radius_meters']], [false, null, null, 150]);
    });

    testWidgets('saving other fields keeps the saved geofence exactly', (tester) async {
      await pump(tester);
      await openEdit(tester, 1);
      await tester.enterText(find.widgetWithText(TextField, 'North').first, 'North Hub');
      await save(tester);
      final b = server.writes.single.body;
      expect(b['branch_name'], 'North Hub');
      expect([b['geofencing_enabled'], b['latitude'], b['longitude'], b['allowed_radius_meters']],
          [true, 19.076, 72.8777, 200]);
    });

    testWidgets('invalid input is flagged inline and nothing is sent; editing a field clears its error', (tester) async {
      await pump(tester);
      await openEdit(tester, 2);
      await setToggle(tester, true);
      await tester.enterText(byKey('branch-geofence-latitude'), '12.9');
      await tester.enterText(byKey('branch-geofence-radius'), '5001');
      await save(tester);
      expect(server.writes, isEmpty);
      expect(fieldError(tester, 'branch-geofence-longitude'), 'Both latitude and longitude must be provided together.');
      expect(fieldError(tester, 'branch-geofence-radius'), 'Allowed radius must be between 10 and 5000 metres.');
      await tester.enterText(byKey('branch-geofence-radius'), '10');
      await tester.pumpAndSettle();
      expect(fieldError(tester, 'branch-geofence-radius'), isNull);
    });

    testWidgets('a server error is shown in the dialog with every value kept; retry succeeds', (tester) async {
      final s = Server()..refuse = (status: 400, message: 'latitude: Ensure that there are no more than 8 decimal places.');
      await pump(tester, with_: s);
      await openEdit(tester, 2);
      await setToggle(tester, true);
      await tester.enterText(byKey('branch-geofence-latitude'), '12.971612345');
      await tester.enterText(byKey('branch-geofence-longitude'), '77.5946');
      await save(tester);
      expect(tester.widget<Text>(find.descendant(of: byKey('branch-form-error'), matching: find.byType(Text))).data,
          'latitude: Ensure that there are no more than 8 decimal places.');
      expect(find.byType(BranchFormDialog), findsOneWidget);
      expect(toggleOn(tester), isTrue);
      expect(fieldText(tester, 'branch-geofence-latitude'), '12.971612345');
      s.refuse = null;
      await tester.enterText(byKey('branch-geofence-latitude'), '12.9716');
      await save(tester);
      expect(s.writes, hasLength(2));
      expect(s.writes.last.body['latitude'], 12.9716);
      expect(find.byType(BranchFormDialog), findsNothing);
    });

    testWidgets('a second tap while saving sends nothing more', (tester) async {
      final s = Server()..hold = Completer();
      await pump(tester, with_: s);
      await openEdit(tester, 1);
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pump();
      expect(tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed, isNull,
          reason: 'Save is disabled while the request is in flight');
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();
      s.hold!.complete();
      await tester.pumpAndSettle();
      expect(s.writes, hasLength(1));
    });

    testWidgets('details sheet shows web\'s status for an enabled branch without coordinates', (tester) async {
      await pump(tester);
      await tester.tap(byKey('view-3'));
      await tester.pumpAndSettle();
      expect(find.text('No Coordinates'), findsOneWidget);
    });
  });

  group('permissions and create', () {
    test('without settings.edit create/edit are refused before any request', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(viewer));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(branchListProvider, (_, __) {});
      await c.read(branchListProvider.future);
      final geo = validateBranchGeofence(enabled: true, latitude: '1', longitude: '2', radius: '100').value;
      final n = c.read(branchListProvider.notifier);
      expect(
          await n.edit(id: 1, cityId: 1, stateId: 1, branchName: 'X', address: 'A', status: 'active', isHeadquarter: false, geofence: geo),
          kBranchEditDenied);
      expect(
          await n.create(cityId: 1, stateId: 1, branchName: 'X', address: 'A', status: 'active', isHeadquarter: false, geofence: geo),
          kBranchEditDenied);
      expect(server.writes, isEmpty);
    });

    test('create (Add Branch) sends the geofence in the POST payload', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(admin));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(branchListProvider, (_, __) {});
      await c.read(branchListProvider.future);
      final geo = validateBranchGeofence(enabled: true, latitude: '28.6139', longitude: '77.2090', radius: '120').value;
      expect(
          await c.read(branchListProvider.notifier).create(
              cityId: 1, stateId: 1, branchName: 'Delhi', address: '2 Test Lane', status: 'active', isHeadquarter: false, geofence: geo),
          isNull);
      final w = server.writes.single;
      expect([w.method, w.path], ['POST', ApiConstants.branches]);
      expect([w.body['geofencing_enabled'], w.body['latitude'], w.body['longitude'], w.body['allowed_radius_meters']],
          [true, 28.6139, 77.209, 120]);
    });

    test('an edit without a geofence argument sends no geofence keys (other callers unchanged)', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(admin));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(branchListProvider, (_, __) {});
      await c.read(branchListProvider.future);
      await c.read(branchListProvider.notifier).edit(
          id: 1, cityId: 1, stateId: 1, branchName: 'North', address: '1 Test Road', status: 'active', isHeadquarter: false);
      final b = server.writes.single.body;
      expect(b.keys.toSet().intersection({'geofencing_enabled', 'latitude', 'longitude', 'allowed_radius_meters'}), isEmpty);
      expect(server.writes.single.method, 'PATCH');
    });
  });
}

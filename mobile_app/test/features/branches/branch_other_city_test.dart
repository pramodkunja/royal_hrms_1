import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/branches/data/models/branch_model.dart';
import 'package:mobile_app/features/branches/domain/branch_form_rules.dart';
import 'package:mobile_app/features/branches/presentation/providers/branch_providers.dart';
import 'package:mobile_app/features/branches/presentation/widgets/branch_form_dialog.dart';
import 'package:mobile_app/features/branches/presentation/widgets/branch_list_states.dart';

// Task 97: Add / Edit Branch "Other (type city name)" — web BranchManagement.tsx
// (OTHER_CITY, CITY_NAME_RE, new_city_name payload, debounced city_name code
// preview) = backend BranchSerializer.validate. Stand-in server, synthetic data.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

const _existing = {
  'id': 1,
  'branch_code': 'UC-001',
  'branch_name': 'Head Office',
  'address': '1 Test Road',
  'state': 1,
  'state_name': 'Test State',
  'city': 77, // not in the cities master list below
  'city_name': 'Unlisted Town',
  'status': 'active',
  'is_headquarter': false,
  'employees_count': 2,
};

class Server implements HttpClientAdapter {
  int citiesStatus = 200;
  List<Map<String, dynamic>> cities = [
    {'id': 5, 'name': 'Test City', 'state': 1, 'state_name': 'Test State'}
  ];
  ({int status, String message})? refuse;
  final calls = <({String method, String path, Map<String, dynamic> query, Object? body})>[];
  Iterable<({String method, String path, Map<String, dynamic> query, Object? body})> get writes =>
      calls.where((c) => c.method != 'GET');
  Iterable<Map<String, dynamic>> get previews =>
      calls.where((c) => c.path == '/branch/branches/preview-code/').map((c) => c.query);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, query: Map.of(o.queryParameters), body: o.data));
    switch ((o.method, o.path)) {
      case ('GET', '/branch/states/'):
        return _json(200, {
          'status': 'success',
          'data': [
            {'id': 1, 'name': 'Test State', 'code': 'TS'}
          ]
        });
      case ('GET', '/branch/states/1/cities/'):
        if (citiesStatus != 200) return _json(citiesStatus, {'status': 'error', 'message': 'boom'});
        return _json(200, {'status': 'success', 'data': cities});
      case ('GET', '/branch/branches/preview-code/'):
        final n = o.queryParameters['city_name'];
        return _json(200, {
          'status': 'success',
          'data': {'branch_code': n != null ? '${n.toString().substring(0, 3).toUpperCase()}-001' : 'TC-009'}
        });
      case ('GET', '/branch/branches/'):
        return _json(200, {
          'status': 'success',
          'data': {'count': 1, 'results': [_existing]}
        });
    }
    if (o.method == 'POST' || o.method == 'PATCH') {
      final r = refuse;
      if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': {}});
      final b = Map<String, dynamic>.from(o.data as Map);
      return _json(o.method == 'POST' ? 201 : 200, {
        'status': 'success',
        'data': {..._existing, 'id': o.method == 'POST' ? 9 : 1, ...b, 'city': 5}
      });
    }
    return _json(200, {'status': 'success', 'data': <String, dynamic>{}});
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
          id: 'u1',
          email: 'admin@example.test',
          fullName: 'Test Admin',
          role: 'system_admin',
          roleDisplay: 'Admin',
          mustChangePassword: false,
          permissions: ['settings.view', 'settings.edit', 'branches.create', 'branches.edit', 'employees.view'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete',
        ),
      );
}

late Server server;
Finder byKey(String k) => find.byKey(Key(k));
final cityField = find.byKey(const Key('branch-new-city-name'));

Future<void> pumpList(WidgetTester tester, {Server? s}) async {
  tester.view.physicalSize = const Size(1080, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = s ?? Server();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          if (ref.watch(authStateProvider).valueOrNull?.user == null) return const SizedBox();
          final list = ref.watch(branchListProvider).valueOrNull ?? const [];
          void open(BranchModel? b) => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => Dialog(child: BranchFormDialog(branch: b)),
              );
          return ListView(children: [
            TextButton(key: const Key('open-add'), onPressed: () => open(null), child: const Text('Add')),
            for (final b in list)
              TextButton(key: Key('edit-${b.id}'), onPressed: () => open(b as BranchModel), child: const Text('Edit')),
          ]);
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> pickState(WidgetTester tester) async {
  await tester.tap(find.text('Select State'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test State').last);
  await tester.pumpAndSettle();
}

Future<void> pickOther(WidgetTester tester) async {
  await tester.tap(find.text('Select City'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(kOtherCityLabel).last);
  await tester.pumpAndSettle();
}

Future<void> fillRest(WidgetTester tester) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Branch Name *'), 'New Branch');
  await tester.enterText(find.widgetWithText(TextFormField, 'Branch Address *'), '2 Test Road');
  await tester.pump();
}

Future<void> typeCity(WidgetTester tester, String v) async {
  await tester.enterText(cityField, v);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pumpAndSettle();
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(byKey('branch-form-submit'));
  await tester.tap(byKey('branch-form-submit'));
  await tester.pumpAndSettle();
}

String? errOf(WidgetTester tester, Finder f) =>
    tester.widget<TextField>(find.descendant(of: f, matching: find.byType(TextField)).first).decoration!.errorText;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (web CITY_NAME_RE + validate)', () {
    test('valid names', () {
      for (final n in ['Pune', 'New Delhi', "St-Mary's Town", 'a b-c']) {
        expect(validateNewCityName(n), isNull, reason: n);
      }
    });
    test('invalid / empty', () {
      expect(validateNewCityName('  '), 'Please enter a city name.');
      for (final n in ['Pune1', 'Pu  ne', '-Pune', 'Pune-', "Pune''x", 'Pün']) {
        expect(validateNewCityName(n), 'City name may only contain letters, spaces, hyphens and apostrophes.',
            reason: n);
      }
    });
  });

  group('Add Branch', () {
    testWidgets('1. no state: city disabled "Select a state first"', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      expect(find.text('Select a state first'), findsOneWidget);
      expect(find.text('Select a city first'), findsOneWidget); // code placeholder
      expect(cityField, findsNothing);
    });

    testWidgets('2. selecting Other shows the text field; code empty until a valid name', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      expect(cityField, findsOneWidget);
      expect(find.text('Enter new city name'), findsWidgets);
      expect(server.previews, isEmpty);
    });

    testWidgets('3. input is filtered to letters, space, apostrophe, hyphen', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      await tester.enterText(cityField, "Ab1c2 d_e!-f'g");
      await tester.pump();
      expect(tester.widget<TextField>(cityField).controller!.text, "Abc de-f'g");
    });

    testWidgets('4. debounced city_name preview shows the code (no city_id)', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      await tester.enterText(cityField, 'Pu');
      await tester.enterText(cityField, 'Pune');
      await tester.pump(const Duration(milliseconds: 100));
      expect(server.previews, isEmpty); // still debouncing
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(server.previews.toList(), [
        {'city_name': 'Pune'}
      ]);
      expect(find.widgetWithText(TextFormField, 'PUN-001'), findsOneWidget);
      // an invalid name clears the code again
      await typeCity(tester, 'Pune-');
      expect(find.widgetWithText(TextFormField, 'PUN-001'), findsNothing);
    });

    testWidgets('5. empty name: "Please enter a city name."; nothing sent', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      await fillRest(tester);
      await submit(tester);
      expect(find.text('Please enter a city name.'), findsOneWidget);
      expect(server.writes, isEmpty);
    });

    testWidgets('6. invalid name (trailing hyphen) shows the regex message; nothing sent', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      await fillRest(tester);
      await typeCity(tester, 'Pune-');
      await submit(tester);
      expect(find.text('City name may only contain letters, spaces, hyphens and apostrophes.'), findsOneWidget);
      expect(server.writes, isEmpty);
    });

    testWidgets('7. valid name: POST has new_city_name (trimmed) and no city', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      await fillRest(tester);
      await typeCity(tester, '  Pune ');
      await submit(tester);
      final w = server.writes.toList();
      expect(w, hasLength(1));
      expect(w.single.method, 'POST');
      final body = Map<String, dynamic>.from(w.single.body as Map);
      expect(body['new_city_name'], 'Pune');
      expect(body.containsKey('city'), isFalse);
      expect(body['state'], 1);
      expect(body['branch_name'], 'New Branch');
      expect(find.byType(BranchFormDialog), findsNothing);
    });

    testWidgets('8. listed city still sends city and no new_city_name', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await tester.tap(find.text('Select City'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test City').last);
      await tester.pumpAndSettle();
      expect(server.previews.toList(), [
        {'city_id': 5}
      ]);
      await fillRest(tester);
      await submit(tester);
      final body = Map<String, dynamic>.from(server.writes.single.body as Map);
      expect(body['city'], 5);
      expect(body.containsKey('new_city_name'), isFalse);
    });

    testWidgets('9. switching back to a listed city hides and clears the field', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      await typeCity(tester, 'Pune');
      await tester.tap(find.text(kOtherCityLabel).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test City').last);
      await tester.pumpAndSettle();
      expect(cityField, findsNothing);
    });

    testWidgets('10. empty city list: only Other is offered and works', (tester) async {
      final s = Server()..cities = [];
      await pumpList(tester, s: s);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await tester.tap(find.text('Select City'));
      await tester.pumpAndSettle();
      expect(find.text('Test City'), findsNothing);
      expect(find.text(kOtherCityLabel), findsOneWidget);
    });

    testWidgets('11. cities request fails: same as empty (web catch -> [])', (tester) async {
      final s = Server()..citiesStatus = 500;
      await pumpList(tester, s: s);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      expect(cityField, findsOneWidget);
      expect(find.text('Could not load cities'), findsNothing);
    });

    testWidgets('12. no state / no city: web messages with full stops', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await fillRest(tester);
      await submit(tester);
      expect(find.text('Please select a state.'), findsOneWidget);
      expect(find.text('Please select a city.'), findsOneWidget);
      expect(server.writes, isEmpty);
    });

    testWidgets('13. empty address: "Address is required."', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      await typeCity(tester, 'Pune');
      await tester.enterText(find.widgetWithText(TextFormField, 'Branch Name *'), 'New Branch');
      await submit(tester);
      expect(find.text('Address is required.'), findsOneWidget);
    });

    testWidgets('14. Other chosen but code not generated: web code message', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      await fillRest(tester);
      await submit(tester);
      expect(find.text('Branch code could not be generated. Try re-selecting the city.'), findsOneWidget);
    });

    testWidgets('15. server 403 shown in the form, values kept, new name kept', (tester) async {
      final s = Server()..refuse = (status: 403, message: 'You do not have permission to perform this action.');
      await pumpList(tester, s: s);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      await fillRest(tester);
      await typeCity(tester, 'Pune');
      await submit(tester);
      expect(find.byType(BranchFormDialog), findsOneWidget);
      expect(find.textContaining('permission'), findsWidgets);
      expect(tester.widget<TextField>(cityField).controller!.text, 'Pune');
    });

    testWidgets('16. server field error is surfaced', (tester) async {
      final s = Server()..refuse = (status: 400, message: 'City name may only contain letters, spaces, hyphens and apostrophes.');
      await pumpList(tester, s: s);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      await pickState(tester);
      await pickOther(tester);
      await fillRest(tester);
      await typeCity(tester, 'Pune');
      await submit(tester);
      expect(find.byType(BranchFormDialog), findsOneWidget);
      expect(find.textContaining('City name may only contain'), findsWidgets);
    });
  });

  group('Edit Branch', () {
    testWidgets('17. city not in master list: edit keeps city id, no preview, no Other field', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('edit-1'));
      await tester.pumpAndSettle();
      expect(cityField, findsNothing);
      expect(server.previews, isEmpty);
      await tester.enterText(find.widgetWithText(TextFormField, 'Branch Name *'), 'Renamed Office');
      await submit(tester);
      final w = server.writes.single;
      expect(w.method, 'PATCH');
      final body = Map<String, dynamic>.from(w.body as Map);
      expect(body['city'], 77);
      expect(body.containsKey('new_city_name'), isFalse);
    });

    testWidgets('18. edit with Other: PATCH has new_city_name and no city; no code preview', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('edit-1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Select City'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(kOtherCityLabel).last);
      await tester.pumpAndSettle();
      await typeCity(tester, "Saint-John's");
      expect(server.previews, isEmpty);
      await submit(tester);
      final body = Map<String, dynamic>.from(server.writes.single.body as Map);
      expect(body['new_city_name'], "Saint-John's");
      expect(body.containsKey('city'), isFalse);
    });
  });

  // Task 98: copy parity with web BranchManagement.tsx.
  group('copy (web strings)', () {
    testWidgets('Add form labels, placeholders and no extra helper text', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('open-add'));
      await tester.pumpAndSettle();
      expect(find.text('Add New Branch'), findsOneWidget);
      expect(find.text('Create a new office location'), findsNothing);
      expect(find.text('State/Region *'), findsOneWidget);
      expect(find.text('Select State'), findsOneWidget);
      expect(find.text('City *'), findsOneWidget);
      expect(find.text('Branch Code (auto-generated)'), findsOneWidget);
      expect(find.text('Branch Name *'), findsOneWidget);
      expect(find.text('Branch Address *'), findsOneWidget);
      expect(find.text('Status *'), findsOneWidget);
      expect(find.text('Mark as Headquarter'), findsOneWidget);
      expect(find.text('Only one branch can be the headquarter'), findsNothing);
      expect(find.text('Enable Geofencing'), findsOneWidget);
      expect(find.text('Create Branch'), findsOneWidget);
      await pickState(tester);
      expect(find.text('Select City'), findsOneWidget);
    });

    testWidgets('Edit form title has no subtitle; Save Changes', (tester) async {
      await pumpList(tester);
      await tester.tap(byKey('edit-1'));
      await tester.pumpAndSettle();
      expect(find.text('Edit Branch: Head Office'), findsOneWidget);
      expect(find.text('Update branch details'), findsNothing);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Status *'), findsOneWidget);
    });

    testWidgets('empty list copy', (tester) async {
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: BranchEmptyView(onAdd: () {}))));
      expect(find.text('No Branches Found'), findsOneWidget);
      expect(find.text("You haven't added any branches yet."), findsOneWidget);
    });
  });
}

import 'dart:async';
import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:mobile_app/features/attendance/presentation/widgets/ot_approver_field.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/employees/data/datasources/employees_remote_datasource.dart';
import 'package:mobile_app/features/employees/data/models/employee_model.dart';
import 'package:mobile_app/features/employees/presentation/providers/employee_providers.dart';

// Task 42 (D-A11): HR Attendance → OT Entry "Approved By" picker. Web
// OtEntryTab.tsx lists approvers from GET /employees/hrs/ and saves
// approved_by = the approver's employee_id; production HRListView needs a
// branch and employees.view. Mobile scopes the list to the selected OT
// employee's branch. A stand-in server answers every call; nothing is sent
// anywhere and no overtime is really created. Synthetic data only.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

Map<String, dynamic> emp(String code, String name, String branch) => {
      'id': 'u-$code',
      'employee_id': code,
      'first_name': name.split(' ').first,
      'last_name': name.split(' ').last,
      'full_name': name,
      'email': '',
      'branch': branch,
      'status': 'active',
      'is_active': true,
    };

Map<String, dynamic> hr(String code, String name, String branch) =>
    {'id': 'uuid-$code', 'employee_id': code, 'full_name': name, 'department': 'HR', 'branch': branch};

class FakeServer implements HttpClientAdapter {
  Map<String, List<Map<String, dynamic>>> hrsByBranch = {
    'North Wing': [hr('HR-N1', 'Asha Rao', 'North Wing'), hr('HR-N2', 'Bilal Khan', 'North Wing')],
    'South Wing': [hr('HR-S1', 'Chen Li', 'South Wing')],
    'East Wing': [],
  };
  int? hrsStatus;
  Completer<void>? holdHrs;
  ({int status, String message})? refuseCreate;
  final hrQueries = <Map<String, dynamic>>[];
  final creates = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == '/employees/' && o.method == 'GET') {
      return _json(200, {
        'status': 'success',
        'data': {
          'results': [
            emp('EMP-1', 'Pat Kumar', 'North Wing'),
            emp('EMP-2', 'Sam Iyer', 'South Wing'),
            emp('EMP-3', 'Lee Das', 'North Wing'),
            emp('EMP-4', 'Ria Sen', ''),
            emp('EMP-5', 'Om Nair', 'East Wing'),
          ],
          'total_pages': 1,
        },
      });
    }
    if (o.path == '/employees/hrs/' && o.method == 'GET') {
      hrQueries.add(Map.of(o.queryParameters));
      final gate = holdHrs;
      if (gate != null) await gate.future;
      final st = hrsStatus;
      if (st != null) return _json(st, {'status': 'error', 'message': 'HR list unavailable.', 'data': {}});
      final branch = o.queryParameters['branch'] as String?;
      if (branch == null || branch.isEmpty) {
        return _json(400, {'status': 'error', 'message': 'branch query parameter is required.', 'data': {}});
      }
      return _json(200, {'status': 'success', 'message': 'HR users retrieved.', 'data': hrsByBranch[branch] ?? []});
    }
    if (o.path == '/attendance/overtime/create/' && o.method == 'POST') {
      creates.add(Map<String, dynamic>.from(o.data as Map));
      final r = refuseCreate;
      if (r != null) return _json(r.status, {'status': 'error', 'message': r.message, 'data': {}});
      return _json(201, {
        'status': 'success',
        'message': 'Overtime entry created.',
        'data': {'id': 'ot-1'}
      });
    }
    // Everything else on the screen: empty lists / zero counts.
    return _json(200, {
      'status': 'success',
      'message': 'ok',
      'data': {'results': [], 'count': 0, 'summary_chips': <String, int>{}},
    });
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

UserEntity hrUser(List<String> perms) => UserEntity(
      id: 'hr1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final hrEntry = hrUser(['attendance.view', 'attendance.create', 'employees.view']);

late FakeServer server;
late ProviderContainer container;

Dio _dio(FakeServer s) => Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s;

Finder byKey(String k) => find.byKey(Key(k));

Future<void> pumpOtTab(WidgetTester tester, {UserEntity? as, FakeServer? with_}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? FakeServer();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? hrEntry)),
      dioProvider.overrideWithValue(_dio(server)),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      // 24-hour time picker, so times are typed as HH and MM.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      home: const Scaffold(body: AttendanceScreen()),
    ),
  ));
  await tester.pumpAndSettle();
  container = ProviderScope.containerOf(tester.element(find.byType(AttendanceScreen)));
  await tester.tap(find.text('OT Entry'));
  await tester.pumpAndSettle();
}

Future<void> selectEmployee(WidgetTester tester, String label, {String from = 'Select employee'}) async {
  await tester.tap(find.text(from).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> selectApprover(WidgetTester tester, String name) async {
  await tester.tap(find.byWidgetPredicate((w) =>
      w.key is ValueKey && '${(w.key as ValueKey).value}'.startsWith('ot-approver-') && w is DropdownButtonFormField));
  await tester.pumpAndSettle();
  await tester.tap(find.text(name).last);
  await tester.pumpAndSettle();
}

Future<void> setTime(WidgetTester tester, int index, String hh, String mm) async {
  await tester.tap(find.text('Select time').first);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.keyboard_outlined));
  await tester.pumpAndSettle();
  final fields = find.descendant(of: find.byType(Dialog), matching: find.byType(TextField));
  await tester.enterText(fields.at(0), hh);
  await tester.enterText(fields.at(1), mm);
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

Future<void> fillTimes(WidgetTester tester) async {
  await setTime(tester, 0, '09', '00'); // OT Start
  await setTime(tester, 1, '11', '30'); // OT End (the remaining "Select time")
}

Future<void> submit(WidgetTester tester) async {
  await tester.ensureVisible(find.widgetWithText(ElevatedButton, 'Add OT Entry'));
  await tester.tap(find.widgetWithText(ElevatedButton, 'Add OT Entry'));
  await tester.pumpAndSettle();
}

List<String> approverItems(WidgetTester tester) => tester
    .widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>))
    .items!
    .map((i) => (i.child as Text).data!)
    .toList();

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules', () {
    const listed = [
      EmployeePickerOption(id: 'u1', employeeId: 'HR-N1', fullName: 'Asha Rao', department: 'HR', branch: 'North'),
    ];

    test('otApproverForSubmit: none, a listed approver, an unlisted or unknown one', () {
      expect(otApproverForSubmit(null, listed), (approvedBy: null, error: null));
      expect(otApproverForSubmit('', null), (approvedBy: null, error: null));
      expect(otApproverForSubmit('HR-N1', listed), (approvedBy: 'HR-N1', error: null));
      expect(otApproverForSubmit('HR-S1', listed).approvedBy, isNull);
      expect(otApproverForSubmit('HR-S1', listed).error, contains('no longer available'));
      expect(otApproverForSubmit('HR-N1', null).error, isNotNull, reason: 'list not loaded: never sent unchecked');
    });

    test('GET /employees/hrs/ with the branch; employee_id and full_name parsed', () async {
      final s = FakeServer();
      final list = await EmployeesRemoteDataSource(_dio(s)).fetchHrs('North Wing');
      expect(s.hrQueries.single, {'branch': 'North Wing'});
      expect(list.map((o) => (o.employeeId, o.fullName, o.id)), [
        ('HR-N1', 'Asha Rao', 'uuid-HR-N1'),
        ('HR-N2', 'Bilal Khan', 'uuid-HR-N2'),
      ]);
    });
  });

  group('OT Entry', () {
    testWidgets('1. no free-text field; picker waits for an employee and asks nothing yet', (tester) async {
      await pumpOtTab(tester);
      expect(find.text('Approved By'), findsOneWidget);
      expect(find.textContaining('employee ID or name'), findsNothing);
      expect(find.text('e.g. E001 or Jane Doe'), findsNothing);
      expect(byKey('ot-approver-disabled'), findsOneWidget);
      expect(find.text('Select an employee first'), findsOneWidget);
      expect(server.hrQueries, isEmpty);
    });

    testWidgets('2. approvers for the employee\'s branch, full names; the employee_id is saved as approved_by',
        (tester) async {
      await pumpOtTab(tester);
      await selectEmployee(tester, 'Pat Kumar (EMP-1)');
      expect(server.hrQueries.single, {'branch': 'North Wing'});
      await selectApprover(tester, 'Bilal Khan');
      expect(approverItems(tester), ['Select approver…', 'Asha Rao', 'Bilal Khan']);
      await fillTimes(tester);
      await submit(tester);
      expect(server.creates, hasLength(1));
      final body = server.creates.single;
      expect(body['employee_id'], 'EMP-1');
      expect(body['approved_by'], 'HR-N2', reason: 'web: approved_by = employee_id, not the name or UUID');
      expect(body['ot_start'], '09:00:00');
      expect(body['ot_end'], '11:30:00');
      expect(body['ot_type'], 'regular');
      expect(find.text('OT entry added.'), findsOneWidget);
      // After saving, the approver is cleared (web resets the form).
      expect(approverItems(tester).first, 'Select approver…');
      final field = tester.widget<DropdownButtonFormField<String?>>(find.byType(DropdownButtonFormField<String?>));
      expect(field.initialValue, isNull);
    });

    testWidgets('3. no approver chosen: approved_by is not sent (backend saves it as Pending)', (tester) async {
      await pumpOtTab(tester);
      await selectEmployee(tester, 'Pat Kumar (EMP-1)');
      await fillTimes(tester);
      await submit(tester);
      expect(server.creates.single.containsKey('approved_by'), isFalse);
    });

    testWidgets('4. another employee: that branch\'s approvers, previous choice cleared', (tester) async {
      await pumpOtTab(tester);
      await selectEmployee(tester, 'Pat Kumar (EMP-1)');
      await selectApprover(tester, 'Asha Rao');
      await selectEmployee(tester, 'Sam Iyer (EMP-2)', from: 'Pat Kumar (EMP-1)');
      expect(server.hrQueries.last, {'branch': 'South Wing'});
      expect(approverItems(tester), ['Select approver…', 'Chen Li']);
      await fillTimes(tester);
      await submit(tester);
      expect(server.creates.single['employee_id'], 'EMP-2');
      expect(server.creates.single.containsKey('approved_by'), isFalse, reason: 'North Wing approver not carried over');
    });

    testWidgets('5. loading, then an empty branch says so; the entry can still be saved', (tester) async {
      final s = FakeServer();
      final gate = s.holdHrs = Completer<void>();
      await pumpOtTab(tester, with_: s);
      await tester.tap(find.text('Select employee'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Om Nair (EMP-5)').last);
      await tester.pump();
      await tester.pump();
      expect(byKey('ot-approver-loading'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('No HR approver is available for East Wing. The entry will be saved without an approver.'),
          findsOneWidget);
      await fillTimes(tester);
      await submit(tester);
      expect(s.creates.single.containsKey('approved_by'), isFalse);
    });

    testWidgets('6. error with the server message; Retry asks again and shows the list', (tester) async {
      final s = FakeServer()..hrsStatus = 500;
      await pumpOtTab(tester, with_: s);
      await selectEmployee(tester, 'Pat Kumar (EMP-1)');
      expect(byKey('ot-approver-error'), findsOneWidget);
      expect(find.textContaining('HR list unavailable.'), findsOneWidget);
      s.hrsStatus = null;
      await tester.tap(byKey('ot-approver-retry'));
      await tester.pumpAndSettle();
      expect(s.hrQueries, hasLength(2));
      expect(byKey('ot-approver-error'), findsNothing);
      await selectApprover(tester, 'Asha Rao');
    });

    testWidgets('7. employee without a branch: nothing requested (the backend needs one), explained', (tester) async {
      await pumpOtTab(tester);
      await selectEmployee(tester, 'Ria Sen (EMP-4)');
      expect(byKey('ot-approver-no-branch'), findsOneWidget);
      expect(server.hrQueries, isEmpty);
    });

    testWidgets('8. viewer without employees.view: no request (HRListView would 403); can still save', (tester) async {
      await pumpOtTab(tester, as: hrUser(['attendance.view', 'attendance.create']));
      await selectEmployee(tester, 'Pat Kumar (EMP-1)');
      expect(byKey('ot-approver-no-permission'), findsOneWidget);
      expect(server.hrQueries, isEmpty);
      await fillTimes(tester);
      await submit(tester);
      expect(server.creates.single.containsKey('approved_by'), isFalse);
    });

    testWidgets('9. an approver who drops out of the list is never sent; the form says so', (tester) async {
      await pumpOtTab(tester);
      await selectEmployee(tester, 'Pat Kumar (EMP-1)');
      await selectApprover(tester, 'Bilal Khan');
      await fillTimes(tester);
      // The branch's HR list changes (Bilal deactivated) and is reloaded.
      server.hrsByBranch['North Wing'] = [hr('HR-N1', 'Asha Rao', 'North Wing')];
      container.invalidate(employeeHrOptionsProvider('North Wing'));
      await tester.pumpAndSettle();
      expect(approverItems(tester), ['Select approver…', 'Asha Rao']);
      await submit(tester);
      expect(server.creates, isEmpty);
      expect(
          find.text(
              'The selected approver is no longer available for this employee. Choose another approver or leave it empty.'),
          findsOneWidget);
      // Saving again goes through without an approver.
      await submit(tester);
      expect(server.creates.single.containsKey('approved_by'), isFalse);
    });

    testWidgets('10. a save error is shown and the chosen approver is kept for another try', (tester) async {
      final s = FakeServer()..refuseCreate = (status: 400, message: 'OT date cannot be in the future.');
      await pumpOtTab(tester, with_: s);
      await selectEmployee(tester, 'Pat Kumar (EMP-1)');
      await selectApprover(tester, 'Asha Rao');
      await fillTimes(tester);
      await submit(tester);
      expect(find.text('OT date cannot be in the future.'), findsOneWidget);
      s.refuseCreate = null;
      await submit(tester);
      expect(s.creates.map((c) => c['approved_by']), ['HR-N1', 'HR-N1']);
    });

    testWidgets('11. existing validation still runs before anything is sent', (tester) async {
      await pumpOtTab(tester);
      await submit(tester);
      expect(find.text('Please select an employee.'), findsOneWidget);
      await selectEmployee(tester, 'Pat Kumar (EMP-1)');
      await submit(tester);
      expect(find.text('Please select OT start and end times.'), findsOneWidget);
      expect(server.creates, isEmpty);
    });
  });
}

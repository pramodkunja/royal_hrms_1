// Task 110 Part A harness: Add / Edit Candidate → Interviewer selector, with a stand-in API
// (nothing leaves the test) and render-evidence shots (T1011_SHOTS=1).
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

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
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/interview_list/data/models/candidate_model.dart';
import 'package:mobile_app/features/interview_list/presentation/providers/interview_providers.dart';
import 'package:mobile_app/features/interview_list/presentation/widgets/add_candidate_sheet.dart';
import 'package:mobile_app/features/separation/presentation/widgets/employee_picker_field.dart';

import 'shot_harness.dart';

const longName = 'Venkatasubramanian Ramachandran Iyer-Krishnamurthy the Third of Hyderabad';

class T110Server implements HttpClientAdapter {
  /// People the directory returns. Default: a handful, one with a very long name.
  List<Map<String, dynamic>> people = defaultPeople();
  int? total; // the directory's real size when larger than what is returned
  int employeesStatus = 200;
  Completer<void>? employeesHold;
  int? saveStatus;
  String saveMessage = 'Enter a valid URL.';
  final requests = <({String method, String path, Map<String, dynamic> query, Object? body})>[];

  static List<Map<String, dynamic>> defaultPeople() => [
        person(1, 'Asha Verma', 'Senior Engineer'),
        person(2, longName, 'Principal Architect and Engineering Manager'),
        person(3, 'Ravi Kumar', 'HR Executive'),
        person(4, 'Meera Nair', ''),
      ];

  static Map<String, dynamic> person(int n, String name, String designation) => {
        'uuid': 'uuid-$n',
        'id': 'EMP-${n.toString().padLeft(4, '0')}',
        'employee_id': 'EMP-${n.toString().padLeft(4, '0')}',
        'full_name': name,
        'department': 'Engineering',
        'designation': designation,
      };

  static List<Map<String, dynamic>> many(int n) =>
      [for (var i = 1; i <= n; i++) person(i, 'Person Number $i', 'Role $i')];

  List<Map<String, dynamic>> writes(String method) => [
        for (final r in requests)
          if (r.method == method) Map<String, dynamic>.from(r.body as Map)
      ];
  List<({String method, String path, Map<String, dynamic> query, Object? body})> gets(String path) => [
        for (final r in requests)
          if (r.method == 'GET' && r.path == path) r
      ];

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    requests.add((method: o.method, path: o.path, query: Map.of(o.queryParameters), body: o.data));
    if (o.method == 'POST' || o.method == 'PUT') {
      if (saveStatus != null) {
        return _json({
          'status': 'error',
          'message': saveMessage,
          'data': {
            'meeting_link': [saveMessage]
          }
        }, saveStatus!);
      }
      final b = Map<String, dynamic>.from(o.data as Map);
      return _json({
        'status': 'success',
        'message': 'Saved.',
        'data': {
          'id': 7,
          'name': 'New Person',
          'email': 'new@example.test',
          'position_applied': 'Analyst',
          'status': 'pending',
          'interview_mode': 'in_person',
          'meeting_link': '',
          'created_at': '2026-11-01T10:00:00Z',
          ...b,
        },
      }, o.method == 'POST' ? 201 : 200);
    }
    if (o.path == ApiConstants.employees) {
      final hold = employeesHold;
      if (hold != null) await hold.future;
      if (employeesStatus != 200) {
        return _json(
            {'status': 'error', 'message': employeesStatus == 403 ? 'You do not have permission.' : 'Server error.'},
            employeesStatus);
      }
      final q = (o.queryParameters['search'] as String?)?.toLowerCase();
      final rows =
          q == null ? people : people.where((p) => '${p['full_name']} ${p['id']}'.toLowerCase().contains(q)).toList();
      return _json({
        'status': 'success',
        'data': {'count': q == null ? (total ?? rows.length) : rows.length, 'results': rows}
      });
    }
    if (o.path == ApiConstants.branches) {
      return _json({
        'status': 'success',
        'data': {
          'results': [
            {'id': 1, 'branch_name': 'North'}
          ]
        }
      });
    }
    if (o.path == ApiConstants.candidateStats) {
      return _json({
        'status': 'success',
        'data': {'total': 0, 'pending': 0, 'selected': 0, 'rejected': 0}
      });
    }
    if (o.path == ApiConstants.candidates) {
      return _json({
        'status': 'success',
        'data': {'count': 0, 'page': 1, 'page_size': 10, 'total_pages': 1, 'status_choices': [], 'results': <Object>[]}
      });
    }
    return _json({'status': 'success', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

class _Storage extends SecureStorageService {
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
          email: 'hr@example.test',
          fullName: 'Test HR',
          role: 'hr',
          roleDisplay: 'HR',
          branch: 'North',
          mustChangePassword: false,
          permissions: ['recruitment.view', 'recruitment.edit', 'recruitment.create', 'employees.view'],
          onboardingStatus: 'complete',
          assessmentStatus: 'complete'));
}

late T110Server last;

Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 12; i++) {
    await t.pump(const Duration(milliseconds: 80));
  }
}

Map<String, dynamic> existingCandidate({String? interviewer, String interviewerName = ''}) => {
      'id': 7,
      'name': 'Test Candidate',
      'email': 'candidate@example.test',
      'phone': '9000000000',
      'position_applied': 'Analyst',
      'branch': 1,
      'branch_name': 'North',
      'interview_date': null,
      'interview_time': null,
      'interview_mode': 'in_person',
      'meeting_link': '',
      'interviewer': interviewer,
      'interviewer_name': interviewerName,
      'status': 'pending',
      'portal_credentials_sent': false,
      'added_by_name': 'Test HR',
      'created_at': '2026-11-01T10:00:00Z',
    };

Future<void> openForm(WidgetTester t,
    {Size size = const Size(393, 852),
    double scale = 1,
    T110Server? server,
    Map<String, dynamic>? existing,
    bool dark = false,
    double keyboard = 0,
    bool shots = true}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  if (keyboard > 0) t.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(t.view.reset);
  AppColors.applyMode(dark);
  addTearDown(() => AppColors.applyMode(false));
  if (shots && shotsEnabled) await t.runAsync(loadShotFonts);
  final s = server ?? T110Server();
  last = s;
  await t.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(_Auth.new),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_Storage()),
    ],
    child: shotFrame(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(dark),
      builder: (c, child) =>
          MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          ref.watch(authStateProvider);
          ref.watch(candidateListProvider);
          return Center(
            child: ElevatedButton(
              key: const Key('open'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) =>
                    AddCandidateDialog(existing: existing == null ? null : CandidateModel.fromJson(existing)),
              ),
              child: const Text('open'),
            ),
          );
        }),
      ),
    )),
  ));
  await settle(t);
  await t.tap(find.byKey(const Key('open')));
  await settle(t);
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> reveal(WidgetTester t) async {
  if (byKey('candidate-interviewer').evaluate().isEmpty) {
    // the form is a lazy scroll view: bring the field into the built range first
    await t.scrollUntilVisible(byKey('candidate-interviewer'), 200, scrollable: find.descendant(of: find.byType(Dialog), matching: find.byType(Scrollable)).first);
  }
  await t.ensureVisible(byKey('candidate-interviewer'));
}

Future<void> openSelector(WidgetTester t) async {
  await reveal(t);
  await t.pump();
  await t.tap(byKey('candidate-interviewer'));
  await settle(t);
}

void shot(String name, Future<void> Function(WidgetTester t) body) {
  testWidgets('shot $name', (t) async {
    await body(t);
    await shoot(t, name);
  }, skip: !shotsEnabled);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Before-screenshots: the previous control (search-first employee picker, still used elsewhere in the app).
  shot('b_01_old_search_picker', (t) async {
    t.view.physicalSize = const Size(393, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    if (shotsEnabled) await t.runAsync(loadShotFonts);
    last = T110Server();
    await t.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_Auth.new),
        dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = last),
        cookieJarProvider.overrideWithValue(CookieJar()),
        secureStorageProvider.overrideWithValue(_Storage()),
      ],
      child: shotFrame(MaterialApp(
        theme: AppTheme.themeFor(false),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Interviewer'),
              const SizedBox(height: 6),
              EmployeePickerField(value: null, onChanged: (_) {}, hintText: 'Search interviewer by name or ID…'),
            ]),
          ),
        ),
      )),
    ));
    await settle(t);
  });
  shot('b_02_old_search_typed', (t) async {
    t.view.physicalSize = const Size(393, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    if (shotsEnabled) await t.runAsync(loadShotFonts);
    last = T110Server();
    await t.pumpWidget(ProviderScope(
      overrides: [
        authStateProvider.overrideWith(_Auth.new),
        dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = last),
        cookieJarProvider.overrideWithValue(CookieJar()),
        secureStorageProvider.overrideWithValue(_Storage()),
      ],
      child: shotFrame(MaterialApp(
        theme: AppTheme.themeFor(false),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Interviewer'),
              const SizedBox(height: 6),
              EmployeePickerField(value: null, onChanged: (_) {}, hintText: 'Search interviewer by name or ID…'),
            ]),
          ),
        ),
      )),
    ));
    await settle(t);
    await t.enterText(find.byType(TextField), 'ra');
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
  });

  shot('i_01_form', (t) async {
    await openForm(t, size: const Size(393, 1200));
    await reveal(t);
    await t.pump();
  });
  shot('i_02_dropdown_open', (t) async {
    await openForm(t, size: const Size(393, 852));
    await openSelector(t);
  });
  shot('i_03_prefilled_edit', (t) async {
    await openForm(t,
        size: const Size(393, 1200), existing: existingCandidate(interviewer: 'uuid-2', interviewerName: longName));
    await reveal(t);
    await t.pump();
  });
  shot('i_04_large_list_filter', (t) async {
    await openForm(t, size: const Size(393, 852), server: T110Server()..people = T110Server.many(60));
    await openSelector(t);
  });
  shot('i_05_error', (t) async {
    await openForm(t, size: const Size(393, 852), server: T110Server()..employeesStatus = 500);
    await openSelector(t);
  });
  shot('i_06_empty', (t) async {
    await openForm(t, size: const Size(393, 852), server: T110Server()..people = []);
    await openSelector(t);
  });
  shot('i_07_320_2x_open', (t) async {
    await openForm(t, size: const Size(320, 568), scale: 2);
    await openSelector(t);
  });
  shot('i_08_320_2x_form', (t) async {
    await openForm(t,
        size: const Size(320, 2400),
        scale: 2,
        existing: existingCandidate(interviewer: 'uuid-2', interviewerName: longName));
    await reveal(t);
    await t.pump();
  });
  shot('i_09_keyboard_filter', (t) async {
    await openForm(t, size: const Size(393, 852), keyboard: 300, server: T110Server()..people = T110Server.many(30));
    await openSelector(t);
  });
  shot('i_10_dark_open', (t) async {
    await openForm(t, size: const Size(393, 852), dark: true);
    await openSelector(t);
  });
  shot('i_11_tablet_open', (t) async {
    await openForm(t, size: const Size(1000, 800));
    await openSelector(t);
  });
}

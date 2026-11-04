import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/contacts/data/models/company_contact.dart';
import 'package:mobile_app/features/contacts/presentation/screens/contact_matrix_screen.dart';
import 'package:mobile_app/features/dashboard/presentation/navigation/nav_config.dart';

// Phase 5 (C): the Company Contact Matrix against a stand-in for the
// production API (apps/accounts/views_policy.py): GET lists company-wide
// contacts plus the caller's branch with `can_manage` (documents.create);
// POST needs documents.create, PATCH documents.edit, DELETE documents.delete
// (soft delete); name required; an email or a phone required.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

class FakeContactsServer implements HttpClientAdapter {
  FakeContactsServer(this.contacts, {required this.perms});

  final List<Map<String, dynamic>> contacts;
  final Set<String> perms;
  final calls = <({String method, String path, Object? body, Map<String, dynamic> query})>[];
  int nextId = 100;
  int failNextGet = 0; // status to answer the next GET with (0 = normal)
  bool dropNextGet = false;
  Completer<void>? holdWrite;

  bool _has(String p) => perms.contains(p) || perms.contains('settings.edit');
  int count(String method, [String? path]) =>
      calls.where((c) => c.method == method && (path == null || c.path == path)).length;

  Map<String, dynamic> _row(Map<String, dynamic> c) => {...c}..remove('_active');

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data, query: o.queryParameters));
    final m = o.method;
    if (o.path == '/branch/branches/' && m == 'GET') {
      return _json(200, {
        'status': 'success',
        'message': 'ok',
        'data': {
          'results': [
            {'id': 1, 'branch_name': 'Surat'},
            {'id': 2, 'branch_name': 'Hyderabad'},
          ]
        }
      });
    }
    if (o.path == '/company-contacts/' && m == 'GET') {
      if (dropNextGet) {
        dropNextGet = false;
        throw DioException(requestOptions: o, type: DioExceptionType.connectionError);
      }
      if (failNextGet != 0) {
        final s = failNextGet;
        failNextGet = 0;
        return _json(s, {'status': 'error', 'message': 'Server error.', 'data': {}});
      }
      return _json(200, {
        'status': 'success',
        'message': 'Contact matrix.',
        'data': {
          'contacts': [
            for (final c in contacts)
              if (c['_active'] != false) _row(c)
          ],
          'can_manage': _has('documents.create'),
        }
      });
    }
    if (holdWrite != null) await holdWrite!.future;
    final body = (o.data is Map ? (o.data as Map).cast<String, dynamic>() : <String, dynamic>{});
    String? invalid() {
      if (body.containsKey('name') && '${body['name']}'.trim().isEmpty) return 'Name is required.';
      if ('${body['email'] ?? ''}'.isEmpty && '${body['phone'] ?? ''}'.isEmpty) {
        return 'Enter an email or a phone number.';
      }
      return null;
    }

    if (o.path == '/company-contacts/' && m == 'POST') {
      if (!_has('documents.create')) {
        return _json(403, {'status': 'error', 'message': 'You do not have permission to manage contacts.', 'data': {}});
      }
      final bad = invalid();
      if (bad != null) return _json(400, {'status': 'error', 'message': bad, 'data': {}});
      final row = {...body, 'id': nextId++, 'branch_name': body['branch'] == 1 ? 'Surat' : ''};
      contacts.add(row);
      return _json(201, {'status': 'success', 'message': 'Contact added.', 'data': row});
    }
    final detail = RegExp(r'^/company-contacts/(\d+)/$').firstMatch(o.path);
    if (detail != null) {
      final id = int.parse(detail.group(1)!);
      final row = contacts.where((c) => c['id'] == id && c['_active'] != false).firstOrNull;
      if (m == 'PATCH') {
        if (!_has('documents.edit')) {
          return _json(
              403, {'status': 'error', 'message': 'You do not have permission to manage contacts.', 'data': {}});
        }
        if (row == null) return _json(404, {'status': 'error', 'message': 'Contact not found.', 'data': {}});
        row.addAll(body);
        return _json(200, {'status': 'success', 'message': 'Contact updated.', 'data': _row(row)});
      }
      if (m == 'DELETE') {
        if (!_has('documents.delete')) {
          return _json(
              403, {'status': 'error', 'message': 'You do not have permission to manage contacts.', 'data': {}});
        }
        if (row == null) return _json(404, {'status': 'error', 'message': 'Contact not found.', 'data': {}});
        row['_active'] = false;
        return _json(200, {'status': 'success', 'message': 'Contact removed.', 'data': {}});
      }
    }
    return _json(404, {'status': 'error', 'message': 'Not found', 'data': {}});
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> contact(int id, String name, int level,
        {int order = 0, String email = '', String phone = '', int? branch, String branchName = ''}) =>
    {
      'id': id,
      'name': name,
      'designation': 'HR Executive',
      'department': 'HR',
      'email': email,
      'phone': phone,
      'purpose': 'Attendance, WFH',
      'escalation_level': level,
      'branch': branch,
      'branch_name': branchName,
      'display_order': order,
    };

List<Map<String, dynamic>> seed() => [
      contact(1, 'Zara', 2, email: 'zara@example.com'),
      contact(2, 'Bina', 1, order: 2, phone: '0000000001', branch: 1, branchName: 'Surat'),
      contact(3, 'Amit', 1, order: 1, email: 'amit@example.com', phone: '0000000002'),
    ];

UserEntity user(List<String> perms) => UserEntity(
    id: 'u1',
    email: 'e@example.com',
    fullName: 'Pat',
    role: 'employee',
    roleDisplay: 'Employee',
    mustChangePassword: false,
    permissions: perms,
    onboardingStatus: 'complete',
    assessmentStatus: 'complete');

class _Auth extends AuthNotifier {
  _Auth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
}

const hrAll = ['documents.view', 'documents.create', 'documents.edit', 'documents.delete'];

late FakeContactsServer server;
late List<Uri> launched;

Future<void> pumpMatrix(WidgetTester tester,
    {List<String> perms = const [], List<Map<String, dynamic>>? rows, void Function(FakeContactsServer)? setup}) async {
  tester.view.physicalSize = const Size(1080, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = FakeContactsServer(rows ?? seed(), perms: perms.toSet());
  setup?.call(server);
  launched = [];
  await tester.pumpWidget(ProviderScope(
    overrides: [
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      authStateProvider.overrideWith(() => _Auth(user(perms))),
      contactLauncherProvider.overrideWithValue((uri) async {
        launched.add(uri);
        return true;
      }),
    ],
    child: const MaterialApp(home: ContactMatrixScreen()),
  ));
  await tester.pumpAndSettle();
}

double top(WidgetTester tester, String text) => tester.getTopLeft(find.text(text).first).dy;

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(Key(key)));
  await tester.tap(find.byKey(Key(key)));
  await tester.pumpAndSettle();
}

Future<void> menu(WidgetTester tester, int id, String item) async {
  await tapKey(tester, 'contact-menu-$id');
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model and rules (web contactMatrix.ts)', () {
    test('parses the list and can_manage', () {
      final m = ContactMatrix.fromJson({
        'contacts': [contact(2, 'Bina', 1, branch: 1, branchName: 'Surat')],
        'can_manage': true,
      });
      final c = m.contacts.single;
      expect((c.id, c.name, c.escalationLevel, c.branch, c.branchName), (2, 'Bina', 1, 1, 'Surat'));
      expect(m.canManage, isTrue);
      expect(ContactMatrix.fromJson(null).contacts, isEmpty);
    });

    test('groups by level, then display order, then name', () {
      final groups = groupContactsByLevel(ContactMatrix.fromJson({'contacts': seed()}).contacts);
      expect(groups.map((g) => g.level), [1, 2]);
      expect(groups.first.contacts.map((c) => c.name), ['Amit', 'Bina']);
      expect(contactLevelLabel(1), 'First point of contact');
      expect(contactLevelLabel(3), 'Escalation level 3');
    });

    test('form checks match web', () {
      expect(contactFormError(const ContactForm(email: 'a@b.co')), 'Name is required.');
      expect(contactFormError(const ContactForm(name: 'A')), 'Enter an email or a phone number.');
      expect(contactFormError(const ContactForm(name: 'A', email: 'nope')), 'Enter a valid email address.');
      expect(contactFormError(const ContactForm(name: 'A', phone: '1', escalationLevel: 0)),
          'Escalation level starts at 1.');
      expect(contactFormError(const ContactForm(name: 'A', phone: '1')), isNull);
    });

    test('payload is the serializer\'s writable fields', () {
      expect(const ContactForm(name: ' Asha ', phone: '1', branch: 2, escalationLevel: 2).toJson(), {
        'name': 'Asha',
        'designation': '',
        'department': '',
        'email': '',
        'phone': '1',
        'purpose': '',
        'escalation_level': 2,
        'branch': 2,
        'display_order': 0,
      });
    });
  });

  group('viewing', () {
    testWidgets('every employee sees the contacts grouped by escalation level', (tester) async {
      await pumpMatrix(tester);
      expect(server.count('GET', '/company-contacts/'), 1);
      expect(find.text('First point of contact'), findsOneWidget);
      expect(find.text('Escalation level 2'), findsOneWidget);
      expect(top(tester, 'Amit'), lessThan(top(tester, 'Bina')));
      expect(top(tester, 'Bina'), lessThan(top(tester, 'Zara')));
      expect(find.text('Surat'), findsOneWidget);
      expect(find.text('All branches'), findsNWidgets(2));
      // Read-only for an employee.
      expect(find.byKey(const Key('contact-add')), findsNothing);
      expect(find.byKey(const Key('contact-menu-3')), findsNothing);
    });

    testWidgets('detail sheet shows every field and calls / emails', (tester) async {
      await pumpMatrix(tester);
      await tapKey(tester, 'contact-3');
      expect(find.byKey(const Key('contact-detail')), findsOneWidget);
      expect(find.text('amit@example.com'), findsOneWidget);
      expect(find.text('Attendance, WFH'), findsWidgets);
      await tapKey(tester, 'contact-call');
      await tapKey(tester, 'contact-email-action');
      expect(launched, [Uri(scheme: 'tel', path: '0000000002'), Uri(scheme: 'mailto', path: 'amit@example.com')]);
      expect(find.text('Edit'), findsNothing); // employee
    });

    testWidgets('empty: says so, with the right hint for each audience', (tester) async {
      await pumpMatrix(tester, rows: []);
      expect(find.textContaining('No contacts have been added yet. Please check with HR.'), findsOneWidget);
      await pumpMatrix(tester, rows: [], perms: hrAll);
      expect(find.textContaining('Use Add Contact to enter the approved contact list.'), findsOneWidget);
    });

    testWidgets('server error: message and Retry, which reloads', (tester) async {
      await pumpMatrix(tester, setup: (s) => s.failNextGet = 500);
      expect(find.text('Server error.'), findsOneWidget);
      expect(find.text('Amit'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Amit'), findsOneWidget);
    });

    testWidgets('connection failure: No connection with Retry', (tester) async {
      await pumpMatrix(tester, setup: (s) => s.dropNextGet = true);
      expect(find.text('No connection'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Amit'), findsOneWidget);
    });

    testWidgets('pull to refresh reloads', (tester) async {
      await pumpMatrix(tester);
      // Triggers the screen's own onRefresh, as a pull does.
      final refresh = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator)).show();
      await tester.pumpAndSettle();
      await refresh;
      expect(server.count('GET', '/company-contacts/'), 2);
    });
  });

  group('managing (HR)', () {
    testWidgets('actions follow can_manage and the edit/delete codenames', (tester) async {
      await pumpMatrix(tester, perms: hrAll);
      expect(find.byKey(const Key('contact-add')), findsOneWidget);
      await tapKey(tester, 'contact-menu-3');
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Remove'), findsOneWidget);
    });

    testWidgets('can add but not delete: no Remove offered', (tester) async {
      await pumpMatrix(tester, perms: const ['documents.create', 'documents.edit']);
      await tapKey(tester, 'contact-menu-3');
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Remove'), findsNothing);
    });

    testWidgets('add: checked before sending, then POSTed once and listed', (tester) async {
      await pumpMatrix(tester, perms: hrAll);
      await tapKey(tester, 'contact-add');
      await tapKey(tester, 'contact-save');
      expect(find.text('Name is required.'), findsOneWidget);
      expect(server.count('POST'), 0);

      await tester.enterText(find.byKey(const Key('contact-name')), 'Asha');
      await tester.enterText(find.byKey(const Key('contact-email')), 'asha@example.com');
      await tester.enterText(find.byKey(const Key('contact-level')), '2');
      await tester.tap(find.byKey(const Key('contact-branch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Surat').last);
      await tester.pumpAndSettle();

      server.holdWrite = Completer<void>();
      await tester.tap(find.byKey(const Key('contact-save')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('contact-save'))); // a second tap while saving
      await tester.pump();
      server.holdWrite!.complete();
      await tester.pumpAndSettle();

      expect(server.count('POST', '/company-contacts/'), 1);
      expect(server.calls.firstWhere((c) => c.method == 'POST').body, {
        'name': 'Asha',
        'designation': '',
        'department': '',
        'email': 'asha@example.com',
        'phone': '',
        'purpose': '',
        'escalation_level': 2,
        'branch': 1,
        'display_order': 0,
      });
      expect(find.text('Contact added.'), findsOneWidget);
      expect(find.text('Asha'), findsOneWidget); // reloaded list
      expect(server.calls.where((c) => c.path == '/branch/branches/').single.query, {'page_size': 100});
    });

    testWidgets('edit: PATCH to the contact, branch kept, list updated', (tester) async {
      await pumpMatrix(tester, perms: hrAll);
      await menu(tester, 2, 'Edit');
      expect(find.text('Surat'), findsWidgets); // current branch preselected
      await tester.enterText(find.byKey(const Key('contact-name')), 'Bina R');
      await tapKey(tester, 'contact-save');
      final patch = server.calls.firstWhere((c) => c.method == 'PATCH');
      expect(patch.path, '/company-contacts/2/');
      expect((patch.body as Map)['name'], 'Bina R');
      expect((patch.body as Map)['branch'], 1);
      expect(find.text('Bina R'), findsOneWidget);
    });

    testWidgets('a server refusal keeps the form open with its message', (tester) async {
      await pumpMatrix(tester,
          perms: const ['documents.create', 'documents.edit'], setup: (s) => s.perms.remove('documents.edit'));
      // The server no longer allows edit (e.g. permissions changed meanwhile).
      await menu(tester, 3, 'Edit');
      await tapKey(tester, 'contact-save');
      expect(find.text('You do not have permission to manage contacts.'), findsOneWidget);
      expect(find.byKey(const Key('contact-form-error')), findsOneWidget);
    });

    testWidgets('remove: confirmed, DELETEd once, gone from the list', (tester) async {
      await pumpMatrix(tester, perms: hrAll);
      await menu(tester, 1, 'Remove');
      expect(find.text('Remove Zara from the Contact Matrix?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(server.count('DELETE', '/company-contacts/1/'), 1);
      expect(find.text('Zara'), findsNothing);
      expect(find.text('Contact removed.'), findsOneWidget);
    });

    testWidgets('cancelling the confirmation sends nothing', (tester) async {
      await pumpMatrix(tester, perms: hrAll);
      await menu(tester, 1, 'Remove');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(server.count('DELETE'), 0);
      expect(find.text('Zara'), findsOneWidget);
    });
  });

  group('navigation', () {
    test('menu entry for every signed-in user, titled Contact Matrix', () {
      final item = kAllNav.whereType<NavItem>().firstWhere((i) => i.id == 'contacts');
      expect(item.path, AppRoutes.contacts);
      expect(item.permission, isNull);
      expect(pageTitle(AppRoutes.contacts), 'Contact Matrix');
    });

    test('the route opens for an employee without any permission', () {
      expect(resolveAuthRedirect(authState: AuthState(user: user(const [])), path: AppRoutes.contacts), isNull);
    });
  });
}

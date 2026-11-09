import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/data/models/roles_model.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:mobile_app/features/settings/presentation/roles/roles_screen.dart';

// P1-4: Role "Can manage team" / "Can manage branch" capabilities, as web
// settings/permissions (RoleFormFields checkboxes; page.tsx addRole POST
// /roles/ {name, display_name, is_active:true, can_manage_team,
// can_manage_branch, permission_codenames}; editRole PUT /roles/<id>/ {name
// (immutable), display_name, is_active (unchanged), can_manage_team,
// can_manage_branch, permission_codenames, expected_updated_at}) on
// production RoleSerializer (both writable booleans) + RoleDetailView
// (settings.edit via CanManageRoles; 409 when expected_updated_at is stale).
// Synthetic roles; mocked Dio only — no real role is created or changed.

Map<String, dynamic> roleJson(int id, String name, String display,
        {bool team = false,
        bool branch = false,
        List<String> perms = const ['employees.view'],
        String? updated,
        bool system = false}) =>
    {
      'id': id,
      'name': name,
      'display_name': display,
      'is_active': true,
      'can_manage_team': team,
      'can_manage_branch': branch,
      'is_system_role': system,
      'permissions': perms,
      'user_count': 3,
      'created_at': '2026-10-01T09:00:00Z',
      'updated_at': updated ?? '2026-11-01T09:00:00.000000Z',
    };

class Server implements HttpClientAdapter {
  Server({bool withSystemRole = false}) {
    if (withSystemRole) {
      roles[10] = roleJson(10, 'employee', 'Employee', perms: ['leave.view'], system: true);
    }
  }

  final roles = <int, Map<String, dynamic>>{
    7: roleJson(7, 'test_branch_lead', 'Test Branch Lead', branch: true, perms: ['employees.view', 'leave.approve']),
    8: roleJson(8, 'test_team_lead', 'Test Team Lead', team: true, perms: ['leave.view']),
  };
  final writes = <({String method, String path, Map<String, dynamic> body})>[];
  int? failStatus;
  String failMessage = 'Role name must start with a letter.';
  int _bump = 0;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.path == ApiConstants.permissions) {
      return _json({
        'status': 'success',
        'data': {
          'count': 4,
          'results': {
            'employees': [
              {'id': 1, 'codename': 'employees.view', 'module': 'employees', 'action': 'view'},
            ],
            'leave': [
              {'id': 2, 'codename': 'leave.view', 'module': 'leave', 'action': 'view'},
              {'id': 3, 'codename': 'leave.approve', 'module': 'leave', 'action': 'approve'},
            ],
          }
        }
      });
    }
    if (o.path == ApiConstants.roles && o.method == 'GET') {
      return _json({
        'status': 'success',
        'data': {'count': roles.length, 'results': roles.values.toList()}
      });
    }
    if (o.method != 'GET') {
      final body = Map<String, dynamic>.from(o.data as Map);
      writes.add((method: o.method, path: o.path, body: body));
      if (failStatus != null) {
        return _json({'status': 'error', 'message': failMessage, 'data': {}}, failStatus!);
      }
      if (o.path == ApiConstants.roles && o.method == 'POST') {
        final created = roleJson(9, body['name'], body['display_name'],
            team: body['can_manage_team'], branch: body['can_manage_branch'],
            perms: List<String>.from(body['permission_codenames']));
        roles[9] = created;
        return _json({'status': 'success', 'message': 'Role created successfully.', 'data': created}, 201);
      }
      final id = int.parse(o.path.split('/').where((s) => s.isNotEmpty).last);
      final current = roles[id]!;
      if (o.method == 'PUT') {
        final expected = body['expected_updated_at'];
        if (expected != null && expected != current['updated_at']) {
          return _json({
            'status': 'error',
            'message': 'This role was changed by someone else since you loaded it. Reload the page and try again.',
            'data': {}
          }, 409);
        }
        final updated = {
          ...current,
          'display_name': body['display_name'],
          'is_active': body['is_active'],
          if (body.containsKey('can_manage_team')) 'can_manage_team': body['can_manage_team'],
          if (body.containsKey('can_manage_branch')) 'can_manage_branch': body['can_manage_branch'],
          'permissions': body['permission_codenames'],
          'updated_at': '2026-11-09T10:00:0${_bump++}.000000Z',
        };
        roles[id] = updated;
        return _json({'status': 'success', 'message': 'Role updated successfully.', 'data': updated});
      }
      if (o.method == 'PATCH') {
        roles[id] = {...current, ...body};
        return _json({'status': 'success', 'message': 'Role updated successfully.', 'data': roles[id]});
      }
    }
    return _json({'status': 'success', 'data': {'results': [], 'count': 0}});
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

final editor = user(['settings.view', 'settings.edit']);
final viewer = user(['settings.view']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pumpRoles(WidgetTester tester, {UserEntity? as, Server? with_}) async {
  tester.view.physicalSize = const Size(1080, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = with_ ?? Server();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? editor),
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(
          path: '/s',
          builder: (_, __) => Consumer(
            builder: (context, ref, _) =>
                ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : const RolesScreen(),
          ),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

bool checked(WidgetTester tester, String key) => tester.widget<CheckboxListTile>(byKey(key)).value!;

Future<void> openEditFor(WidgetTester tester, int index) async {
  await tester.tap(find.byIcon(Icons.edit_outlined).at(index));
  await tester.pumpAndSettle();
  expect(find.text('Edit Role'), findsOneWidget);
}

Future<void> submit(WidgetTester tester, String label) async {
  final btn = find.widgetWithText(FilledButton, label);
  await tester.ensureVisible(btn);
  await tester.tap(btn);
  await tester.pumpAndSettle();
}

Future<void> tapCheckbox(WidgetTester tester, String key) async {
  await tester.ensureVisible(byKey(key));
  await tester.tap(byKey(key));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model and payload', () {
    test('a role loads can_manage_team, can_manage_branch and updated_at; the edit form copies them', () {
      final r = RoleModel.fromJson(roleJson(7, 'test_branch_lead', 'Test Branch Lead', branch: true));
      expect([r.canManageTeam, r.canManageBranch], [false, true]);
      expect(r.updatedAt, '2026-11-01T09:00:00.000000Z');
      expect(r.copyWith(isActive: false).canManageBranch, isTrue, reason: 'toggle keeps capabilities');
      final f = RoleFormData.fromModel(r);
      expect([f.canManageTeam, f.canManageBranch, f.expectedUpdatedAt], [false, true, '2026-11-01T09:00:00.000000Z']);
      expect(f.toJson(), {
        'name': 'test_branch_lead',
        'display_name': 'Test Branch Lead',
        'is_active': true,
        'can_manage_team': false,
        'can_manage_branch': true,
        'permission_codenames': ['employees.view'],
        'expected_updated_at': '2026-11-01T09:00:00.000000Z',
      });
    });

    test('a new role defaults both capabilities to false and sends no expected_updated_at', () {
      final f = RoleFormData(displayName: 'X', name: 'x', permissions: {'leave.view'});
      expect(f.toJson(), {
        'name': 'x',
        'display_name': 'X',
        'is_active': true,
        'can_manage_team': false,
        'can_manage_branch': false,
        'permission_codenames': ['leave.view'],
      });
      final old = RoleModel.fromJson(const {'id': 1, 'name': 'legacy', 'display_name': 'Legacy'});
      expect([old.canManageTeam, old.canManageBranch, old.updatedAt], [false, false, null]);
    });
  });

  group('form (settings.edit)', () {
    testWidgets('Edit shows each role\'s saved capabilities with web\'s labels', (tester) async {
      await pumpRoles(tester);
      await openEditFor(tester, 0); // Test Branch Lead
      expect(find.text('Can manage team'), findsOneWidget);
      expect(find.text('Can manage branch'), findsOneWidget);
      expect(find.textContaining('appear in manager dropdowns'), findsOneWidget);
      expect(find.textContaining('unconditional access to every employee'), findsOneWidget);
      expect(checked(tester, 'role-can-manage-team'), isFalse);
      expect(checked(tester, 'role-can-manage-branch'), isTrue);
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
      await openEditFor(tester, 1); // Test Team Lead
      expect(checked(tester, 'role-can-manage-team'), isTrue);
      expect(checked(tester, 'role-can-manage-branch'), isFalse);
    });

    testWidgets('Add Role sends both capabilities with the web create payload', (tester) async {
      await pumpRoles(tester);
      await tester.tap(byKey('role-add'));
      await tester.pumpAndSettle();
      expect(checked(tester, 'role-can-manage-team'), isFalse);
      expect(checked(tester, 'role-can-manage-branch'), isFalse);
      await tester.enterText(find.widgetWithText(TextFormField, 'Role Name *'), 'Area Lead');
      await tapCheckbox(tester, 'role-can-manage-team');
      await tapCheckbox(tester, 'role-can-manage-branch');
      await tester.ensureVisible(find.text('View Only'));
      await tester.tap(find.text('View Only'));
      await tester.pumpAndSettle();
      expect(checked(tester, 'role-can-manage-team'), isTrue, reason: 'presets change permissions only');
      await submit(tester, '+ Add Role');

      final w = server.writes.single;
      expect(w.method, 'POST');
      expect(w.path, ApiConstants.roles);
      expect(w.body, {
        'name': 'area_lead',
        'display_name': 'Area Lead',
        'is_active': true,
        'can_manage_team': true,
        'can_manage_branch': true,
        'permission_codenames': unorderedEquals(['employees.view', 'leave.view']),
      });
      expect(find.text('Add New Role'), findsNothing, reason: 'closed on success');
    });

    testWidgets('Edit sends both capabilities and preserves name, active state and permissions', (tester) async {
      await pumpRoles(tester);
      await openEditFor(tester, 0);
      await tapCheckbox(tester, 'role-can-manage-team'); // false → true
      await tapCheckbox(tester, 'role-can-manage-branch'); // true → false
      await submit(tester, 'Save Changes');

      final w = server.writes.single;
      expect(w.method, 'PUT');
      expect(w.path, ApiConstants.roleDetail(7));
      expect(w.body, {
        'name': 'test_branch_lead',
        'display_name': 'Test Branch Lead',
        'is_active': true,
        'can_manage_team': true,
        'can_manage_branch': false,
        'permission_codenames': unorderedEquals(['employees.view', 'leave.approve']),
        'expected_updated_at': '2026-11-01T09:00:00.000000Z',
      });
      expect(find.text('Edit Role'), findsNothing);
      // the list now holds the saved values
      await openEditFor(tester, 0);
      expect(checked(tester, 'role-can-manage-team'), isTrue);
      expect(checked(tester, 'role-can-manage-branch'), isFalse);
    });

    testWidgets('saving without touching the capabilities sends the saved values unchanged', (tester) async {
      await pumpRoles(tester);
      await openEditFor(tester, 1); // Test Team Lead: team true, branch false
      await submit(tester, 'Save Changes');
      final b = server.writes.single.body;
      expect([b['can_manage_team'], b['can_manage_branch']], [true, false]);
      expect(b['permission_codenames'], ['leave.view']);
      expect(server.roles[8]!['can_manage_team'], isTrue);
    });

    testWidgets('a server error keeps the form open with every value as entered; retry succeeds',
        (tester) async {
      await pumpRoles(tester, with_: Server()..failStatus = 400);
      await openEditFor(tester, 0);
      await tester.enterText(find.widgetWithText(TextFormField, 'Test Branch Lead'), 'Renamed Lead');
      await tapCheckbox(tester, 'role-can-manage-team');
      await submit(tester, 'Save Changes');

      expect(find.text('Edit Role'), findsOneWidget, reason: 'still open');
      expect(tester.widget<Text>(find.descendant(of: byKey('role-form-error'), matching: find.byType(Text))).data,
          'Role name must start with a letter.');
      expect(find.widgetWithText(TextFormField, 'Renamed Lead'), findsOneWidget);
      expect(checked(tester, 'role-can-manage-team'), isTrue);
      expect(checked(tester, 'role-can-manage-branch'), isTrue);
      expect(server.roles[7]!['can_manage_team'], isFalse, reason: 'server unchanged');

      server.failStatus = null;
      await submit(tester, 'Save Changes');
      expect(server.writes, hasLength(2));
      expect(server.writes.last.body['display_name'], 'Renamed Lead');
      expect(server.writes.last.body['can_manage_team'], isTrue);
      expect(find.text('Edit Role'), findsNothing);
    });

    testWidgets('a 409 (role changed elsewhere) reloads the roles, closes the stale form and reports it',
        (tester) async {
      final s = Server();
      await pumpRoles(tester, with_: s);
      await openEditFor(tester, 0);
      // someone else saves the role meanwhile
      s.roles[7] = {...s.roles[7]!, 'can_manage_team': true, 'updated_at': '2026-11-09T08:00:00.000000Z'};
      await tapCheckbox(tester, 'role-can-manage-branch');
      await submit(tester, 'Save Changes');

      expect(server.writes.single.body['expected_updated_at'], '2026-11-01T09:00:00.000000Z');
      expect(find.text('Edit Role'), findsNothing, reason: 'stale form closed');
      expect(find.textContaining('changed by someone else'), findsOneWidget);
      expect(s.roles[7]!['can_manage_branch'], isTrue, reason: 'the stale save did not apply');
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await openEditFor(tester, 0);
      expect(checked(tester, 'role-can-manage-team'), isTrue, reason: 'form reopens from the reloaded role');
    });

    testWidgets('the active toggle still sends only is_active (capabilities untouched)', (tester) async {
      await pumpRoles(tester);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      final w = server.writes.single;
      expect(w.method, 'PATCH');
      expect(w.body, {'is_active': false});
      expect(server.roles[7]!['can_manage_branch'], isTrue);
    });
  });

  group('permissions', () {
    testWidgets('without settings.edit there is no Add Role or Edit, so capabilities cannot be changed',
        (tester) async {
      await pumpRoles(tester, as: viewer);
      expect(byKey('role-add'), findsNothing);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(byKey('role-view-only-7'), findsOneWidget);
    });

    test('the provider refuses create/edit without settings.edit, before any request', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(viewer));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(rolesProvider, (_, __) {});
      final roles = await c.read(rolesProvider.future);
      final form = RoleFormData.fromModel(roles.first)
        ..canManageTeam = true
        ..canManageBranch = false;
      expect(await c.read(rolesProvider.notifier).edit(7, form), kSettingsEditDenied);
      expect(await c.read(rolesProvider.notifier).create(RoleFormData(name: 'x', displayName: 'X')..canManageBranch = true),
          kSettingsEditDenied);
      expect(server.writes, isEmpty);
      expect(server.roles[7]!['can_manage_branch'], isTrue);
    });
  });

  group('system roles (is_system_role) — as web: badge only, still editable', () {
    test('is_system_role true marks a system role; false, missing or the old is_system key do not', () {
      expect(RoleModel.fromJson(roleJson(10, 'employee', 'Employee', system: true)).isSystem, isTrue);
      expect(RoleModel.fromJson(roleJson(7, 'x', 'X')).isSystem, isFalse);
      expect(RoleModel.fromJson(const {'id': 1, 'name': 'a', 'display_name': 'A'}).isSystem, isFalse);
      expect(RoleModel.fromJson(const {'id': 1, 'name': 'a', 'display_name': 'A', 'is_system': true}).isSystem, isFalse,
          reason: 'the backend field is is_system_role');
      final r = RoleModel.fromJson(roleJson(10, 'employee', 'Employee', system: true));
      expect(r.copyWith(isActive: false).isSystem, isTrue);
      expect(RoleFormData.fromModel(r).toJson().containsKey('is_system_role'), isFalse,
          reason: 'read-only on the server, never sent');
    });

    testWidgets('the System badge shows only on the system role', (tester) async {
      await pumpRoles(tester, with_: Server(withSystemRole: true));
      expect(byKey('role-system-badge-10'), findsOneWidget);
      expect(byKey('role-system-badge-7'), findsNothing);
      expect(byKey('role-system-badge-8'), findsNothing);
      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('system and custom roles all keep Edit and an enabled active toggle (web parity)', (tester) async {
      await pumpRoles(tester, with_: Server(withSystemRole: true));
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(3));
      final switches = tester.widgetList<Switch>(find.byType(Switch)).toList();
      expect(switches, hasLength(3));
      expect(switches.every((s) => s.onChanged != null), isTrue);
    });

    testWidgets('a system role can be edited (capabilities included) like web', (tester) async {
      await pumpRoles(tester, with_: Server(withSystemRole: true));
      await openEditFor(tester, 2); // Employee (system)
      expect(checked(tester, 'role-can-manage-team'), isFalse);
      await tapCheckbox(tester, 'role-can-manage-team');
      await submit(tester, 'Save Changes');
      final w = server.writes.single;
      expect(w.method, 'PUT');
      expect(w.path, ApiConstants.roleDetail(10));
      expect(w.body['name'], 'employee');
      expect(w.body['can_manage_team'], isTrue);
      expect(w.body.containsKey('is_system_role'), isFalse);
    });

    testWidgets('a system role\'s active toggle sends PATCH {is_active} like web', (tester) async {
      await pumpRoles(tester, with_: Server(withSystemRole: true));
      await tester.tap(find.byType(Switch).at(2));
      await tester.pumpAndSettle();
      final w = server.writes.single;
      expect(w.method, 'PATCH');
      expect(w.path, ApiConstants.roleDetail(10));
      expect(w.body, {'is_active': false});
    });

    testWidgets('without settings.edit a system role shows the badge and View only, no actions', (tester) async {
      await pumpRoles(tester, as: viewer, with_: Server(withSystemRole: true));
      expect(byKey('role-system-badge-10'), findsOneWidget);
      expect(byKey('role-view-only-10'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNothing);
      expect(find.byType(Switch), findsNothing);
    });
  });
}

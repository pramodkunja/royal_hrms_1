import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import 'package:mobile_app/features/approvals/presentation/screens/approvals_screen.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 71a (audit finding H1): Team Approvals and Face ID approvals for
// admins. Web approvals/page.tsx and TeamApprovalsSection.tsx use
// usePermission / useAnyPermission — the superuser flag (which the login also
// sets for any settings.edit role) or the permission — and the backend's
// has_perm passes superuser / settings.edit. Mobile used plain list lookups,
// so an admin without explicit approve codenames (e.g. the seeded
// system_admin) lost both queues. Actions still follow the server's
// can_action. Synthetic users; a stand-in server records every request.

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _page(List<Map<String, dynamic>> rows) =>
    _json(200, {'status': 'success', 'message': 'ok', 'data': {'count': rows.length, 'page': 1, 'page_size': 100, 'total_pages': 1, 'results': rows}});

Map<String, dynamic> leaveRow(String id, {bool canApprove = true}) => {
      'id': id,
      'employee_name': 'Asha Test',
      'employee_code': 'EMP-1',
      'leave_type': 'casual',
      'leave_type_display': 'Casual Leave',
      'start_date': '2026-11-20',
      'end_date': '2026-11-20',
      'status': 'pending',
      'reason': 'Family function',
      'created_at': '2026-11-13T09:00:00Z',
      'can_approve': canApprove,
    };

class Server implements HttpClientAdapter {
  final gets = <(String, Map<String, dynamic>)>[];
  final writes = <(String, String)>[];
  bool leaveCanApprove = true;
  bool refuseApprove = false;

  bool asked(String path) => gets.any((g) => g.$1 == path);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET') {
      gets.add((o.path, Map.of(o.queryParameters)));
    } else {
      writes.add((o.method, o.path));
    }
    if (o.method != 'GET') {
      if (refuseApprove) {
        return _json(403, {'status': 'error', 'message': 'You are not the approver for this stage.', 'data': {}});
      }
      return _json(200, {'status': 'success', 'message': 'ok', 'data': {}});
    }
    if (o.path == '/leave/requests/') return _page([leaveRow('L1', canApprove: leaveCanApprove)]);
    if (o.path == '/attendance/face-registration/pending/') {
      return _page([
        {
          'id': 'f1',
          'employee_name': 'Ravi Test',
          'employee_id': 'EMP-2',
          'status': 'pending',
          'submitted_at': '2026-11-12T09:00:00Z',
        }
      ]);
    }
    return _page(const []);
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

UserEntity user(List<String> perms, {bool superuser = false, bool team = false, List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'r',
      roleDisplay: 'Role',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      canManageTeam: team,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

/// A settings.edit admin as the login reports it (is_superuser true for
/// settings.edit roles), holding no approve codename.
final settingsAdmin = user(['settings.view', 'settings.edit'], superuser: true);

/// Same admin from an older cached session without the flag.
final settingsAdminNoFlag = user(['settings.view', 'settings.edit']);

/// Seeded system_admin (apps/accounts/migrations/0002 seed): no
/// leave/expenses/wfh/attendance.create/facial_recognition codenames.
final systemAdmin = user([
  'employees.view', 'employees.create', 'employees.edit', 'attendance.view', 'payroll.view', //
  'settings.view', 'settings.edit', 'audit.view', 'branches.view', //
], superuser: true);

final employee = user(['attendance.view', 'leave.view', 'leave.create']);
final leaveApprover = user(['leave.view', 'leave.approve']);
final attendanceStaff = user(['attendance.view', 'attendance.create', 'attendance.edit']);
final faceApprover = user(['facial_recognition.approve']);

late Server server;
late ProviderContainer container;

Future<void> pump(WidgetTester tester, UserEntity u, {void Function(Server)? setup}) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Consumer(
        builder: (context, ref, _) =>
            ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : const ApprovalsScreen(),
      ),
    ),
  ));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
  container = ProviderScope.containerOf(tester.element(find.byType(ApprovalsScreen)));
}

/// Tab labels; a single tab shows no bar, so fall back to what's on screen.
List<String> tabs(WidgetTester tester) {
  final bar = find.byType(TabBar);
  if (bar.evaluate().isEmpty) return const [];
  return [for (final t in tester.widgetList<Tab>(find.descendant(of: bar, matching: find.byType(Tab)))) t.text ?? ''];
}

const teamKinds = ['/leave/requests/', '/expenses/', '/attendance/corrections/', '/wfh/requests/', '/separation/requests/'];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('admins (settings.edit / superuser, no approve codenames)', () {
    for (final (label, admin) in [
      ('settings.edit admin', settingsAdmin),
      ('settings.edit admin without the superuser flag (older session)', settingsAdminNoFlag),
      ('seeded system_admin pattern', systemAdmin),
    ]) {
      testWidgets('$label: Team Approvals shown and every team queue fetched', (tester) async {
        await pump(tester, admin);
        expect(tabs(tester), contains('Team Approvals'));
        for (final path in teamKinds) {
          expect(server.asked(path), isTrue, reason: path);
        }
        final leave = server.gets.firstWhere((g) => g.$1 == '/leave/requests/');
        expect(leave.$2['scope'], 'team');
        final wfh = server.gets.firstWhere((g) => g.$1 == '/wfh/requests/');
        expect(wfh.$2['scope'], 'team');
        expect(find.text('Asha Test'), findsWidgets); // the leave row reaches the inbox
      });
    }

    testWidgets('Face ID Approvals shown and its queue fetched (face_attendance on / unknown)', (tester) async {
      await pump(tester, settingsAdmin);
      expect(tabs(tester), contains('Face ID Approvals'));
      await tester.tap(find.text('Face ID Approvals'));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(server.asked('/attendance/face-registration/pending/'), isTrue);
    });

    testWidgets('face_attendance off: no Face ID tab and its queue never fetched', (tester) async {
      await pump(tester, user(['settings.edit'], superuser: true, modules: const ['leave', 'attendance']));
      expect(tabs(tester), isNot(contains('Face ID Approvals')));
      expect(server.asked('/attendance/face-registration/pending/'), isFalse);
      // Disabled modules are not fetched either.
      expect(server.asked('/expenses/'), isFalse);
      expect(server.asked('/wfh/requests/'), isFalse);
      expect(server.asked('/separation/requests/'), isFalse);
      expect(server.asked('/leave/requests/'), isTrue);
      expect(server.asked('/attendance/corrections/'), isTrue);
    });

    testWidgets('attendance module off: corrections not fetched for the admin', (tester) async {
      await pump(tester, user(['settings.edit'], superuser: true, modules: const ['leave']));
      expect(server.asked('/attendance/corrections/'), isFalse);
      expect(tabs(tester), isNot(contains('Attendance Approval')));
    });
  });

  group('others unchanged', () {
    testWidgets('ordinary employee: no approval tabs, no team queue requested', (tester) async {
      await pump(tester, employee);
      expect(tabs(tester), isEmpty);
      expect(find.text('Team Approvals'), findsNothing);
      expect(find.text('Face ID Approvals'), findsNothing);
      for (final path in [...teamKinds, '/attendance/face-registration/pending/', '/payroll/queries/']) {
        expect(server.asked(path), isFalse, reason: path);
      }
    });

    testWidgets('explicit leave.approve: Team Approvals; only the leave queue', (tester) async {
      await pump(tester, leaveApprover);
      expect(find.text('Team Approvals'), findsWidgets);
      expect(server.asked('/leave/requests/'), isTrue);
      for (final path in ['/expenses/', '/attendance/corrections/', '/wfh/requests/', '/separation/requests/']) {
        expect(server.asked(path), isFalse, reason: path);
      }
      expect(find.text('Face ID Approvals'), findsNothing);
    });

    testWidgets('attendance staff (attendance.create): Team Approvals with corrections only', (tester) async {
      await pump(tester, attendanceStaff);
      expect(find.text('Team Approvals'), findsWidgets);
      expect(server.asked('/attendance/corrections/'), isTrue);
      expect(server.asked('/leave/requests/'), isFalse);
    });

    testWidgets('explicit facial_recognition.approve: Face ID tab only', (tester) async {
      await pump(tester, faceApprover);
      // A single tab shows no tab bar: the Face ID queue itself is on screen.
      expect(tabs(tester), isEmpty);
      expect(server.asked('/attendance/face-registration/pending/'), isTrue);
      expect(find.text('Team Approvals'), findsNothing);
      for (final path in teamKinds) {
        expect(server.asked(path), isFalse, reason: path);
      }
    });
  });

  group('actions stay with the server', () {
    testWidgets('a visible row the server marks not actionable gets no Approve / Reject', (tester) async {
      await pump(tester, settingsAdmin, setup: (s) => s.leaveCanApprove = false);
      expect(find.text('Asha Test'), findsWidgets);
      expect(find.widgetWithText(ElevatedButton, 'Approve'), findsNothing);
      expect(find.widgetWithText(OutlinedButton, 'Reject'), findsNothing);
      final items = container.read(unifiedTeamApprovalsProvider).requireValue;
      expect(items.single.canAction, isFalse);
    });

    testWidgets('an approval the server refuses: its message, nothing changed locally', (tester) async {
      await pump(tester, settingsAdmin, setup: (s) => s.refuseApprove = true);
      final item = container.read(unifiedTeamApprovalsProvider).requireValue.single;
      expect(item.canAction, isTrue);
      String? err;
      container.read(unifiedTeamApprovalsProvider.notifier).approve(item, remarks: 'ok').then((e) => err = e);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(err, 'You are not the approver for this stage.');
      expect(server.writes, hasLength(1));
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/leave_balance_import_screen.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/leave_policy_screen.dart';

// Task 71e (audit finding L1): Settings → Leave Policy → Import Opening
// Balances.
//  - Web entry: leave-policy/page.tsx shows the button only for
//    usePermission("leave.edit") (superuser flag or the codename), on a page
//    whose route needs settings.view (proxy.ts) and the leave module
//    (lib/modules.ts).
//  - Backend: LeaveOpeningBalance{Validate,Import,Sample}View all check
//    _has_perm(leave.approve) (superuser / settings.edit / the codename).
// Mobile route and screen now follow web's entry rule; a leave.approve-only
// user is kept out as on web. Synthetic users and files; a stand-in server
// records requests. Nothing is imported anywhere.

const importPath = AppRoutes.settingsLeaveBalanceImport;

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
ResponseBody _ok(Object data) => _json(200, {'status': 'success', 'message': 'ok', 'data': data});

class Server implements HttpClientAdapter {
  final requests = <(String, String)>[];
  final uploads = <(String, String, List<int>)>[]; // path, field:filename, bytes
  String? refuse;

  bool get touchedImport => requests.any((r) => r.$2.startsWith('/leave/balance/import'));

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    requests.add((o.method, o.path));
    if (o.data is FormData) {
      for (final f in (o.data as FormData).files) {
        final bytes = <int>[];
        await for (final chunk in f.value.clone().finalize()) {
          bytes.addAll(chunk);
        }
        uploads.add((o.path, '${f.key}:${f.value.filename}', bytes));
      }
    }
    if (o.path.startsWith('/leave/balance/import') && refuse != null) {
      return _json(403, {'status': 'error', 'message': refuse, 'data': {}});
    }
    if (o.path == '/leave/balance/import/validate/') {
      return _ok({
        'total_rows': 3,
        'valid_rows': 2,
        'error_rows': 1,
        'balance_rows': 2,
        'history_rows': 1,
        'preview': [
          {'row': 1, 'row_type': 'balance', 'employee_id': 'EMP-T1', 'leave_type': 'casual', 'financial_year': '2026-27', 'valid': true},
          {'row': 2, 'row_type': 'balance', 'employee_id': 'EMP-T2', 'leave_type': 'sick', 'financial_year': '2026-27', 'valid': true},
          {
            'row': 3,
            'row_type': 'history',
            'employee_id': 'EMP-T9',
            'leave_type': 'casual',
            'financial_year': '2026-27',
            'from_date': '2026-05-01',
            'to_date': '2026-05-02',
            'days': 2,
            'valid': false,
            'error': 'Employee not found',
          },
        ],
      });
    }
    if (o.path == '/leave/balance/import/') {
      return _ok({
        'total_records': 3,
        'balances_created': 2,
        'history_imported': 0,
        'successful': 2,
        'failed': 1,
        'skipped': 0,
        'errors': [
          {'row': 3, 'employee_id': 'EMP-T9', 'leave_type': 'casual', 'reason': 'Employee not found'}
        ],
      });
    }
    return _ok(<Object>[]);
  }

  @override
  void close({bool force = false}) {}
}

/// Stands in for the platform file picker; records whether it was opened.
class FakePicker extends FilePicker {
  PlatformFile? next;
  int opened = 0;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    opened++;
    final f = next;
    return f == null ? null : FilePickerResult([f]);
  }
}

final csvBytes = Uint8List.fromList(utf8.encode('Employee ID,Leave Type,Financial Year,Opening Balance\nEMP-T1,casual,2026-27,4\n'));
PlatformFile csv({int? size}) => PlatformFile(name: 'opening.csv', size: size ?? csvBytes.length, bytes: csvBytes);

class _NullStorage extends SecureStorageService {
  @override
  Future<String?> read(String key) async => null;
  @override
  Future<void> write(String key, String value) async {}
}

class TestAuth extends AuthNotifier {
  TestAuth(this.u);
  final UserEntity u;
  @override
  Future<AuthState> build() async => AuthState(user: u);
  void become(UserEntity next) => state = AsyncData(AuthState(user: next));
}

UserEntity user(List<String> perms, {bool superuser = false, List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'u@example.test',
      fullName: 'Test User',
      role: 'r',
      roleDisplay: 'Role',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      enabledModules: modules,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final leaveAdmin = user(['settings.view', 'leave.view', 'leave.edit', 'leave.approve']);
final settingsAdmin = user(['settings.view', 'settings.edit']); // older session: no superuser flag
final superuser = user(const [], superuser: true);
final approveOnly = user(['settings.view', 'leave.view', 'leave.approve']);
final viewOnly = user(['settings.view', 'leave.view']);
final employee = user(['leave.view', 'leave.create', 'attendance.view']);
final editNoSettings = user(['leave.view', 'leave.edit']);

late Server server;
late FakePicker picker;
late TestAuth auth;

Future<void> pumpApp(WidgetTester tester, UserEntity u, {String at = importPath}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  picker = FakePicker();
  FilePicker.platform = picker;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => auth = TestAuth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: at,
        // The app's own guard, as AppRouter applies it.
        redirect: (_, s) => resolveAuthRedirect(authState: AuthState(user: u), path: s.matchedLocation),
        routes: [
          GoRoute(path: AppRoutes.dashboard, builder: (_, __) => const Scaffold(body: Text('Dashboard home'))),
          GoRoute(
            path: AppRoutes.settingsLeavePolicy,
            builder: (_, __) => Consumer(
              builder: (context, ref, _) =>
                  ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : const LeavePolicyScreen(),
            ),
          ),
          GoRoute(path: importPath, builder: (_, __) => const LeaveBalanceImportScreen()),
        ],
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The screen on its own, without the router (as if reached through retained
/// navigation state).
Future<void> pumpScreen(WidgetTester tester, UserEntity u) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  picker = FakePicker();
  FilePicker.platform = picker;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => auth = TestAuth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/x', routes: [
        GoRoute(path: '/x', builder: (_, __) => const LeaveBalanceImportScreen()),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

final noAccess = find.byKey(const Key('leave-import-no-access'));
final pickCard = find.text('Tap to select CSV or XLSX file');
final validateBtn = find.widgetWithText(FilledButton, 'Validate File');

Future<void> pickAndValidate(WidgetTester tester) async {
  picker.next = csv();
  await tester.tap(pickCard);
  await tester.pumpAndSettle();
  await tester.tap(validateBtn);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('access matrix (route, direct navigation, screen rule)', () {
    final cases = <(String, UserEntity, bool)>[
      ('Leave Policy administrator (leave.edit)', leaveAdmin, true),
      ('settings.edit administrator', settingsAdmin, true),
      ('explicit superuser', superuser, true),
      ('leave.approve only', approveOnly, false),
      ('leave.view only', viewOnly, false),
      ('ordinary employee', employee, false),
      ('leave.edit without settings.view (web route needs it)', editNoSettings, false),
    ];
    for (final (label, u, allowed) in cases) {
      test('$label → ${allowed ? 'allowed' : 'refused'}', () {
        expect(canAccessPath(u, importPath), allowed, reason: 'route');
        expect(resolveAuthRedirect(authState: AuthState(user: u), path: importPath), allowed ? isNull : AppRoutes.dashboard,
            reason: 'direct navigation');
        expect(canImportLeaveBalances(u), allowed, reason: 'screen');
      });
    }

    test('Leave Policy itself is unchanged: settings.view', () {
      expect(canAccessPath(approveOnly, AppRoutes.settingsLeavePolicy), isTrue);
      expect(canAccessPath(viewOnly, AppRoutes.settingsLeavePolicy), isTrue);
      expect(canAccessPath(employee, AppRoutes.settingsLeavePolicy), isFalse);
      expect(extraPermissionsFor(AppRoutes.settingsLeavePolicy), isNull);
      expect(extraPermissionsFor(importPath), ['leave.edit']);
    });

    test('leave module off: refused even for administrators', () {
      for (final u in [
        user(leaveAdmin.permissions, modules: const ['attendance']),
        user(const ['settings.edit'], superuser: true, modules: const []),
      ]) {
        expect(canAccessPath(u, importPath), isFalse);
        expect(resolveAuthRedirect(authState: AuthState(user: u), path: importPath), AppRoutes.dashboard);
        expect(canImportLeaveBalances(u), isFalse);
      }
      expect(canAccessPath(user(leaveAdmin.permissions, modules: const ['leave']), importPath), isTrue);
    });
  });

  group('direct-route navigation', () {
    for (final (label, u) in [('leave.approve only', approveOnly), ('leave.view only', viewOnly), ('employee', employee)]) {
      testWidgets('$label: sent to the dashboard; no import screen, no request', (tester) async {
        await pumpApp(tester, u);
        expect(find.text('Dashboard home'), findsOneWidget);
        expect(find.byType(LeaveBalanceImportScreen), findsNothing);
        expect(server.touchedImport, isFalse);
      });
    }

    testWidgets('leave module off: sent to the dashboard', (tester) async {
      await pumpApp(tester, user(leaveAdmin.permissions, modules: const ['attendance']));
      expect(find.text('Dashboard home'), findsOneWidget);
      expect(find.byType(LeaveBalanceImportScreen), findsNothing);
    });

    for (final (label, u) in [('leave admin', leaveAdmin), ('settings.edit admin', settingsAdmin), ('superuser', superuser)]) {
      testWidgets('$label: import screen opens', (tester) async {
        await pumpApp(tester, u);
        expect(find.byType(LeaveBalanceImportScreen), findsOneWidget);
        expect(noAccess, findsNothing);
        expect(validateBtn, findsOneWidget);
      });
    }
  });

  group('navigation from Leave Policy', () {
    testWidgets('leave admin: entry shown and opens the import screen', (tester) async {
      await pumpApp(tester, leaveAdmin, at: AppRoutes.settingsLeavePolicy);
      await tester.tap(find.byKey(const Key('leave-import-entry')));
      await tester.pumpAndSettle();
      expect(find.byType(LeaveBalanceImportScreen), findsOneWidget);
      expect(validateBtn, findsOneWidget);
    });

    for (final (label, u) in [('leave.approve only', approveOnly), ('leave.view only', viewOnly)]) {
      testWidgets('$label: Leave Policy opens without the import entry', (tester) async {
        await pumpApp(tester, u, at: AppRoutes.settingsLeavePolicy);
        expect(find.byType(LeavePolicyScreen), findsOneWidget);
        expect(find.byKey(const Key('leave-import-entry')), findsNothing);
        expect(find.byTooltip('Import Opening Balances'), findsNothing);
      });
    }

    testWidgets('existing Leave Policy tabs unchanged: leave.approve keeps Monthly, no Carry Forward', (tester) async {
      await pumpApp(tester, approveOnly, at: AppRoutes.settingsLeavePolicy);
      expect(find.text('Monthly Leave Management'), findsOneWidget);
      expect(find.text('Carry Forward'), findsNothing);
    });

    testWidgets('existing Leave Policy tabs unchanged: leave admin keeps Carry Forward and Monthly', (tester) async {
      await pumpApp(tester, leaveAdmin, at: AppRoutes.settingsLeavePolicy);
      expect(find.text('Monthly Leave Management'), findsOneWidget);
      expect(find.text('Carry Forward'), findsOneWidget);
    });
  });

  group('screen-level protection (reached without the router guard)', () {
    for (final (label, u) in [('leave.approve only', approveOnly), ('employee', employee)]) {
      testWidgets('$label: no upload, preview, import or sample controls; nothing sent', (tester) async {
        await pumpScreen(tester, u);
        expect(noAccess, findsOneWidget);
        expect(pickCard, findsNothing);
        expect(validateBtn, findsNothing);
        expect(find.text('Sample CSV'), findsNothing);
        expect(server.requests, isEmpty);
        expect(picker.opened, 0);
      });
    }

    testWidgets('permission lost with a file picked: preview is never requested', (tester) async {
      await pumpScreen(tester, leaveAdmin);
      picker.next = csv();
      await tester.tap(pickCard);
      await tester.pumpAndSettle();
      expect(find.text('opening.csv'), findsOneWidget);
      auth.become(approveOnly);
      await tester.pumpAndSettle();
      expect(noAccess, findsOneWidget);
      expect(validateBtn, findsNothing);
      expect(server.touchedImport, isFalse);
    });

    testWidgets('permission lost on the preview: import is never sent', (tester) async {
      await pumpScreen(tester, leaveAdmin);
      await pickAndValidate(tester);
      expect(find.text('2 of 3 rows ready to import'), findsOneWidget);
      auth.become(viewOnly);
      await tester.pumpAndSettle();
      expect(noAccess, findsOneWidget);
      expect(find.text('Import 2 rows'), findsNothing);
      expect(server.requests.where((r) => r.$2 == '/leave/balance/import/'), isEmpty);
    });
  });

  group('authorised workflow (unchanged)', () {
    testWidgets('dry-run preview, then confirmed import with the same multipart payload', (tester) async {
      await pumpScreen(tester, leaveAdmin);
      await pickAndValidate(tester);
      // Preview only: validate sent, nothing imported yet.
      expect(server.requests, [('POST', '/leave/balance/import/validate/')]);
      expect(server.uploads.single.$2, 'file:opening.csv');
      expect(server.uploads.single.$3, csvBytes);
      expect(find.text('2 of 3 rows ready to import'), findsOneWidget);
      expect(find.text('1 rows have errors and will be skipped'), findsOneWidget);
      expect(find.text('Employee not found'), findsOneWidget);
      // Confirm.
      await tester.tap(find.text('Import 2 rows'));
      await tester.pumpAndSettle();
      expect(server.requests.last, ('POST', '/leave/balance/import/'));
      expect(server.uploads.last.$1, '/leave/balance/import/');
      expect(server.uploads.last.$2, 'file:opening.csv');
      expect(server.uploads.last.$3, csvBytes);
      expect(find.text('Balances'), findsOneWidget);
      expect(find.text('Import Another File'), findsOneWidget);
    });

    for (final (label, u) in [('settings.edit admin', settingsAdmin), ('superuser', superuser)]) {
      testWidgets('$label: preview works', (tester) async {
        await pumpScreen(tester, u);
        await pickAndValidate(tester);
        expect(find.text('2 of 3 rows ready to import'), findsOneWidget);
      });
    }

    testWidgets('file validation kept: over 5 MB is rejected before any request', (tester) async {
      await pumpScreen(tester, leaveAdmin);
      picker.next = csv(size: 6 * 1024 * 1024);
      await tester.tap(pickCard);
      await tester.pumpAndSettle();
      expect(find.text('File is too large. Maximum allowed size is 5 MB.'), findsOneWidget);
      expect(tester.widget<FilledButton>(validateBtn).onPressed, isNull);
      expect(server.requests, isEmpty);
    });

    testWidgets('backend refusal of the preview is shown; nothing imported', (tester) async {
      await pumpScreen(tester, leaveAdmin);
      server.refuse = 'Only System Admin, HR Admin, and HR can validate import files.';
      await pickAndValidate(tester);
      expect(find.text('Only System Admin, HR Admin, and HR can validate import files.'), findsOneWidget);
      expect(find.textContaining('rows ready to import'), findsNothing);
      expect(server.requests.where((r) => r.$2 == '/leave/balance/import/'), isEmpty);
    });

    testWidgets('backend refusal of the import is shown on the preview', (tester) async {
      await pumpScreen(tester, leaveAdmin);
      await pickAndValidate(tester);
      server.refuse = 'Only System Admin, HR Admin, and HR can import leave balances.';
      await tester.tap(find.text('Import 2 rows'));
      await tester.pumpAndSettle();
      expect(find.text('Only System Admin, HR Admin, and HR can import leave balances.'), findsOneWidget);
      expect(find.text('2 of 3 rows ready to import'), findsOneWidget);
      expect(find.text('Import Another File'), findsNothing);
    });
  });
}

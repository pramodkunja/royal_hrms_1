import 'dart:convert';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/network/api_client.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/core/router/app_router.dart';
import 'package:mobile_app/core/security/secure_storage.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';
import 'package:mobile_app/features/interview_list/presentation/providers/interview_providers.dart';
import 'package:mobile_app/features/interview_list/presentation/screens/candidate_bulk_import_screen.dart';
import 'package:mobile_app/features/interview_list/presentation/screens/interview_list_screen.dart';

// Task 20: web interview-list page renders "Bulk Import" only when canCreate =
// usePermission("recruitment.create") (is_superuser || own permission — no
// settings.edit bypass); the import endpoint also requires recruitment.create.
// CandidateBulkImportModal "File Requirements": "Accepted formats: .csv,
// .xlsx (max 5 MB)", "Required columns: Name, Email, Position, Branch",
// "Optional columns: Phone, Interview Date, Interview Mode, Notes", then
// Sample CSV / Sample XLSX. Stand-in server; nothing is imported.

class Server implements HttpClientAdapter {
  final paths = <String>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    paths.add('${o.method} ${o.path}');
    final Object data = o.path == ApiConstants.candidates
        ? {'count': 0, 'page': 1, 'page_size': 10, 'total_pages': 1, 'status_choices': <Object>[], 'results': <Object>[]}
        : <String, dynamic>{};
    return ResponseBody.fromString(jsonEncode({'status': 'success', 'data': data}), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
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

UserEntity user(List<String> perms, {bool superuser = false}) => UserEntity(
      id: 'u1',
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: superuser,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final creator = user(const ['recruitment.view', 'recruitment.create']);
final viewer = user(const ['recruitment.view']);
final superuser = user(const [], superuser: true);
final settingsOnly = user(const ['recruitment.view', 'settings.edit']);

late Server server;

Future<void> pump(WidgetTester tester, Widget home, UserEntity u) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ],
    child: MaterialApp(
      home: Consumer(builder: (_, ref, child) {
        ref.watch(authStateProvider);
        return child!;
      }, child: home),
    ),
  ));
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rule (web canCreate)', () {
    test('recruitment.create or superuser; view-only and settings.edit-only are not enough', () {
      expect(canOpenCandidateBulkImport(creator), isTrue);
      expect(canOpenCandidateBulkImport(superuser), isTrue);
      expect(canOpenCandidateBulkImport(viewer), isFalse);
      expect(canOpenCandidateBulkImport(settingsOnly), isFalse);
      expect(canOpenCandidateBulkImport(null), isFalse);
    });

    test('the route now requires recruitment.create (a view-only user is redirected)', () {
      expect(requiredPermissionsFor(AppRoutes.candidateBulkImport), ['recruitment.create']);
      expect(canAccessPath(creator, AppRoutes.candidateBulkImport), isTrue);
      expect(canAccessPath(viewer, AppRoutes.candidateBulkImport), isFalse);
      expect(canAccessPath(superuser, AppRoutes.candidateBulkImport), isTrue);
    });
  });

  group('menu entry (Interview List FAB)', () {
    Future<void> openFab(WidgetTester tester) async {
      await tester.tap(find.byType(FloatingActionButton).first);
      await tester.pumpAndSettle();
    }

    // Each test closes the menu before it ends: the shared ExpandableFab
    // reads `ref` in dispose(), which throws when torn down while open (an
    // existing shared-widget issue, reported separately).
    Future<void> closeFab(WidgetTester tester) async {
      await tester.tap(find.byType(FloatingActionButton).first, warnIfMissed: false);
      await tester.pumpAndSettle();
    }

    for (final (name, u) in [('creator', creator), ('superuser', superuser)]) {
      testWidgets('$name sees Bulk Import', (tester) async {
        await pump(tester, const InterviewListScreen(), u);
        await openFab(tester);
        expect(find.text('Bulk Import'), findsOneWidget);
        expect(find.text('Add Candidate'), findsOneWidget);
        await closeFab(tester);
      });
    }

    for (final (name, u) in [('view-only', viewer), ('settings.edit only', settingsOnly)]) {
      testWidgets('$name does not see Bulk Import (no quick-action button at all)', (tester) async {
        await pump(tester, const InterviewListScreen(), u);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Bulk Import'), findsNothing);
      });
    }
  });

  group('screen guard (direct navigation)', () {
    for (final (name, u) in [('view-only', viewer), ('settings.edit only', settingsOnly)]) {
      testWidgets('$name: no-permission view, no sample/import controls, no requests', (tester) async {
        await pump(tester, const CandidateBulkImportScreen(), u);
        expect(byKey('candidate-import-denied'), findsOneWidget);
        expect(find.text('You do not have permission to import candidates.'), findsOneWidget);
        expect(byKey('candidate-sample-csv'), findsNothing);
        expect(byKey('candidate-sample-xlsx'), findsNothing);
        expect(find.text('Import'), findsNothing);
        expect(server.paths.where((p) => p.contains('bulk-import')), isEmpty);
      });
    }

    for (final (name, u) in [('creator', creator), ('superuser', superuser)]) {
      testWidgets('$name gets the import screen', (tester) async {
        await pump(tester, const CandidateBulkImportScreen(), u);
        expect(byKey('candidate-import-denied'), findsNothing);
        expect(byKey('candidate-sample-csv'), findsOneWidget);
        expect(find.text('Import'), findsOneWidget);
      });
    }
  });

  group('File Requirements (web wording and order)', () {
    testWidgets('heading, formats and size, required chips, optional list, then the samples', (tester) async {
      await pump(tester, const CandidateBulkImportScreen(), creator);
      final box = byKey('candidate-import-requirements');
      expect(find.descendant(of: box, matching: find.text('File Requirements')), findsOneWidget);
      final formats = tester.widget<Text>(byKey('candidate-import-formats'));
      expect(formats.textSpan!.toPlainText(), 'Accepted formats: .csv, .xlsx (max 5 MB)');
      expect(find.descendant(of: box, matching: find.text('Required columns:')), findsOneWidget);
      final chips = ['Name', 'Email', 'Position', 'Branch'];
      final xs = [for (final c in chips) tester.getTopLeft(find.descendant(of: box, matching: find.text(c))).dx];
      expect(xs, [...xs]..sort(), reason: 'Name, Email, Position, Branch in order');
      expect(tester.widget<Text>(byKey('candidate-import-optional')).data,
          'Optional columns: Phone, Interview Date, Interview Mode, Notes');
      // the sample buttons sit inside the same box, as on web
      expect(find.descendant(of: box, matching: byKey('candidate-sample-csv')), findsOneWidget);
      expect(find.descendant(of: box, matching: byKey('candidate-sample-xlsx')), findsOneWidget);
      // the old raw-key guide is gone
      for (final old in ['name', 'position_applied', 'branch_name', 'CSV / XLSX format']) {
        expect(find.text(old), findsNothing, reason: old);
      }
    });
  });
}

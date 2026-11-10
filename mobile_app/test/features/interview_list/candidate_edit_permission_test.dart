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
import 'package:mobile_app/features/interview_list/data/models/candidate_model.dart';
import 'package:mobile_app/features/interview_list/presentation/providers/interview_providers.dart';
import 'package:mobile_app/features/interview_list/presentation/widgets/add_candidate_sheet.dart';
import 'package:mobile_app/features/interview_list/presentation/widgets/candidate_card.dart';

// Task 28: web interview-list/page.tsx — canEditRec = usePermission
// ("recruitment.edit") (hooks/usePermission.ts: is_superuser, else the user's
// own permissions; no settings.edit bypass).
//   Edit        : canEditRec && status !== "converted"
//   Status menu : canEditRec && status ∉ {converted, selected, offer_sent}
// Mobile enforces the same rule in the card and inside updateCandidate /
// updateStatus. Stand-in server; no real candidate is touched.

const id = 7;

Map<String, dynamic> cand(String status) => {
      'id': id,
      'name': 'Test Candidate',
      'email': 'candidate@example.test',
      'phone': '9000000000',
      'position_applied': 'Analyst',
      'branch': 1,
      'branch_name': 'North',
      'interview_date': '2026-12-01',
      'interview_mode': 'in_person',
      'status': status,
      'portal_credentials_sent': status == 'offer_sent',
      'added_by_name': 'Test HR',
      'created_at': '2026-11-01T10:00:00Z',
      'logs': <Object>[],
    };

class Server implements HttpClientAdapter {
  Server(this.listStatus);
  final String listStatus;
  final writes = <({String method, String path, Map<String, dynamic> body})>[];

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      final body = o.data is Map ? Map<String, dynamic>.from(o.data as Map) : <String, dynamic>{};
      writes.add((method: o.method, path: o.path, body: body));
      final status = (body['status'] as String?) ?? listStatus;
      return _json({'status': 'success', 'message': 'ok', 'data': cand(status)});
    }
    if (o.path == ApiConstants.candidates) {
      return _json({
        'status': 'success',
        'data': {'count': 1, 'page': 1, 'page_size': 10, 'total_pages': 1, 'status_choices': <Object>[], 'results': [cand(listStatus)]}
      });
    }
    if (o.path == ApiConstants.branches) {
      return _json({
        'status': 'success',
        'data': {
          'results': [
            {'id': 1, 'branch_name': 'North', 'branch_code': 'BR-N'}
          ]
        }
      });
    }
    return _json({'status': 'success', 'data': <String, dynamic>{'total': 1}});
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
      branch: 'North',
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final superuser = user(const [], superuser: true);
final recEdit = user(const ['recruitment.view', 'recruitment.edit']);
final settingsOnly = user(const ['recruitment.view', 'settings.edit']);
final noRelevant = user(const ['recruitment.view']);
final both = user(const ['recruitment.view', 'recruitment.edit', 'settings.edit']);

final allowedUsers = [('superuser', superuser), ('own recruitment.edit', recEdit), ('settings.edit + recruitment.edit', both)];
final deniedUsers = [('settings.edit only', settingsOnly), ('no relevant permission', noRelevant)];

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Finder get editButton => find.byKey(const Key('candidate-edit-$id'));
Finder get statusMenu => find.byKey(const Key('candidate-status-menu-$id'));

Future<void> pumpCard(WidgetTester tester, UserEntity u, String status) async {
  tester.view.physicalSize = const Size(1080, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server(status);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: overrides(u),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          ref.watch(authStateProvider);
          ref.watch(candidateListProvider);
          return SingleChildScrollView(child: CandidateCard(candidate: CandidateModel.fromJson(cand(status))));
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// The action methods, called directly (another UI path) with the candidate
/// loaded in the list as [status].
Future<({String? edit, String? status, Server server})> callActions(
    WidgetTester tester, UserEntity u, String status) async {
  server = Server(status);
  late WidgetRef captured;
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: overrides(u),
    child: Consumer(builder: (_, ref, __) {
      captured = ref;
      ref.watch(authStateProvider);
      ref.watch(candidateListProvider);
      return const SizedBox();
    }),
  ));
  await tester.pumpAndSettle();
  final n = captured.read(candidateListProvider.notifier);
  String? editErr;
  String? statusErr;
  await tester.runAsync(() async {
    editErr = await n.updateCandidate(id, {'position_applied': 'Senior Analyst'});
    statusErr = await n.updateStatus(id, 'screening');
  });
  return (edit: editErr, status: statusErr, server: server);
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rule', () {
    test('superuser or own recruitment.edit; settings.edit alone never', () {
      expect(canEditCandidates(superuser), isTrue);
      expect(canEditCandidates(recEdit), isTrue);
      expect(canEditCandidates(both), isTrue);
      expect(canEditCandidates(settingsOnly), isFalse);
      expect(canEditCandidates(noRelevant), isFalse);
      expect(canEditCandidates(null), isFalse);
    });

    test('status conditions differ between Edit and the status menu (web)', () {
      final expected = {
        // status: (Edit, status menu)
        'pending': (true, true),
        'screening': (true, true),
        'interview_scheduled': (true, true),
        'interview_done': (true, true),
        'rejected': (true, true),
        'selected': (true, false),
        'offer_sent': (true, false),
        'converted': (false, false),
      };
      expected.forEach((status, want) {
        final c = CandidateModel.fromJson(cand(status));
        expect((canEditCandidate(recEdit, c), canChangeCandidateStatus(recEdit, c)), want, reason: status);
        expect((canEditCandidate(settingsOnly, c), canChangeCandidateStatus(settingsOnly, c)), (false, false),
            reason: 'settings.edit only · $status');
      });
    });
  });

  group('card UI', () {
    for (final (name, u) in allowedUsers) {
      testWidgets('$name: pending → Edit and status menu', (tester) async {
        await pumpCard(tester, u, 'pending');
        expect(editButton, findsOneWidget);
        expect(statusMenu, findsOneWidget);
      });

      testWidgets('$name: selected → Edit, no status menu, Send Login', (tester) async {
        await pumpCard(tester, u, 'selected');
        expect(editButton, findsOneWidget);
        expect(statusMenu, findsNothing);
        expect(find.byKey(const Key('candidate-send-login-$id')), findsOneWidget);
      });

      testWidgets('$name: converted → neither', (tester) async {
        await pumpCard(tester, u, 'converted');
        expect(editButton, findsNothing);
        expect(statusMenu, findsNothing);
        expect(find.text('Employee'), findsOneWidget);
      });
    }

    for (final (name, u) in deniedUsers) {
      for (final status in ['pending', 'selected', 'rejected']) {
        testWidgets('$name: $status → no Edit, no status menu, no Send Login', (tester) async {
          await pumpCard(tester, u, status);
          expect(editButton, findsNothing);
          expect(statusMenu, findsNothing);
          expect(find.byKey(const Key('candidate-send-login-$id')), findsNothing);
        });
      }
    }

    testWidgets('allowed: Edit opens the existing edit dialog; menu labels unchanged', (tester) async {
      await pumpCard(tester, recEdit, 'pending');
      await tester.tap(editButton);
      await tester.pumpAndSettle();
      expect(find.byType(AddCandidateDialog), findsOneWidget);
      Navigator.of(tester.element(find.byType(AddCandidateDialog))).pop();
      await tester.pumpAndSettle();
      await tester.tap(statusMenu);
      await tester.pumpAndSettle();
      // Mobile's existing (shorter) labels — unchanged by this task.
      for (final label in ['Screening', 'Scheduled', 'Done', 'Selected', 'Rejected']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      await tester.tap(find.text('Screening').last);
      await tester.pumpAndSettle();
      expect(server.writes.single.method, 'PATCH');
      expect(server.writes.single.path, ApiConstants.candidateStatus(id));
      expect(server.writes.single.body, {'status': 'screening'});
    });
  });

  group('action methods (direct calls)', () {
    for (final (name, u) in deniedUsers) {
      testWidgets('$name: edit and status change refused before any request', (tester) async {
        final r = await callActions(tester, u, 'pending');
        expect(r.edit, kCandidateEditDenied);
        expect(r.status, kCandidateStatusChangeDenied);
        expect(r.server.writes, isEmpty);
      });
    }

    for (final (name, u) in allowedUsers) {
      testWidgets('$name: edit (PUT) and status change (PATCH) go through', (tester) async {
        final r = await callActions(tester, u, 'pending');
        expect([r.edit, r.status], [null, null]);
        expect(r.server.writes.map((w) => '${w.method} ${w.path}'), [
          'PUT ${ApiConstants.candidateDetail(id)}',
          'PATCH ${ApiConstants.candidateStatus(id)}',
        ]);
        expect(r.server.writes.first.body, {'position_applied': 'Senior Analyst'});
      });
    }

    testWidgets('allowed user, converted candidate: both refused (web hides both)', (tester) async {
      final r = await callActions(tester, recEdit, 'converted');
      expect([r.edit, r.status], [kCandidateEditDenied, kCandidateStatusChangeDenied]);
      expect(r.server.writes, isEmpty);
    });

    testWidgets('allowed user, selected candidate: edit allowed, status change refused (web)', (tester) async {
      final r = await callActions(tester, recEdit, 'selected');
      expect(r.edit, isNull);
      expect(r.status, kCandidateStatusChangeDenied);
      expect(r.server.writes.map((w) => w.method), ['PUT']);
    });
  });

  group('neighbouring permissions unchanged', () {
    test('Send Login: superuser or own recruitment.edit, Selected only', () {
      final sel = CandidateModel.fromJson(cand('selected'));
      expect(canSendCandidateLogin(recEdit, sel), isTrue);
      expect(canSendCandidateLogin(superuser, sel), isTrue);
      expect(canSendCandidateLogin(settingsOnly, sel), isFalse);
      expect(canSendCandidateLogin(recEdit, CandidateModel.fromJson(cand('pending'))), isFalse);
    });

    test('Add Candidate / Bulk Import: superuser or own recruitment.create (edit does not count)', () {
      expect(canCreateCandidates(recEdit), isFalse);
      expect(canCreateCandidates(user(const ['recruitment.create'])), isTrue);
      expect(canCreateCandidates(superuser), isTrue);
      expect(canCreateCandidates(settingsOnly), isFalse);
      expect(canOpenCandidateBulkImport(settingsOnly), isFalse);
    });
  });
}

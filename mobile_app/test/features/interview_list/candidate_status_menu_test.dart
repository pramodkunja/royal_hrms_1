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
import 'package:mobile_app/features/interview_list/presentation/widgets/candidate_card.dart';
import 'package:mobile_app/features/interview_list/presentation/widgets/mark_candidate_sheet.dart';

// Task 16 (audit A-I4 remainder): web interview-list page.tsx shows the
// status <select> only when `canEditRec && status ∉ {converted, selected,
// offer_sent}`; its options are CandidateStatusView._STATUS_CHOICES (pending,
// screening, interview_scheduled, interview_done, selected, rejected);
// selected/rejected open MarkCandidateModal, anything else PATCHes
// /recruitment/candidates/<id>/status/ {status}. Synthetic candidates on a
// stand-in server — no real candidate is changed and no email is sent.

const id = 7;

Map<String, dynamic> cand(String status, {bool sent = false}) => {
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
      'portal_credentials_sent': sent,
      'added_by_name': 'Test HR',
      'created_at': '2026-11-01T10:00:00Z',
      'logs': <Object>[],
    };

class Server implements HttpClientAdapter {
  Server(this.listStatus);
  String listStatus;
  final patches = <Map<String, dynamic>>[];

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'PATCH' && o.path == ApiConstants.candidateStatus(id)) {
      final body = Map<String, dynamic>.from(o.data as Map);
      patches.add(body);
      return _json({'status': 'success', 'message': 'Status updated.', 'data': cand(body['status'] as String)});
    }
    if (o.path == ApiConstants.candidates) {
      return _json({
        'status': 'success',
        'data': {
          'count': 1,
          'page': 1,
          'page_size': 10,
          'total_pages': 1,
          'status_choices': <Object>[],
          'results': [cand(listStatus)],
        }
      });
    }
    if (o.path == ApiConstants.candidateStats) {
      return _json({'status': 'success', 'data': {'total': 1}});
    }
    if (o.path == ApiConstants.settingsEmailTemplates) {
      return _json({'status': 'success', 'data': {'count': 0, 'results': <String, dynamic>{}}});
    }
    return _json({'status': 'success', 'data': <String, dynamic>{}});
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

final editor = user(const ['recruitment.view', 'recruitment.edit']);
final viewer = user(const ['recruitment.view']);

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Finder get menu => find.byKey(const Key('candidate-status-menu-$id'));

Future<void> pumpCard(WidgetTester tester, String status, {UserEntity? as, bool sent = false}) async {
  tester.view.physicalSize = const Size(1080, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server(status);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? editor),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          ref.watch(authStateProvider);
          ref.watch(candidateListProvider);
          return SingleChildScrollView(child: CandidateCard(candidate: CandidateModel.fromJson(cand(status, sent: sent))));
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<List<String>> openMenu(WidgetTester tester) async {
  await tester.tap(menu);
  await tester.pumpAndSettle();
  return tester
      .widgetList<PopupMenuItem<String>>(find.byWidgetPredicate((w) => w is PopupMenuItem<String>))
      .map((i) => i.value!)
      .toList();
}

const _choices = ['pending', 'screening', 'interview_scheduled', 'interview_done', 'selected', 'rejected'];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('eligibility rule (web page.tsx)', () {
    test('recruitment.edit and a pre-selection status; selected / offer_sent / converted never', () {
      final expected = {
        'pending': true,
        'screening': true,
        'interview_scheduled': true,
        'interview_done': true,
        'rejected': true,
        'selected': false,
        'offer_sent': false,
        'converted': false,
      };
      expected.forEach((status, ok) {
        final c = CandidateModel.fromJson(cand(status));
        expect(canChangeCandidateStatus(editor, c), ok, reason: status);
        expect(canChangeCandidateStatus(viewer, c), isFalse, reason: 'viewer · $status');
      });
      final pending = CandidateModel.fromJson(cand('pending'));
      // Task 28: web usePermission has no settings.edit bypass.
      expect(canChangeCandidateStatus(user(const ['settings.edit']), pending), isFalse, reason: 'settings.edit alone is not enough');
      expect(canChangeCandidateStatus(user(const [], superuser: true), pending), isTrue);
      expect(canChangeCandidateStatus(null, pending), isFalse);
    });
  });

  group('menu visibility and options', () {
    for (final status in ['pending', 'screening', 'interview_scheduled', 'interview_done', 'rejected']) {
      testWidgets('$status: menu shown with web\'s other choices', (tester) async {
        await pumpCard(tester, status);
        expect(menu, findsOneWidget);
        expect(await openMenu(tester), [for (final s in _choices) if (s != status) s],
            reason: 'offer_sent and converted are never offered');
      });
    }

    for (final status in ['selected', 'offer_sent', 'converted']) {
      testWidgets('$status: no status menu', (tester) async {
        await pumpCard(tester, status);
        expect(menu, findsNothing);
      });
    }

    testWidgets('selected keeps Send Login; offer_sent shows "Login Sent"; converted shows "Employee"', (tester) async {
      await pumpCard(tester, 'selected');
      expect(find.text('Send Login'), findsOneWidget);
      await pumpCard(tester, 'offer_sent', sent: true);
      expect(find.text('Login Sent'), findsOneWidget);
      await pumpCard(tester, 'converted');
      expect(find.text('Employee'), findsOneWidget);
    });

    testWidgets('without recruitment.edit: no status menu for any status', (tester) async {
      for (final status in ['pending', 'interview_done', 'rejected']) {
        await pumpCard(tester, status, as: viewer);
        expect(menu, findsNothing, reason: status);
      }
    });
  });

  group('choosing an option (unchanged behaviour)', () {
    testWidgets('a pipeline status is PATCHed straight away', (tester) async {
      await pumpCard(tester, 'pending');
      await openMenu(tester);
      await tester.tap(find.text('Screening').last);
      await tester.pumpAndSettle();
      expect(server.patches, [
        {'status': 'screening'}
      ]);
    });

    for (final (label, target) in [('Selected', 'selected'), ('Rejected', 'rejected')]) {
      testWidgets('$label opens the confirmation sheet and sends nothing yet', (tester) async {
        await pumpCard(tester, 'interview_done');
        await openMenu(tester);
        await tester.tap(find.text(label).last);
        await tester.pumpAndSettle();
        final sheet = tester.widget<MarkCandidateSheet>(find.byType(MarkCandidateSheet));
        expect(sheet.targetStatus, target);
        expect(server.patches, isEmpty);
      });
    }
  });

  group('hidden options cannot be triggered', () {
    Future<(String?, Server)> attempt(WidgetTester tester, UserEntity u, String listStatus) async {
      server = Server(listStatus);
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        overrides: overrides(u),
        child: Consumer(builder: (_, ref, __) {
          captured = ref;
          ref.watch(authStateProvider);
          ref.watch(candidateListProvider);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      final err = await tester.runAsync(() => captured.read(candidateListProvider.notifier).updateStatus(id, 'screening'));
      return (err, server);
    }

    testWidgets('without recruitment.edit the action refuses and sends nothing', (tester) async {
      final (err, s) = await attempt(tester, viewer, 'pending');
      expect(err, kCandidateStatusChangeDenied);
      expect(s.patches, isEmpty);
    });

    for (final status in ['selected', 'offer_sent', 'converted']) {
      testWidgets('a $status candidate in the list can\'t be moved through the action', (tester) async {
        final (err, s) = await attempt(tester, editor, status);
        expect(err, kCandidateStatusChangeDenied);
        expect(s.patches, isEmpty);
      });
    }

    testWidgets('an eligible candidate still goes through', (tester) async {
      final (err, s) = await attempt(tester, editor, 'rejected');
      expect(err, isNull);
      expect(s.patches, [
        {'status': 'screening'}
      ]);
    });
  });
}

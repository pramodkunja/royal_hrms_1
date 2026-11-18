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
import 'package:mobile_app/features/leave/data/models/leave_models.dart';
import 'package:mobile_app/features/leave/presentation/widgets/apply_leave_type_selector.dart';
import 'package:mobile_app/features/leave/presentation/widgets/leave_document_rule.dart';
import 'package:mobile_app/features/settings/data/models/leave_policy_model.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/widgets/add_leave_type_dialog.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart';
import 'package:mobile_app/shared/validators/form_validators.dart';

import 'apply_leave_types_documents_test.dart' as h;

// Task 93 — HO-39 (leave type eligibility), HO-40 (medical certificate rule),
// HO-41 (Add Leave Type "Applicable to" + messages, server save message).
// Web source of truth: frontend/app/dashboard/leave/_data.ts
// (buildApplicableLeaveTypes, documentRule), leave/_components/ApplyLeaveForm.tsx,
// settings/leave-policy/_components/PolicyTab.tsx + LeavePoliciesTab.tsx.
// Stand-in servers with synthetic data; nothing is sent anywhere.

Map<String, dynamic> pol(String code, String display,
        {bool active = true, bool? eligible, bool attach = false, bool med = false, int after = 3}) =>
    {
      ...h.policy(code, display, attach: attach, active: active),
      'medical_certificate_required': med,
      'medical_certificate_after_days': after,
      if (eligible != null) 'eligible_for_me': eligible,
    };

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

/// The Apply Leave stand-in server, with a configurable preview day count
/// and an optional failing policy list.
class _ApplyServer extends h.Server {
  double previewDays = 0.5;
  bool failPolicies = false;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path == '/leave/policy/' && failPolicies) {
      return _json(500, {'status': 'error', 'message': 'Server error.'});
    }
    final r = await super.fetch(o, s, c);
    if (o.path == '/leave/requests/' && o.method == 'GET' && o.queryParameters['action'] == 'preview') {
      final body = jsonDecode(await utf8.decoder.bind(r.stream).join()) as Map<String, dynamic>;
      (body['data'] as Map<String, dynamic>)['actual_leave_days'] = previewDays;
      return _json(200, body);
    }
    return r;
  }
}

List<String> shownTypes(WidgetTester tester) => [
      for (final l in const ['Casual Leave', 'Earned Leave', 'Sick Leave', 'Leave Without Pay',
        'Maternity Leave', 'Paternity Leave', 'Pink Leave'])
        if (find.text(l).evaluate().isNotEmpty) l,
    ];

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('HO-39 eligibility (web buildApplicableLeaveTypes)', () {
    test('eligible_for_me parsed; absent → null (treated as eligible)', () {
      expect(LeaveTypeModel.fromJson(pol('paternity', 'Paternity Leave', eligible: false)).eligibleForMe, isFalse);
      expect(LeaveTypeModel.fromJson(pol('casual', 'Casual Leave')).eligibleForMe, isNull);
    });

    test('filters inactive and ineligible types; built-ins without a policy stay; empty until loaded', () {
      final types = [
        LeaveTypeModel.fromJson(pol('casual', 'Casual Leave', eligible: true)),
        LeaveTypeModel.fromJson(pol('maternity', 'Maternity Leave', eligible: false)), // gender rule
        LeaveTypeModel.fromJson(pol('paternity', 'Paternity Leave', active: false)), // inactive built-in
        LeaveTypeModel.fromJson(pol('pink_leave', 'Pink Leave', eligible: false)), // ineligible custom
        LeaveTypeModel.fromJson(pol('old', 'Old Leave', active: false)), // inactive custom
        LeaveTypeModel.fromJson(pol('earned', 'Earned Leave')), // no eligible_for_me (older server)
      ];
      final codes = LeaveTypeOption.applicableFromEntities(types, const [], policiesLoaded: true).map((o) => o.code);
      expect(codes, ['casual', 'earned', 'sick', 'lwp']); // sick / lwp have no policy row → kept
      expect(LeaveTypeOption.applicableFromEntities(types, const [], policiesLoaded: false), isEmpty);
    });

    testWidgets('Apply Leave shows only the types this employee may apply for', (tester) async {
      final s = _ApplyServer()
        ..policies = [
          pol('casual', 'Casual Leave', eligible: true),
          pol('earned', 'Earned Leave', eligible: true),
          pol('sick', 'Sick Leave', eligible: true),
          pol('lwp', 'Leave Without Pay', eligible: true),
          pol('maternity', 'Maternity Leave', eligible: false),
          pol('paternity', 'Paternity Leave', eligible: true),
          pol('pink_leave', 'Pink Leave', eligible: false),
        ];
      await h.pump(tester, with_: s);
      expect(shownTypes(tester),
          ['Casual Leave', 'Earned Leave', 'Sick Leave', 'Leave Without Pay', 'Paternity Leave']);
    });

    testWidgets('if the first type is not offered, the first offered one is selected (never a hidden type)',
        (tester) async {
      final s = _ApplyServer()
        ..policies = [
          pol('casual', 'Casual Leave', eligible: false),
          pol('earned', 'Earned Leave', eligible: true),
        ];
      await h.pump(tester, with_: s);
      expect(find.text('Casual Leave'), findsNothing);
      expect(find.text('Earned Leave'), findsWidgets);
    });

    testWidgets('policy list failure: message + Retry (no built-in list guessed)', (tester) async {
      final s = _ApplyServer()..failPolicies = true;
      await h.pump(tester, with_: s);
      expect(find.byKey(const Key('apply-leave-types-error')), findsOneWidget);
      expect(find.text('Casual Leave'), findsNothing);
      s.failPolicies = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Casual Leave'), findsWidgets);
    });

    testWidgets('nothing offered: empty message, Submit disabled', (tester) async {
      final s = _ApplyServer()
        ..policies = [
          for (final c in ['casual', 'earned', 'sick', 'lwp', 'maternity', 'paternity'])
            pol(c, c, eligible: false),
        ];
      await h.pump(tester, with_: s);
      expect(find.byKey(const Key('apply-leave-types-empty')), findsOneWidget);
      expect(find.text('No leave types are available to you.'), findsOneWidget);
    });
  });

  group('HO-40 medical certificate (web documentRule)', () {
    final med = LeaveTypeModel.fromJson(pol('sick', 'Sick Leave', med: true, after: 3));

    test('rules: attachment / medical from N days / neither / not loaded', () {
      expect(leaveDocumentRule(med, 2, fallback: true),
          (required: false, hint: 'A medical certificate is required for leave of 3 or more days.'));
      expect(leaveDocumentRule(med, 3, fallback: false).required, isTrue);
      final one = LeaveTypeModel.fromJson(pol('sick', 'Sick Leave', med: true, after: 1));
      expect(leaveDocumentRule(one, 1, fallback: false).hint, 'A medical certificate is required for leave of 1 or more day.');
      final attach = LeaveTypeModel.fromJson(pol('casual', 'Casual Leave', attach: true, med: true));
      expect(leaveDocumentRule(attach, 0.5, fallback: false), (required: true, hint: ''));
      expect(leaveDocumentRule(LeaveTypeModel.fromJson(pol('earned', 'Earned Leave')), 9, fallback: true),
          (required: false, hint: ''));
      expect(leaveDocumentRule(null, 1, fallback: true), (required: true, hint: ''));
      expect(leaveDocFallback('sick', null), isTrue);
      expect(leaveDocFallback('maternity', null), isTrue);
      expect(leaveDocFallback('casual', null), isFalse);
      expect(leaveDocumentRequiredMessage(''), 'Supporting document is required for this leave type.');
    });

    Future<void> pumpSick(WidgetTester tester, double previewDays) async {
      final s = _ApplyServer()
        ..previewDays = previewDays
        ..policies = [
          pol('casual', 'Casual Leave', eligible: true),
          pol('sick', 'Sick Leave', eligible: true, med: true, after: 3),
        ];
      await h.pump(tester, with_: s);
      await h.selectType(tester, 'Sick Leave');
    }

    testWidgets('below N days: optional, hint shown; submit sends the request', (tester) async {
      await pumpSick(tester, 0.5);
      expect(find.byKey(const Key('apply-leave-doc-hint')), findsOneWidget);
      await h.fillAndSubmit(tester);
      expect(h.server.posts, hasLength(1));
    });

    testWidgets('N or more days (server preview): required; without a file the hint is the error, nothing sent',
        (tester) async {
      await pumpSick(tester, 3);
      await h.fillAndSubmit(tester);
      expect(h.server.posts, isEmpty);
      expect(h.docLabel(tester), 'Required');
      expect(find.text('A medical certificate is required for leave of 3 or more days.'), findsNWidgets(2)); // hint + error
    });
  });

  group('HO-41 Add Leave Type (web PolicyTab)', () {
    test('web messages for the display name; key preview as web', () {
      expect(FormValidators.leaveTypeName(''), 'Display name is required.');
      expect(FormValidators.leaveTypeName('Leave 2'),
          'Display name can only contain letters, spaces, and hyphens — no numbers or special characters.');
      expect(FormValidators.leaveTypeName('Pink Leave'), isNull);
      expect(leaveTypeKeyPreview(' Pink  - Leave '), 'pink_leave');
    });

    test('payload carries applicable_gender (default all)', () {
      expect(LeavePolicyFormData().toJson()['applicable_gender'], 'all');
      expect(LeavePolicyFormData(applicableGender: 'female').toJson()['applicable_gender'], 'female');
    });

    testWidgets('Applicable to: default All; Female sent; carry-forward ≥ 1 rule; inline server error', (tester) async {
      final s = _PolicyServer();
      await _pumpDialog(tester, s, ['settings.view', 'leave.approve']);
      expect(find.text('All employees'), findsOneWidget);
      expect(find.text('Display Name *'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).first, 'Pink Leave');
      await tester.pump();
      expect(find.text('Key: pink_leave'), findsOneWidget);

      await tester.tap(find.byKey(const Key('add-leave-type-gender')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Female employees only').last);
      await tester.pumpAndSettle();

      // Carry forward on with 0 days → web message, nothing sent.
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Add Leave Type').last);
      await tester.tap(find.text('Add Leave Type').last);
      await tester.pumpAndSettle();
      expect(find.text('Must be at least 1 when carry forward is enabled.'), findsOneWidget);
      expect(s.posts, isEmpty);

      await tester.tap(find.byType(Switch).first); // carry forward off again
      await tester.pumpAndSettle();
      s.refuse = 'A leave type with this name already exists.';
      await tester.ensureVisible(find.text('Add Leave Type').last);
      await tester.tap(find.text('Add Leave Type').last);
      await tester.pumpAndSettle();
      expect(s.posts, hasLength(1));
      final body = s.posts.single;
      expect(body['leave_type_label'], 'Pink Leave');
      expect(body['applicable_gender'], 'female');
      expect(find.byKey(const Key('add-leave-type-error')), findsOneWidget);
      expect(find.text('A leave type with this name already exists.'), findsOneWidget);
    });

    testWidgets('without settings.edit / leave.approve: refused locally, nothing sent', (tester) async {
      final s = _PolicyServer();
      await _pumpDialog(tester, s, ['settings.view']);
      await tester.enterText(find.byType(TextFormField).first, 'Pink Leave');
      await tester.ensureVisible(find.text('Add Leave Type').last);
      await tester.tap(find.text('Add Leave Type').last);
      await tester.pumpAndSettle();
      expect(s.posts, isEmpty);
      expect(find.text('Permission denied.'), findsOneWidget);
    });

    test('rules save returns the server message (e.g. "Removed N unused balance(s)…")', () async {
      final s = _PolicyServer()
        ..putMessage = 'Policy updated. Removed 2 unused balance(s) from employees this leave type no longer applies to.';
      final c = ProviderContainer(overrides: _overrides(s, ['settings.view', 'leave.approve']));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      await c.read(leavePoliciesProvider.future);
      final r = await c
          .read(leavePoliciesProvider.notifier)
          .updatePolicyWithMessage('pink_leave', LeavePolicyFormData(applicableGender: 'female'));
      expect(r.error, isNull);
      expect(r.message, startsWith('Policy updated. Removed 2 unused balance(s)'));
      s.putMessage = '';
      final r2 = await c
          .read(leavePoliciesProvider.notifier)
          .updatePolicyWithMessage('pink_leave', LeavePolicyFormData());
      expect(r2.message, 'Policy updated.'); // web fallback
    });
  });
}

// ── Add Leave Type harness ──────────────────────────────────────────────────

class _PolicyServer implements HttpClientAdapter {
  final posts = <Map<String, dynamic>>[];
  String? refuse;
  String putMessage = 'Policy updated.';

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.method == 'GET' && o.path == '/leave/policy/') {
      return _json(200, {'status': 'success', 'message': 'ok', 'data': [pol('casual', 'Casual Leave')]});
    }
    if (o.method == 'POST' && o.path == '/leave/policy/') {
      posts.add(Map<String, dynamic>.from(o.data as Map));
      if (refuse != null) return _json(400, {'status': 'error', 'message': refuse});
      return _json(201, {'status': 'success', 'message': 'Created.', 'data': pol('pink_leave', 'Pink Leave')});
    }
    if (o.method == 'PUT' && o.path.startsWith('/leave/policy/')) {
      return _json(200, {'status': 'success', 'message': putMessage, 'data': pol('pink_leave', 'Pink Leave')});
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

late UserEntity _who;

class _Auth extends AuthNotifier {
  @override
  Future<AuthState> build() async => AuthState(user: _who);
}

List<Override> _overrides(_PolicyServer s, List<String> perms) {
  _who = UserEntity(
    id: 'u1',
    email: 'hr@example.test',
    fullName: 'Test HR',
    role: 'hr_admin',
    roleDisplay: 'HR',
    mustChangePassword: false,
    permissions: perms,
    onboardingStatus: 'complete',
    assessmentStatus: 'complete',
  );
  return [
    authStateProvider.overrideWith(_Auth.new),
    dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s),
    cookieJarProvider.overrideWithValue(CookieJar()),
    secureStorageProvider.overrideWithValue(_NullStorage()),
  ];
}

Future<void> _pumpDialog(WidgetTester tester, _PolicyServer s, List<String> perms) async {
  tester.view.physicalSize = const Size(1080, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: _overrides(s, perms),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(builder: (context, ref, _) {
          ref.watch(authStateProvider); // sign-in resolved before the dialog acts
          return Center(child: Material(child: AddLeaveTypeDialog(ref: ref)));
        }),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

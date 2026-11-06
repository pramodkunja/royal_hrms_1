import 'dart:async';
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
import 'package:mobile_app/features/settings/data/models/leave_policy_model.dart';
import 'package:mobile_app/features/settings/presentation/leave_policy/leave_policy_screen.dart';
import 'package:mobile_app/features/settings/presentation/providers/settings_providers.dart';

// P2: Leave Policy → Leave Application Rules → Long Leave, as web
// LeavePoliciesTab.tsx ("Long Leave — From (days or more, 0 = off)",
// "Long Leave — Notice (days in advance)") over production LeavePolicy
// long_leave_min_days / long_leave_notice_days (PositiveIntegerField,
// default 0; serializer IntegerField(min_value=0)), saved with the rules
// PUT /leave/policy/<type>/ (partial update; settings.edit or leave.approve).
// Stand-in server, synthetic policies; nothing is sent anywhere.

Map<String, dynamic> policy(String type, String display, {Map<String, dynamic> extra = const {}}) => {
      'id': type.hashCode & 0xffff,
      'leave_type': type,
      'leave_type_display': display,
      'annual_days': '12.0',
      'can_carry_forward': false,
      'max_carry_forward_days': 0,
      'policy_note': 'Synthetic note',
      'is_active': true,
      'updated_at': '2026-11-01T00:00:00Z',
      'minimum_leave_duration': '0.5',
      'maximum_leave_duration': 10,
      'minimum_notice_period': 2,
      'allow_half_day': true,
      'sandwich_leave_enabled': true,
      'applicable_gender': 'female',
      'medical_certificate_after_days': 4,
      ...extra,
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> policies = [
    policy('earned', 'Earned Leave', extra: {'long_leave_min_days': 5, 'long_leave_notice_days': 15}),
    policy('casual', 'Casual Leave', extra: {'long_leave_min_days': 0, 'long_leave_notice_days': 0}),
    policy('legacy', 'Legacy Leave'), // a server that does not send the long-leave fields
  ];
  final puts = <({String path, Map<String, dynamic> body})>[];
  Completer<void>? hold;
  ({int status, String message})? refuseNext;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method == 'GET' && o.path == ApiConstants.leaveTypes) {
      return _json({'status': 'success', 'message': 'ok', 'data': policies});
    }
    if (o.method == 'PUT' && o.path.startsWith(ApiConstants.leaveTypes)) {
      final body = Map<String, dynamic>.from(o.data as Map);
      puts.add((path: o.path, body: body));
      if (hold != null) await hold!.future;
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _json({'status': 'error', 'message': r.message}, r.status);
      }
      final type = o.path.split('/').where((s) => s.isNotEmpty).last;
      final saved = {...policies.firstWhere((p) => p['leave_type'] == type), ...body};
      policies = [for (final p in policies) p['leave_type'] == type ? saved : p];
      return _json({'status': 'success', 'message': 'Policy updated.', 'data': saved});
    }
    return _json({'status': 'success', 'message': 'ok', 'data': []});
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

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pump(WidgetTester tester, {List<String> perms = const ['settings.view', 'leave.approve']}) async {
  tester.view.physicalSize = const Size(1080, 9000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(user(perms)),
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: '/s', routes: [
        GoRoute(
          path: '/s',
          builder: (_, __) => Consumer(
            builder: (context, ref, _) =>
                ref.watch(authStateProvider).valueOrNull?.user == null ? const SizedBox() : const LeavePolicyScreen(),
          ),
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(Tab, 'Leave Policy'));
  await tester.pumpAndSettle();
}

final minField = find.byKey(const Key('long-leave-min-days'));
final noticeField = find.byKey(const Key('long-leave-notice-days'));

/// Expands "Leave Application Rules" if it is collapsed.
Future<void> showRules(WidgetTester tester) async {
  // Presence, not hit-testability: locked (read-only) fields are not tappable.
  if (find.text('Minimum Notice Period (days)').evaluate().isEmpty) {
    final title = find.text('Leave Application Rules');
    await tester.ensureVisible(title);
    await tester.tap(title);
    await tester.pumpAndSettle();
  }
}

String fieldText(WidgetTester tester, Finder f) =>
    tester.widget<EditableText>(find.descendant(of: f, matching: find.byType(EditableText))).controller.text;

Future<void> selectType(WidgetTester tester, String label) async {
  final picker = find.byType(DropdownButtonFormField<String>).first;
  await tester.ensureVisible(picker);
  await tester.tap(picker);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> enter(WidgetTester tester, Finder f, String text) async {
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> save(WidgetTester tester) async {
  final b = find.widgetWithText(FilledButton, 'Save Policy');
  await tester.ensureVisible(b);
  await tester.tap(b);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('model', () {
    test('parsing: numbers or numeric strings; absent stays null (not invented); junk is 0', () {
      LeavePolicyModel m(Map<String, dynamic> extra) => LeavePolicyModel.fromJson(policy('x', 'X', extra: extra));
      expect(m({'long_leave_min_days': 5, 'long_leave_notice_days': 15}).longLeaveMinDays, 5);
      expect(m({'long_leave_min_days': 5, 'long_leave_notice_days': 15}).longLeaveNoticeDays, 15);
      expect(m({'long_leave_min_days': '7', 'long_leave_notice_days': 30.0}).longLeaveMinDays, 7);
      expect(m({'long_leave_min_days': 0}).longLeaveMinDays, 0);
      expect(m({}).longLeaveMinDays, isNull);
      expect(m({}).longLeaveNoticeDays, isNull);
      expect(m({'long_leave_min_days': null}).longLeaveMinDays, 0); // web: ?? 0
      expect(m({'long_leave_min_days': 'abc'}).longLeaveMinDays, 0);
    });

    test('serialization: sent when known, left out when the server never sent them', () {
      final known = LeavePolicyFormData.fromModel(
          LeavePolicyModel.fromJson(policy('x', 'X', extra: {'long_leave_min_days': 5, 'long_leave_notice_days': 15})));
      expect(known.toJson()['long_leave_min_days'], 5);
      expect(known.toJson()['long_leave_notice_days'], 15);
      final unknown = LeavePolicyFormData.fromModel(LeavePolicyModel.fromJson(policy('x', 'X'))).toJson();
      expect(unknown.containsKey('long_leave_min_days'), isFalse);
      expect(unknown.containsKey('long_leave_notice_days'), isFalse);
    });

    test('permission rule = production LeavePolicyView.put: settings.edit or leave.approve (or superuser)', () {
      expect(canEditLeavePolicies(user(['settings.view', 'settings.edit'])), isTrue);
      expect(canEditLeavePolicies(user(['settings.view', 'leave.approve'])), isTrue);
      expect(canEditLeavePolicies(user([], superuser: true)), isTrue);
      expect(canEditLeavePolicies(user(['settings.view', 'leave.view', 'leave.edit'])), isFalse);
      expect(canEditLeavePolicies(null), isFalse);
    });

    test('the provider refuses a save without permission before any request', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(user(['settings.view'])));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      final policies = await c.read(leavePoliciesProvider.future);
      final form = LeavePolicyFormData.fromModel(policies.first)..longLeaveMinDays = 9;
      expect(await c.read(leavePoliciesProvider.notifier).updatePolicy('earned', form), 'Permission denied.');
      expect(server.puts, isEmpty);
    });
  });

  group('Leave Application Rules', () {
    testWidgets('shows web\'s two fields with the policy\'s values; switching type reloads them', (tester) async {
      await pump(tester);
      await showRules(tester);
      expect(find.text('Long Leave — From (days or more, 0 = off)'), findsOneWidget);
      expect(find.text('Long Leave — Notice (days in advance)'), findsOneWidget);
      expect(fieldText(tester, minField), '5');
      expect(fieldText(tester, noticeField), '15');
      await selectType(tester, 'Casual Leave');
      await showRules(tester);
      expect(fieldText(tester, minField), '0');
      expect(fieldText(tester, noticeField), '0');
    });

    testWidgets('a server that does not send them: no fields and nothing sent for them', (tester) async {
      await pump(tester);
      await selectType(tester, 'Legacy Leave');
      await showRules(tester);
      expect(find.text('Minimum Notice Period (days)'), findsOneWidget);
      expect(minField, findsNothing);
      expect(noticeField, findsNothing);
      await save(tester);
      final body = server.puts.single.body;
      expect(body.containsKey('long_leave_min_days'), isFalse);
      expect(body.containsKey('long_leave_notice_days'), isFalse);
    });

    testWidgets('save sends the edited values with every other rule unchanged (PUT /leave/policy/<type>/)',
        (tester) async {
      await pump(tester);
      await showRules(tester);
      await enter(tester, minField, '7');
      await enter(tester, noticeField, '21');
      await save(tester);
      final put = server.puts.single;
      expect(put.path, ApiConstants.leavePolicyDetail('earned'));
      expect(put.body['long_leave_min_days'], 7);
      expect(put.body['long_leave_notice_days'], 21);
      // Unrelated settings go back exactly as loaded.
      expect(put.body['minimum_notice_period'], 2);
      expect(put.body['maximum_leave_duration'], 10);
      expect(put.body['sandwich_leave_enabled'], isTrue);
      expect(put.body['applicable_gender'], 'female');
      expect(put.body['medical_certificate_after_days'], 4);
      expect(put.body['policy_note'], 'Synthetic note');
      expect(find.text('Leave policy updated.'), findsOneWidget);
    });

    testWidgets('0 turns the rule off and is sent as 0; blank is sent as 0; only digits can be typed', (tester) async {
      await pump(tester);
      await showRules(tester);
      await enter(tester, minField, '0');
      await enter(tester, noticeField, '');
      await save(tester);
      expect(server.puts.single.body['long_leave_min_days'], 0);
      expect(server.puts.single.body['long_leave_notice_days'], 0);
      await enter(tester, minField, '-3.5x');
      expect(fieldText(tester, minField), isNot(contains('-')));
      expect(fieldText(tester, minField), isNot(contains('.')));
    });

    testWidgets('a server validation error is shown and the typed values stay', (tester) async {
      await pump(tester);
      server.refuseNext = (status: 400, message: 'Ensure this value is greater than or equal to 0.');
      await showRules(tester);
      await enter(tester, minField, '6');
      await save(tester);
      expect(find.text('Ensure this value is greater than or equal to 0.'), findsOneWidget);
      expect(fieldText(tester, minField), '6');
    });

    testWidgets('one save at a time', (tester) async {
      await pump(tester);
      server.hold = Completer();
      await showRules(tester);
      await enter(tester, minField, '8');
      final b = find.widgetWithText(FilledButton, 'Save Policy');
      await tester.ensureVisible(b);
      await tester.tap(b);
      await tester.pump();
      await tester.tap(find.byType(FilledButton).last, warnIfMissed: false);
      await tester.pump();
      server.hold!.complete();
      await tester.pumpAndSettle();
      expect(server.puts, hasLength(1));
    });
  });

  group('permissions', () {
    for (final perms in [
      ['settings.view', 'settings.edit'],
      ['settings.view', 'leave.approve'],
    ]) {
      testWidgets('${perms.last}: fields editable and Save shown', (tester) async {
        await pump(tester, perms: perms);
        await showRules(tester);
        expect(find.byKey(const Key('leave-rules-view-only')), findsNothing);
        expect(find.widgetWithText(FilledButton, 'Save Policy'), findsOneWidget);
        await enter(tester, minField, '9');
        expect(fieldText(tester, minField), '9');
      });
    }

    testWidgets('without settings.edit or leave.approve: values readable, locked, no Save, nothing sent',
        (tester) async {
      await pump(tester, perms: ['settings.view', 'leave.view']);
      await showRules(tester); // sections still expand for reading
      expect(find.byKey(const Key('leave-rules-view-only')), findsOneWidget);
      expect(fieldText(tester, minField), '5');
      expect(fieldText(tester, noticeField), '15');
      expect(find.widgetWithText(FilledButton, 'Save Policy'), findsNothing);
      await tester.tap(minField, warnIfMissed: false);
      await tester.enterText(minField, '99');
      await tester.pump();
      // enterText bypasses hit-testing; the lock is what stops a real tap.
      expect(
          tester
              .widgetList<IgnorePointer>(find.ancestor(of: minField, matching: find.byType(IgnorePointer)))
              .any((w) => w.ignoring),
          isTrue);
      expect(server.puts, isEmpty);
      // The type picker still works for reading other types.
      await selectType(tester, 'Casual Leave');
      await showRules(tester);
      expect(fieldText(tester, minField), '0');
    });
  });
}

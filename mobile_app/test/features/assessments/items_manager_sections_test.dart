import 'dart:async';
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
import 'package:mobile_app/features/assessments/data/models/assessment_model.dart';
import 'package:mobile_app/features/assessments/presentation/providers/assessments_providers.dart';
import 'package:mobile_app/features/assessments/presentation/widgets/item_form.dart';
import 'package:mobile_app/features/assessments/presentation/widgets/items_manager_dialog.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// P2: Assessment Admin → Items Manager sections, as web ItemsModal.tsx over
// production AssessmentSectionListCreateView / AssessmentSectionDetailView
// (GET assessments.view; POST / PUT / DELETE assessments.edit; delete moves the
// section's items to unsectioned) and AssessmentItem* views (`section` on the
// item payload). Stand-in server, synthetic assessment; nothing is sent anywhere.

const aid = '11111111-1111-4111-8111-111111111111';
const s1 = 'aaaaaaaa-0000-4000-8000-000000000001';
const s2 = 'aaaaaaaa-0000-4000-8000-000000000002';
final sectionsPath = ApiConstants.assessmentSections(aid);
String sectionPath(String id) => ApiConstants.assessmentSectionDetail(aid, id);
final itemsPath = ApiConstants.assessmentItems(aid);

Map<String, dynamic> section(String id, String title, int order, {int score = 10, int? count}) =>
    {'id': id, 'title': title, 'order': order, 'score': score, 'item_count': count ?? 0, 'created_at': null};

Map<String, dynamic> item(String id, String title, int order, {String? sectionId, bool omitSection = false}) => {
      'id': id,
      if (!omitSection) 'section_id': sectionId,
      'item_type': 'video',
      'title': title,
      'order': order,
      'video_url': 'https://youtu.be/abc',
      'duration_secs': 120,
      'question': '',
      'option_a': '',
      'option_b': '',
      'option_c': '',
      'option_d': '',
      'correct_option': '',
      'created_at': '2026-11-01T00:00:00Z',
    };

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> sections = [
    section(s2, 'Second: Policies and Compliance Fundamentals for New Joiners', 2, score: 40),
    section(s1, 'Technical Knowledge', 1, score: 30),
  ];
  List<Map<String, dynamic>> items = [
    item('i1', 'Intro video', 1, sectionId: s1),
    item('i2', 'Policy video', 2, sectionId: s2),
    item('i3', 'Loose video', 3),
  ];
  int sectionsStatus = 200;
  Completer<void>? holdGetSections;
  Completer<void>? holdWrite;
  ({int status, String message})? refuseNext;
  final calls = <({String method, String path, Object? body})>[];

  List<({String method, String path, Object? body})> of(String m, String p) =>
      calls.where((c) => c.method == m && c.path == p).toList();
  int get writes => calls.where((c) => c.method != 'GET').length;

  ResponseBody _json(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    if (o.method != 'GET') {
      if (holdWrite != null) await holdWrite!.future;
      final r = refuseNext;
      if (r != null) {
        refuseNext = null;
        return _json({'status': 'error', 'message': r.message}, r.status);
      }
    }
    if (o.path == sectionsPath && o.method == 'GET') {
      if (holdGetSections != null) await holdGetSections!.future;
      if (sectionsStatus != 200) return _json({'status': 'error', 'message': 'Permission denied.'}, sectionsStatus);
      return _json({'status': 'success', 'data': sections});
    }
    if (o.path == sectionsPath && o.method == 'POST') {
      final b = Map<String, dynamic>.from(o.data as Map);
      final created = section(
          'aaaaaaaa-0000-4000-8000-00000000000${sections.length + 1}', b['title'] as String, b['order'] as int,
          score: b['score'] as int);
      sections = [...sections, created];
      return _json({'status': 'success', 'message': 'Section created.', 'data': created}, 201);
    }
    if (o.path.startsWith(sectionsPath) && o.method == 'PUT') {
      final id = o.path.split('/').where((p) => p.isNotEmpty).last;
      final b = Map<String, dynamic>.from(o.data as Map);
      sections = [
        for (final s in sections) s['id'] == id ? {...s, ...b} : s
      ];
      return _json(
          {'status': 'success', 'message': 'Section updated.', 'data': sections.firstWhere((s) => s['id'] == id)});
    }
    if (o.path.startsWith(sectionsPath) && o.method == 'DELETE') {
      final id = o.path.split('/').where((p) => p.isNotEmpty).last;
      sections = sections.where((s) => s['id'] != id).toList();
      items = [
        for (final i in items) i['section_id'] == id ? {...i, 'section_id': null} : i
      ];
      return _json({'status': 'success', 'message': 'Section deleted. Items moved to unsectioned.', 'data': null});
    }
    if (o.path == itemsPath && o.method == 'GET') return _json({'status': 'success', 'data': items});
    if (o.path == itemsPath && o.method == 'POST') {
      final b = Map<String, dynamic>.from(o.data as Map);
      final created = {...item('i9', b['title'] as String, b['order'] as int), 'section_id': b['section']};
      items = [...items, created];
      return _json({'status': 'success', 'data': created}, 201);
    }
    if (o.path.startsWith('/assessments/items/') && o.method == 'PUT') {
      final id = o.path.split('/').where((p) => p.isNotEmpty).last;
      final b = Map<String, dynamic>.from(o.data as Map);
      final cur = items.firstWhere((i) => i['id'] == id);
      final updated = {...cur, 'title': b['title'], if (b.containsKey('section')) 'section_id': b['section']};
      items = [for (final i in items) i['id'] == id ? updated : i];
      return _json({'status': 'success', 'data': updated});
    }
    if (o.path.startsWith('/assessments/items/') && o.method == 'DELETE') {
      final id = o.path.split('/').where((p) => p.isNotEmpty).last;
      items = items.where((i) => i['id'] != id).toList();
      return _json({'status': 'success', 'data': null});
    }
    return _json({'status': 'success', 'data': []});
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

final editor = user(['assessments.view', 'assessments.edit']);
final viewer = user(['assessments.view']);
final assessment = AssessmentModel.fromJson(const {'id': aid, 'title': 'Synthetic Onboarding Assessment'});

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pump(WidgetTester tester, {UserEntity? as, void Function(Server)? setup, bool settle = true}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  setup?.call(server);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides(as ?? editor),
    child: MaterialApp(
      home: Scaffold(
        body: Consumer(
          builder: (context, ref, _) => ref.watch(authStateProvider).valueOrNull?.user == null
              ? const SizedBox()
              : Center(child: ItemsManagerDialog(assessment: assessment)),
        ),
      ),
    ),
  ));
  if (settle) await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.ensureVisible(byKey(k));
  await tester.tap(byKey(k));
  await tester.pumpAndSettle();
}

Future<void> fillSection(WidgetTester tester, {String? title, String? order, String? score}) async {
  if (title != null) await tester.enterText(byKey('section-title'), title);
  if (order != null) await tester.enterText(byKey('section-order'), order);
  if (score != null) await tester.enterText(byKey('section-score'), score);
  await tester.pump();
}

String ctrlText(WidgetTester tester, String key) => tester.widget<TextField>(byKey(key)).controller!.text;

Finder inSection(String id, Finder f) => find.descendant(of: byKey('section-$id'), matching: f);

Future<void> addVideoItem(WidgetTester tester, String title) async {
  final form = find.byType(ItemForm);
  await tester.enterText(find.descendant(of: form, matching: find.widgetWithText(TextFormField, 'Title *')), title);
  await tester.enterText(
      find.descendant(of: form, matching: find.widgetWithText(TextFormField, 'Video URL *')), 'https://youtu.be/x');
  final submit = find.descendant(of: form, matching: find.text('Add Item')).last;
  await tester.ensureVisible(submit);
  await tester.tap(submit);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('models', () {
    test('section parsing (numbers or strings; item_count optional)', () {
      final s = AssessmentSectionModel.fromJson(section(s1, 'Tech', 2, score: 30, count: 4));
      expect([s.id, s.title, s.order, s.score, s.itemCount], [s1, 'Tech', 2, 30, 4]);
      final loose = AssessmentSectionModel.fromJson(const {'id': s2, 'title': 'X', 'order': '3', 'score': '15'});
      expect([loose.order, loose.score, loose.itemCount], [3, 15, null]);
    });

    test('section form = web: trimmed title, Number(order)||1, Number(score)||0; defaults order = count+1, score 0',
        () {
      final add = AssessmentSectionFormData.add(2);
      expect([add.title, add.order, add.score], ['', '3', '0']);
      expect(AssessmentSectionFormData(title: '  Tech  ', order: '4', score: '40').toJson(),
          {'title': 'Tech', 'order': 4, 'score': 40});
      expect(
          AssessmentSectionFormData(title: 'T', order: '', score: '').toJson(), {'title': 'T', 'order': 1, 'score': 0});
      expect(AssessmentSectionFormData(title: 'T', order: '0', score: 'x').toJson(),
          {'title': 'T', 'order': 1, 'score': 0});
      expect(AssessmentSectionFormData(title: '   ').validate(), 'Title is required.');
      expect(AssessmentSectionFormData(title: 'T').validate(), isNull);
    });

    test('items read section_id (or section); the form sends section exactly when web would', () {
      final m = AssessmentItemModel.fromJson(item('i1', 'A', 1, sectionId: s1));
      expect([m.sectionId, m.sectionKnown], [s1, true]);
      final unsec = AssessmentItemModel.fromJson(item('i2', 'B', 1));
      expect([unsec.sectionId, unsec.sectionKnown], [null, true]);
      final legacy = AssessmentItemModel.fromJson({...item('i3', 'C', 1), 'section': s2}..remove('section_id'));
      expect(legacy.sectionId, s2);
      final unknown = AssessmentItemModel.fromJson(item('i4', 'D', 1, omitSection: true));
      expect([unknown.sectionId, unknown.sectionKnown], [null, false]);
      // Edit keeps the item's own section; an unknown section is never sent (so never cleared).
      expect(AssessmentItemFormData.fromModel(m).toJson()['section'], s1);
      expect(AssessmentItemFormData.fromModel(unsec).toJson().containsKey('section'), isTrue);
      expect(AssessmentItemFormData.fromModel(unsec).toJson()['section'], isNull);
      expect(AssessmentItemFormData.fromModel(unknown).toJson().containsKey('section'), isFalse);
      // A plain new form (the dialog always sets it) sends nothing extra.
      expect(AssessmentItemFormData().toJson().containsKey('section'), isFalse);
    });

    test('permission rule = production views: assessments.edit (or superuser)', () {
      expect(canEditAssessments(editor), isTrue);
      expect(canEditAssessments(viewer), isFalse);
      expect(canEditAssessments(user([], superuser: true)), isTrue);
      expect(canEditAssessments(null), isFalse);
    });

    test('section and item writes are refused before any request without assessments.edit', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(viewer));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      await c.read(assessmentSectionsProvider(aid).future);
      await c.read(assessmentItemsProvider(aid).future);
      final sec = c.read(assessmentSectionsProvider(aid).notifier);
      final items = c.read(assessmentItemsProvider(aid).notifier);
      expect(await sec.createSection(AssessmentSectionFormData(title: 'X')), 'Permission denied.');
      expect(await sec.editSection(s1, AssessmentSectionFormData(title: 'X')), 'Permission denied.');
      expect(await sec.removeSection(s1), 'Permission denied.');
      expect(await items.createItem(AssessmentItemFormData(title: 'X', videoUrl: 'https://x')), 'Permission denied.');
      expect(await items.editItem('i1', AssessmentItemFormData(title: 'X')), 'Permission denied.');
      expect(await items.removeItem('i1'), 'Permission denied.');
      expect(server.writes, 0);
    });

    test('one section write at a time', () async {
      server = Server()..holdWrite = Completer();
      final c = ProviderContainer(overrides: overrides(editor));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      await c.read(assessmentSectionsProvider(aid).future);
      final n = c.read(assessmentSectionsProvider(aid).notifier);
      final first = n.createSection(AssessmentSectionFormData(title: 'A'));
      await Future<void>.delayed(Duration.zero);
      expect(await n.removeSection(s1), isNotNull);
      server.holdWrite!.complete();
      expect(await first, isNull);
      expect(server.writes, 1);
    });
  });

  group('listing', () {
    testWidgets('sections in order with "<score> marks · <n> items", their items, and the unsectioned group',
        (tester) async {
      await pump(tester);
      expect(server.of('GET', sectionsPath), hasLength(1));
      expect(server.of('GET', itemsPath), hasLength(1));
      expect(find.text('Sections'), findsOneWidget);
      expect(find.text('Synthetic Onboarding Assessment'), findsOneWidget);
      // Order 1 first, numbered 1 and 2, regardless of response order.
      expect(tester.getTopLeft(byKey('section-$s1')).dy, lessThan(tester.getTopLeft(byKey('section-$s2')).dy));
      expect(inSection(s1, find.text('1')), findsOneWidget);
      expect(tester.widget<Text>(byKey('section-meta-$s1')).data, '30 marks · 1 item');
      expect(inSection(s1, find.textContaining('Intro video')), findsOneWidget);
      expect(inSection(s2, find.textContaining('Policy video')), findsOneWidget);
      // A long title is shown (wrapped), not lost.
      expect(find.text('Second: Policies and Compliance Fundamentals for New Joiners'), findsOneWidget);
      expect(find.text('Items not assigned to any section'), findsOneWidget);
      expect(find.descendant(of: byKey('unsectioned-group'), matching: find.textContaining('Loose video')),
          findsOneWidget);
      expect(byKey('unsectioned-add-item'), findsOneWidget);
    });

    testWidgets('no sections: unsectioned items are listed under "Items"', (tester) async {
      await pump(tester, setup: (s) => s.sections = []);
      expect(find.text('Items'), findsOneWidget);
      expect(find.text('Items not assigned to any section'), findsNothing);
    });

    testWidgets('empty: "No sections or items yet…" and only Add Section', (tester) async {
      await pump(tester, setup: (s) {
        s.sections = [];
        s.items = [];
      });
      expect(byKey('items-empty'), findsOneWidget);
      expect(byKey('section-add'), findsOneWidget);
      expect(byKey('unsectioned-add-item'), findsNothing);
    });

    testWidgets('loading, then a failed load with Retry', (tester) async {
      final gate = Completer<void>();
      await pump(tester, settle: false, setup: (s) => s.holdGetSections = gate);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(byKey('items-loading'), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(byKey('items-loading'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await pump(tester, setup: (s) => s.sectionsStatus = 500);
      expect(byKey('items-load-error'), findsOneWidget);
      server.sectionsStatus = 200;
      await tapKey(tester, 'items-retry');
      expect(byKey('section-$s1'), findsOneWidget);
    });
  });

  group('section actions', () {
    testWidgets('Add Section: defaults (order = count + 1, score 0), POST web\'s payload, list refreshes',
        (tester) async {
      await pump(tester);
      await tapKey(tester, 'section-add');
      expect(find.text('Add Section'), findsWidgets);
      expect(ctrlText(tester, 'section-order'), '3');
      expect(ctrlText(tester, 'section-score'), '0');
      await fillSection(tester, title: '  Soft Skills  ', score: '20');
      final before = server.of('GET', sectionsPath).length;
      await tapKey(tester, 'section-save');
      expect(server.of('POST', sectionsPath).single.body, {'title': 'Soft Skills', 'order': 3, 'score': 20});
      expect(server.of('GET', sectionsPath).length, before + 1);
      expect(byKey('section-form'), findsNothing);
      expect(find.text('Soft Skills'), findsOneWidget);
    });

    testWidgets('Title is required (nothing sent); the server\'s refusal is shown in the form', (tester) async {
      await pump(tester);
      await tapKey(tester, 'section-add');
      await tapKey(tester, 'section-save');
      expect(find.text('Title is required.'), findsOneWidget);
      expect(server.writes, 0);
      server.refuseNext = (status: 400, message: 'Section score must be at least 1.');
      await fillSection(tester, title: 'Zero score');
      await tapKey(tester, 'section-save');
      expect(find.text('Section score must be at least 1.'), findsOneWidget);
      expect(byKey('section-form'), findsOneWidget);
    });

    testWidgets('Edit (and reorder via Order): PUT to the section with title/order/score', (tester) async {
      await pump(tester);
      await tapKey(tester, 'section-edit-$s1');
      expect(find.text('Edit Section'), findsOneWidget);
      expect(ctrlText(tester, 'section-title'), 'Technical Knowledge');
      await fillSection(tester, order: '5');
      await tapKey(tester, 'section-save');
      expect(server.of('PUT', sectionPath(s1)).single.body, {'title': 'Technical Knowledge', 'order': 5, 'score': 30});
      // Now ordered after the other section.
      expect(tester.getTopLeft(byKey('section-$s2')).dy, lessThan(tester.getTopLeft(byKey('section-$s1')).dy));
      expect(find.text('Update'), findsNothing);
    });

    testWidgets('Delete asks first; Cancel sends nothing; confirm DELETEs and its items become unsectioned',
        (tester) async {
      await pump(tester);
      await tapKey(tester, 'section-delete-$s1');
      expect(find.text('Delete this section? Items will become unsectioned.'), findsOneWidget);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(server.writes, 0);
      final itemGets = server.of('GET', itemsPath).length;
      await tapKey(tester, 'section-delete-$s1');
      await tapKey(tester, 'section-delete-confirm');
      expect(server.of('DELETE', sectionPath(s1)), hasLength(1));
      expect(server.of('GET', itemsPath).length, itemGets + 1); // web refetches items too
      expect(byKey('section-$s1'), findsNothing);
      expect(find.descendant(of: byKey('unsectioned-group'), matching: find.textContaining('Intro video')),
          findsOneWidget);
    });

    testWidgets('a failed delete is shown above the list', (tester) async {
      await pump(tester, setup: (s) => s.refuseNext = (status: 403, message: 'Permission denied.'));
      await tapKey(tester, 'section-delete-$s1');
      await tapKey(tester, 'section-delete-confirm');
      expect(find.descendant(of: byKey('items-list-error'), matching: find.text('Permission denied.')), findsOneWidget);
      expect(byKey('section-$s1'), findsOneWidget);
    });

    testWidgets('double-tapping Save sends one request; Saving… meanwhile', (tester) async {
      await pump(tester, setup: (s) => s.holdWrite = Completer());
      await tapKey(tester, 'section-add');
      await fillSection(tester, title: 'Once');
      await tester.tap(byKey('section-save'));
      await tester.pump();
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(byKey('section-save'), warnIfMissed: false);
      server.holdWrite!.complete();
      await tester.pumpAndSettle();
      expect(server.of('POST', sectionsPath), hasLength(1));
    });
  });

  group('items and sections', () {
    testWidgets('"Add Item" in a section sends that section; the item appears there', (tester) async {
      await pump(tester);
      await tapKey(tester, 'section-add-item-$s2');
      await addVideoItem(tester, 'New in second');
      final post = server.of('POST', itemsPath).single;
      expect((post.body as Map)['section'], s2);
      expect((post.body as Map)['order'], 4); // web: max order + 1
      expect(inSection(s2, find.textContaining('New in second')), findsOneWidget);
      expect(tester.widget<Text>(byKey('section-meta-$s2')).data, '40 marks · 2 items');
    });

    testWidgets('"Add Unsectioned Item" sends section null', (tester) async {
      await pump(tester);
      await tapKey(tester, 'unsectioned-add-item');
      await addVideoItem(tester, 'Another loose');
      final body = server.of('POST', itemsPath).single.body as Map;
      expect(body.containsKey('section'), isTrue);
      expect(body['section'], isNull);
    });

    testWidgets('editing an item keeps its section (existing question CRUD unchanged otherwise)', (tester) async {
      await pump(tester);
      await tapKey(tester, 'item-edit-i1');
      final form = find.byType(ItemForm);
      await tester.enterText(
          find.descendant(of: form, matching: find.widgetWithText(TextFormField, 'Title *')), 'Renamed');
      final submit = find.descendant(of: form, matching: find.text('Update Item'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final body = server.of('PUT', ApiConstants.assessmentItemDetail('i1')).single.body as Map;
      expect(body['section'], s1);
      expect(body['title'], 'Renamed');
      expect(body['item_type'], 'video');
      expect(inSection(s1, find.textContaining('Renamed')), findsOneWidget);
    });

    testWidgets('an item whose section the server never reported is edited without touching it', (tester) async {
      await pump(tester, setup: (s) => s.items = [item('i5', 'Old shape', 1, omitSection: true)]);
      await tapKey(tester, 'item-edit-i5');
      final form = find.byType(ItemForm);
      final submit = find.descendant(of: form, matching: find.text('Update Item'));
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      final body = server.of('PUT', ApiConstants.assessmentItemDetail('i5')).single.body as Map;
      expect(body.containsKey('section'), isFalse);
    });

    testWidgets('deleting an item still works (existing behaviour)', (tester) async {
      await pump(tester);
      await tapKey(tester, 'item-delete-i3');
      await tester.tap(find.text('Remove'));
      await tester.pumpAndSettle();
      expect(server.of('DELETE', ApiConstants.assessmentItemDetail('i3')), hasLength(1));
      // It was the only unsectioned item, so that group is gone; the existing snackbar confirms.
      expect(byKey('unsectioned-group'), findsNothing);
      expect(find.text('"Loose video" removed.'), findsOneWidget);
    });
  });

  group('permissions', () {
    testWidgets('assessments.view only: everything readable; no Add Section, section or item actions', (tester) async {
      await pump(tester, as: viewer);
      expect(byKey('section-$s1'), findsOneWidget);
      expect(find.textContaining('Intro video'), findsOneWidget);
      for (final k in [
        'section-add',
        'section-edit-$s1',
        'section-delete-$s1',
        'section-add-item-$s1',
        'unsectioned-add-item',
        'item-edit-i1',
        'item-delete-i1',
      ]) {
        expect(byKey(k), findsNothing, reason: k);
      }
      expect(find.text('Done'), findsOneWidget);
      expect(server.writes, 0);
    });
  });
}

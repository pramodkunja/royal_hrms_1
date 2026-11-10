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
import 'package:mobile_app/features/assessments/presentation/widgets/item_row.dart';
import 'package:mobile_app/features/assessments/presentation/widgets/items_manager_dialog.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 25: assessment item save bodies = web ItemsModal saveItem, exactly.
//   base  = { item_type, title.trim(), order: Number(order) || 1, section: forSectionId }
//   video = { ...base, video_url: trim, duration_secs: duration ? Number : null }
//   quiz  = { ...base, question, option_a..d (trimmed), correct_option }
// POST /assessments/<id>/items/ (create) and PUT /assessments/items/<id>/
// (update) send the same body. No pass_score (the backend's
// AssessmentItemCreateSerializer has no such field), no empty fields of the
// other type. `section` is absent (JSON drops undefined) only when editing an
// item whose section the server never reported. Stand-in server only.

const aid = '11111111-1111-4111-8111-111111111111';
const s1 = 'aaaaaaaa-0000-4000-8000-000000000001';
final itemsPath = ApiConstants.assessmentItems(aid);

Map<String, dynamic> videoItem(String id, int order, {String? sectionId, bool omitSection = false}) => {
      'id': id,
      if (!omitSection) 'section_id': sectionId,
      'item_type': 'video',
      'title': 'Intro video',
      'order': order,
      'video_url': 'https://youtu.be/abc123',
      'duration_secs': 120,
      'question': '',
      'option_a': '',
      'option_b': '',
      'option_c': '',
      'option_d': '',
      'correct_option': '',
      'created_at': '2026-11-01T00:00:00Z',
    };

Map<String, dynamic> quizItem(String id, int order, {String? sectionId}) => {
      'id': id,
      'section_id': sectionId,
      'item_type': 'quiz',
      'title': 'Notice period',
      'order': order,
      'video_url': '',
      'duration_secs': null,
      'question': 'How long is the notice period?',
      'option_a': '30 days',
      'option_b': '60 days',
      'option_c': '90 days',
      'option_d': '',
      'correct_option': 'b',
      'created_at': '2026-11-01T00:00:00Z',
    };

Map<String, dynamic> sectionJson(String id, String title) =>
    {'id': id, 'title': title, 'order': 1, 'score': 10, 'item_count': 1, 'created_at': null};

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> items = [
    videoItem('v1', 1),
    quizItem('q1', 2, sectionId: s1),
    videoItem('v9', 3, omitSection: true),
  ];
  final writes = <({String method, String path, Map<String, dynamic> body})>[];

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      // The raw JSON actually sent — keys with null values included.
      final body = jsonDecode(jsonEncode(o.data)) as Map<String, dynamic>;
      writes.add((method: o.method, path: o.path, body: body));
      return _json({'status': 'success', 'data': {...videoItem('new', 9), ...body, 'id': 'new'}}, 201);
    }
    if (o.path == itemsPath) return _json({'status': 'success', 'data': items});
    if (o.path == ApiConstants.assessmentSections(aid)) {
      return _json({'status': 'success', 'data': [sectionJson(s1, 'Policies')]});
    }
    return _json({'status': 'success', 'data': <Object>[]});
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
      email: 'hr@example.test',
      fullName: 'Test HR',
      role: 'hr',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

final editor = user(const ['assessments.view', 'assessments.edit']);
final viewer = user(const ['assessments.view']);
final assessment = AssessmentModel.fromJson(const {'id': aid, 'title': 'Synthetic Assessment'});

late Server server;

List<Override> overrides(UserEntity u) => [
      authStateProvider.overrideWith(() => _Auth(u)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
    ];

Future<void> pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: overrides(editor),
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
  await tester.pumpAndSettle();
}

Finder byKey(String k) => find.byKey(Key(k));
Finder get form => find.byType(ItemForm);
Finder field(String label) => find.descendant(of: form, matching: find.widgetWithText(TextFormField, label));
Finder dropdown(String label) =>
    find.descendant(of: form, matching: find.widgetWithText(DropdownButtonFormField<String>, label));

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.ensureVisible(byKey(k));
  await tester.tap(byKey(k));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, Finder dd, String label) async {
  await tester.ensureVisible(dd);
  await tester.tap(dd);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> type(WidgetTester tester, Finder f, String text) async {
  await tester.ensureVisible(f);
  await tester.enterText(f, text);
  await tester.pump();
}

Future<void> submit(WidgetTester tester, String label) async {
  final b = find.descendant(of: form, matching: find.text(label)).last;
  await tester.ensureVisible(b);
  await tester.tap(b);
  await tester.pumpAndSettle();
}

const quizKeys = {
  'section', 'item_type', 'title', 'order', 'question', 'option_a', 'option_b', 'option_c', 'option_d', 'correct_option', //
};
const videoKeys = {'section', 'item_type', 'title', 'order', 'video_url', 'duration_secs'};

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('the four web bodies, captured from the editor', () {
    testWidgets('1. video create', (tester) async {
      await pump(tester);
      await tapKey(tester, 'unsectioned-add-item');
      await choose(tester, dropdown('Type *'), 'Video');
      await type(tester, field('Title *'), '  Welcome  ');
      await type(tester, byKey('item-video-url'), '  https://youtu.be/abc123  ');
      await type(tester, field('Duration (seconds)'), '90');
      await submit(tester, 'Add Item');
      final w = server.writes.single;
      expect([w.method, w.path], ['POST', itemsPath]);
      expect(w.body, {
        'section': null,
        'item_type': 'video',
        'title': 'Welcome',
        'order': 4,
        'video_url': 'https://youtu.be/abc123',
        'duration_secs': 90,
      });
      expect(w.body['order'], isA<int>());
      expect(w.body['duration_secs'], isA<int>());
    });

    testWidgets('2. video update (empty duration → null; section kept)', (tester) async {
      await pump(tester);
      await tapKey(tester, 'item-edit-v1');
      await type(tester, field('Title *'), 'Intro video v2');
      await type(tester, field('Duration (seconds)'), '');
      await submit(tester, 'Update Item');
      final w = server.writes.single;
      expect([w.method, w.path], ['PUT', ApiConstants.assessmentItemDetail('v1')]);
      expect(w.body, {
        'section': null,
        'item_type': 'video',
        'title': 'Intro video v2',
        'order': 1,
        'video_url': 'https://youtu.be/abc123',
        'duration_secs': null,
      });
      expect(w.body.containsKey('duration_secs'), isTrue, reason: 'web sends null, not omitted');
    });

    testWidgets('3. quiz create', (tester) async {
      await pump(tester);
      await tapKey(tester, 'section-add-item-$s1');
      await choose(tester, dropdown('Type *'), 'Quiz');
      await type(tester, field('Title *'), 'Leave policy');
      await type(tester, field('Question *'), '  How many casual leaves?  ');
      await type(tester, field('Option A *'), ' 8 ');
      await type(tester, field('Option B *'), '12');
      await type(tester, field('Option C'), '15');
      await choose(tester, dropdown('Correct Option *'), 'Option B');
      await submit(tester, 'Add Item');
      final w = server.writes.single;
      expect([w.method, w.path], ['POST', itemsPath]);
      expect(w.body, {
        'section': s1,
        'item_type': 'quiz',
        'title': 'Leave policy',
        'order': 4,
        'question': 'How many casual leaves?',
        'option_a': '8',
        'option_b': '12',
        'option_c': '15',
        'option_d': '',
        'correct_option': 'b',
      });
    });

    testWidgets('4. quiz update', (tester) async {
      await pump(tester);
      await tapKey(tester, 'item-edit-q1');
      await type(tester, field('Question *'), 'What is the notice period?');
      await submit(tester, 'Update Item');
      final w = server.writes.single;
      expect([w.method, w.path], ['PUT', ApiConstants.assessmentItemDetail('q1')]);
      expect(w.body, {
        'section': s1,
        'item_type': 'quiz',
        'title': 'Notice period',
        'order': 2,
        'question': 'What is the notice period?',
        'option_a': '30 days',
        'option_b': '60 days',
        'option_c': '90 days',
        'option_d': '',
        'correct_option': 'b',
      });
    });

    testWidgets('True / False goes through the ordinary quiz fields', (tester) async {
      await pump(tester);
      await tapKey(tester, 'unsectioned-add-item');
      await choose(tester, dropdown('Type *'), 'Quiz');
      await type(tester, field('Title *'), 'TF');
      await type(tester, field('Question *'), 'Is attendance mandatory?');
      await choose(tester, dropdown('Question Type *'), 'True / False');
      await submit(tester, 'Add Item');
      final b = server.writes.single.body;
      expect(b.keys.toSet(), quizKeys);
      expect([b['option_a'], b['option_b'], b['option_c'], b['option_d'], b['correct_option']],
          ['True', 'False', '', '', 'a']);
    });

    testWidgets('editing an item whose section was never reported sends no section key', (tester) async {
      await pump(tester);
      await tapKey(tester, 'item-edit-v9');
      await submit(tester, 'Update Item');
      expect(server.writes.single.body.containsKey('section'), isFalse);
      expect(server.writes.single.body.keys.toSet(), videoKeys.difference({'section'}));
    });
  });

  group('Task 27: no Points / Order inputs; order set as web does', () {
    testWidgets('the item form has no Points and no Order field (web has neither)', (tester) async {
      await pump(tester);
      await tapKey(tester, 'unsectioned-add-item');
      await choose(tester, dropdown('Type *'), 'Quiz');
      expect(field('Points'), findsNothing);
      expect(field('Order'), findsNothing);
      expect(find.descendant(of: form, matching: find.text('Points')), findsNothing);
      expect(find.descendant(of: form, matching: find.text('Order')), findsNothing);
    });

    testWidgets('add: order = highest existing order + 1, an int (web openAddItem)', (tester) async {
      await pump(tester);
      await tapKey(tester, 'unsectioned-add-item');
      await type(tester, field('Title *'), 'V');
      await type(tester, byKey('item-video-url'), 'https://youtu.be/x');
      await submit(tester, 'Add Item');
      expect(server.writes.single.body['order'], 4);
      expect(server.writes.single.body['order'], isA<int>());
    });

    testWidgets('edit: the item keeps its own order', (tester) async {
      await pump(tester);
      await tapKey(tester, 'item-edit-q1');
      await submit(tester, 'Update Item');
      expect(server.writes.single.body['order'], 2);
    });

    testWidgets('rows show web\'s quiz line (question · Correct: X), never points', (tester) async {
      await pump(tester);
      expect(find.text('How long is the notice period? · Correct: B'), findsOneWidget);
      expect(find.textContaining('pt'), findsNothing);
      expect(find.textContaining('Quiz ·'), findsNothing);
    });
  });

  testWidgets('row line: question cut at 60 + "…", "—" when no correct option (web)', (tester) async {
    final long = 'Q' * 70;
    final model = AssessmentItemModel.fromJson({...quizItem('x', 1), 'question': long, 'correct_option': ''});
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: ItemRow(item: model, deleting: false)),
    ));
    expect(find.text('${'Q' * 60}… · Correct: —'), findsOneWidget);
  });

  group('serialization rules (model)', () {
    AssessmentItemFormData quizForm({int order = 1}) => AssessmentItemFormData(
          itemType: AssessmentItemType.quiz,
          order: order,
          title: 'Q',
          question: 'Q?',
          optionA: 'A',
          optionB: 'B',
          sendSection: true,
        );

    test('a video body has only video keys; a quiz body only quiz keys; never pass_score', () {
      final v = AssessmentItemFormData(title: 'V', videoUrl: 'https://youtu.be/x', durationSecs: 60, sendSection: true)
          .toJson();
      expect(v.keys.toSet(), videoKeys);
      final q = quizForm().toJson();
      expect(q.keys.toSet(), quizKeys);
      for (final body in [v, q]) {
        expect(body.containsKey('pass_score'), isFalse);
      }
      for (final k in ['question', 'option_a', 'option_b', 'option_c', 'option_d', 'correct_option']) {
        expect(v.containsKey(k), isFalse, reason: 'video body has no $k');
      }
      for (final k in ['video_url', 'duration_secs']) {
        expect(q.containsKey(k), isFalse, reason: 'quiz body has no $k');
      }
    });

    test('order follows web Number(order) || 1 (always a whole number now: web and mobile set it automatically)', () {
      expect(quizForm(order: 0).toJson()['order'], 1);
      expect(quizForm(order: 3).toJson()['order'], 3);
      expect(quizForm(order: -2).toJson()['order'], -2, reason: 'web sends it; the server rejects it');
    });

    test('section: null for an unsectioned add, absent when not to be sent', () {
      expect(AssessmentItemFormData(title: 'V', videoUrl: 'https://x.test/a.mp4', sendSection: true).toJson()['section'],
          isNull);
      expect(AssessmentItemFormData(title: 'V', videoUrl: 'https://x.test/a.mp4').toJson().containsKey('section'), isFalse);
    });

    test('the one deliberate difference: a scheme-less video link gets https://', () {
      expect(AssessmentItemFormData(title: 'V', videoUrl: ' youtu.be/x ').toJson()['video_url'], 'https://youtu.be/x');
    });
  });

  group('permissions', () {
    test('without assessments.edit nothing is sent', () async {
      server = Server();
      final c = ProviderContainer(overrides: overrides(viewer));
      addTearDown(c.dispose);
      await c.read(authStateProvider.future);
      c.listen(assessmentItemsProvider(aid), (_, __) {});
      await c.read(assessmentItemsProvider(aid).future);
      final n = c.read(assessmentItemsProvider(aid).notifier);
      final form = AssessmentItemFormData(title: 'V', videoUrl: 'https://youtu.be/x', sendSection: true);
      expect(await n.createItem(form), kAssessmentEditDenied);
      expect(await n.editItem('v1', form), kAssessmentEditDenied);
      expect(server.writes, isEmpty);
    });
  });
}

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
import 'package:mobile_app/features/assessments/presentation/widgets/assessment_video_preview.dart';
import 'package:mobile_app/features/assessments/presentation/widgets/item_form.dart';
import 'package:mobile_app/features/assessments/presentation/widgets/items_manager_dialog.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/controllers/auth_notifier.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/auth/presentation/states/auth_state.dart';

// Task 24 (audit F-AC02): web assessments/_components/ItemsModal.tsx
//  - True / False helper: "Question Type" (Multiple Choice / True / False) for
//    quiz items; True/False sets A "True", B "False", clears C/D, a C/D answer
//    falls back to A; A/B read-only, C/D hidden, answer labels True/False; an
//    item whose A/B are true/false (any case) with no C reopens as True/False;
//    changing the item type resets to Multiple Choice. Payload unchanged.
//  - Video: toEmbedUrl (youtu.be/ID, ?v=ID, vimeo.com/N) → embedded player,
//    else <video>; rows show VideoLink ("Watch video" / URL cut at 48 + "…").
//    Mobile (no web-view/video plugin): a preview card whose Play opens the
//    video outside the app.
// Stand-in server; nothing is created or changed anywhere.

const aid = '11111111-1111-4111-8111-111111111111';
final itemsPath = ApiConstants.assessmentItems(aid);

Map<String, dynamic> quiz(String id, String title, int order,
        {String a = 'Yes', String b = 'No', String c = 'Maybe', String d = '', String correct = 'a'}) =>
    {
      'id': id,
      'section_id': null,
      'item_type': 'quiz',
      'title': title,
      'order': order,
      'video_url': '',
      'duration_secs': null,
      'question': 'Q for $title?',
      'option_a': a,
      'option_b': b,
      'option_c': c,
      'option_d': d,
      'correct_option': correct,
      'pass_score': 1,
      'created_at': '2026-11-01T00:00:00Z',
    };

Map<String, dynamic> video(String id, String title, int order, String url) => {
      'id': id,
      'section_id': null,
      'item_type': 'video',
      'title': title,
      'order': order,
      'video_url': url,
      'duration_secs': 120,
      'question': '',
      'option_a': '',
      'option_b': '',
      'option_c': '',
      'option_d': '',
      'correct_option': '',
      'created_at': '2026-11-01T00:00:00Z',
    };

const longUrl = 'https://cdn.example.test/media/onboarding/2026/welcome-to-the-company-intro.mp4';

class Server implements HttpClientAdapter {
  List<Map<String, dynamic>> items = [
    quiz('tf1', 'Is the sky blue', 1, a: 'TRUE', b: 'false', c: '', correct: 'b'),
    quiz('mc1', 'Notice period', 2),
    video('v1', 'Intro video', 3, 'https://youtu.be/abc123'),
    video('v2', 'Welcome file', 4, longUrl),
  ];
  final writes = <({String method, String path, Map<String, dynamic> body})>[];

  ResponseBody _json(Object b, [int status = 200]) => ResponseBody.fromString(jsonEncode(b), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    if (o.method != 'GET') {
      final body = Map<String, dynamic>.from(o.data as Map);
      writes.add((method: o.method, path: o.path, body: body));
      return _json({'status': 'success', 'data': {...quiz('new', '${body['title']}', 9), ...body, 'id': 'new'}}, 201);
    }
    if (o.path == itemsPath) return _json({'status': 'success', 'data': items});
    return _json({'status': 'success', 'data': <Object>[]}); // sections
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
final opened = <Uri>[];
bool openerResult = true;

Future<void> pump(WidgetTester tester, {UserEntity? as}) async {
  tester.view.physicalSize = const Size(800, 3600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  server = Server();
  opened.clear();
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      authStateProvider.overrideWith(() => _Auth(as ?? editor)),
      dioProvider.overrideWithValue(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = server),
      cookieJarProvider.overrideWithValue(CookieJar()),
      secureStorageProvider.overrideWithValue(_NullStorage()),
      assessmentVideoOpenerProvider.overrideWithValue((uri) async {
        opened.add(uri);
        return openerResult;
      }),
    ],
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
String text(WidgetTester tester, String key) => tester.widget<TextField>(find.descendant(of: byKey(key), matching: find.byType(TextField))).controller!.text;
bool readOnly(WidgetTester tester, String key) =>
    tester.widget<TextField>(find.descendant(of: byKey(key), matching: find.byType(TextField))).readOnly;

Future<void> tapKey(WidgetTester tester, String k) async {
  await tester.ensureVisible(byKey(k));
  await tester.tap(byKey(k));
  await tester.pumpAndSettle();
}

Future<void> choose(WidgetTester tester, Finder dropdown, String label) async {
  await tester.ensureVisible(dropdown);
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Finder dropdownLabelled(String label) =>
    find.descendant(of: form, matching: find.widgetWithText(DropdownButtonFormField<String>, label));

Future<void> openAddQuiz(WidgetTester tester) async {
  await tapKey(tester, 'unsectioned-add-item');
  await choose(tester, dropdownLabelled('Type *'), 'Quiz');
}

Future<void> submit(WidgetTester tester, String label) async {
  final b = find.descendant(of: form, matching: find.text(label)).last;
  await tester.ensureVisible(b);
  await tester.tap(b);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => openerResult = true);

  group('True / False rules (web openEditItem / changeQuestionType)', () {
    test('detection: true/false in A/B (any case) and no C', () {
      bool tf(String a, String b, String c, {String type = 'quiz'}) =>
          isTrueFalseQuestion(itemType: type, optionA: a, optionB: b, optionC: c);
      expect(tf('True', 'False', ''), isTrue);
      expect(tf('TRUE', 'false', ''), isTrue);
      expect(tf('True', 'False', 'Maybe'), isFalse);
      expect(tf('False', 'True', ''), isFalse);
      expect(tf('Yes', 'No', ''), isFalse);
      expect(tf('True', 'False', '', type: 'video'), isFalse);
    });

    test('applying it: A True, B False, C/D cleared; a C/D answer falls back to A', () {
      final c = [for (final v in ['x', 'y', 'z', 'w']) TextEditingController(text: v)];
      expect(applyTrueFalse(a: c[0], b: c[1], c: c[2], d: c[3], correctOption: 'd'), 'a');
      expect(c.map((e) => e.text), ['True', 'False', '', '']);
      expect(applyTrueFalse(a: c[0], b: c[1], c: c[2], d: c[3], correctOption: 'b'), 'b');
    });
  });

  group('True / False helper in the item form', () {
    testWidgets('a new quiz starts as Multiple Choice with A–D editable', (tester) async {
      await pump(tester);
      await openAddQuiz(tester);
      expect(find.descendant(of: form, matching: find.text('Multiple Choice')), findsOneWidget);
      expect(byKey('item-option-c'), findsOneWidget);
      expect(byKey('item-option-d'), findsOneWidget);
      expect(readOnly(tester, 'item-option-a'), isFalse);
    });

    testWidgets('choosing True / False fills and locks A/B, hides C/D, labels the answer; saves as plain options',
        (tester) async {
      await pump(tester);
      await openAddQuiz(tester);
      await tester.enterText(field('Title *'), 'Policy check');
      await tester.enterText(field('Question *'), 'Is the policy mandatory?');
      await choose(tester, dropdownLabelled('Question Type *'), 'True / False');
      expect([text(tester, 'item-option-a'), text(tester, 'item-option-b')], ['True', 'False']);
      expect([readOnly(tester, 'item-option-a'), readOnly(tester, 'item-option-b')], [true, true]);
      expect(byKey('item-option-c'), findsNothing);
      expect(byKey('item-option-d'), findsNothing);
      await choose(tester, dropdownLabelled('Correct Option *'), 'False');
      await submit(tester, 'Add Item');
      final w = server.writes.single;
      expect([w.method, w.path], ['POST', itemsPath]);
      expect(w.body['item_type'], 'quiz');
      expect([w.body['option_a'], w.body['option_b'], w.body['option_c'], w.body['option_d'], w.body['correct_option']],
          ['True', 'False', '', '', 'b']);
      expect(w.body.containsKey('question_type'), isFalse, reason: 'UI helper only — no new API field');
    });

    testWidgets('an answer of C becomes A when switching to True / False', (tester) async {
      await pump(tester);
      await openAddQuiz(tester);
      await choose(tester, dropdownLabelled('Correct Option *'), 'Option C');
      await choose(tester, dropdownLabelled('Question Type *'), 'True / False');
      expect(find.descendant(of: dropdownLabelled('Correct Option *'), matching: find.text('True')), findsOneWidget);
    });

    testWidgets('back to Multiple Choice: options stay (now editable), C/D shown again', (tester) async {
      await pump(tester);
      await openAddQuiz(tester);
      await choose(tester, dropdownLabelled('Question Type *'), 'True / False');
      await choose(tester, dropdownLabelled('Question Type *'), 'Multiple Choice');
      expect([text(tester, 'item-option-a'), text(tester, 'item-option-b')], ['True', 'False']);
      expect(readOnly(tester, 'item-option-a'), isFalse);
      expect(byKey('item-option-c'), findsOneWidget);
    });

    testWidgets('changing the item type resets the question type to Multiple Choice', (tester) async {
      await pump(tester);
      await openAddQuiz(tester);
      await choose(tester, dropdownLabelled('Question Type *'), 'True / False');
      await choose(tester, dropdownLabelled('Type *'), 'Video');
      await choose(tester, dropdownLabelled('Type *'), 'Quiz');
      expect(find.descendant(of: form, matching: find.text('Multiple Choice')), findsOneWidget);
    });

    testWidgets('editing a True/False item reopens as True / False; the update keeps True/False', (tester) async {
      await pump(tester);
      await tapKey(tester, 'item-edit-tf1');
      expect(find.descendant(of: form, matching: find.text('True / False')), findsOneWidget);
      expect(readOnly(tester, 'item-option-a'), isTrue);
      expect(byKey('item-option-c'), findsNothing);
      expect(find.descendant(of: dropdownLabelled('Correct Option *'), matching: find.text('False')), findsOneWidget);
      await tester.enterText(field('Question *'), 'Is the sky blue on a clear day?');
      await submit(tester, 'Update Item');
      final w = server.writes.single;
      expect([w.method, w.path], ['PUT', ApiConstants.assessmentItemDetail('tf1')]);
      expect([w.body['option_a'], w.body['option_b'], w.body['option_c'], w.body['correct_option']],
          ['TRUE', 'false', '', 'b'],
          reason: 'stored values are kept as they were (only re-filled when the type is switched)');
    });

    testWidgets('editing a multiple-choice item reopens as Multiple Choice', (tester) async {
      await pump(tester);
      await tapKey(tester, 'item-edit-mc1');
      expect(find.descendant(of: form, matching: find.text('Multiple Choice')), findsOneWidget);
      expect(text(tester, 'item-option-c'), 'Maybe');
    });

    testWidgets('validation is unchanged: a True/False quiz still needs a question', (tester) async {
      await pump(tester);
      await openAddQuiz(tester);
      await tester.enterText(field('Title *'), 'No question');
      await choose(tester, dropdownLabelled('Question Type *'), 'True / False');
      await submit(tester, 'Add Item');
      expect(find.text('Question is required.'), findsOneWidget);
      expect(server.writes, isEmpty);
    });
  });

  group('video sources (web toEmbedUrl)', () {
    test('embed rules, rule for rule', () {
      expect(assessmentVideoEmbedUrl('https://youtu.be/abc123?t=5'), 'https://www.youtube.com/embed/abc123');
      expect(assessmentVideoEmbedUrl('https://www.youtube.com/watch?v=XyZ_9&list=1'), 'https://www.youtube.com/embed/XyZ_9');
      expect(assessmentVideoEmbedUrl('https://youtube.com/watch?feature=x&v=Q1'), 'https://www.youtube.com/embed/Q1');
      expect(assessmentVideoEmbedUrl('https://vimeo.com/76979871'), 'https://player.vimeo.com/video/76979871');
      expect(assessmentVideoEmbedUrl('https://cdn.example.test/a.mp4'), isNull);
      expect(assessmentVideoEmbedUrl(''), isNull);
    });

    test('source kinds, with the same scheme rule as saving', () {
      expect(assessmentVideoSource(''), AssessmentVideoSource.none);
      expect(assessmentVideoSource('youtu.be/abc'), AssessmentVideoSource.youtube);
      expect(assessmentVideoSource('https://vimeo.com/1'), AssessmentVideoSource.vimeo);
      expect(assessmentVideoSource('https://cdn.example.test/a.mp4'), AssessmentVideoSource.file);
      expect(assessmentVideoSource('cdn.example.test/a.mp4'), AssessmentVideoSource.file);
      expect(assessmentVideoSource('ftp://files.example.test/a.mp4'), AssessmentVideoSource.invalid);
      expect(assessmentVideoSource('not a link'), AssessmentVideoSource.invalid);
      expect(assessmentVideoPlayableUrl('youtu.be/abc'), 'https://youtu.be/abc');
    });

    test('row link label (web VideoLink)', () {
      expect(assessmentVideoLinkLabel('https://youtu.be/abc'), 'Watch video');
      expect(assessmentVideoLinkLabel(longUrl), '${longUrl.substring(0, 48)}…');
      expect(assessmentVideoLinkLabel('https://x.test/a.mp4'), 'https://x.test/a.mp4');
    });
  });

  group('video preview in the form', () {
    Future<void> openAddVideo(WidgetTester tester) async {
      await tapKey(tester, 'unsectioned-add-item');
      await choose(tester, dropdownLabelled('Type *'), 'Video');
    }

    testWidgets('appears as the URL is typed, by source; nothing for an empty URL', (tester) async {
      await pump(tester);
      await openAddVideo(tester);
      expect(find.byType(AssessmentVideoPreview), findsOneWidget);
      expect(byKey('video-preview-play'), findsNothing, reason: 'empty URL → no preview');
      await tester.enterText(byKey('item-video-url'), 'https://youtu.be/abc123');
      await tester.pump();
      expect(byKey('video-preview-youtube'), findsOneWidget);
      expect(find.text('YouTube video'), findsOneWidget);
      await tester.enterText(byKey('item-video-url'), 'https://vimeo.com/42');
      await tester.pump();
      expect(byKey('video-preview-vimeo'), findsOneWidget);
      await tester.enterText(byKey('item-video-url'), 'https://cdn.example.test/a.mp4');
      await tester.pump();
      expect(byKey('video-preview-file'), findsOneWidget);
      expect(find.text('Video file'), findsOneWidget);
      await tester.enterText(byKey('item-video-url'), 'not a link');
      await tester.pump();
      expect(byKey('video-preview-invalid'), findsOneWidget);
      expect(byKey('video-preview-play'), findsNothing);
    });

    testWidgets('Play opens the (scheme-completed) URL outside the app', (tester) async {
      await pump(tester);
      await openAddVideo(tester);
      await tester.enterText(byKey('item-video-url'), 'youtu.be/abc123');
      await tester.pumpAndSettle();
      await tapKey(tester, 'video-preview-play');
      expect(opened, [Uri.parse('https://youtu.be/abc123')]);
      expect(server.writes, isEmpty, reason: 'previewing never saves');
    });

    testWidgets('a video that cannot be opened says so', (tester) async {
      openerResult = false;
      await pump(tester);
      await openAddVideo(tester);
      await tester.enterText(byKey('item-video-url'), 'https://cdn.example.test/a.mp4');
      await tester.pumpAndSettle();
      await tapKey(tester, 'video-preview-play');
      expect(find.text('Could not open the video.'), findsOneWidget);
    });

    testWidgets('saving a video item is unchanged', (tester) async {
      await pump(tester);
      await openAddVideo(tester);
      await tester.enterText(field('Title *'), 'Welcome');
      await tester.enterText(byKey('item-video-url'), 'https://youtu.be/abc123');
      await submit(tester, 'Add Item');
      final b = server.writes.single.body;
      expect([b['item_type'], b['video_url']], ['video', 'https://youtu.be/abc123']);
    });
  });

  group('video links on item rows (web VideoLink)', () {
    for (final (name, u) in [('editor', editor), ('view-only', viewer)]) {
      testWidgets('$name: "Watch video" for YouTube, the shortened URL for a file; tapping opens it', (tester) async {
        await pump(tester, as: u);
        expect(find.text('Watch video'), findsOneWidget);
        expect(find.text('${longUrl.substring(0, 48)}…'), findsOneWidget);
        await tester.tap(find.text('Watch video'));
        await tester.pumpAndSettle();
        expect(opened, [Uri.parse('https://youtu.be/abc123')]);
      });
    }

    testWidgets('view-only users still cannot add or edit items (Task 23 rule)', (tester) async {
      await pump(tester, as: viewer);
      expect(byKey('unsectioned-add-item'), findsNothing);
      expect(byKey('item-edit-tf1'), findsNothing);
    });
  });
}

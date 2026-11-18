import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/dashboard/presentation/navigation/nav_config.dart';
import 'package:mobile_app/features/training/data/models/training_models.dart';
import 'package:mobile_app/features/training/presentation/screens/my_assessment_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/my_course_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/my_learning_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/my_material_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/training_course_screen.dart';
import 'package:mobile_app/features/training/presentation/widgets/training_video_player.dart';

import '../../core/permissions/p0_permission_parity_test.dart' as h;

// Task 90 batch 2: My Learning (employee). Contract from backend
// apps/training/services.py + views.py and web app/dashboard/my-learning.
// A stand-in server with synthetic data; nothing is sent anywhere. The real
// WebView player is replaced by a fake that reports playback on demand.

ResponseBody _json(Object body, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> _ok(Object data, [String m = 'ok']) => {'status': 'success', 'message': m, 'data': data};

Map<String, dynamic> _course({String? assessment = 'Test Quiz'}) => {
      'id': 'c1', 'title': 'Test Safety Course', 'description': 'Test description', 'category': 'Safety',
      'owner': null, 'trainer_name': '', 'has_thumbnail': false, 'duration_minutes': 30, 'is_mandatory': true,
      'is_active': true, 'start_date': null, 'deadline': null,
      'assessment': assessment == null ? null : {'id': 'a1', 'title': assessment, 'pass_percentage': 70},
      'videos_optional': false, 'archived': false, 'created_at': '2026-11-01T10:00:00',
    };

Map<String, dynamic> _assignment(String id, String status, {int pct = 0, String? startsOn, String? due}) => {
      'id': id,
      'employee': {'id': 'u1', 'name': 'Test User', 'employee_id': 'T-1', 'branch': '', 'department': ''},
      'course_id': 'c1', 'course_title': 'Course $id', 'status': status, 'source': 'individual',
      'due_date': due, 'assigned_at': '2026-11-01T10:00:00', 'started_at': null, 'completed_at': null,
      'attempts_used': 0, 'best_score_percent': null, 'assessment_passed': null,
      'progress_percent': pct, 'course': {..._course(), 'title': 'Course $id'}, 'material_count': 2,
      'starts_on': startsOn,
    };

Map<String, dynamic> _mat(String id, String type,
        {String format = '', String provider = '', String embed = '', String url = '', bool tracked = false,
        bool manual = false, int minView = 0, int? duration, Map<String, dynamic>? progress, bool required = true}) =>
    {
      'id': id, 'title': 'Test $id', 'description': '', 'material_type': type, 'order': 1, 'is_required': required,
      'file_format': format, 'file_size': 1000, 'original_name': '', 'provider': provider, 'embed_id': embed,
      'external_url': url, 'duration_seconds': duration, 'min_view_seconds': minView,
      'allow_manual_completion': manual, 'is_tracked': tracked, 'is_archived': false,
      'progress': progress ??
          {'opened_at': null, 'watched_seconds': 0, 'last_position_seconds': 0, 'duration_seconds': duration,
           'completed_at': null, 'completion_method': ''},
    };

Map<String, dynamic> _prog({String? opened, String? completed, double watched = 0, String method = ''}) => {
      'opened_at': opened, 'watched_seconds': watched, 'last_position_seconds': 0, 'duration_seconds': null,
      'completed_at': completed, 'completion_method': method,
    };

Map<String, dynamic> _assess({bool unlocked = true, bool canAttempt = true, bool? passed, int used = 0,
        int max = 3, bool hasQ = true, int? best}) =>
    {
      'required': true, 'title': 'Test Quiz', 'pass_percentage': 70, 'max_attempts': max, 'attempts_used': used,
      'attempts_left': max == 0 ? null : max - used, 'time_limit_mins': 15, 'unlocked': unlocked,
      'can_attempt': canAttempt, 'has_questions': hasQ, 'starts_on': null, 'passed': passed,
      'best_score_percent': best, 'can_retake': passed == true && canAttempt, 'last_result': null,
    };

class _LServer extends h.Server {
  final log = <String>[];
  final bodies = <String, Object?>{};
  int listStatus = 200;
  List<Map<String, dynamic>> list = [
    _assignment('a-new', 'assigned'),
    _assignment('a-prog', 'in_progress', pct: 50),
    _assignment('a-over', 'overdue', due: '2026-01-01'),
    _assignment('a-done', 'completed', pct: 100),
    _assignment('a-fail', 'failed', pct: 100),
  ];
  Map<String, dynamic> detail = {
    ..._assignment('a-prog', 'in_progress', pct: 50),
    'materials': [
      _mat('m-pdf', 'document', format: 'pdf', minView: 60),
      _mat('m-yt', 'external_video', provider: 'youtube', embed: 'abcdefghijk',
          url: 'https://www.youtube.com/watch?v=abcdefghijk', tracked: true, duration: 100),
    ],
    'assessment': _assess(unlocked: false, canAttempt: false),
  };

  /// Server reply for material actions: what the material looks like after.
  Map<String, dynamic> Function(String materialId, String action)? onAction;
  String? videoSource = 'https://res.cloudinary.com/test/video/authenticated/s--x--/v1/clip.mp4';

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    log.add('${o.method} ${o.path}');
    if (o.method != 'GET') bodies['${o.method} ${o.path}'] = o.data;
    final p = o.path;
    if (o.method == 'GET' && p == '/training/my/') {
      if (listStatus == 403) {
        return _json({'status': 'error', 'message': 'Training & Learning is not enabled for your company.'}, 403);
      }
      if (listStatus != 200) return _json({'status': 'error', 'message': 'Server error.'}, listStatus);
      return _json(_ok(list));
    }
    if (o.method == 'GET' && p.startsWith('/training/my/')) return _json(_ok(detail));
    if (o.method == 'GET' && p.endsWith('/video-source/')) return _json(_ok({'url': videoSource, 'content_type': 'video/mp4'}));
    if (o.method == 'GET' && p.endsWith('/file/')) {
      return ResponseBody.fromBytes(utf8.encode('%PDF-1.4 test'), 200, headers: {
        Headers.contentTypeHeader: ['application/pdf']
      });
    }
    final m = RegExp(r'^/training/my/[^/]+/materials/([^/]+)/(open|progress|confirm)/$').firstMatch(p);
    if (o.method == 'POST' && m != null) {
      final mat = onAction?.call(m.group(1)!, m.group(2)!) ??
          _mat(m.group(1)!, 'document', format: 'pdf', progress: _prog(opened: '2026-11-18T10:00:00Z'));
      return _json(_ok({'material': mat, 'status': 'in_progress', 'assessment': _assess()}, 'Saved.'));
    }
    if (o.method == 'POST' && p.endsWith('/assessment/start/')) {
      return _json(_ok({
        'attempt_id': 'at1', 'attempt_number': 1, 'started_at': '2026-11-18T10:00:00Z', 'time_limit_mins': 15,
        'questions': [
          {'id': 'q1', 'question': 'Test question one?', 'section': '', 'options': [
            {'key': 'a', 'text': 'Alpha'}, {'key': 'b', 'text': 'Beta'}]},
          {'id': 'q2', 'question': 'Test question two?', 'section': 'S1', 'options': [
            {'key': 'a', 'text': 'Gamma'}, {'key': 'b', 'text': 'Delta'}]},
        ],
      }, 'Assessment started.'));
    }
    if (o.method == 'POST' && p.endsWith('/assessment/submit/')) {
      return _json(_ok({'score': 2, 'max_score': 2, 'percentage': 100, 'pass_percentage': 70, 'passed': true,
          'status': 'completed', 'assessment': _assess(passed: true, best: 100, used: 1)}, 'Assessment submitted.'));
    }
    return super.fetch(o, s, c);
  }
}

late _LServer _srv;
Iterable<String> _writes() => _srv.log.where((l) => !l.startsWith('GET '));

UserEntity _user({List<String> perms = const [], List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'user@example.test',
      fullName: 'Test User',
      role: 'employee',
      roleDisplay: 'Employee',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: false,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
      enabledModules: modules,
    );

/// Fake player: records the builder call and exposes onBeat / onError.
class _FakePlayer {
  TrainingBeat? onBeat;
  ValueChanged<String>? onError;
  String? sourceUrl;
  int builds = 0;
}

late _FakePlayer _player;
Uri? _launched;

List<Override> _overrides() => [
      ...h.overrides(_user()),
      trainingVideoPlayerBuilderProvider.overrideWithValue(
          ({required material, required sourceUrl, required onBeat, required onError}) {
        _player
          ..onBeat = onBeat
          ..onError = onError
          ..sourceUrl = sourceUrl
          ..builds += 1;
        return const SizedBox(key: Key('fake-player'), height: 100);
      }),
      trainingLinkLauncherProvider.overrideWithValue((uri) async {
        _launched = uri;
        return true;
      }),
    ];

Future<void> _pumpApp(WidgetTester tester,
    {String at = '/dashboard/my-learning', void Function(_LServer)? configure, Size size = const Size(720, 5000)}) async {
  // Tall by default so every lazily-built card exists; layout at phone size
  // is checked separately.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  _srv = _LServer();
  _player = _FakePlayer();
  _launched = null;
  configure?.call(_srv);
  h.server = _srv;
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(),
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: at, routes: [
        GoRoute(
          path: '/dashboard/my-learning',
          builder: (_, __) => const Scaffold(body: MyLearningScreen()),
          routes: [
            GoRoute(path: ':id', builder: (_, st) => MyCourseScreen(assignmentId: st.pathParameters['id']!)),
          ],
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Pumps the material screen for [mat] inside an assignment with [status].
Future<void> _pumpMaterial(WidgetTester tester, Map<String, dynamic> mat,
    {String status = 'in_progress', void Function(_LServer)? configure}) async {
  tester.view.physicalSize = const Size(720, 1640);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  _srv = _LServer();
  _player = _FakePlayer();
  _launched = null;
  configure?.call(_srv);
  h.server = _srv;
  final training = MyTraining.fromJson({..._assignment('a1', status), 'materials': [mat]});
  await tester.pumpWidget(ProviderScope(
    overrides: _overrides(),
    child: MaterialApp(
      home: MyMaterialScreen(training: training, material: training.materials!.single),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rules (web lib/training.ts)', () {
    TrainingMaterial m(Map<String, dynamic> j) => TrainingMaterial.fromJson(j);

    test('materialHint for each material type and state', () {
      expect(trainingMaterialHint(m(_mat('d', 'document', format: 'pdf'))),
          'Open the document, then confirm you have read it');
      expect(trainingMaterialHint(m(_mat('d', 'document', format: 'pdf', minView: 90, progress: _prog(opened: 'x')))),
          'Confirm after reading (minimum 1m 30s)');
      expect(trainingMaterialHint(m(_mat('d', 'document', progress: _prog(opened: 'x', completed: 'y')))), 'Completed');
      expect(trainingMaterialHint(m(_mat('v', 'video', tracked: true, duration: 200, progress: _prog(watched: 50)))),
          'Watched 25% — completes at 90%');
      expect(trainingMaterialHint(m(_mat('v', 'video', tracked: true))), 'Video length not set — ask HR');
      expect(trainingMaterialHint(m(_mat('v', 'external_video', provider: 'vimeo', manual: true))),
          'Watch it, then confirm');
      expect(trainingMaterialHint(m(_mat('v', 'external_video', provider: 'vimeo'))),
          "Progress can't be tracked for this video — ask HR");
    });

    test('canConfirm: only after opening; never for tracked videos', () {
      expect(trainingCanConfirm(m(_mat('d', 'document'))), isFalse);
      expect(trainingCanConfirm(m(_mat('d', 'document', progress: _prog(opened: 'x')))), isTrue);
      expect(trainingCanConfirm(m(_mat('d', 'document', progress: _prog(opened: 'x', completed: 'y')))), isFalse);
      expect(trainingCanConfirm(m(_mat('v', 'external_video', provider: 'youtube', tracked: true, progress: _prog(opened: 'x')))),
          isFalse);
      expect(trainingCanConfirm(m(_mat('v', 'external_video', provider: 'vimeo', manual: true, progress: _prog(opened: 'x')))),
          isTrue);
      expect(trainingCanConfirm(m(_mat('v', 'external_video', provider: 'vimeo', progress: _prog(opened: 'x')))), isFalse);
    });

    test('secondsUntilConfirm counts the minimum reading time from opened_at', () {
      final mat = m(_mat('d', 'document', minView: 60, progress: _prog(opened: '2026-11-18T10:00:00Z')));
      expect(trainingSecondsUntilConfirm(mat, DateTime.utc(2026, 11, 18, 10, 0, 20)), 40);
      expect(trainingSecondsUntilConfirm(mat, DateTime.utc(2026, 11, 18, 10, 2)), 0);
      expect(trainingSecondsUntilConfirm(m(_mat('d', 'document', progress: _prog(opened: 'x'))), DateTime.now()), 0);
    });

    test('status filters: overdue is its own tab; All keeps everything', () {
      final rows = [for (final r in _LServer().list) MyTraining.fromJson(r)];
      expect(filterMyTraining(rows, null), hasLength(5));
      for (final (s, _) in kMyLearningFilters.skip(1)) {
        final got = filterMyTraining(rows, s);
        expect(got, hasLength(1), reason: s!.api);
        expect(got.single.status, s);
      }
      expect(kMyLearningFilters.map((f) => f.$2),
          ['All', 'Not started', 'In progress', 'Overdue', 'Completed', 'Failed']);
    });

    test('heartbeat: at most one report per 10 s unless forced', () {
      var now = DateTime(2026, 11, 18, 10);
      final sent = <double>[];
      final hb = TrainingHeartbeat(send: (p, d) async => sent.add(p), clock: () => now);
      hb.beat(1, 100);
      now = now.add(const Duration(seconds: 3));
      hb.beat(4, 100); // throttled
      hb.beat(5, 100, force: true); // pause / end
      now = now.add(const Duration(seconds: 11));
      hb.beat(16, 100);
      expect(sent, [1, 5, 16]);
    });

    test('player page: only valid ids and https sources; values are JSON-escaped', () {
      final yt = m(_mat('v', 'external_video', provider: 'youtube', embed: 'abcdefghijk', tracked: true));
      final html = trainingPlayerHtml(yt)!;
      expect(html, contains('"abcdefghijk"'));
      expect(html, contains('youtube-nocookie.com'));
      expect(trainingPlayerHtml(m(_mat('v', 'external_video', provider: 'youtube', embed: 'bad"id</script>'))), isNull);
      expect(trainingPlayerHtml(m(_mat('v', 'external_video', provider: 'vimeo', embed: '12a'))), isNull);
      expect(trainingPlayerHtml(m(_mat('v', 'external_video', provider: 'vimeo', embed: '123'))), contains('player.vimeo.com'));
      expect(trainingPlayerHtml(m(_mat('v', 'external_video', provider: 'direct', url: 'http://x.test/a.mp4'))), isNull);
      final direct = trainingPlayerHtml(
          m(_mat('v', 'external_video', provider: 'direct', url: 'https://x.test/a.mp4?q="</script>')))!;
      expect(direct, isNot(contains('"</script>')));
      expect(trainingPlayerHtml(m(_mat('v', 'video')), sourceUrl: 'https://res.test/v.mp4'), contains('<video'));
      expect(trainingPlayerHtml(m(_mat('v', 'video'))), isNull); // no signed URL
      expect(trainingPlayerHtml(m(_mat('d', 'document', format: 'pdf'))), isNull);
    });

    test('player messages and top-level navigation guard', () {
      final b = parseTrainingPlayerMessage('{"t":"beat","p":12.5,"d":100,"f":true}')!;
      expect((b.type, b.position, b.duration, b.force), ('beat', 12.5, 100.0, true));
      expect(parseTrainingPlayerMessage('{"t":"error","m":"x"}')!.message, 'x');
      expect(parseTrainingPlayerMessage('not json'), isNull);
      expect(parseTrainingPlayerMessage('{"t":"other"}'), isNull);
      const origin = 'https://royalhrms.com';
      expect(trainingPlayerAllowsTopLevel('about:blank', origin), isTrue);
      expect(trainingPlayerAllowsTopLevel('https://royalhrms.com/', origin), isTrue);
      expect(trainingPlayerAllowsTopLevel('https://www.youtube.com/watch?v=abcdefghijk', origin), isFalse);
      expect(trainingPlayerAllowsTopLevel('https://royalhrms.com/dashboard', origin), isFalse);
    });
  });

  group('navigation and access', () {
    bool inNav(UserEntity u) => buildNav(u).whereType<NavItem>().any((i) => i.path == '/dashboard/my-learning');

    test('every signed-in user (no permission); hidden without the training module', () {
      expect(inNav(_user()), isTrue);
      expect(canAccessPath(_user(), '/dashboard/my-learning/a1'), isTrue);
      expect(inNav(_user(modules: ['leave'])), isFalse);
      expect(canAccessPath(_user(modules: ['leave']), '/dashboard/my-learning'), isFalse);
      expect(inNav(_user(modules: ['training'])), isTrue);
      expect(pageTitle('/dashboard/my-learning'), 'My Learning');
    });
  });

  group('My Learning list', () {
    testWidgets('six tabs filter the list; viewing sends no writes', (tester) async {
      await _pumpApp(tester);
      expect(find.byKey(const Key('my-learning-card-a-new')), findsOneWidget);
      expect(find.byKey(const Key('my-learning-card-a-fail')), findsOneWidget);
      final expected = {
        'assigned': 'a-new', 'in_progress': 'a-prog', 'overdue': 'a-over', 'completed': 'a-done', 'failed': 'a-fail',
      };
      for (final MapEntry(key: tab, value: id) in expected.entries) {
        final t = find.byKey(Key('my-learning-tab-$tab'));
        await tester.ensureVisible(t);
        await tester.tap(t);
        await tester.pumpAndSettle();
        expect(find.byKey(Key('my-learning-card-$id')), findsOneWidget, reason: tab);
        expect(find.byType(Card).evaluate().length + find.byKey(const Key('my-learning-list')).evaluate().length,
            greaterThan(0));
        for (final other in expected.values.where((v) => v != id)) {
          expect(find.byKey(Key('my-learning-card-$other')), findsNothing, reason: '$tab shows $other');
        }
      }
      expect(find.text('Overdue'), findsWidgets);
      expect(_writes(), isEmpty);
    });

    testWidgets('phone size, 1.5x text: no overflow on list, course and assessment', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpApp(tester, size: const Size(720, 1640));
      expect(tester.takeException(), isNull);
      await _pumpApp(tester, at: '/dashboard/my-learning/a-prog', size: const Size(720, 1640));
      expect(tester.takeException(), isNull);
    });

    testWidgets('card shows status, due date and progress', (tester) async {
      await _pumpApp(tester);
      expect(find.text('50% of required materials'), findsOneWidget);
      expect(find.textContaining('Due 2026-01-01'), findsOneWidget);
      expect(find.text('Failed Assessment'), findsOneWidget);
    });

    testWidgets('empty list and empty tab messages', (tester) async {
      await _pumpApp(tester, configure: (s) => s.list = []);
      expect(find.text('No training has been assigned to you yet.'), findsOneWidget);
      await _pumpApp(tester, configure: (s) => s.list = [_assignment('a1', 'completed')]);
      await tester.tap(find.byKey(const Key('my-learning-tab-assigned')));
      await tester.pumpAndSettle();
      expect(find.text('Nothing here.'), findsOneWidget);
    });

    testWidgets('module disabled / permission denied: server message, no pointless Retry', (tester) async {
      await _pumpApp(tester, configure: (s) => s.listStatus = 403);
      expect(find.textContaining('not enabled for your company'), findsWidgets);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('server failure shows Retry, which reloads', (tester) async {
      await _pumpApp(tester, configure: (s) => s.listStatus = 500);
      expect(find.text('Retry'), findsOneWidget);
      _srv.listStatus = 200;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('my-learning-card-a-new')), findsOneWidget);
    });
  });

  group('Course page', () {
    testWidgets('read-only: materials, hints and assessment row; no writes', (tester) async {
      await _pumpApp(tester, at: '/dashboard/my-learning/a-prog');
      expect(find.text('1. Test m-pdf'), findsOneWidget);
      expect(find.textContaining('Open the document, then confirm you have read it'), findsOneWidget);
      expect(find.textContaining('Watched 0% — completes at 90%'), findsOneWidget);
      expect(find.text('Complete the materials first'), findsOneWidget);
      expect(find.byKey(const Key('my-course-summary')), findsOneWidget);
      expect(_writes(), isEmpty);
    });

    testWidgets('closed (failed) and not-yet-open courses show their notices', (tester) async {
      await _pumpApp(tester,
          at: '/dashboard/my-learning/a-fail',
          configure: (s) => s.detail = {...s.detail, 'status': 'failed'});
      expect(find.byKey(const Key('my-course-closed')), findsOneWidget);
      await _pumpApp(tester,
          at: '/dashboard/my-learning/a-new',
          configure: (s) => s.detail = {...s.detail, 'starts_on': '2099-01-01'});
      expect(find.byKey(const Key('my-course-not-open')), findsOneWidget);
      await tester.tap(find.byKey(const Key('my-material-m-pdf')));
      await tester.pumpAndSettle();
      expect(find.byType(MyMaterialScreen), findsNothing); // not tappable before the start date
      expect(_writes(), isEmpty);
    });
  });

  group('Material viewer', () {
    testWidgets('PDF: records "open" once, then waits out the minimum reading time', (tester) async {
      await _pumpMaterial(tester, _mat('m-pdf', 'document', format: 'pdf', minView: 60), configure: (s) {
        s.onAction = (id, action) => _mat(id, 'document', format: 'pdf', minView: 60,
            progress: _prog(opened: DateTime.now().toUtc().toIso8601String()));
      });
      await tester.pump(const Duration(milliseconds: 100));
      expect(_writes(), ['POST /training/my/a1/materials/m-pdf/open/']);
      expect(find.byKey(const Key('my-material-pdf')), findsOneWidget);
      final confirm = tester.widget<FilledButton>(find.byKey(const Key('my-material-confirm')));
      expect(confirm.onPressed, isNull);
      expect(find.byKey(const Key('my-material-wait')), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // dispose timers
    });

    testWidgets('document already opened: confirm sends "confirm" and shows Completed', (tester) async {
      await _pumpMaterial(tester,
          _mat('m-pdf', 'document', format: 'pdf', progress: _prog(opened: '2026-11-18T09:00:00Z')), configure: (s) {
        s.onAction = (id, action) => _mat(id, 'document', format: 'pdf',
            progress: _prog(opened: '2026-11-18T09:00:00Z', completed: '2026-11-18T10:00:00Z', method: 'read'));
      });
      expect(_writes(), isEmpty); // already opened: no second "open"
      await tester.tap(find.byKey(const Key('my-material-confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(_writes(), ['POST /training/my/a1/materials/m-pdf/confirm/']);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.byKey(const Key('my-material-confirm')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('PowerPoint / Word: not shown, not downloaded, nothing recorded, no confirm', (tester) async {
      await _pumpMaterial(tester, _mat('m-doc', 'document', format: 'pptx'));
      expect(find.byKey(const Key('my-material-office')), findsOneWidget);
      expect(find.byKey(const Key('my-material-confirm')), findsNothing);
      expect(_srv.log, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('closed course: content shown, nothing recorded, no confirm', (tester) async {
      await _pumpMaterial(tester, _mat('m-pdf', 'document', format: 'pdf'), status: 'failed');
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const Key('my-material-closed')), findsOneWidget);
      expect(find.byKey(const Key('my-material-confirm')), findsNothing);
      expect(_writes(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('tracked YouTube video: throttled playback reports; completes only from the server', (tester) async {
      final yt = _mat('m-yt', 'external_video', provider: 'youtube', embed: 'abcdefghijk',
          url: 'https://www.youtube.com/watch?v=abcdefghijk', tracked: true, duration: 100);
      var completeNow = false;
      await _pumpMaterial(tester, yt, configure: (s) {
        s.onAction = (id, action) => {
              ...yt,
              'progress': _prog(
                  opened: '2026-11-18T09:00:00Z',
                  watched: completeNow ? 95 : 10,
                  completed: completeNow ? '2026-11-18T10:00:00Z' : null,
                  method: completeNow ? 'tracked' : ''),
            };
      });
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const Key('fake-player')), findsOneWidget);
      expect(_writes(), ['POST /training/my/a1/materials/m-yt/open/']);
      expect(find.byKey(const Key('my-material-confirm')), findsNothing); // tracked: never by confirmation

      _player.onBeat!(5, 100, force: true); // play
      _player.onBeat!(7, 100); // within 10 s: throttled
      await tester.pump(const Duration(milliseconds: 50));
      expect(_writes().where((w) => w.endsWith('/progress/')), hasLength(1));
      expect(_srv.bodies['POST /training/my/a1/materials/m-yt/progress/'], {'position': 5.0, 'duration': 100.0});
      expect(find.textContaining('Watched 10%'), findsOneWidget);

      completeNow = true;
      _player.onBeat!(95, 100, force: true); // end
      await tester.pump(const Duration(milliseconds: 50));
      expect(_writes().where((w) => w.endsWith('/progress/')), hasLength(2));
      expect(find.text('Completed'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('opening the original link records nothing', (tester) async {
      await _pumpMaterial(tester,
          _mat('m-yt', 'external_video', provider: 'youtube', embed: 'abcdefghijk',
              url: 'https://www.youtube.com/watch?v=abcdefghijk', tracked: true, duration: 100,
              progress: _prog(opened: '2026-11-18T09:00:00Z')));
      await tester.tap(find.byKey(const Key('my-material-open-original')));
      await tester.pump();
      expect(_launched.toString(), 'https://www.youtube.com/watch?v=abcdefghijk');
      expect(_writes(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('untracked Vimeo: playback never reported; confirm only if HR allows it', (tester) async {
      final vimeo = _mat('m-vi', 'external_video', provider: 'vimeo', embed: '123', url: 'https://vimeo.com/123',
          manual: true, progress: _prog(opened: '2026-11-18T09:00:00Z'));
      await _pumpMaterial(tester, vimeo);
      _player.onBeat!(50, 100, force: true);
      await tester.pump(const Duration(milliseconds: 50));
      expect(_writes(), isEmpty);
      expect(find.text('I have watched this'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());

      await _pumpMaterial(tester, {...vimeo, 'allow_manual_completion': false});
      expect(find.byKey(const Key('my-material-confirm')), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('uploaded video plays from the signed URL; no URL → web-only message', (tester) async {
      final up = _mat('m-up', 'video', format: 'mp4', tracked: true, duration: 60,
          progress: _prog(opened: '2026-11-18T09:00:00Z'));
      await _pumpMaterial(tester, up);
      await tester.pumpAndSettle();
      expect(_srv.log, contains('GET /training/materials/m-up/video-source/'));
      expect(_player.sourceUrl, startsWith('https://res.cloudinary.com/'));
      await tester.pumpWidget(const SizedBox());

      await _pumpMaterial(tester, up, configure: (s) => s.videoSource = null);
      await tester.pumpAndSettle();
      expect(find.text('This video can only be played on the web app.'), findsOneWidget);
      expect(_writes(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('player error is shown', (tester) async {
      await _pumpMaterial(tester,
          _mat('m-yt', 'external_video', provider: 'youtube', embed: 'abcdefghijk',
              url: 'https://www.youtube.com/watch?v=abcdefghijk', tracked: true, duration: 100,
              progress: _prog(opened: '2026-11-18T09:00:00Z')));
      _player.onError!("This video can't be played here (it may not allow embedding).");
      await tester.pump();
      expect(find.byKey(const Key('my-material-video-error')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('Assessment', () {
    Future<void> pumpAssessment(WidgetTester tester, Map<String, dynamic> state) async {
      tester.view.physicalSize = const Size(720, 1640);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      _srv = _LServer()..detail = {..._LServer().detail, 'assessment': state};
      _player = _FakePlayer();
      h.server = _srv;
      await tester.pumpWidget(ProviderScope(
        overrides: _overrides(),
        child: const MaterialApp(home: MyAssessmentScreen(assignmentId: 'a1', courseTitle: 'Test Safety Course')),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('locked until the materials are done; no start offered', (tester) async {
      await pumpAssessment(tester, _assess(unlocked: false, canAttempt: false));
      expect(find.byKey(const Key('my-assessment-locked')), findsOneWidget);
      expect(find.byKey(const Key('my-assessment-start')), findsNothing);
      expect(find.text('Pass mark 70% · 0 of 3 attempts used · 15 minute time limit'), findsOneWidget);
    });

    testWidgets('no attempts left / no questions messages', (tester) async {
      await pumpAssessment(tester, _assess(canAttempt: false, used: 3));
      expect(find.byKey(const Key('my-assessment-no-attempts')), findsOneWidget);
      await pumpAssessment(tester, _assess(canAttempt: false, hasQ: false));
      expect(find.byKey(const Key('my-assessment-noq')), findsOneWidget);
    });

    testWidgets('start → answer → unanswered check → submit sends the answers; result shown', (tester) async {
      await pumpAssessment(tester, _assess());
      await tester.tap(find.byKey(const Key('my-assessment-start')));
      await tester.pumpAndSettle();
      expect(_writes(), ['POST /training/my/a1/assessment/start/']);
      expect(find.text('1. Test question one?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('my-assessment-opt-q1-b')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('my-assessment-submit')));
      await tester.pumpAndSettle();
      expect(find.text('1 question(s) unanswered. Submit anyway?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_writes(), hasLength(1)); // not submitted
      final opt = find.byKey(const Key('my-assessment-opt-q2-a'));
      await tester.ensureVisible(opt);
      await tester.tap(opt);
      await tester.pump();
      await tester.ensureVisible(find.byKey(const Key('my-assessment-submit')));
      await tester.tap(find.byKey(const Key('my-assessment-submit')));
      await tester.pumpAndSettle();
      expect(_srv.bodies['POST /training/my/a1/assessment/submit/'], {
        'answers': {'q1': 'b', 'q2': 'a'}
      });
      expect(find.byKey(const Key('my-assessment-result')), findsOneWidget);
      expect(find.text('Passed — 100% (pass mark 70%).'), findsOneWidget);
    });

    testWidgets('passed: retake offered with the web wording', (tester) async {
      await pumpAssessment(tester, _assess(passed: true, best: 80, used: 1));
      expect(find.text('You passed — best score 80%.'), findsOneWidget);
      expect(find.text('Retake to improve score'), findsOneWidget);
    });
  });
}

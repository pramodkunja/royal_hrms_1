import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/error/exceptions.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/auth/presentation/providers/auth_providers.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/app_top_bar.dart';
import 'package:mobile_app/features/profile/data/services/profile_document_viewer.dart';
import 'package:mobile_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:mobile_app/features/training/data/models/training_models.dart';
import 'package:mobile_app/features/training/presentation/providers/training_file_io.dart';
import 'package:mobile_app/features/training/presentation/providers/training_office_opener.dart';
import 'package:mobile_app/features/training/presentation/providers/training_providers.dart';
import 'package:mobile_app/features/training/presentation/screens/my_course_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/my_material_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/training_course_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/training_screen.dart';
import 'package:mobile_app/features/training/presentation/widgets/training_video_player.dart';

import '../../core/permissions/p0_permission_parity_test.dart' as h;

// Task 90 batch 3: Training admin authoring, CSV export, HO-46 / HO-47 and
// the course-opening parity switch. A stand-in server with synthetic data;
// nothing is sent anywhere. File pickers, the CSV saver and the Office
// launcher are fakes — no platform dialog, no file leaves the test.

ResponseBody _json(Object body, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> _ok(Object data, [String m = 'ok']) => {'status': 'success', 'message': m, 'data': data};

const _c1 = 'c1111111-0000-0000-0000-000000000001';

Map<String, dynamic> _material(String id, String type,
        {String format = '', String provider = '', bool tracked = false, int? duration, bool required = true,
        bool manual = false, String url = ''}) =>
    {
      'id': id, 'title': 'Test $id', 'description': '', 'material_type': type, 'order': 1, 'is_required': required,
      'file_format': format, 'file_size': 2048, 'original_name': '', 'provider': provider, 'embed_id': '',
      'external_url': url, 'duration_seconds': duration, 'min_view_seconds': 0, 'allow_manual_completion': manual,
      'is_tracked': tracked, 'is_archived': false,
    };

Map<String, dynamic> _course({bool archived = false, Map<String, dynamic>? assessment}) => {
      'id': _c1, 'title': 'Test Safety Course', 'description': 'Test description', 'category': 'Safety',
      'owner': null, 'trainer_name': '', 'has_thumbnail': false, 'duration_minutes': 30, 'is_mandatory': false,
      'is_active': true, 'start_date': null, 'deadline': null, 'assessment': assessment, 'videos_optional': false,
      'auto_assign_new_joiners': false, 'new_joiner_deadline_days': 30, 'new_joiner_branches': [],
      'new_joiner_departments': [], 'archived': archived, 'created_at': '2026-11-01T10:00:00',
      'assigned_count': 0, 'completed_count': 0, 'material_count': 3,
      'materials': [
        _material('m1', 'document', format: 'pdf'),
        _material('m2', 'external_video', provider: 'youtube', tracked: true, url: 'https://youtu.be/abcdefghijk'),
        _material('m3', 'document', format: 'pptx'),
      ],
    };

class _BServer extends h.Server {
  final log = <String>[];
  final bodies = <String, Object?>{};
  Map<String, dynamic> course = _course();
  bool failCsv = false;
  Uint8List officeBytes = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 1, 2, 3]);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    final q = o.queryParameters.isEmpty
        ? ''
        : '?${Uri(queryParameters: o.queryParameters.map((k, v) => MapEntry(k, '$v'))).query}';
    log.add('${o.method} ${o.path}$q');
    if (o.method != 'GET') bodies['${o.method} ${o.path}'] = o.data;
    final p = o.path;
    switch ('${o.method} $p') {
      case 'GET /training/courses/':
        return _json(_ok([course]));
      case 'POST /training/courses/':
        return _json(_ok({..._course(), 'id': 'new-1', 'title': (o.data as Map)['title']}, 'Course created.'), 201);
      case 'GET /training/dashboard/':
        return _json(_ok({'total_courses': 1}));
      case 'GET /training/assessments/':
        return _json(_ok([
          {'id': 'a1', 'title': 'Test Quiz', 'questions': 5, 'pass_percentage': 70},
        ]));
      case 'GET /training/employees/':
        return _json(_ok({'employees': [], 'departments': ['Test Ops'], 'branches': ['Test Branch']}));
      case 'GET /training/reports/':
        if (o.queryParameters['export'] == 'csv') {
          if (failCsv) return _json({'status': 'error', 'message': 'Server error.'}, 500);
          return ResponseBody.fromBytes(utf8.encode('Employee,Course\nTest,Test\n'), 200, headers: {
            Headers.contentTypeHeader: ['text/csv']
          });
        }
        return _json(_ok([
          {
            'id': 'r1', 'employee': {'id': 'e1', 'name': 'Test Person', 'employee_id': 'T-1', 'branch': '', 'department': ''},
            'course_id': _c1, 'course_title': 'Test Safety Course', 'status': 'assigned', 'source': 'individual',
            'due_date': null, 'assigned_at': '2026-11-01T10:00:00', 'started_at': null, 'completed_at': null,
            'attempts_used': 0, 'best_score_percent': null, 'assessment_passed': null, 'progress_percent': 0,
          }
        ]));
    }
    if (o.method == 'GET' && p == '/training/courses/$_c1/') return _json(_ok(course));
    if (o.method == 'PATCH' && p == '/training/courses/$_c1/') return _json(_ok(course, 'Course saved.'));
    if (o.method == 'GET' && p == '/training/courses/$_c1/progress/') return _json(_ok([]));
    if (o.method == 'POST' && p == '/training/courses/$_c1/thumbnail/') return _json(_ok({'has_thumbnail': true}));
    if (o.method == 'POST' && p == '/training/courses/$_c1/materials/') {
      return _json(_ok(_material('new', 'document', format: 'pdf'), 'Material added.'), 201);
    }
    if (o.method == 'POST' && p == '/training/courses/$_c1/materials/reorder/') return _json(_ok([]));
    if (o.method == 'PATCH' && p.startsWith('/training/materials/')) return _json(_ok(_material('m1', 'document')));
    if (o.method == 'DELETE' && p.startsWith('/training/materials/')) return _json(_ok({}, 'Material removed.'));
    if (o.method == 'GET' && p.endsWith('/file/')) {
      return ResponseBody.fromBytes(officeBytes, 200, headers: {
        Headers.contentTypeHeader: ['application/octet-stream']
      });
    }
    final m = RegExp(r'^/training/my/[^/]+/materials/([^/]+)/(open|progress|confirm)/$').firstMatch(p);
    if (o.method == 'POST' && m != null) {
      return _json(_ok({
        'material': {..._material(m.group(1)!, 'document', format: 'pptx'), 'progress': {'opened_at': '2026-11-18T10:00:00Z', 'watched_seconds': 0, 'last_position_seconds': 0, 'duration_seconds': null, 'completed_at': null, 'completion_method': ''}},
        'status': 'in_progress',
      }));
    }
    if (o.method == 'GET' && p.startsWith('/training/my/')) {
      return _json(_ok({
        'id': 'as1',
        'employee': {'id': 'u1', 'name': 'Test User', 'employee_id': '', 'branch': '', 'department': ''},
        'course_id': _c1, 'course_title': 'Test Safety Course', 'status': myStatus, 'source': 'individual',
        'due_date': null, 'assigned_at': '2026-11-01T10:00:00', 'started_at': null, 'completed_at': null,
        'attempts_used': 0, 'best_score_percent': null, 'assessment_passed': null, 'progress_percent': 0,
        'course': _course(), 'material_count': 2, 'starts_on': null,
        'materials': [
          {..._material('done', 'document', format: 'pdf'), 'progress': {'opened_at': 'x', 'watched_seconds': 0, 'last_position_seconds': 0, 'duration_seconds': null, 'completed_at': 'y', 'completion_method': 'read'}},
          {..._material('next', 'document', format: 'pdf'), 'progress': {'opened_at': null, 'watched_seconds': 0, 'last_position_seconds': 0, 'duration_seconds': null, 'completed_at': null, 'completion_method': ''}},
        ],
        'assessment': {'required': false},
      }));
    }
    return super.fetch(o, s, c);
  }

  String myStatus = 'assigned';
}

late _BServer _srv;
Iterable<String> _writes() => _srv.log.where((l) => !l.startsWith('GET '));

UserEntity _user(List<String> perms) => UserEntity(
      id: 'u1',
      email: 'user@example.test',
      fullName: 'Test User',
      role: 'hr_admin',
      roleDisplay: 'HR',
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: false,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
    );

const _all = [
  'training.view', 'training.create', 'training.edit', 'training.delete', 'training.assign',
  'training.view_all_progress', 'training.manage_assessments', 'training.view_reports',
];

TrainingUploadFile? _nextPick;
List<String>? _pickedExtensions;
(String, Uint8List)? _saved;
(String, String)? _officeLaunch;

late Directory _tmp;

List<Override> _overrides(List<String> perms) => [
      ...h.overrides(_user(perms)),
      // App-private temp folder → a throwaway test directory.
      profileDocumentTempStoreProvider.overrideWithValue(ProfileDocumentTempStore(tempRoot: () async => _tmp)),
      trainingFilePickerProvider.overrideWithValue((ext) async {
        _pickedExtensions = ext;
        return _nextPick;
      }),
      trainingFileSaverProvider.overrideWithValue((name, bytes) async {
        _saved = (name, bytes);
        return true;
      }),
      trainingOfficeLauncherProvider.overrideWithValue((path, mime) async {
        _officeLaunch = (path, mime);
        return 'opened';
      }),
      trainingLinkLauncherProvider.overrideWithValue((uri) async => true),
      trainingVideoPlayerBuilderProvider.overrideWithValue(
          ({required material, required sourceUrl, required onBeat, required onError}) => const SizedBox()),
    ];

void _reset(void Function(_BServer)? configure) {
  _srv = _BServer();
  configure?.call(_srv);
  h.server = _srv;
  _nextPick = null;
  _pickedExtensions = null;
  _saved = null;
  _officeLaunch = null;
}

Future<void> _pumpRouter(WidgetTester tester, List<String> perms,
    {String at = '/dashboard/training', void Function(_BServer)? configure, double height = 9000}) async {
  tester.view.physicalSize = Size(720, height);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  _reset(configure);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: _overrides(perms),
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: at, routes: [
        GoRoute(
          path: '/dashboard/training',
          builder: (_, __) => const Scaffold(body: TrainingScreen()),
          routes: [
            GoRoute(path: ':courseId', builder: (_, st) => TrainingCourseScreen(courseId: st.pathParameters['courseId']!)),
          ],
        ),
      ]),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tab(WidgetTester tester, String name) async {
  final f = find.byKey(Key('training-course-tab-$name'));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// Taps, then lets real file I/O (the temporary copy) finish.
Future<void> _realAsyncTap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  for (var i = 0; i < 40; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump(const Duration(milliseconds: 20));
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    _tmp = Directory.systemTemp.createTempSync('training_b3_');
  });
  tearDownAll(() {
    if (_tmp.existsSync()) _tmp.deleteSync(recursive: true);
  });

  group('course form (web validateCourse / courseFormPayload)', () {
    const base = TrainingCourseForm(title: 'T');

    test('validation messages match web', () {
      expect(base.validate(), isEmpty);
      expect(const TrainingCourseForm(title: '  ').validate()['title'], 'Give the course a title.');
      expect(base.copyWith(durationMinutes: '1.5').validate()['duration_minutes'], 'Enter whole minutes.');
      expect(base.copyWith(startDate: '2026-12-10', deadline: '2026-12-01').validate()['deadline'],
          'The deadline must be on or after the start date.');
      expect(base.copyWith(autoAssignNewJoiners: true, newJoinerDeadlineDays: '400').validate()['new_joiner_deadline_days'],
          'Enter 0–365 days.');
      expect(base.copyWith(autoAssignNewJoiners: false, newJoinerDeadlineDays: '400').validate(), isEmpty);
      expect(base.copyWith(videosOptional: true).validate()['videos_optional'],
          'Link an assessment — employees complete the course by passing it.');
      expect(base.copyWith(videosOptional: true, assessment: 'a1').validate(), isEmpty);
    });

    test('payload: empty → null, assessment only for manage_assessments', () {
      final f = base.copyWith(description: 'd', durationMinutes: '', assessment: '');
      final p = f.toPayload(canLinkAssessment: true);
      expect(p['duration_minutes'], isNull);
      expect(p['start_date'], isNull);
      expect(p['assessment'], isNull);
      expect(p.containsKey('assessment'), isTrue);
      expect(f.toPayload(canLinkAssessment: false).containsKey('assessment'), isFalse);
      expect(base.copyWith(newJoinerDeadlineDays: 'x').toPayload(canLinkAssessment: false)['new_joiner_deadline_days'], 0);
      expect(TrainingCourseForm.fromCourse(TrainingCourse.fromJson(_course(assessment: {'id': 'a1', 'title': 'Q'})))
          .assessment, 'a1');
    });
  });

  group('materials rules (web lib/training.ts + validation.py)', () {
    test('video links: providers, ids and rejected links', () {
      expect(parseTrainingVideoLink('https://www.youtube.com/watch?v=abcdefghijk').provider, 'youtube');
      expect(parseTrainingVideoLink('https://youtu.be/abcdefghijk').id, 'abcdefghijk');
      expect(parseTrainingVideoLink('https://www.youtube.com/shorts/abcdefghijk').provider, 'youtube');
      expect(parseTrainingVideoLink('https://vimeo.com/123456').id, '123456');
      expect(parseTrainingVideoLink('https://cdn.example.com/a.mp4').provider, 'direct');
      expect(parseTrainingVideoLink('http://youtu.be/abcdefghijk').error, 'Only secure https:// links are allowed.');
      expect(parseTrainingVideoLink('https://u:p@example.com/a.mp4').error,
          'Links with a user name or password are not allowed.');
      expect(parseTrainingVideoLink('https://10.0.0.1/a.mp4').error, 'The link must point to a public website.');
      expect(parseTrainingVideoLink('https://youtube.com/watch?v=short').error, 'That YouTube link has no valid video id.');
      expect(parseTrainingVideoLink('https://example.com/page').error, contains('Supported links'));
      expect(parseTrainingVideoLink('  ').error, 'Paste the video link.');
    });

    test('lengths, required length and uploads', () {
      expect(trainingVideoLengthSeconds('2', '30'), 150);
      expect(trainingVideoLengthSeconds('1', '60'), 0);
      expect(parseTrainingVideoLength('12:30'), 750);
      expect(parseTrainingVideoLength('5'), 300);
      expect(parseTrainingVideoLength('0'), isNull);
      expect(parseTrainingVideoLength('1:75'), isNull);
      expect(trainingNeedsVideoLength('video', null), isTrue);
      expect(trainingNeedsVideoLength('external_video', 'vimeo'), isFalse);
      expect(trainingNeedsVideoLength('external_video', 'youtube'), isTrue);
      expect(trainingUploadError(fileName: null, size: 0, kind: 'document'), 'Choose a file.');
      expect(trainingUploadError(fileName: 'a.exe', size: 9, kind: 'document'),
          'Upload a PDF, PowerPoint (.pptx) or Word (.docx) file.');
      expect(trainingUploadError(fileName: 'a.mov', size: 9, kind: 'video'), 'Upload an MP4 or WebM video.');
      expect(trainingUploadError(fileName: 'a.pdf', size: 0, kind: 'document'), 'The file is empty.');
      expect(trainingUploadError(fileName: 'a.pdf', size: 10 * 1024 * 1024, kind: 'document'),
          'The file must be 9 MB or smaller.');
      expect(trainingUploadError(fileName: 'A.PDF', size: 10, kind: 'document'), '');
    });

    test('draft payloads match web', () {
      const link = TrainingMaterialDraft(
          kind: 'external_video', title: ' Intro ', link: 'https://vimeo.com/1', allowConfirm: true, required: false);
      expect(link.isValid, isTrue); // Vimeo: length optional
      expect(link.isUntrackedLink, isTrue);
      expect(link.linkPayload(), {
        'material_type': 'external_video', 'title': 'Intro', 'external_url': 'https://vimeo.com/1',
        'is_required': false, 'allow_manual_completion': true, 'duration_seconds': null,
      });
      const yt = TrainingMaterialDraft(kind: 'external_video', title: 'T', link: 'https://youtu.be/abcdefghijk');
      expect(yt.lengthError, 'Enter the video length.');
      final doc = TrainingMaterialDraft(
          kind: 'document', title: 'Handbook', minViewMinutes: '2',
          file: TrainingUploadFile(name: 'h.pdf', bytes: Uint8List(10)));
      expect(doc.uploadFields(), {'material_type': 'document', 'title': 'Handbook', 'is_required': 'true', 'min_view_seconds': '120'});
      final vid = TrainingMaterialDraft(
          kind: 'video', title: 'V', durMin: '1', durSec: '5', file: TrainingUploadFile(name: 'v.mp4', bytes: Uint8List(10)));
      expect(vid.uploadFields()['duration_seconds'], '65');
      expect(const TrainingMaterialDraft(kind: 'video', title: 'V').sourceError, 'Choose a video.');
    });
  });

  group('action layer: permission enforced before any request', () {
    Future<(TrainingAdminActions, _BServer)> actions(List<String> perms) async {
      _reset(null);
      final container = ProviderContainer(overrides: _overrides(perms));
      addTearDown(container.dispose);
      await container.read(authStateProvider.future);
      return (container.read(trainingAdminActionsProvider), _srv);
    }

    test('every write is refused locally without its permission', () async {
      final (a, srv) = await actions(['training.view']);
      final course = TrainingCourse.fromJson(_course());
      final m = course.materials!.first;
      final row = TrainingAssignmentRow.fromJson(const {'id': 'r1', 'status': 'failed'});
      final calls = <Future<Object?> Function()>[
        () => a.createCourse(title: 'X'),
        () => a.saveCourse(course, TrainingCourseForm.fromCourse(course)),
        () => a.uploadThumbnail(course, TrainingUploadFile(name: 't.png', bytes: Uint8List(4))),
        () => a.assessmentOptions(),
        () => a.addMaterial(course, const TrainingMaterialDraft(kind: 'external_video', title: 'T', link: 'https://vimeo.com/1')),
        () => a.updateMaterial(course, m, {'is_required': false}),
        () => a.removeMaterial(course, m),
        () => a.moveMaterial(course, 0, 1),
        () => a.deleteCourse(course),
        () => a.assign(course, const AssignRequest(mode: AssignMode.all)),
        () => a.removeAssignment(row),
        () => a.resetAttempts(row),
        () => a.exportCsv(const TrainingReportFilter()),
      ];
      for (final (i, call) in calls.indexed) {
        await expectLater(Future.sync(call), throwsA(isA<ForbiddenException>()), reason: 'call $i');
      }
      expect(srv.log.where((l) => !l.startsWith('GET /auth')), isEmpty);
    });

    test('archived course: edits refused even with training.edit', () async {
      final (a, srv) = await actions(_all);
      final archived = TrainingCourse.fromJson(_course(archived: true));
      await expectLater(Future.sync(() => a.saveCourse(archived, TrainingCourseForm.fromCourse(archived))), throwsA(isA<ForbiddenException>()));
      await expectLater(Future.sync(() => a.removeMaterial(archived, archived.materials!.first)), throwsA(isA<ForbiddenException>()));
      expect(srv.log, isEmpty);
    });

    test('invalid input is refused locally; reorder sends every id once, swapped', () async {
      final (a, srv) = await actions(_all);
      final course = TrainingCourse.fromJson(_course());
      await expectLater(Future.sync(() => a.createCourse(title: '  ')), throwsA(isA<ValidationException>()));
      await expectLater(Future.sync(() => a.saveCourse(course, const TrainingCourseForm(title: ''))), throwsA(isA<ValidationException>()));
      await expectLater(Future.sync(() => a.addMaterial(course, const TrainingMaterialDraft(title: 'x'))), throwsA(isA<ValidationException>()));
      await expectLater(Future.sync(() => a.uploadThumbnail(course, TrainingUploadFile(name: 't.gif', bytes: Uint8List(4)))),
          throwsA(isA<ValidationException>()));
      await expectLater(
          Future.sync(() => a.uploadThumbnail(course, TrainingUploadFile(name: 't.png', bytes: Uint8List(3 * 1024 * 1024)))),
          throwsA(isA<ValidationException>()));
      expect(srv.log, isEmpty);
      await a.moveMaterial(course, 0, 1);
      expect(srv.bodies['POST /training/courses/$_c1/materials/reorder/'], {
        'order': ['m2', 'm1', 'm3']
      });
      await a.moveMaterial(course, 0, -1); // out of range: nothing sent
      expect(srv.log.where((l) => l.contains('reorder')), hasLength(1));
    });
  });

  group('New Course', () {
    testWidgets('only with training.create; empty title refused locally; create posts and opens the course',
        (tester) async {
      await _pumpRouter(tester, ['training.view']);
      expect(find.byKey(const Key('training-new-course')), findsNothing);

      await _pumpRouter(tester, _all);
      await tester.tap(find.byKey(const Key('training-new-course')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('new-course-create')));
      await tester.pumpAndSettle();
      expect(find.text('Give the course a title.'), findsOneWidget);
      expect(_writes(), isEmpty);
      await tester.enterText(find.byKey(const Key('new-course-title')), 'Test Fire Safety');
      await tester.enterText(find.byKey(const Key('new-course-category')), 'Safety');
      await tester.tap(find.byKey(const Key('new-course-create')));
      await tester.pumpAndSettle();
      expect(_srv.bodies['POST /training/courses/'], {'title': 'Test Fire Safety', 'category': 'Safety'});
      expect(find.byType(TrainingCourseScreen), findsOneWidget);
    });

    testWidgets('Cancel sends nothing', (tester) async {
      await _pumpRouter(tester, _all);
      await tester.tap(find.byKey(const Key('training-new-course')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_writes(), isEmpty);
    });
  });

  group('Edit course', () {
    testWidgets('editor saves the web payload (with the assessment link)', (tester) async {
      await _pumpRouter(tester, _all, at: '/dashboard/training/$_c1');
      expect(find.byKey(const Key('course-form')), findsOneWidget);
      expect(_srv.log, contains('GET /training/assessments/'));
      await tester.enterText(find.byKey(const Key('course-form-title')), 'Test Renamed');
      await tester.pump();
      await _tapVisible(tester, find.byKey(const Key('course-form-save')));
      final body = _srv.bodies['PATCH /training/courses/$_c1/'] as Map;
      expect(body['title'], 'Test Renamed');
      expect(body.containsKey('assessment'), isTrue);
      expect(body['assessment'], isNull);
      expect(body['category'], 'Safety');
      expect(find.text('Course saved.'), findsOneWidget);
    });

    testWidgets('without manage_assessments: no assessment list request and no assessment in the payload',
        (tester) async {
      await _pumpRouter(tester, ['training.view', 'training.edit'], at: '/dashboard/training/$_c1');
      expect(_srv.log, isNot(contains('GET /training/assessments/')));
      expect(find.byKey(const Key('course-form-assessment')), findsNothing);
      await _tapVisible(tester, find.byKey(const Key('course-form-save')));
      expect((_srv.bodies['PATCH /training/courses/$_c1/'] as Map).containsKey('assessment'), isFalse);
    });

    testWidgets('invalid form: error shown, Save disabled, nothing sent', (tester) async {
      await _pumpRouter(tester, _all, at: '/dashboard/training/$_c1');
      await tester.enterText(find.byKey(const Key('course-form-title')), '');
      await tester.pump();
      expect(find.text('Give the course a title.'), findsOneWidget);
      final save = tester.widget<ButtonStyleButton>(find.byKey(const Key('course-form-save')));
      expect(save.onPressed, isNull);
      await _tapVisible(tester, find.byKey(const Key('course-form-videos-optional')));
      expect(find.byKey(const Key('course-form-videos-optional-error')), findsOneWidget);
      expect(_writes(), isEmpty);
    });

    testWidgets('thumbnail: PNG uploads as multipart; cancel sends nothing', (tester) async {
      await _pumpRouter(tester, _all, at: '/dashboard/training/$_c1');
      await _tapVisible(tester, find.byKey(const Key('course-form-thumbnail')));
      expect(_writes(), isEmpty); // picker cancelled
      expect(_pickedExtensions, ['png', 'jpg', 'jpeg']);
      _nextPick = TrainingUploadFile(name: 'thumb.png', bytes: Uint8List.fromList([0x89, 0x50, 0x4E, 0x47]));
      await _tapVisible(tester, find.byKey(const Key('course-form-thumbnail')));
      final fd = _srv.bodies['POST /training/courses/$_c1/thumbnail/'] as FormData;
      expect(fd.files.single.key, 'thumbnail');
      expect(fd.files.single.value.filename, 'thumb.png');
      expect(find.text('Thumbnail updated.'), findsOneWidget);
    });

    testWidgets('view-only user gets read-only details, no form', (tester) async {
      await _pumpRouter(tester, ['training.view'], at: '/dashboard/training/$_c1');
      expect(find.byKey(const Key('course-form')), findsNothing);
      expect(find.byKey(const Key('training-details')), findsOneWidget);
    });
  });

  group('Materials management', () {
    testWidgets('editor controls: required toggle, reorder, set length, remove (confirmed)', (tester) async {
      await _pumpRouter(tester, _all, at: '/dashboard/training/$_c1');
      await _tab(tester, 'Materials');
      await _tapVisible(tester, find.byKey(const Key('material-required-m1')));
      expect(_srv.bodies['PATCH /training/materials/m1/'], {'is_required': false});

      await _tapVisible(tester, find.byKey(const Key('material-down-m1')));
      expect(_srv.bodies['POST /training/courses/$_c1/materials/reorder/'], {
        'order': ['m2', 'm1', 'm3']
      });

      await _tapVisible(tester, find.byKey(const Key('material-set-length-m2')));
      await tester.enterText(find.byKey(const Key('material-length-input')), '12:30');
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Save')));
      await tester.pumpAndSettle();
      expect(_srv.bodies['PATCH /training/materials/m2/'], {'duration_seconds': 750});

      await _tapVisible(tester, find.byKey(const Key('material-remove-m3')));
      expect(find.textContaining("Employees' progress history is kept"), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_srv.log.where((l) => l.startsWith('DELETE')), isEmpty);
      await _tapVisible(tester, find.byKey(const Key('material-remove-m3')));
      await tester.tap(find.widgetWithText(FilledButton, 'Remove'));
      await tester.pumpAndSettle();
      expect(_srv.log, contains('DELETE /training/materials/m3/'));
    });

    testWidgets('add a video link: client checks first, then the web JSON body', (tester) async {
      await _pumpRouter(tester, _all, at: '/dashboard/training/$_c1');
      await _tab(tester, 'Materials');
      await _tapVisible(tester, find.byKey(const Key('add-material-toggle')));
      await _tapVisible(tester, find.byKey(const Key('add-material-kind-external_video')));
      await _tapVisible(tester, find.byKey(const Key('add-material-submit')));
      expect(find.text('Give the material a title.'), findsOneWidget);
      expect(find.text('Paste the video link.'), findsOneWidget);
      expect(_writes(), isEmpty);
      await tester.enterText(find.byKey(const Key('add-material-title')), 'Test Intro');
      await tester.enterText(find.byKey(const Key('add-material-link')), 'https://youtu.be/abcdefghijk');
      await tester.pump();
      await _tapVisible(tester, find.byKey(const Key('add-material-submit')));
      expect(find.text('Enter the video length.'), findsOneWidget);
      expect(_writes(), isEmpty);
      await tester.enterText(find.byKey(const Key('add-material-dur-min')), '3');
      await tester.pump();
      await _tapVisible(tester, find.byKey(const Key('add-material-submit')));
      expect(_srv.bodies['POST /training/courses/$_c1/materials/'], {
        'material_type': 'external_video', 'title': 'Test Intro', 'external_url': 'https://youtu.be/abcdefghijk',
        'is_required': true, 'allow_manual_completion': false, 'duration_seconds': 180,
      });
    });

    testWidgets('upload a document: picked file sent as multipart with the web fields', (tester) async {
      await _pumpRouter(tester, _all, at: '/dashboard/training/$_c1');
      await _tab(tester, 'Materials');
      await _tapVisible(tester, find.byKey(const Key('add-material-toggle')));
      _nextPick = TrainingUploadFile(name: 'handbook.pdf', bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')));
      await _tapVisible(tester, find.byKey(const Key('add-material-file')));
      expect(_pickedExtensions, ['pdf', 'pptx', 'docx']);
      await tester.enterText(find.byKey(const Key('add-material-title')), 'Test Handbook');
      await tester.enterText(find.byKey(const Key('add-material-min-view')), '2');
      await tester.pump();
      await _tapVisible(tester, find.byKey(const Key('add-material-submit')));
      final fd = _srv.bodies['POST /training/courses/$_c1/materials/'] as FormData;
      expect(Map.fromEntries(fd.fields), {
        'material_type': 'document', 'title': 'Test Handbook', 'is_required': 'true', 'min_view_seconds': '120',
      });
      expect(fd.files.single.key, 'file');
      expect(fd.files.single.value.filename, 'handbook.pdf');
    });

    testWidgets('a file over the limit is refused before upload', (tester) async {
      await _pumpRouter(tester, _all, at: '/dashboard/training/$_c1');
      await _tab(tester, 'Materials');
      await _tapVisible(tester, find.byKey(const Key('add-material-toggle')));
      _nextPick = TrainingUploadFile(name: 'big.pdf', bytes: Uint8List(10 * 1024 * 1024));
      await _tapVisible(tester, find.byKey(const Key('add-material-file')));
      await tester.enterText(find.byKey(const Key('add-material-title')), 'Big');
      await tester.pump();
      await _tapVisible(tester, find.byKey(const Key('add-material-submit')));
      expect(find.text('The file must be 9 MB or smaller.'), findsOneWidget);
      expect(_writes(), isEmpty);
    });

    testWidgets('view-only: no edit controls, no Add form', (tester) async {
      await _pumpRouter(tester, ['training.view'], at: '/dashboard/training/$_c1');
      await _tab(tester, 'Materials');
      expect(find.byKey(const Key('material-remove-m1')), findsNothing);
      expect(find.byKey(const Key('add-material')), findsNothing);
    });
  });

  group('CSV export', () {
    testWidgets('exports the filtered report and hands it to the saver', (tester) async {
      await _pumpRouter(tester, _all);
      await tester.tap(find.byKey(const Key('training-tab-reports')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('training-report-export')));
      await tester.pumpAndSettle();
      expect(_srv.log, contains('GET /training/reports/?export=csv'));
      expect(_saved!.$1, 'training-report.csv');
      expect(utf8.decode(_saved!.$2), startsWith('Employee,Course'));
      expect(find.text('Report saved.'), findsOneWidget);
      expect(_writes(), isEmpty);
    });

    testWidgets('failure is reported and nothing is saved', (tester) async {
      await _pumpRouter(tester, _all, configure: (s) => s.failCsv = true);
      await tester.tap(find.byKey(const Key('training-tab-reports')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('training-report-export')));
      await tester.pumpAndSettle();
      expect(_saved, isNull);
      expect(find.byType(SnackBar), findsOneWidget); // the failure is reported
    });
  });

  group('HO-47 PowerPoint / Word', () {
    Future<void> pumpLearner(WidgetTester tester, {String status = 'in_progress', void Function(_BServer)? configure}) async {
      tester.view.physicalSize = const Size(720, 1640);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      _reset(configure);
      final t = MyTraining.fromJson({
        'id': 'as1', 'status': status, 'course': _course(),
        'materials': [_material('m3', 'document', format: 'pptx')],
      });
      await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
        overrides: _overrides(const []),
        child: MaterialApp(home: MyMaterialScreen(training: t, material: t.materials!.single)),
      ));
      await tester.pumpAndSettle();
    }

    testWidgets('learner: nothing on screen open; tap records "open" then hands the file over', (tester) async {
      await pumpLearner(tester);
      expect(_srv.log, isEmpty);
      await _realAsyncTap(tester, find.byKey(const Key('my-material-open-office')));
      expect(_writes(), ['POST /training/my/as1/materials/m3/open/']);
      expect(_srv.log, contains('GET /training/materials/m3/file/'));
      expect(_officeLaunch!.$1, endsWith('training-material.pptx'));
      expect(_officeLaunch!.$2, 'application/vnd.openxmlformats-officedocument.presentationml.presentation');
      expect(find.text('I have read this'), findsOneWidget); // now opened → confirm offered
    });

    testWidgets('closed course: the file opens but nothing is recorded', (tester) async {
      await pumpLearner(tester, status: 'failed');
      await _realAsyncTap(tester, find.byKey(const Key('my-material-open-office')));
      expect(_writes(), isEmpty);
    });

    testWidgets('not a real Office file: refused, not handed over', (tester) async {
      await pumpLearner(tester, configure: (s) => s.officeBytes = Uint8List.fromList(utf8.encode('<html>')));
      await _realAsyncTap(tester, find.byKey(const Key('my-material-open-office')));
      expect(_officeLaunch, isNull);
      expect(find.text('The file could not be opened. Please try again.'), findsOneWidget);
    });

    testWidgets('admin: opens in another app without any learner write', (tester) async {
      await _pumpRouter(tester, ['training.view'], at: '/dashboard/training/$_c1');
      await _tab(tester, 'Materials');
      await tester.ensureVisible(find.byKey(const Key('training-material-office-m3')));
      await tester.pumpAndSettle();
      await _realAsyncTap(tester, find.byKey(const Key('training-material-office-m3')));
      expect(_officeLaunch, isNotNull);
      expect(_writes(), isEmpty);
    });
  });

  group('course-opening parity switch', () {
    Future<void> pumpCourse(WidgetTester tester, {required bool autoOpen, String status = 'assigned'}) async {
      tester.view.physicalSize = const Size(720, 1640);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      _reset((s) => s.myStatus = status);
      await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
        overrides: _overrides(const []),
        child: MaterialApp(home: MyCourseScreen(assignmentId: 'as1', autoOpenFirstMaterial: autoOpen)),
      ));
      await tester.pumpAndSettle();
    }

    test('default is OFF', () => expect(kMyLearningAutoOpenFirstMaterial, isFalse));

    testWidgets('OFF: the course page records nothing', (tester) async {
      await pumpCourse(tester, autoOpen: false);
      expect(find.byType(MyMaterialScreen), findsNothing);
      expect(_writes(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ON (web parity): the first unfinished material opens and records "open"', (tester) async {
      await pumpCourse(tester, autoOpen: true);
      expect(find.byType(MyMaterialScreen), findsOneWidget);
      expect(_writes(), ['POST /training/my/as1/materials/next/open/']);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ON but the course is closed: nothing opens', (tester) async {
      await pumpCourse(tester, autoOpen: true, status: 'failed');
      expect(find.byType(MyMaterialScreen), findsNothing);
      expect(_writes(), isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('HO-46', () {
    testWidgets('long app-bar title is scaled to fit instead of cut off', (tester) async {
      tester.view.physicalSize = const Size(720, 1640);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
        child: MaterialApp(
          home: Scaffold(
            appBar: AppTopBar(
              title: 'Training & Learning',
              onMenuTap: () {},
              onLogoutTap: () {},
              onThemeToggleTap: () {},
              onSearchTap: () {},
              isDarkMode: false,
              isBlueTheme: true,
            ),
          ),
        ),
      ));
      expect(find.text('Training & Learning'), findsOneWidget);
      // Scaled at layout time (survives a late font load), at most to 75%.
      expect(find.byKey(const Key('app-top-bar-title-fit')), findsOneWidget);
      final fitted = tester.getSize(find.byKey(const Key('app-top-bar-title-fit')));
      final row = tester.getSize(find.byType(Expanded).first);
      expect(fitted.width, lessThanOrEqualTo(row.width + 0.5));
      expect(tester.takeException(), isNull);
    });


    testWidgets('progress bars are hidden from screen readers (text states the value)', (tester) async {
      await _pumpRouter(tester, _all);
      await tester.tap(find.byKey(const Key('training-tab-reports')));
      await tester.pumpAndSettle();
      final bar = find.byType(LinearProgressIndicator).first;
      expect(find.ancestor(of: bar, matching: find.byType(ExcludeSemantics)), findsWidgets);
      expect(find.text('0% progress'), findsOneWidget);
    });
  });
}

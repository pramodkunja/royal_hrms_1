import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/core/router/access_control.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/dashboard/presentation/navigation/nav_config.dart';
import 'package:mobile_app/features/training/data/models/training_models.dart';
import 'package:mobile_app/features/training/presentation/screens/training_course_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/training_screen.dart';

import '../../core/permissions/p0_permission_parity_test.dart' as h;

// Task 90 batch 1: Training & Learning admin screens. Contract from backend
// apps/training/views.py and web app/dashboard/training. A stand-in server
// with synthetic data; nothing is sent anywhere.

ResponseBody _json(Object body, [int status = 200]) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> _ok(Object data, [String message = 'ok']) => {'status': 'success', 'message': message, 'data': data};
Map<String, dynamic> _deny() => {'status': 'error', 'message': 'You do not have permission to perform this action.'};

const _c1 = 'c1111111-0000-0000-0000-000000000001';
const _c2 = 'c2222222-0000-0000-0000-000000000002';

Map<String, dynamic> _course(String id, String title,
        {bool active = true, bool archived = false, String category = 'Safety', String? deadline}) =>
    {
      'id': id,
      'title': title,
      'description': 'Test description',
      'category': category,
      'owner': null,
      'trainer_name': 'Test Trainer',
      'has_thumbnail': false,
      'duration_minutes': 45,
      'is_mandatory': true,
      'is_active': active,
      'start_date': null,
      'deadline': deadline,
      'assessment': {'id': 'a1', 'title': 'Test Quiz', 'pass_percentage': 70},
      'videos_optional': false,
      'auto_assign_new_joiners': false,
      'new_joiner_deadline_days': 30,
      'new_joiner_branches': [],
      'new_joiner_departments': [],
      'archived': archived,
      'created_at': '2026-11-01T10:00:00',
      'assigned_count': 3,
      'completed_count': 1,
      'material_count': 2,
    };

Map<String, dynamic> _row(String id, String status, {String? startedAt, int? best}) => {
      'id': id,
      'employee': {'id': 'u-$id', 'name': 'Test Person $id', 'employee_id': 'T-$id', 'branch': 'Test Branch', 'department': 'Test Ops'},
      'course_id': _c1,
      'course_title': 'Test Safety Course',
      'status': status,
      'source': 'individual',
      'due_date': '2026-12-31',
      'assigned_at': '2026-11-02T10:00:00',
      'started_at': startedAt,
      'completed_at': null,
      'attempts_used': 1,
      'best_score_percent': best,
      'assessment_passed': null,
      'progress_percent': 50,
    };

class _TServer extends h.Server {
  final log = <String>[];
  final bodies = <String, Object?>{};
  bool denyDashboard = false;
  bool denyCourses = false;
  bool emptyCourses = false;
  Map<String, dynamic> detail = {
    ..._course(_c1, 'Test Safety Course', deadline: '2099-01-31'),
    'materials': [
      {
        'id': 'm1', 'title': 'Test Handbook', 'description': '', 'material_type': 'document', 'order': 1,
        'is_required': true, 'file_format': 'pdf', 'file_size': 204800, 'original_name': 'h.pdf', 'provider': '',
        'embed_id': '', 'external_url': '', 'duration_seconds': null, 'min_view_seconds': 60,
        'allow_manual_completion': false, 'is_tracked': false, 'is_archived': false,
      },
      {
        'id': 'm2', 'title': 'Test Intro Video', 'description': '', 'material_type': 'external_video', 'order': 2,
        'is_required': true, 'file_format': '', 'file_size': 0, 'original_name': '', 'provider': 'youtube',
        'embed_id': 'abcdefghijk', 'external_url': 'https://www.youtube.com/watch?v=abcdefghijk',
        'duration_seconds': 300, 'min_view_seconds': 0, 'allow_manual_completion': false, 'is_tracked': true,
        'is_archived': false,
      },
    ],
  };

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    final q = o.queryParameters.isEmpty ? '' : '?${Uri(queryParameters: o.queryParameters.map((k, v) => MapEntry(k, '$v'))).query}';
    final key = '${o.method} ${o.path}$q';
    log.add(key);
    if (o.method != 'GET') bodies['${o.method} ${o.path}'] = o.data;
    switch ('${o.method} ${o.path}') {
      case 'GET ${ApiConstants.trainingDashboard}':
        if (denyDashboard) return _json(_deny(), 403);
        return _json(_ok({
          'total_courses': 2, 'active_courses': 1, 'employees_assigned': 3, 'assigned': 4, 'completed': 1,
          'in_progress': 1, 'not_started': 1, 'overdue': 1, 'failed': 0, 'assessment_passed': 1,
          'assessment_failed': 0, 'completion_percent': 25,
        }));
      case 'GET ${ApiConstants.trainingCourses}':
        if (denyCourses) return _json(_deny(), 403);
        if (emptyCourses) return _json(_ok([]));
        final archived = o.queryParameters['archived'] == 1;
        return _json(_ok([
          _course(_c1, 'Test Safety Course'),
          _course(_c2, 'Test Compliance Basics', category: 'Compliance', active: false),
          if (archived) _course('c3', 'Test Old Course', archived: true, active: false),
        ]));
      case 'GET ${ApiConstants.trainingEmployees}':
        return _json(_ok({
          'employees': [
            {'id': 'e1', 'name': 'Test Alpha', 'employee_id': 'T-1', 'branch': 'Test Branch', 'department': 'Test Ops'},
            {'id': 'e2', 'name': 'Test Beta', 'employee_id': 'T-2', 'branch': 'Test Branch', 'department': 'Test Sales'},
          ],
          'departments': ['Test Ops', 'Test Sales'],
          'branches': ['Test Branch'],
        }));
      case 'GET ${ApiConstants.trainingReports}':
        return _json(_ok([_row('r1', 'completed', best: 90)]));
      case 'POST /training/courses/$_c1/assign/':
        return _json(_ok({'assigned': 1, 'already_assigned': 0}, 'Assigned to 1 employee(s).'));
    }
    if (o.method == 'GET' && o.path == ApiConstants.trainingCourse(_c1)) return _json(_ok(detail));
    if (o.method == 'GET' && o.path == ApiConstants.trainingCourseProgress(_c1)) {
      return _json(_ok([
        _row('p1', 'assigned'),
        _row('p2', 'failed', startedAt: '2026-11-03T09:00:00', best: 40),
        _row('p3', 'in_progress', startedAt: '2026-11-03T09:00:00'),
      ]));
    }
    return super.fetch(o, s, c);
  }
}

late _TServer _srv;

UserEntity _user(List<String> perms, {List<String>? modules}) => UserEntity(
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
      enabledModules: modules,
    );

const _admin = [
  'training.view', 'training.create', 'training.edit', 'training.delete', 'training.assign',
  'training.view_all_progress', 'training.manage_assessments', 'training.view_reports',
];

Future<void> _pump(WidgetTester tester, List<String> perms,
    {String at = '/dashboard/training', void Function(_TServer)? configure}) async {
  tester.view.physicalSize = const Size(720, 1640);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  _srv = _TServer();
  configure?.call(_srv);
  h.server = _srv;
  await tester.pumpWidget(ProviderScope(
    overrides: h.overrides(_user(perms)),
    child: MaterialApp.router(
      routerConfig: GoRouter(initialLocation: at, routes: [
        GoRoute(
          path: '/dashboard/training',
          builder: (_, __) => const Scaffold(body: TrainingScreen()),
          routes: [
            GoRoute(
              path: ':courseId',
              builder: (_, st) => TrainingCourseScreen(courseId: st.pathParameters['courseId']!),
            ),
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

Iterable<String> _writes() => _srv.log.where((l) => !l.startsWith('GET '));

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('models', () {
    test('course, material and assignment rows parse the backend shape', () {
      final c = TrainingCourse.fromJson(_TServer().detail);
      expect(c.title, 'Test Safety Course');
      expect(c.assessment?.passPercentage, 70);
      expect(c.materials, hasLength(2));
      expect(c.materials!.first.isPdf, isTrue);
      expect(c.materials![1].kindLabel, 'YouTube');
      expect(c.summaryLine, 'Safety · Mandatory');
      final r = TrainingAssignmentRow.fromJson(_row('x', 'overdue'));
      expect(r.status, TrainingStatus.overdue);
      expect(r.employee.subtitle, 'T-x · Test Ops · Test Branch');
      expect(TrainingStatus.parse('nonsense'), TrainingStatus.assigned);
    });

    test('missing fields fall back instead of throwing', () {
      final c = TrainingCourse.fromJson(const {});
      expect(c.title, '');
      expect(c.isActive, isTrue);
      expect(c.materials, isNull);
      expect(TrainingDashboard.fromJson(const {}).completionPercent, 0);
    });

    test('assign body sends only the chosen mode (web AssignPanel)', () {
      const people = AssignRequest(mode: AssignMode.people, employeeIds: ['e1'], departments: ['X'], dueDate: '2099-01-01');
      expect(people.toJson(),
          {'employee_ids': ['e1'], 'departments': <String>[], 'branches': <String>[], 'all': false, 'due_date': '2099-01-01'});
      const groups = AssignRequest(mode: AssignMode.groups, employeeIds: ['e1'], branches: ['B']);
      expect(groups.toJson()['employee_ids'], isEmpty);
      expect(groups.toJson()['branches'], ['B']);
      expect(groups.toJson()['due_date'], isNull);
      expect(const AssignRequest(mode: AssignMode.all).toJson()['all'], isTrue);
      expect(const AssignRequest(mode: AssignMode.people).isReady, isFalse);
      expect(const AssignRequest(mode: AssignMode.groups).isReady, isFalse);
      expect(const AssignRequest(mode: AssignMode.all).isReady, isTrue);
    });

    test('report filter sends only set values; duration/bytes formats match web', () {
      expect(const TrainingReportFilter().toQuery(), isEmpty);
      expect(const TrainingReportFilter(status: 'overdue', from: '2026-01-01').toQuery(),
          {'status': 'overdue', 'from': '2026-01-01'});
      expect(formatTrainingDuration(3900), '1h 5m');
      expect(formatTrainingDuration(200), '3m 20s');
      expect(formatTrainingDuration(0), '');
      expect(formatTrainingBytes(204800), '200 KB');
      expect(formatTrainingBytes(3 * 1024 * 1024), '3.0 MB');
    });
  });

  group('access and navigation', () {
    bool inNav(UserEntity u) => buildNav(u).whereType<NavItem>().any((i) => i.path == '/dashboard/training');

    test('menu item and route need training.view and the training module', () {
      expect(inNav(_user(['training.view'])), isTrue);
      expect(canAccessPath(_user(['training.view']), '/dashboard/training/$_c1'), isTrue);
      expect(inNav(_user(['leave.view'])), isFalse);
      expect(canAccessPath(_user(['leave.view']), '/dashboard/training'), isFalse);
      expect(inNav(_user(['training.view'], modules: ['leave'])), isFalse);
      expect(canAccessPath(_user(['training.view'], modules: ['leave']), '/dashboard/training'), isFalse);
      expect(inNav(_user(['training.view'], modules: ['training'])), isTrue);
      expect(pageTitle('/dashboard/training'), 'Training & Learning');
    });
  });

  group('Training screen', () {
    testWidgets('dashboard figures and the course list load', (tester) async {
      await _pump(tester, _admin);
      expect(find.byKey(const Key('training-stats')), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
      expect(find.text('1 (25%)'), findsOneWidget);
      expect(find.text('Test Safety Course'), findsOneWidget);
      expect(find.text('Test Compliance Basics'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.byKey(const Key('training-tab-reports')), findsOneWidget);
      expect(find.byKey(const Key('training-new-course')), findsOneWidget); // batch 3: New Course
      expect(_writes(), isEmpty);
    });

    testWidgets('search filters by title or category; Show archived asks the server', (tester) async {
      await _pump(tester, _admin);
      await tester.enterText(find.byKey(const Key('training-search')), 'compliance');
      await tester.pump();
      expect(find.text('Test Safety Course'), findsNothing);
      expect(find.text('Test Compliance Basics'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('training-search')), 'zzz');
      await tester.pump();
      expect(find.text('No courses match your search.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('training-search')), '');
      await tester.tap(find.byKey(const Key('training-show-archived')));
      await tester.pumpAndSettle();
      expect(_srv.log, contains('GET ${ApiConstants.trainingCourses}?archived=1'));
      await tester.enterText(find.byKey(const Key('training-search')), 'old');
      await tester.pump();
      expect(find.text('Test Old Course'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);
    });

    testWidgets('view-only user: no Reports tab, no stats on 403, no create note', (tester) async {
      await _pump(tester, ['training.view'], configure: (s) => s.denyDashboard = true);
      expect(find.byKey(const Key('training-stats')), findsNothing);
      expect(find.byKey(const Key('training-tab-reports')), findsNothing);
      expect(find.byKey(const Key('training-new-course')), findsNothing);
      expect(find.text('Test Safety Course'), findsOneWidget);
    });

    testWidgets('empty and error states', (tester) async {
      await _pump(tester, _admin, configure: (s) => s.emptyCourses = true);
      expect(find.text('No courses yet.'), findsOneWidget);
      await _pump(tester, _admin, configure: (s) => s.denyCourses = true);
      expect(find.textContaining('You do not have permission'), findsWidgets);
    });

    testWidgets('Reports: rows load and a filter is sent as a query parameter', (tester) async {
      await _pump(tester, _admin);
      await tester.tap(find.byKey(const Key('training-tab-reports')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('training-report-count')), findsOneWidget);
      expect(find.text('1 record(s)'), findsOneWidget);
      expect(find.text('Best score 90%'), findsOneWidget);
      await tester.tap(find.byKey(const Key('training-report-status')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Overdue').last);
      await tester.pumpAndSettle();
      expect(_srv.log, contains('GET ${ApiConstants.trainingReports}?status=overdue'));
      expect(_writes(), isEmpty);
    });

    testWidgets('no overflow at 1.5x text on a phone-sized screen', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pump(tester, _admin);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const Key('training-tab-reports')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('Course screen', () {
    testWidgets('admin sees Details, Materials, Assign, Progress and Delete', (tester) async {
      await _pump(tester, _admin, at: '/dashboard/training/$_c1');
      for (final t in ['Details', 'Materials', 'Assign', 'Progress']) {
        expect(find.byKey(Key('training-course-tab-$t')), findsOneWidget, reason: t);
      }
      expect(find.byKey(const Key('training-course-delete')), findsOneWidget);
      // Batch 3: editors get the course form (read-only details for others).
      expect(find.byKey(const Key('course-form')), findsOneWidget);
    });

    testWidgets('view-only user: no Assign tab, no Delete', (tester) async {
      await _pump(tester, ['training.view'], at: '/dashboard/training/$_c1');
      expect(find.byKey(const Key('training-course-tab-Assign')), findsNothing);
      expect(find.byKey(const Key('training-course-delete')), findsNothing);
      expect(find.byKey(const Key('training-edit-on-web')), findsNothing);
      expect(find.text('Test Quiz (pass mark 70%)'), findsOneWidget); // read-only details
    });

    testWidgets('archived course: no Assign, no Delete even for admin', (tester) async {
      await _pump(tester, _admin,
          at: '/dashboard/training/$_c1',
          configure: (s) => s.detail = {...s.detail, 'archived': true, 'is_active': false});
      expect(find.byKey(const Key('training-course-tab-Assign')), findsNothing);
      expect(find.byKey(const Key('training-course-delete')), findsNothing);
    });

    testWidgets('Materials: PDF preview and external link offered; link opens via launcher', (tester) async {
      await _pump(tester, _admin, at: '/dashboard/training/$_c1');
      await _tab(tester, 'Materials');
      expect(find.text('1. Test Handbook'), findsOneWidget);
      expect(find.byKey(const Key('training-material-preview-m1')), findsOneWidget);
      expect(find.textContaining('min. 1m reading'), findsOneWidget);
      expect(find.byKey(const Key('training-material-open-m2')), findsOneWidget);
    });

    testWidgets('Delete asks first; Cancel sends nothing', (tester) async {
      await _pump(tester, _admin, at: '/dashboard/training/$_c1');
      await tester.tap(find.byKey(const Key('training-course-delete')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Courses with training history are archived instead'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_writes(), isEmpty);
    });

    testWidgets('Progress: Reset only on failed rows, Remove only on unstarted rows; Cancel sends nothing',
        (tester) async {
      await _pump(tester, _admin, at: '/dashboard/training/$_c1');
      await _tab(tester, 'Progress');
      expect(find.byKey(const Key('training-remove-p1')), findsOneWidget);
      expect(find.byKey(const Key('training-reset-p1')), findsNothing);
      expect(find.byKey(const Key('training-reset-p2')), findsOneWidget);
      expect(find.byKey(const Key('training-remove-p2')), findsNothing);
      expect(find.byKey(const Key('training-reset-p3')), findsNothing);
      expect(find.byKey(const Key('training-remove-p3')), findsNothing);
      await tester.tap(find.byKey(const Key('training-remove-p1')));
      await tester.pumpAndSettle();
      expect(find.text('Remove this course from Test Person p1?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_writes(), isEmpty);
    });

    testWidgets('Progress actions hidden without assign / manage_assessments', (tester) async {
      await _pump(tester, ['training.view', 'training.view_all_progress'], at: '/dashboard/training/$_c1');
      await _tab(tester, 'Progress');
      expect(find.text('Test Person p1'), findsOneWidget);
      expect(find.byKey(const Key('training-remove-p1')), findsNothing);
      expect(find.byKey(const Key('training-reset-p2')), findsNothing);
    });
  });

  group('Assign', () {
    Future<void> openAssign(WidgetTester tester, {void Function(_TServer)? configure}) async {
      await _pump(tester, _admin, at: '/dashboard/training/$_c1', configure: configure);
      await _tab(tester, 'Assign');
    }

    bool enabled(WidgetTester t) =>
        t.widget<ButtonStyleButton>(find.byKey(const Key('training-assign-submit'))).onPressed != null;

    testWidgets('disabled until someone is chosen; due date defaults to the course deadline', (tester) async {
      await openAssign(tester);
      expect(enabled(tester), isFalse);
      expect(find.text('No employees selected'), findsOneWidget);
      expect(find.text('Due 2099-01-31'), findsOneWidget);
      await tester.tap(find.byKey(const Key('training-assign-emp-e1')));
      await tester.pump();
      expect(find.text('1 employee selected'), findsOneWidget);
      expect(enabled(tester), isTrue);
    });

    testWidgets('confirmation is required; Cancel sends no POST', (tester) async {
      await openAssign(tester);
      await tester.tap(find.byKey(const Key('training-assign-emp-e1')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('training-assign-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Assign course?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(_writes(), isEmpty);
    });

    testWidgets('confirmed assignment posts the web body, shows the server message and opens Progress',
        (tester) async {
      await openAssign(tester);
      await tester.tap(find.byKey(const Key('training-assign-emp-e2')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('training-assign-submit')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Assign').last);
      await tester.pumpAndSettle();
      expect(_writes(), ['POST /training/courses/$_c1/assign/']);
      expect(_srv.bodies['POST /training/courses/$_c1/assign/'],
          {'employee_ids': ['e2'], 'departments': <String>[], 'branches': <String>[], 'all': false, 'due_date': '2099-01-31'});
      expect(find.text('Assigned to 1 employee(s).'), findsOneWidget);
      expect(find.byKey(const Key('training-progress')), findsOneWidget);
    });

    testWidgets('groups mode: department chips build the selection', (tester) async {
      await openAssign(tester);
      await tester.tap(find.byKey(const Key('training-assign-mode-groups')));
      await tester.pumpAndSettle();
      expect(enabled(tester), isFalse);
      await tester.tap(find.byKey(const Key('training-assign-dept-Test Ops')));
      await tester.pump();
      expect(find.text('1 department'), findsOneWidget);
      expect(enabled(tester), isTrue);
    });

    testWidgets('inactive course: warning shown and Assign stays disabled', (tester) async {
      await openAssign(tester, configure: (s) => s.detail = {...s.detail, 'is_active': false});
      expect(find.byKey(const Key('training-assign-inactive')), findsOneWidget);
      await tester.tap(find.byKey(const Key('training-assign-mode-all')));
      await tester.pumpAndSettle();
      expect(enabled(tester), isFalse);
    });
  });

  group('launcher', () {
    testWidgets('external link goes through the launcher provider only', (tester) async {
      Uri? opened;
      _srv = _TServer();
      h.server = _srv;
      tester.view.physicalSize = const Size(720, 1640);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          ...h.overrides(_user(_admin)),
          trainingLinkLauncherProvider.overrideWithValue((uri) async {
            opened = uri;
            return true;
          }),
        ],
        child: const MaterialApp(home: TrainingCourseScreen(courseId: _c1)),
      ));
      await tester.pumpAndSettle();
      await _tab(tester, 'Materials');
      await tester.tap(find.byKey(const Key('training-material-open-m2')));
      await tester.pumpAndSettle();
      expect(opened.toString(), 'https://www.youtube.com/watch?v=abcdefghijk');
      expect(_writes(), isEmpty);
    });
  });
}

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/auth/domain/entities/user_entity.dart';
import 'package:mobile_app/features/dashboard/presentation/widgets/app_top_bar.dart';
import 'package:mobile_app/features/training/presentation/screens/my_course_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/my_learning_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/training_course_screen.dart';
import 'package:mobile_app/features/training/presentation/screens/training_screen.dart';
import 'package:mobile_app/features/training/presentation/widgets/training_video_player.dart';
import 'package:mobile_app/core/theme/app_theme.dart';

import '../../core/permissions/p0_permission_parity_test.dart' as h;
import '../../visual/shot_harness.dart';

// Task 102: one stand-in Training API (admin + learner) shared by the redesign
// tests and the render-evidence test. Synthetic data only; nothing leaves the
// process. Contract: backend apps/training/views.py, web lib/training.ts.

ResponseBody tJson(Object body, [int status = 200]) => ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
Map<String, dynamic> tOk(Object data, [String m = 'ok']) => {'status': 'success', 'message': m, 'data': data};

const tAdminPerms = [
  'training.view',
  'training.create',
  'training.edit',
  'training.delete',
  'training.assign',
  'training.view_all_progress',
  'training.manage_assessments',
  'training.view_reports',
];

const tC1 = 'c1111111-0000-0000-0000-000000000001';
const tC2 = 'c2222222-0000-0000-0000-000000000002';

Map<String, dynamic> tCourse(String id, String title,
        {bool active = true,
        bool archived = false,
        String category = 'Safety',
        String? deadline,
        String description = 'How to work safely on site: evacuation, first aid and incident reporting.',
        bool mandatory = true,
        int assigned = 12,
        int completed = 5,
        int materials = 3,
        Map<String, dynamic>? assessment = const {'id': 'a1', 'title': 'Safety Quiz', 'pass_percentage': 70}}) =>
    {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'owner': null,
      'trainer_name': 'Test Trainer',
      'has_thumbnail': false,
      'duration_minutes': 45,
      'is_mandatory': mandatory,
      'is_active': active,
      'start_date': null,
      'deadline': deadline,
      'assessment': assessment,
      'videos_optional': false,
      'auto_assign_new_joiners': false,
      'new_joiner_deadline_days': 30,
      'new_joiner_branches': [],
      'new_joiner_departments': [],
      'archived': archived,
      'created_at': '2026-11-01T10:00:00',
      'assigned_count': assigned,
      'completed_count': completed,
      'material_count': materials,
    };

Map<String, dynamic> tMat(String id, String type,
        {String title = '',
        String format = '',
        String provider = '',
        String embed = '',
        String url = '',
        bool tracked = false,
        bool manual = false,
        int minView = 0,
        int? duration,
        bool required = true,
        int size = 204800,
        Map<String, dynamic>? progress}) =>
    {
      'id': id,
      'title': title.isEmpty ? 'Test $id' : title,
      'description': '',
      'material_type': type,
      'order': 1,
      'is_required': required,
      'file_format': format,
      'file_size': size,
      'original_name': '',
      'provider': provider,
      'embed_id': embed,
      'external_url': url,
      'duration_seconds': duration,
      'min_view_seconds': minView,
      'allow_manual_completion': manual,
      'is_tracked': tracked,
      'is_archived': false,
      if (progress != null) 'progress': progress,
    };

Map<String, dynamic> tProg({String? opened, String? completed, double watched = 0}) => {
      'opened_at': opened,
      'watched_seconds': watched,
      'last_position_seconds': 0,
      'duration_seconds': null,
      'completed_at': completed,
      'completion_method': '',
    };

Map<String, dynamic> tRow(String id, String status,
        {String name = 'Test Person',
        int pct = 50,
        int? best,
        String? started,
        String? due = '2026-12-31',
        String? completed,
        String course = 'Test Safety Course'}) =>
    {
      'id': id,
      'employee': {
        'id': 'u-$id',
        'name': '$name $id',
        'employee_id': 'T-$id',
        'branch': 'Test Branch',
        'department': 'Test Ops'
      },
      'course_id': tC1,
      'course_title': course,
      'status': status,
      'source': 'individual',
      'due_date': due,
      'assigned_at': '2026-11-02T10:00:00',
      'started_at': started,
      'completed_at': completed,
      'attempts_used': 1,
      'best_score_percent': best,
      'assessment_passed': null,
      'progress_percent': pct,
    };

Map<String, dynamic> tAssignment(String id, String status,
        {int pct = 0, String? startsOn, String? due, String? completed, String title = '', int? best}) =>
    {
      ...tRow(id, status, due: due, pct: pct, completed: completed, best: best),
      'employee': {'id': 'u1', 'name': 'Test User', 'employee_id': 'T-1', 'branch': '', 'department': ''},
      'course_title': title.isEmpty ? 'Course $id' : title,
      'course': {
        ...tCourse('c-$id', title.isEmpty ? 'Course $id' : title),
        'assigned_count': 0,
        'completed_count': 0,
      },
      'material_count': 3,
      'starts_on': startsOn,
    };

Map<String, dynamic> tAssess(
        {bool unlocked = true,
        bool canAttempt = true,
        bool? passed,
        int used = 0,
        int max = 3,
        bool hasQ = true,
        int? best}) =>
    {
      'required': true,
      'title': 'Safety Quiz',
      'pass_percentage': 70,
      'max_attempts': max,
      'attempts_used': used,
      'attempts_left': max == 0 ? null : max - used,
      'time_limit_mins': 15,
      'unlocked': unlocked,
      'can_attempt': canAttempt,
      'has_questions': hasQ,
      'starts_on': null,
      'passed': passed,
      'best_score_percent': best,
      'can_retake': passed == true && canAttempt,
      'last_result': null,
    };

class TrainingServer extends h.Server {
  final log = <String>[];
  final bodies = <String, Object?>{};

  int dashboardStatus = 200;
  int coursesStatus = 200;
  int courseStatus = 200;
  int progressStatus = 200;
  int reportsStatus = 200;
  int myStatus = 200;
  int myDetailStatus = 200;
  String denyMessage = 'You do not have permission to perform this action.';

  Map<String, dynamic> dashboard = {
    'total_courses': 8,
    'active_courses': 6,
    'employees_assigned': 42,
    'assigned': 60,
    'completed': 24,
    'in_progress': 18,
    'not_started': 12,
    'overdue': 6,
    'failed': 2,
    'assessment_passed': 20,
    'assessment_failed': 3,
    'completion_percent': 40,
  };

  late List<Map<String, dynamic>> courses = [
    tCourse(tC1, 'Workplace Safety Essentials', deadline: '2026-12-31'),
    tCourse(tC2, 'Compliance Basics',
        category: 'Compliance',
        active: false,
        assigned: 0,
        completed: 0,
        materials: 0,
        assessment: null,
        mandatory: false),
    tCourse('c3', 'Data Protection and Information Security Awareness for All Branch and Head Office Employees',
        category: 'Security',
        description:
            'A long description that goes on to explain what the course covers, who must take it, how long it takes and what happens when the deadline passes without completion.'),
  ];
  Map<String, dynamic> archivedCourse =
      tCourse('c9', 'Old Induction Course', archived: true, active: false, assigned: 4, completed: 4);

  late Map<String, dynamic> detail = {
    ...tCourse(tC1, 'Workplace Safety Essentials', deadline: '2099-01-31'),
    'materials': [
      tMat('m1', 'document', title: 'Safety Handbook', format: 'pdf', minView: 60),
      tMat('m2', 'external_video',
          title: 'Intro Video',
          provider: 'youtube',
          embed: 'abcdefghijk',
          url: 'https://www.youtube.com/watch?v=abcdefghijk',
          tracked: true,
          duration: 300),
      tMat('m3', 'document', title: 'Incident Checklist', format: 'pptx', required: false),
    ],
  };
  late List<Map<String, dynamic>> progress = [
    tRow('p1', 'assigned', pct: 0),
    tRow('p2', 'failed', started: '2026-11-03T09:00:00', best: 40, pct: 100),
    tRow('p3', 'in_progress', started: '2026-11-03T09:00:00'),
    tRow('p4', 'completed', started: '2026-11-03T09:00:00', pct: 100, best: 90, completed: '2026-11-10T09:00:00'),
  ];
  late List<Map<String, dynamic>> reports = [
    tRow('r1', 'completed', best: 90, pct: 100, completed: '2026-11-10T09:00:00'),
    tRow('r2', 'overdue', due: '2026-10-01', pct: 30),
  ];

  late List<Map<String, dynamic>> myList = [
    tAssignment('a-new', 'assigned', title: 'Workplace Safety Essentials', due: '2026-12-20'),
    tAssignment('a-prog', 'in_progress', pct: 50, title: 'Data Protection Awareness', due: '2026-12-05'),
    tAssignment('a-over', 'overdue', pct: 20, due: '2026-10-01', title: 'Anti-Harassment Policy'),
    tAssignment('a-done', 'completed', pct: 100, completed: '2026-11-10T09:00:00', title: 'Code of Conduct', best: 92),
    tAssignment('a-fail', 'failed', pct: 100, title: 'Fire Safety Refresher', best: 40),
  ];
  late Map<String, dynamic> myDetail = {
    ...tAssignment('a-prog', 'in_progress', pct: 50, title: 'Data Protection Awareness', due: '2026-12-05'),
    'materials': [
      tMat('m-pdf', 'document',
          title: 'Policy Handbook',
          format: 'pdf',
          minView: 60,
          progress: tProg(opened: '2026-11-18T10:00:00Z', completed: '2026-11-18T10:05:00Z')),
      tMat('m-yt', 'external_video',
          title: 'Awareness Video',
          provider: 'youtube',
          embed: 'abcdefghijk',
          url: 'https://www.youtube.com/watch?v=abcdefghijk',
          tracked: true,
          duration: 100,
          progress: tProg(watched: 30)),
      tMat('m-opt', 'document', title: 'Further Reading', format: 'pdf', required: false, progress: tProg()),
    ],
    'assessment': tAssess(unlocked: false, canAttempt: false),
  };
  Map<String, dynamic> Function(String materialId, String action)? onAction;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    final key = '${o.method} ${o.path}';
    log.add(key);
    if (o.method != 'GET') bodies[key] = o.data;
    ResponseBody status(int code, [String? msg]) =>
        tJson({'status': 'error', 'message': msg ?? (code == 403 ? denyMessage : 'Server error.')}, code);
    final p = o.path;
    if (o.method == 'GET') {
      if (p == ApiConstants.trainingDashboard) {
        return dashboardStatus == 200 ? tJson(tOk(dashboard)) : status(dashboardStatus);
      }
      if (p == ApiConstants.trainingCourses) {
        if (coursesStatus != 200) return status(coursesStatus);
        final archived = '${o.queryParameters['archived']}' == '1';
        return tJson(tOk([...courses, if (archived) archivedCourse]));
      }
      if (p == ApiConstants.trainingEmployees) {
        return tJson(tOk({
          'employees': [
            {'id': 'e1', 'name': 'Test Alpha', 'employee_id': 'T-1', 'branch': 'Test Branch', 'department': 'Test Ops'},
            {
              'id': 'e2',
              'name': 'Test Beta',
              'employee_id': 'T-2',
              'branch': 'Test Branch',
              'department': 'Test Sales'
            },
          ],
          'departments': ['Test Ops', 'Test Sales'],
          'branches': ['Test Branch'],
        }));
      }
      if (p == ApiConstants.trainingReports) return reportsStatus == 200 ? tJson(tOk(reports)) : status(reportsStatus);
      if (p == ApiConstants.trainingAssessmentOptions) {
        return tJson(tOk([
          {'id': 'a1', 'title': 'Safety Quiz', 'questions': 2, 'pass_percentage': 70},
        ]));
      }
      if (p == ApiConstants.trainingCourse(tC1)) return courseStatus == 200 ? tJson(tOk(detail)) : status(courseStatus);
      if (p == ApiConstants.trainingCourseProgress(tC1)) {
        return progressStatus == 200 ? tJson(tOk(progress)) : status(progressStatus);
      }
      if (p == ApiConstants.trainingMy) {
        if (myStatus == 403) {
          return tJson({'status': 'error', 'message': 'Training & Learning is not enabled for your company.'}, 403);
        }
        return myStatus == 200 ? tJson(tOk(myList)) : status(myStatus);
      }
      if (p.startsWith('/training/my/')) return myDetailStatus == 200 ? tJson(tOk(myDetail)) : status(myDetailStatus);
      if (p.endsWith('/file/')) {
        return ResponseBody.fromBytes(utf8.encode('%PDF-1.4 test'), 200, headers: {
          Headers.contentTypeHeader: ['application/pdf']
        });
      }
    }
    if (o.method == 'POST') {
      if (p == ApiConstants.trainingCourses) {
        return tJson(tOk(tCourse('c-new', '${(o.data as Map)['title']}'), 'Created'), 201);
      }
      if (p == ApiConstants.trainingCourseAssign(tC1)) {
        return tJson(tOk({'assigned': 1, 'already_assigned': 0}, 'Assigned to 1 employee(s).'));
      }
      final m = RegExp(r'^/training/my/[^/]+/materials/([^/]+)/(open|progress|confirm)/$').firstMatch(p);
      if (m != null) {
        final known = [
          for (final x in (myDetail['materials'] as List))
            if (x['id'] == m.group(1)) x as Map<String, dynamic>
        ];
        final mat = onAction?.call(m.group(1)!, m.group(2)!) ??
            (known.isNotEmpty
                ? {...known.first, 'progress': tProg(opened: '2026-11-18T10:00:00Z', watched: 30)}
                : tMat(m.group(1)!, 'document', format: 'pdf', progress: tProg(opened: '2026-11-18T10:00:00Z')));
        return tJson(tOk({'material': mat, 'status': 'in_progress', 'assessment': tAssess()}, 'Saved.'));
      }
      if (p.endsWith('/assessment/start/')) {
        return tJson(tOk({
          'attempt_id': 'at1',
          'attempt_number': 1,
          'started_at': '2026-11-18T10:00:00Z',
          'time_limit_mins': 15,
          'questions': [
            {
              'id': 'q1',
              'question': 'Which exit do you use when the alarm sounds?',
              'section': '',
              'options': [
                {'key': 'a', 'text': 'The nearest marked fire exit'},
                {'key': 'b', 'text': 'The lift'}
              ]
            },
            {
              'id': 'q2',
              'question': 'Who do you tell about a near miss?',
              'section': 'Reporting',
              'options': [
                {'key': 'a', 'text': 'Your supervisor, the same day'},
                {'key': 'b', 'text': 'Nobody'}
              ]
            },
          ],
        }, 'Assessment started.'));
      }
      if (p.endsWith('/assessment/submit/')) {
        return tJson(tOk({
          'score': 2,
          'max_score': 2,
          'percentage': 100,
          'pass_percentage': 70,
          'passed': true,
          'status': 'completed',
          'assessment': tAssess(passed: true, best: 100, used: 1)
        }, 'Assessment submitted.'));
      }
    }
    if (o.method == 'DELETE' || o.method == 'PATCH') return tJson(tOk(<String, dynamic>{}, 'Done.'));
    // Anything else (notification bell, etc.): the shared stand-in's empty success envelope.
    return super.fetch(o, s, c);
  }
}

UserEntity tUser(List<String> perms, {String role = 'hr_admin', List<String>? modules}) => UserEntity(
      id: 'u1',
      email: 'user@example.test',
      fullName: 'Test User',
      role: role,
      roleDisplay: role,
      mustChangePassword: false,
      permissions: perms,
      isSuperuser: false,
      onboardingStatus: 'complete',
      assessmentStatus: 'complete',
      enabledModules: modules,
    );

/// Records what the fake player was asked to do (no WebView in tests).
class TrainingFakes {
  Uri? launched;
}

/// The two shell screens sit under the dashboard's real blue AppTopBar.
Widget tShellFrame(String title, Widget child) => Scaffold(
      appBar: AppTopBar(
        title: title,
        onMenuTap: () {},
        onLogoutTap: () {},
        onThemeToggleTap: () {},
        isDarkMode: false,
        isBlueTheme: true,
      ),
      body: child,
    );

/// Pumps the whole Training area (admin + learner routes) as the app would.
/// [at] picks the first route. Shots draw under [shotFrame].
Future<TrainingServer> pumpTraining(
  WidgetTester tester, {
  List<String> perms = tAdminPerms,
  String at = '/dashboard/training',
  TrainingServer? server,
  Size size = const Size(390, 844),
  double textScale = 1,
  TrainingFakes? fakes,
  bool settle = true,
  double keyboard = 0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  if (keyboard > 0) tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  final s = server ?? TrainingServer();
  h.server = s;
  if (shotsEnabled) await tester.runAsync(loadShotFonts);
  await tester.pumpWidget(ProviderScope(
    key: UniqueKey(),
    overrides: [
      ...h.overrides(tUser(perms)),
      trainingVideoPlayerBuilderProvider.overrideWithValue(
          ({required material, required sourceUrl, required onBeat, required onError}) => Container(
              key: const Key('fake-player'),
              height: 180,
              color: Colors.black12,
              alignment: Alignment.center,
              child: const Text('Video player'))),
      trainingLinkLauncherProvider.overrideWithValue((uri) async {
        fakes?.launched = uri;
        return true;
      }),
    ],
    child: shotFrame(MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeFor(false),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      routerConfig: GoRouter(initialLocation: at, routes: [
        GoRoute(
          path: '/dashboard/training',
          builder: (_, __) => tShellFrame('Training & Learning', const TrainingScreen()),
          routes: [
            GoRoute(
                path: ':courseId', builder: (_, st) => TrainingCourseScreen(courseId: st.pathParameters['courseId']!)),
          ],
        ),
        GoRoute(
          path: '/dashboard/my-learning',
          builder: (_, __) => tShellFrame('My Learning', const MyLearningScreen()),
          routes: [
            GoRoute(path: ':id', builder: (_, st) => MyCourseScreen(assignmentId: st.pathParameters['id']!)),
          ],
        ),
      ]),
    )),
  ));
  if (settle) await tSettle(tester);
  return s;
}

/// pumpAndSettle that survives indefinite spinners: a bounded number of frames.
Future<void> tSettle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

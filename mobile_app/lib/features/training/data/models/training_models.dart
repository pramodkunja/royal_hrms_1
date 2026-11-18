import 'package:flutter/foundation.dart';

// Training & Learning — admin side (Task 90 batch 1).
//
// Contract: backend apps/training/views.py (course_out, material_out,
// assignment_row, DashboardView, EmployeePickerView) and web
// frontend/lib/training.ts. Every field is parsed defensively: a missing key
// falls back to an empty value instead of throwing.

String _s(Object? v) => v == null ? '' : '$v';
String? _sn(Object? v) => v == null || '$v'.isEmpty ? null : '$v';
int _i(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}') ?? 0;
int? _in(Object? v) => v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
bool _b(Object? v) => v == true;
List<String> _strings(Object? v) => v is List ? [for (final x in v) '$x'] : const [];
Map<String, dynamic> _map(Object? v) => v is Map ? v.cast<String, dynamic>() : const {};

/// Assignment status as the API reports it (`display_status`): "overdue" is
/// derived server-side from an open status plus a past due date.
enum TrainingStatus {
  assigned('assigned', 'Assigned'),
  inProgress('in_progress', 'In Progress'),
  completed('completed', 'Completed'),
  failed('failed', 'Failed Assessment'),
  overdue('overdue', 'Overdue');

  const TrainingStatus(this.api, this.label);
  final String api;
  final String label;

  static TrainingStatus parse(Object? v) =>
      TrainingStatus.values.firstWhere((s) => s.api == v, orElse: () => TrainingStatus.assigned);
}

@immutable
class TrainingPerson {
  const TrainingPerson({
    required this.id,
    required this.name,
    this.employeeId = '',
    this.branch = '',
    this.department = '',
  });

  final String id;
  final String name;
  final String employeeId;
  final String branch;
  final String department;

  factory TrainingPerson.fromJson(Map<String, dynamic> j) => TrainingPerson(
        id: _s(j['id']),
        name: _s(j['name']),
        employeeId: _s(j['employee_id']),
        branch: _s(j['branch']),
        department: _s(j['department']),
      );

  /// "EMP-1 · Department · Branch", empty parts left out (web ProgressTable).
  String get subtitle => [employeeId, department, branch].where((p) => p.isNotEmpty).join(' · ');
}

@immutable
class TrainingMaterial {
  const TrainingMaterial({
    required this.id,
    required this.title,
    required this.materialType,
    this.description = '',
    this.order = 0,
    this.isRequired = true,
    this.fileFormat = '',
    this.fileSize = 0,
    this.originalName = '',
    this.provider = '',
    this.externalUrl = '',
    this.durationSeconds,
    this.minViewSeconds = 0,
    this.allowManualCompletion = false,
    this.isTracked = false,
    this.embedId = '',
    this.progress,
  });

  final String id;
  final String title;

  /// video | document | external_video
  final String materialType;
  final String description;
  final int order;
  final bool isRequired;
  final String fileFormat;
  final int fileSize;
  final String originalName;

  /// youtube | vimeo | direct | '' (external videos only)
  final String provider;
  final String externalUrl;
  final int? durationSeconds;
  final int minViewSeconds;
  final bool allowManualCompletion;
  final bool isTracked;

  /// YouTube video id / Vimeo numeric id (external videos).
  final String embedId;

  /// My Learning only: this employee's progress (null on admin responses).
  final TrainingMaterialProgress? progress;

  bool get isDocument => materialType == 'document';
  bool get isUploadedVideo => materialType == 'video';
  bool get isExternal => materialType == 'external_video';
  bool get isPdf => isDocument && fileFormat.toLowerCase() == 'pdf';

  factory TrainingMaterial.fromJson(Map<String, dynamic> j) => TrainingMaterial(
        id: _s(j['id']),
        title: _s(j['title']),
        materialType: _s(j['material_type']),
        description: _s(j['description']),
        order: _i(j['order']),
        isRequired: j['is_required'] != false,
        fileFormat: _s(j['file_format']),
        fileSize: _i(j['file_size']),
        originalName: _s(j['original_name']),
        provider: _s(j['provider']),
        externalUrl: _s(j['external_url']),
        durationSeconds: _in(j['duration_seconds']),
        minViewSeconds: _i(j['min_view_seconds']),
        allowManualCompletion: _b(j['allow_manual_completion']),
        isTracked: _b(j['is_tracked']),
        embedId: _s(j['embed_id']),
        progress: j['progress'] is Map
            ? TrainingMaterialProgress.fromJson((j['progress'] as Map).cast<String, dynamic>())
            : null,
      );

  bool get isCompleted => progress?.completedAt != null;
  bool get isOpened => progress?.openedAt != null;

  /// Web materialKindLabel.
  String get kindLabel {
    if (isDocument) return (fileFormat.isEmpty ? 'document' : fileFormat).toUpperCase();
    if (isUploadedVideo) return 'Video';
    return switch (provider) { 'youtube' => 'YouTube', 'vimeo' => 'Vimeo', _ => 'Video link' };
  }
}

@immutable
class TrainingAssessmentRef {
  const TrainingAssessmentRef({required this.id, required this.title, this.passPercentage = 0});
  final String id;
  final String title;
  final int passPercentage;
}

@immutable
class TrainingCourse {
  const TrainingCourse({
    required this.id,
    required this.title,
    this.description = '',
    this.category = '',
    this.owner,
    this.trainerName = '',
    this.durationMinutes,
    this.isMandatory = false,
    this.isActive = true,
    this.startDate,
    this.deadline,
    this.assessment,
    this.videosOptional = false,
    this.autoAssignNewJoiners = false,
    this.newJoinerDeadlineDays = 30,
    this.newJoinerBranches = const [],
    this.newJoinerDepartments = const [],
    this.archived = false,
    this.assignedCount = 0,
    this.completedCount = 0,
    this.materialCount = 0,
    this.materials,
    this.hasThumbnail = false,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final bool hasThumbnail;
  final TrainingPerson? owner;
  final String trainerName;
  final int? durationMinutes;
  final bool isMandatory;
  final bool isActive;
  final String? startDate;
  final String? deadline;
  final TrainingAssessmentRef? assessment;
  final bool videosOptional;
  final bool autoAssignNewJoiners;
  final int newJoinerDeadlineDays;
  final List<String> newJoinerBranches;
  final List<String> newJoinerDepartments;
  final bool archived;

  /// List rows only (scoped to the viewer's assignment scope by the API).
  final int assignedCount;
  final int completedCount;
  final int materialCount;

  /// Detail responses only (active materials, in order).
  final List<TrainingMaterial>? materials;

  factory TrainingCourse.fromJson(Map<String, dynamic> j) {
    final owner = j['owner'];
    final a = j['assessment'];
    final mats = j['materials'];
    return TrainingCourse(
      id: _s(j['id']),
      title: _s(j['title']),
      description: _s(j['description']),
      category: _s(j['category']),
      hasThumbnail: _b(j['has_thumbnail']),
      owner: owner is Map ? TrainingPerson.fromJson(owner.cast<String, dynamic>()) : null,
      trainerName: _s(j['trainer_name']),
      durationMinutes: _in(j['duration_minutes']),
      isMandatory: _b(j['is_mandatory']),
      isActive: j['is_active'] != false,
      startDate: _sn(j['start_date']),
      deadline: _sn(j['deadline']),
      assessment: a is Map
          ? TrainingAssessmentRef(id: _s(a['id']), title: _s(a['title']), passPercentage: _i(a['pass_percentage']))
          : null,
      videosOptional: _b(j['videos_optional']),
      autoAssignNewJoiners: _b(j['auto_assign_new_joiners']),
      newJoinerDeadlineDays: _in(j['new_joiner_deadline_days']) ?? 30,
      newJoinerBranches: _strings(j['new_joiner_branches']),
      newJoinerDepartments: _strings(j['new_joiner_departments']),
      archived: _b(j['archived']),
      assignedCount: _i(j['assigned_count']),
      completedCount: _i(j['completed_count']),
      materialCount: _i(j['material_count']),
      materials: mats is List
          ? [for (final m in mats.whereType<Map>()) TrainingMaterial.fromJson(m.cast<String, dynamic>())]
          : null,
    );
  }

  /// Web: Archived / Active / Inactive.
  String get stateLabel => archived ? 'Archived' : (isActive ? 'Active' : 'Inactive');

  /// Web CourseTable subtitle: category · Mandatory|Optional · New joiners.
  String get summaryLine => [
        category,
        isMandatory ? 'Mandatory' : 'Optional',
        if (autoAssignNewJoiners) 'New joiners',
      ].where((p) => p.isNotEmpty).join(' · ');

  /// Who runs the course: the owner, else the external trainer's name.
  String get trainerLabel => owner?.name.isNotEmpty == true ? owner!.name : trainerName;
}

@immutable
class TrainingAssignmentRow {
  const TrainingAssignmentRow({
    required this.id,
    required this.employee,
    required this.courseId,
    required this.courseTitle,
    required this.status,
    this.source = '',
    this.dueDate,
    this.assignedAt = '',
    this.startedAt,
    this.completedAt,
    this.attemptsUsed = 0,
    this.bestScorePercent,
    this.assessmentPassed,
    this.progressPercent = 0,
  });

  final String id;
  final TrainingPerson employee;
  final String courseId;
  final String courseTitle;
  final TrainingStatus status;
  final String source;
  final String? dueDate;
  final String assignedAt;
  final String? startedAt;
  final String? completedAt;
  final int attemptsUsed;
  final int? bestScorePercent;
  final bool? assessmentPassed;
  final int progressPercent;

  factory TrainingAssignmentRow.fromJson(Map<String, dynamic> j) => TrainingAssignmentRow(
        id: _s(j['id']),
        employee: TrainingPerson.fromJson(_map(j['employee'])),
        courseId: _s(j['course_id']),
        courseTitle: _s(j['course_title']),
        status: TrainingStatus.parse(j['status']),
        source: _s(j['source']),
        dueDate: _sn(j['due_date']),
        assignedAt: _s(j['assigned_at']),
        startedAt: _sn(j['started_at']),
        completedAt: _sn(j['completed_at']),
        attemptsUsed: _i(j['attempts_used']),
        bestScorePercent: _in(j['best_score_percent']),
        assessmentPassed: j['assessment_passed'] is bool ? j['assessment_passed'] as bool : null,
        progressPercent: _i(j['progress_percent']),
      );

  /// Web: "Reset attempts" only for a failed assessment.
  bool get canResetAttempts => status == TrainingStatus.failed;

  /// Web: "Remove" only while assigned and never started. The backend also
  /// refuses (409) once any material progress exists.
  bool get canRemove => status == TrainingStatus.assigned && startedAt == null;
}

@immutable
class TrainingDashboard {
  const TrainingDashboard({
    this.totalCourses = 0,
    this.activeCourses = 0,
    this.employeesAssigned = 0,
    this.assigned = 0,
    this.completed = 0,
    this.inProgress = 0,
    this.notStarted = 0,
    this.overdue = 0,
    this.failed = 0,
    this.assessmentPassed = 0,
    this.assessmentFailed = 0,
    this.completionPercent = 0,
  });

  final int totalCourses;
  final int activeCourses;
  final int employeesAssigned;
  final int assigned;
  final int completed;
  final int inProgress;
  final int notStarted;
  final int overdue;
  final int failed;
  final int assessmentPassed;
  final int assessmentFailed;
  final int completionPercent;

  factory TrainingDashboard.fromJson(Map<String, dynamic> j) => TrainingDashboard(
        totalCourses: _i(j['total_courses']),
        activeCourses: _i(j['active_courses']),
        employeesAssigned: _i(j['employees_assigned']),
        assigned: _i(j['assigned']),
        completed: _i(j['completed']),
        inProgress: _i(j['in_progress']),
        notStarted: _i(j['not_started']),
        overdue: _i(j['overdue']),
        failed: _i(j['failed']),
        assessmentPassed: _i(j['assessment_passed']),
        assessmentFailed: _i(j['assessment_failed']),
        completionPercent: _i(j['completion_percent']),
      );
}

/// GET /training/employees/ — the assigner's scope (onboarded, active).
@immutable
class TrainingPicker {
  const TrainingPicker({this.employees = const [], this.departments = const [], this.branches = const []});
  final List<TrainingPerson> employees;
  final List<String> departments;
  final List<String> branches;

  factory TrainingPicker.fromJson(Map<String, dynamic> j) => TrainingPicker(
        employees: [
          for (final e in (j['employees'] is List ? j['employees'] as List : const []).whereType<Map>())
            TrainingPerson.fromJson(e.cast<String, dynamic>()),
        ],
        departments: _strings(j['departments']),
        branches: _strings(j['branches']),
      );
}

/// Who to assign a course to — exactly one mode, as on web AssignPanel.
enum AssignMode { people, groups, all }

@immutable
class AssignRequest {
  const AssignRequest({
    required this.mode,
    this.employeeIds = const [],
    this.departments = const [],
    this.branches = const [],
    this.dueDate,
  });

  final AssignMode mode;
  final List<String> employeeIds;
  final List<String> departments;
  final List<String> branches;

  /// yyyy-MM-dd or null.
  final String? dueDate;

  bool get isReady => switch (mode) {
        AssignMode.all => true,
        AssignMode.people => employeeIds.isNotEmpty,
        AssignMode.groups => departments.isNotEmpty || branches.isNotEmpty,
      };

  /// Web AssignPanel body: only the chosen mode's lists are sent.
  Map<String, dynamic> toJson() => {
        'employee_ids': mode == AssignMode.people ? employeeIds : <String>[],
        'departments': mode == AssignMode.groups ? departments : <String>[],
        'branches': mode == AssignMode.groups ? branches : <String>[],
        'all': mode == AssignMode.all,
        'due_date': (dueDate == null || dueDate!.isEmpty) ? null : dueDate,
      };
}

/// Report / progress filters (backend _filtered_assignments query params).
@immutable
class TrainingReportFilter {
  const TrainingReportFilter({
    this.course = '',
    this.status = '',
    this.department = '',
    this.branch = '',
    this.from = '',
    this.to = '',
  });

  final String course;
  final String status;
  final String department;
  final String branch;
  final String from;
  final String to;

  Map<String, String> toQuery() => {
        if (course.isNotEmpty) 'course': course,
        if (status.isNotEmpty) 'status': status,
        if (department.isNotEmpty) 'department': department,
        if (branch.isNotEmpty) 'branch': branch,
        if (from.isNotEmpty) 'from': from,
        if (to.isNotEmpty) 'to': to,
      };

  TrainingReportFilter copyWith({
    String? course,
    String? status,
    String? department,
    String? branch,
    String? from,
    String? to,
  }) =>
      TrainingReportFilter(
        course: course ?? this.course,
        status: status ?? this.status,
        department: department ?? this.department,
        branch: branch ?? this.branch,
        from: from ?? this.from,
        to: to ?? this.to,
      );

  @override
  bool operator ==(Object other) =>
      other is TrainingReportFilter &&
      other.course == course &&
      other.status == status &&
      other.department == department &&
      other.branch == branch &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(course, status, department, branch, from, to);
}

/// Web formatDuration: "1h 5m", "3m 20s", "45s"; '' for nothing.
String formatTrainingDuration(int? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final h = seconds ~/ 3600, m = (seconds % 3600) ~/ 60, s = seconds % 60;
  if (h > 0) return '${h}h ${m}m';
  if (m > 0) return s > 0 ? '${m}m ${s}s' : '${m}m';
  return '${s}s';
}

/// Web formatBytes: "12 KB", "3.4 MB"; '' for nothing.
String formatTrainingBytes(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round().clamp(1, 1023)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// ── My Learning (employee) — backend views.py my_course_out / material_out
// (with progress) / services.assessment_state; web lib/training.ts. ─────────

@immutable
class TrainingMaterialProgress {
  const TrainingMaterialProgress({
    this.openedAt,
    this.watchedSeconds = 0,
    this.lastPositionSeconds = 0,
    this.durationSeconds,
    this.completedAt,
    this.completionMethod = '',
  });

  final String? openedAt;
  final double watchedSeconds;
  final double lastPositionSeconds;
  final double? durationSeconds;
  final String? completedAt;

  /// tracked | read | confirmed | ''
  final String completionMethod;

  static double _d(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}') ?? 0;

  factory TrainingMaterialProgress.fromJson(Map<String, dynamic> j) => TrainingMaterialProgress(
        openedAt: _sn(j['opened_at']),
        watchedSeconds: _d(j['watched_seconds']),
        lastPositionSeconds: _d(j['last_position_seconds']),
        durationSeconds: j['duration_seconds'] == null ? null : _d(j['duration_seconds']),
        completedAt: _sn(j['completed_at']),
        completionMethod: _s(j['completion_method']),
      );
}

/// Web materialHint: what the employee still has to do for one material.
/// The server decides completion: tracked videos at 90% of the length HR
/// set (WATCH_REQUIRED_SHARE), documents by confirmation after the minimum
/// reading time, untracked videos by confirmation only if HR allows it.
String trainingMaterialHint(TrainingMaterial m) {
  final p = m.progress;
  if (p?.completedAt != null) return 'Completed';
  if (m.isDocument) {
    if (p?.openedAt == null) return 'Open the document, then confirm you have read it';
    return m.minViewSeconds > 0
        ? 'Confirm after reading (minimum ${formatTrainingDuration(m.minViewSeconds)})'
        : 'Confirm you have read it';
  }
  if (m.isTracked) {
    final total = (p?.durationSeconds != null && p!.durationSeconds! > 0)
        ? p.durationSeconds!
        : (m.durationSeconds?.toDouble() ?? 0);
    final watched = p?.watchedSeconds ?? 0;
    return total > 0
        ? 'Watched ${((watched / total) * 100).round().clamp(0, 100)}% — completes at 90%'
        : 'Video length not set — ask HR';
  }
  return m.allowManualCompletion ? 'Watch it, then confirm' : "Progress can't be tracked for this video — ask HR";
}

/// Web canConfirm: "I have read / watched this" is offered only after the
/// material was opened, never for a tracked video (it completes by playback).
bool trainingCanConfirm(TrainingMaterial m) {
  if (m.progress?.completedAt != null || m.progress?.openedAt == null) return false;
  if (m.isDocument) return true;
  return !m.isTracked && m.allowManualCompletion;
}

/// Web secondsUntilConfirm: the document minimum reading time left, counted
/// from the server's opened_at.
int trainingSecondsUntilConfirm(TrainingMaterial m, DateTime now) {
  final opened = DateTime.tryParse(m.progress?.openedAt ?? '');
  if (!m.isDocument || opened == null || m.minViewSeconds <= 0) return 0;
  final elapsed = now.difference(opened).inMilliseconds / 1000;
  final left = (m.minViewSeconds - elapsed).ceil();
  return left < 0 ? 0 : left;
}

@immutable
class TrainingAssessmentLastResult {
  const TrainingAssessmentLastResult({required this.percentage, required this.passed});
  final int percentage;
  final bool passed;
}

/// services.assessment_state — the course's linked assessment for this
/// employee. `required: false` when the course has none.
@immutable
class TrainingAssessmentState {
  const TrainingAssessmentState({
    this.required = false,
    this.title = '',
    this.passPercentage = 0,
    this.maxAttempts = 0,
    this.attemptsUsed = 0,
    this.attemptsLeft,
    this.timeLimitMins,
    this.unlocked = false,
    this.canAttempt = false,
    this.canRetake = false,
    this.hasQuestions = true,
    this.startsOn,
    this.passed,
    this.bestScorePercent,
    this.lastResult,
  });

  final bool required;
  final String title;
  final int passPercentage;

  /// 0 = unlimited.
  final int maxAttempts;
  final int attemptsUsed;
  final int? attemptsLeft;
  final int? timeLimitMins;
  final bool unlocked;
  final bool canAttempt;
  final bool canRetake;
  final bool hasQuestions;
  final String? startsOn;
  final bool? passed;
  final int? bestScorePercent;
  final TrainingAssessmentLastResult? lastResult;

  factory TrainingAssessmentState.fromJson(Map<String, dynamic> j) {
    final last = j['last_result'];
    return TrainingAssessmentState(
      required: _b(j['required']),
      title: _s(j['title']),
      passPercentage: _i(j['pass_percentage']),
      maxAttempts: _i(j['max_attempts']),
      attemptsUsed: _i(j['attempts_used']),
      attemptsLeft: _in(j['attempts_left']),
      timeLimitMins: _in(j['time_limit_mins']),
      unlocked: _b(j['unlocked']),
      canAttempt: _b(j['can_attempt']),
      canRetake: _b(j['can_retake']),
      hasQuestions: j['has_questions'] != false,
      startsOn: _sn(j['starts_on']),
      passed: j['passed'] is bool ? j['passed'] as bool : null,
      bestScorePercent: _in(j['best_score_percent']),
      lastResult: last is Map
          ? TrainingAssessmentLastResult(percentage: _i(last['percentage']), passed: _b(last['passed']))
          : null,
    );
  }

  /// Web AssessmentPanel: "N of M attempts used" or "Unlimited attempts".
  String get attemptsText => maxAttempts > 0 ? '$attemptsUsed of $maxAttempts attempts used' : 'Unlimited attempts';

  /// Web course page assessment row subtitle.
  String get rowHint =>
      passed == true ? 'Passed (${bestScorePercent ?? 0}%)' : (unlocked ? 'Available' : 'Complete the materials first');
}

/// One of the employee's own assignments (GET /training/my/[<id>/]).
@immutable
class MyTraining {
  const MyTraining({
    required this.row,
    required this.course,
    this.progressPercent = 0,
    this.materialCount = 0,
    this.startsOn,
    this.materials,
    this.assessment,
  });

  final TrainingAssignmentRow row;
  final TrainingCourse course;
  final int progressPercent;
  final int materialCount;

  /// The course start date while still in the future (nothing opens before).
  final String? startsOn;

  /// Detail only. `is_required` already reflects videos_optional.
  final List<TrainingMaterial>? materials;

  /// Detail only.
  final TrainingAssessmentState? assessment;

  String get id => row.id;
  TrainingStatus get status => row.status;

  /// Web: a failed assessment closes the course ("HR can reset").
  bool get isClosed => row.status == TrainingStatus.failed;

  factory MyTraining.fromJson(Map<String, dynamic> j) {
    final mats = j['materials'];
    final a = j['assessment'];
    return MyTraining(
      row: TrainingAssignmentRow.fromJson(j),
      course: TrainingCourse.fromJson(_map(j['course'])),
      progressPercent: _i(j['progress_percent']),
      materialCount: _i(j['material_count']),
      startsOn: _sn(j['starts_on']),
      materials: mats is List
          ? [for (final m in mats.whereType<Map>()) TrainingMaterial.fromJson(m.cast<String, dynamic>())]
          : null,
      assessment: a is Map ? TrainingAssessmentState.fromJson(a.cast<String, dynamic>()) : null,
    );
  }

  /// Web My Learning card line: Mandatory · N item(s) · Assessment · Due … · Starts …
  String get cardLine => [
        if (course.isMandatory) 'Mandatory',
        '$materialCount item(s)',
        if (course.assessment != null) 'Assessment',
        if (row.dueDate != null) 'Due ${row.dueDate}',
        if (startsOn != null) 'Starts $startsOn',
      ].join(' · ');
}

/// The six My Learning tabs (web FILTERS). null = All.
const kMyLearningFilters = <(TrainingStatus?, String)>[
  (null, 'All'),
  (TrainingStatus.assigned, 'Not started'),
  (TrainingStatus.inProgress, 'In progress'),
  (TrainingStatus.overdue, 'Overdue'),
  (TrainingStatus.completed, 'Completed'),
  (TrainingStatus.failed, 'Failed'),
];

/// Web: rows.filter(r => !filter || r.status === filter). The API already
/// reports "overdue" as the status of an open assignment past its due date,
/// so an overdue course is in Overdue only (not in Not started/In progress).
List<MyTraining> filterMyTraining(List<MyTraining> rows, TrainingStatus? filter) => filter == null
    ? rows
    : [
        for (final r in rows)
          if (r.status == filter) r
      ];

/// POST my/<id>/materials/<mid>/<action>/ response.
@immutable
class TrainingMaterialActionResult {
  const TrainingMaterialActionResult({required this.material, required this.status, this.assessment});
  final TrainingMaterial material;
  final TrainingStatus status;
  final TrainingAssessmentState? assessment;
}

@immutable
class TrainingQuestionOption {
  const TrainingQuestionOption(this.key, this.text);
  final String key;
  final String text;
}

@immutable
class TrainingQuestion {
  const TrainingQuestion({required this.id, required this.question, this.section = '', this.options = const []});
  final String id;
  final String question;
  final String section;
  final List<TrainingQuestionOption> options;

  factory TrainingQuestion.fromJson(Map<String, dynamic> j) => TrainingQuestion(
        id: _s(j['id']),
        question: _s(j['question']),
        section: _s(j['section']),
        options: [
          for (final o in (j['options'] is List ? j['options'] as List : const []).whereType<Map>())
            TrainingQuestionOption(_s(o['key']), _s(o['text'])),
        ],
      );
}

@immutable
class TrainingAttempt {
  const TrainingAttempt({required this.attemptNumber, required this.questions, this.timeLimitMins});
  final int attemptNumber;
  final List<TrainingQuestion> questions;
  final int? timeLimitMins;
}

@immutable
class TrainingAssessmentResult {
  const TrainingAssessmentResult({
    required this.percentage,
    required this.passPercentage,
    required this.passed,
    this.status,
    this.assessment,
  });
  final int percentage;
  final int passPercentage;
  final bool passed;
  final TrainingStatus? status;
  final TrainingAssessmentState? assessment;
}

// ── Admin authoring (Task 90 batch 3) — web lib/training.ts + backend
// apps/training/views.py _apply_course / MaterialListCreateView and
// validation.py. Client checks give instant feedback; the server decides. ──

/// Web todayIso (device-local date).
String trainingTodayIso([DateTime? now]) {
  final d = now ?? DateTime.now();
  return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Web CourseForm / courseToForm / validateCourse / courseFormPayload.
@immutable
class TrainingCourseForm {
  const TrainingCourseForm({
    this.title = '',
    this.description = '',
    this.category = '',
    this.trainerName = '',
    this.durationMinutes = '',
    this.isMandatory = false,
    this.isActive = true,
    this.startDate = '',
    this.deadline = '',
    this.assessment = '',
    this.videosOptional = false,
    this.autoAssignNewJoiners = false,
    this.newJoinerDeadlineDays = '30',
    this.newJoinerBranches = const [],
    this.newJoinerDepartments = const [],
  });

  final String title;
  final String description;
  final String category;
  final String trainerName;
  final String durationMinutes;
  final bool isMandatory;
  final bool isActive;
  final String startDate;
  final String deadline;

  /// Assessment id, '' = none.
  final String assessment;
  final bool videosOptional;
  final bool autoAssignNewJoiners;
  final String newJoinerDeadlineDays;
  final List<String> newJoinerBranches;
  final List<String> newJoinerDepartments;

  factory TrainingCourseForm.fromCourse(TrainingCourse c) => TrainingCourseForm(
        title: c.title,
        description: c.description,
        category: c.category,
        trainerName: c.trainerName,
        durationMinutes: c.durationMinutes != null && c.durationMinutes! > 0 ? '${c.durationMinutes}' : '',
        isMandatory: c.isMandatory,
        isActive: c.isActive,
        startDate: c.startDate ?? '',
        deadline: c.deadline ?? '',
        assessment: c.assessment?.id ?? '',
        videosOptional: c.videosOptional,
        autoAssignNewJoiners: c.autoAssignNewJoiners,
        newJoinerDeadlineDays: '${c.newJoinerDeadlineDays}',
        newJoinerBranches: c.newJoinerBranches,
        newJoinerDepartments: c.newJoinerDepartments,
      );

  TrainingCourseForm copyWith({
    String? title,
    String? description,
    String? category,
    String? trainerName,
    String? durationMinutes,
    bool? isMandatory,
    bool? isActive,
    String? startDate,
    String? deadline,
    String? assessment,
    bool? videosOptional,
    bool? autoAssignNewJoiners,
    String? newJoinerDeadlineDays,
    List<String>? newJoinerBranches,
    List<String>? newJoinerDepartments,
  }) =>
      TrainingCourseForm(
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        trainerName: trainerName ?? this.trainerName,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        isMandatory: isMandatory ?? this.isMandatory,
        isActive: isActive ?? this.isActive,
        startDate: startDate ?? this.startDate,
        deadline: deadline ?? this.deadline,
        assessment: assessment ?? this.assessment,
        videosOptional: videosOptional ?? this.videosOptional,
        autoAssignNewJoiners: autoAssignNewJoiners ?? this.autoAssignNewJoiners,
        newJoinerDeadlineDays: newJoinerDeadlineDays ?? this.newJoinerDeadlineDays,
        newJoinerBranches: newJoinerBranches ?? this.newJoinerBranches,
        newJoinerDepartments: newJoinerDepartments ?? this.newJoinerDepartments,
      );

  /// Web validateCourse: field → message; empty when valid.
  Map<String, String> validate() {
    final e = <String, String>{};
    if (title.trim().isEmpty) e['title'] = 'Give the course a title.';
    if (durationMinutes.isNotEmpty && !RegExp(r'^\d+$').hasMatch(durationMinutes)) {
      e['duration_minutes'] = 'Enter whole minutes.';
    }
    if (startDate.isNotEmpty && deadline.isNotEmpty && deadline.compareTo(startDate) < 0) {
      e['deadline'] = 'The deadline must be on or after the start date.';
    }
    final days = int.tryParse(newJoinerDeadlineDays);
    if (autoAssignNewJoiners && (days == null || days < 0 || days > 365)) {
      e['new_joiner_deadline_days'] = 'Enter 0–365 days.';
    }
    if (videosOptional && assessment.isEmpty) {
      e['videos_optional'] = 'Link an assessment — employees complete the course by passing it.';
    }
    return e;
  }

  /// Web: a deadline already in the past is allowed but warned about.
  bool get deadlinePassed => deadline.isNotEmpty && deadline.compareTo(trainingTodayIso()) < 0;

  /// Web courseFormPayload. `assessment` is sent only by users who may link
  /// assessments (the server refuses a link otherwise, and clears it only for
  /// them).
  Map<String, dynamic> toPayload({required bool canLinkAssessment}) => {
        'title': title.trim(),
        'description': description,
        'category': category,
        'trainer_name': trainerName,
        'duration_minutes': durationMinutes.isEmpty ? null : durationMinutes,
        'is_mandatory': isMandatory,
        'is_active': isActive,
        'start_date': startDate.isEmpty ? null : startDate,
        'deadline': deadline.isEmpty ? null : deadline,
        'videos_optional': videosOptional,
        'auto_assign_new_joiners': autoAssignNewJoiners,
        'new_joiner_deadline_days': int.tryParse(newJoinerDeadlineDays) ?? 0,
        'new_joiner_branches': newJoinerBranches,
        'new_joiner_departments': newJoinerDepartments,
        if (canLinkAssessment) 'assessment': assessment.isEmpty ? null : assessment,
      };
}

/// GET /training/assessments/ (training.manage_assessments).
@immutable
class TrainingAssessmentOption {
  const TrainingAssessmentOption({required this.id, required this.title, this.questions = 0, this.passPercentage = 0});
  final String id;
  final String title;
  final int questions;
  final int passPercentage;

  factory TrainingAssessmentOption.fromJson(Map<String, dynamic> j) => TrainingAssessmentOption(
        id: _s(j['id']),
        title: _s(j['title']),
        questions: _i(j['questions']),
        passPercentage: _i(j['pass_percentage']),
      );

  /// Web option text: "Title (N questions, pass P%)".
  String get label => '$title ($questions questions, pass $passPercentage%)';
}

/// Web parseVideoLink (mirrors backend validation.parse_external_video).
({String provider, String id, String? error}) parseTrainingVideoLink(String raw) {
  ({String provider, String id, String? error}) err(String m) => (provider: '', id: '', error: m);
  final url = raw.trim();
  if (url.isEmpty) return err('Paste the video link.');
  final u = Uri.tryParse(url);
  if (u == null || !u.hasScheme || u.host.isEmpty) return err('That is not a valid link.');
  if (u.scheme != 'https') return err('Only secure https:// links are allowed.');
  if (u.userInfo.isNotEmpty) return err('Links with a user name or password are not allowed.');
  final host = u.host.toLowerCase();
  if (host == 'localhost' ||
      RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host) ||
      host.startsWith('[') ||
      !host.contains('.')) {
    return err('The link must point to a public website.');
  }
  final yt = RegExp(r'^[A-Za-z0-9_-]{11}$');
  if (host == 'youtu.be' || RegExp(r'(^|\.)youtube(-nocookie)?\.com$').hasMatch(host)) {
    var id = '';
    final parts = u.pathSegments.where((p) => p.isNotEmpty).toList();
    if (host == 'youtu.be') {
      id = parts.isNotEmpty ? parts.first : '';
    } else if (u.path == '/watch') {
      id = u.queryParameters['v'] ?? '';
    } else if (parts.isNotEmpty && const ['embed', 'shorts', 'live', 'v'].contains(parts.first)) {
      id = parts.length > 1 ? parts[1] : '';
    }
    return yt.hasMatch(id)
        ? (provider: 'youtube', id: id, error: null)
        : err('That YouTube link has no valid video id.');
  }
  if (RegExp(r'(^|\.)vimeo\.com$').hasMatch(host)) {
    final id = u.pathSegments.firstWhere((p) => RegExp(r'^\d+$').hasMatch(p), orElse: () => '');
    return id.isNotEmpty ? (provider: 'vimeo', id: id, error: null) : err('That Vimeo link has no video id.');
  }
  if (RegExp(r'\.(mp4|webm|m4v)$', caseSensitive: false).hasMatch(u.path)) {
    return (provider: 'direct', id: '', error: null);
  }
  return err('Supported links: YouTube, Vimeo, or a direct https link to an .mp4 / .webm file.');
}

/// Web needsVideoLength: uploaded videos and YouTube / direct links are
/// tracked, so the server requires their length.
bool trainingNeedsVideoLength(String kind, String? provider) =>
    kind == 'video' || (kind == 'external_video' && (provider == 'youtube' || provider == 'direct'));

/// Web videoLengthSeconds: 0 when invalid.
int trainingVideoLengthSeconds(String minutes, String seconds) {
  final m = minutes.isEmpty ? 0 : int.tryParse(minutes);
  final s = seconds.isEmpty ? 0 : int.tryParse(seconds);
  if (m == null || s == null || m < 0 || s < 0 || s > 59) return 0;
  return m * 60 + s;
}

/// Web parseVideoLength ("12:30" or "12" minutes) → seconds, null if invalid.
int? parseTrainingVideoLength(String text) {
  final m = RegExp(r'^(\d{1,4})(?::([0-5]?\d))?$').firstMatch(text.trim());
  if (m == null) return null;
  final total = int.parse(m.group(1)!) * 60 + int.parse(m.group(2) ?? '0');
  return total > 0 ? total : null;
}

/// Web MaterialsEditor client limits (the server enforces its own,
/// TRAINING_DOCUMENT_MAX_MB / TRAINING_VIDEO_MAX_MB, default 9; thumbnails 2).
const kTrainingMaxDocumentMb = 9;
const kTrainingMaxVideoMb = 9;
const kTrainingMaxThumbnailMb = 2;
const kTrainingDocumentExtensions = ['pdf', 'pptx', 'docx'];
const kTrainingVideoExtensions = ['mp4', 'webm', 'm4v'];
const kTrainingThumbnailExtensions = ['png', 'jpg', 'jpeg'];

/// Web uploadError for a picked file ('' when acceptable).
String trainingUploadError({required String? fileName, required int size, required String kind}) {
  if (fileName == null) return kind == 'video' ? 'Choose a video.' : 'Choose a file.';
  final dot = fileName.lastIndexOf('.');
  final ext = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  final allowed = kind == 'video' ? kTrainingVideoExtensions : kTrainingDocumentExtensions;
  if (!allowed.contains(ext)) {
    return kind == 'video' ? 'Upload an MP4 or WebM video.' : 'Upload a PDF, PowerPoint (.pptx) or Word (.docx) file.';
  }
  if (size <= 0) return 'The file is empty.';
  final maxMb = kind == 'video' ? kTrainingMaxVideoMb : kTrainingMaxDocumentMb;
  if (size > maxMb * 1024 * 1024) return 'The file must be $maxMb MB or smaller.';
  return '';
}

/// A file chosen on the device for upload (bytes stay in memory).
@immutable
class TrainingUploadFile {
  const TrainingUploadFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
  int get size => bytes.length;
}

/// Web AddMaterial form → request. Exactly one source per kind.
@immutable
class TrainingMaterialDraft {
  const TrainingMaterialDraft({
    this.kind = 'document',
    this.title = '',
    this.file,
    this.link = '',
    this.minViewMinutes = '',
    this.durMin = '',
    this.durSec = '',
    this.required = true,
    this.allowConfirm = false,
  });

  /// document | video | external_video
  final String kind;
  final String title;
  final TrainingUploadFile? file;
  final String link;
  final String minViewMinutes;
  final String durMin;
  final String durSec;
  final bool required;
  final bool allowConfirm;

  ({String provider, String id, String? error})? get parsedLink =>
      kind == 'external_video' && link.trim().isNotEmpty ? parseTrainingVideoLink(link) : null;

  String get titleError => title.trim().isEmpty ? 'Give the material a title.' : '';

  String get sourceError {
    if (kind == 'external_video') {
      final p = parsedLink;
      return p == null ? 'Paste the video link.' : (p.error ?? '');
    }
    return trainingUploadError(fileName: file?.name, size: file?.size ?? 0, kind: kind);
  }

  int get lengthSeconds => trainingVideoLengthSeconds(durMin, durSec);

  bool get lengthRequired => trainingNeedsVideoLength(kind, parsedLink?.error == null ? parsedLink?.provider : null);

  String get lengthError {
    if (kind == 'document') return '';
    if ((int.tryParse(durSec) ?? 0) > 59) return 'Seconds must be 0–59.';
    if (lengthRequired && lengthSeconds == 0) return 'Enter the video length.';
    return '';
  }

  bool get isValid => titleError.isEmpty && sourceError.isEmpty && lengthError.isEmpty;

  /// Vimeo links can't be tracked: HR may allow confirmation.
  bool get isUntrackedLink => parsedLink?.error == null && parsedLink?.provider == 'vimeo';

  /// JSON body for a video link (web: same keys).
  Map<String, dynamic> linkPayload() => {
        'material_type': 'external_video',
        'title': title.trim(),
        'external_url': link.trim(),
        'is_required': required,
        'allow_manual_completion': allowConfirm,
        'duration_seconds': lengthSeconds == 0 ? null : lengthSeconds,
      };

  /// Multipart text fields for an upload (web FormData, minus the file).
  Map<String, String> uploadFields() => {
        'material_type': kind,
        'title': title.trim(),
        'is_required': '$required',
        if (kind == 'document' && minViewMinutes.isNotEmpty)
          'min_view_seconds': '${(int.tryParse(minViewMinutes) ?? 0) * 60}',
        if (kind == 'video' && lengthSeconds > 0) 'duration_seconds': '$lengthSeconds',
      };

  TrainingMaterialDraft copyWith({
    String? kind,
    String? title,
    TrainingUploadFile? file,
    bool clearFile = false,
    String? link,
    String? minViewMinutes,
    String? durMin,
    String? durSec,
    bool? required,
    bool? allowConfirm,
  }) =>
      TrainingMaterialDraft(
        kind: kind ?? this.kind,
        title: title ?? this.title,
        file: clearFile ? null : (file ?? this.file),
        link: link ?? this.link,
        minViewMinutes: minViewMinutes ?? this.minViewMinutes,
        durMin: durMin ?? this.durMin,
        durSec: durSec ?? this.durSec,
        required: required ?? this.required,
        allowConfirm: allowConfirm ?? this.allowConfirm,
      );
}

/// Web requiredLabel.
String trainingRequiredLabel(String kind, bool hasAssessment) =>
    'Required — must be ${kind == 'document' ? 'read' : 'watched'} '
    '${hasAssessment ? 'before the assessment' : 'to complete the course'}';

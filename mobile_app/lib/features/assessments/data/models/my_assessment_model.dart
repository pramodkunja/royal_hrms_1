import 'assessment_portal_models.dart';

// The signed-in employee's own assessments — GET /api/assessments/my/
// (apps/assessments/views/portal.py MyAssessmentView, any signed-in user).
//
// Response: {"assignments": [PortalAssignmentSerializer...], "all_complete":
// bool}. Not paginated: every assignment of the user is returned at once.
// Only the fields the list shows are read here (web's EmployeeMyAssessments
// MyAssignment); `items`/`responses` belong to taking an assessment.

enum MyAssessmentStatus {
  pending('Pending'),
  inProgress('In Progress'),
  complete('Completed');

  const MyAssessmentStatus(this.label);
  final String label;

  /// CandidateAssignment.STATUS_*. Anything else is treated as pending, as
  /// web does (every non-"complete" row is listed under Pending).
  static MyAssessmentStatus fromApi(Object? value) => switch (value) {
        'in_progress' => inProgress,
        'complete' => complete,
        _ => pending,
      };
}

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
int? _intOrNull(Object? v) =>
    v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
Iterable<Map<String, dynamic>> _maps(Object? v) =>
    (v is List ? v : const []).whereType<Map<String, dynamic>>();

class MyAssessmentAssignment {
  final String id;
  final String title;
  final MyAssessmentStatus status;
  final int passPercentage;
  final int score;
  final int maxScore;
  final int totalItems;
  final int completedItems;
  final int attemptCount;
  final int effectiveMaxAttempts;

  /// null when attempts are unlimited (effective_max_attempts == 0).
  final int? attemptsRemaining;
  final int? timeLimitMins;

  /// ISO date-times as sent by the server, or null.
  final String? deadline;
  final String? completedAt;
  final String? startedAt;

  /// Seconds left on a timed attempt, from the server (null when the
  /// assessment has no time limit or the attempt hasn't started yet).
  final int? timeRemainingSecs;

  /// The assessment's items (any order from the server; see [orderedItems])
  /// and the responses already saved for this attempt.
  final List<AssessmentPortalItem> items;
  final List<AssessmentItemResponse> responses;

  const MyAssessmentAssignment({
    required this.id,
    required this.title,
    required this.status,
    this.passPercentage = 0,
    this.score = 0,
    this.maxScore = 0,
    this.totalItems = 0,
    this.completedItems = 0,
    this.attemptCount = 0,
    this.effectiveMaxAttempts = 0,
    this.attemptsRemaining,
    this.timeLimitMins,
    this.deadline,
    this.completedAt,
    this.startedAt,
    this.timeRemainingSecs,
    this.items = const [],
    this.responses = const [],
  });

  factory MyAssessmentAssignment.fromJson(Map<String, dynamic> json) =>
      MyAssessmentAssignment(
        id: json['id']?.toString() ?? '',
        title: _str(json['assessment_title']) ?? 'Assessment',
        status: MyAssessmentStatus.fromApi(json['status']),
        passPercentage: _int(json['pass_percentage']),
        score: _int(json['score']),
        maxScore: _int(json['max_score']),
        totalItems: _int(json['total_items']),
        completedItems: _int(json['completed_items']),
        attemptCount: _int(json['attempt_count']),
        effectiveMaxAttempts: _int(json['effective_max_attempts']),
        attemptsRemaining: _intOrNull(json['attempts_remaining']),
        timeLimitMins: _intOrNull(json['time_limit_mins']),
        deadline: _str(json['deadline']),
        completedAt: _str(json['completed_at']),
        startedAt: _str(json['started_at']),
        timeRemainingSecs: _intOrNull(json['time_remaining_secs']),
        items: _maps(json['items']).map(AssessmentPortalItem.fromJson).toList(),
        responses: _maps(json['responses'])
            .map(AssessmentItemResponse.fromJson)
            .toList(),
      );

  /// Items in the order the assessment defines (web sorts by `order`).
  List<AssessmentPortalItem> get orderedItems =>
      [...items]..sort((a, b) => a.order.compareTo(b.order));

  AssessmentItemResponse? responseFor(String itemId) {
    for (final r in responses) {
      if (r.itemId == itemId) return r;
    }
    return null;
  }

  /// Web isItemDone: a video is done once watched, a quiz once answered.
  bool isItemDone(AssessmentPortalItem item) {
    final r = responseFor(item.id);
    if (r == null) return false;
    return item.type == AssessmentItemType.video
        ? r.isWatched
        : r.selectedOption.isNotEmpty;
  }

  bool get isComplete => status == MyAssessmentStatus.complete;

  /// Items done, as a whole percentage (web: round(completed / total * 100)).
  int get progressPercent => totalItems > 0
      ? (completedItems / totalItems * 100).round().clamp(0, 100)
      : 0;

  /// Score as a whole percentage (web: round(score / max_score * 100)).
  int get scorePercent => maxScore > 0 ? (score / maxScore * 100).round() : 0;

  /// Web's rule for a completed assignment: score percentage ≥ pass mark.
  bool get passed => scorePercent >= passPercentage;
}

class MyAssessments {
  final List<MyAssessmentAssignment> assignments;
  final bool allComplete;

  const MyAssessments({this.assignments = const [], this.allComplete = true});

  factory MyAssessments.fromJson(Object? data) {
    final map = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    final rows = map['assignments'];
    final list = (rows is List ? rows : const [])
        .whereType<Map<String, dynamic>>()
        .map(MyAssessmentAssignment.fromJson)
        .toList();
    return MyAssessments(
      assignments: list,
      allComplete: map['all_complete'] is bool
          ? map['all_complete'] as bool
          : list.every((a) => a.isComplete),
    );
  }

  List<MyAssessmentAssignment> get pending =>
      assignments.where((a) => !a.isComplete).toList();
  List<MyAssessmentAssignment> get completed =>
      assignments.where((a) => a.isComplete).toList();
}

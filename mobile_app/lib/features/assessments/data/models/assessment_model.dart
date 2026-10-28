import 'package:flutter/foundation.dart';

// Item type codes — match backend AssessmentItem.TYPE_CHOICES exactly.
class AssessmentItemType {
  AssessmentItemType._();
  static const String video = 'video';
  static const String quiz = 'quiz';
}

// Assignment status codes — match backend CandidateAssignment.STATUS_CHOICES.
class AssessmentAssignStatus {
  AssessmentAssignStatus._();
  static const String pending = 'pending';
  static const String inProgress = 'in_progress';
  static const String complete = 'complete';

  static String label(String status) => switch (status) {
    complete => 'Completed',
    inProgress => 'In Progress',
    _ => 'Pending',
  };
}

DateTime? _parseDate(dynamic v) {
  if (v == null) return null;
  if (v is String && v.isEmpty) return null;
  return DateTime.tryParse(v as String);
}

// The backend stores video_url as a Django URLField, which rejects any
// value without a URI scheme (e.g. "youtu.be/xyz" or "www.youtube.com/...")
// with a 400 "Enter a valid URL." error. Users very commonly paste a link
// copied without the "https://" prefix, so normalize it here before it's
// ever sent — mirrors what a browser address bar does automatically.
String _normalizeVideoUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return trimmed;
  if (RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(trimmed)) return trimmed;
  return 'https://$trimmed';
}

// Who an assessment is assigned to — matches backend
// CandidateAssignment.assignee_type exactly. `assignee_id` is a UUID string
// for employees but a plain integer for recruitment candidates, so it's kept
// as a String here (via toString()) to safely hold either shape.
class AssessmentAssigneeType {
  AssessmentAssigneeType._();
  static const String employee = 'employee';
  static const String candidate = 'candidate';

  static String label(String type) =>
      type == employee ? 'Employee' : 'Candidate';
}

@immutable
class AssessmentCandidateModel {
  final String id;
  final String assigneeType; // employee | candidate
  final String assigneeId;
  final String assigneeName;
  final String assigneeEmail;
  final String status; // pending | in_progress | complete
  final int attemptCount;
  final int totalQuestions;
  final int achievedScore;
  final String scorePercentage; // pre-formatted e.g. "80%", "0%", or "N/A"
  final int passPercentage; // the assessment's pass threshold, e.g. 70
  final bool passed;
  final List<dynamic> sectionsBreakdown;
  final DateTime? deadline;
  final DateTime? completedAt;
  final DateTime? createdAt; // "assigned on"

  const AssessmentCandidateModel({
    required this.id,
    required this.assigneeType,
    required this.assigneeId,
    required this.assigneeName,
    required this.assigneeEmail,
    required this.status,
    required this.attemptCount,
    required this.totalQuestions,
    required this.achievedScore,
    required this.scorePercentage,
    required this.passPercentage,
    required this.passed,
    this.sectionsBreakdown = const [],
    this.deadline,
    this.completedAt,
    this.createdAt,
  });

  factory AssessmentCandidateModel.fromJson(Map<String, dynamic> json) {
    return AssessmentCandidateModel(
      id: json['id']?.toString() ?? '',
      assigneeType:
          json['assignee_type'] as String? ?? AssessmentAssigneeType.candidate,
      assigneeId: json['assignee_id']?.toString() ?? '',
      assigneeName: json['assignee_name'] as String? ?? '',
      assigneeEmail: json['assignee_email'] as String? ?? '',
      status: json['status'] as String? ?? AssessmentAssignStatus.pending,
      attemptCount: json['attempt_count'] as int? ?? 1,
      totalQuestions: json['total_questions'] as int? ?? 0,
      achievedScore: json['achieved_score'] as int? ?? 0,
      scorePercentage: json['score_percentage']?.toString() ?? 'N/A',
      passPercentage: json['pass_percentage'] as int? ?? 0,
      passed: json['passed'] as bool? ?? false,
      sectionsBreakdown: json['sections_breakdown'] as List<dynamic>? ?? const [],
      deadline: _parseDate(json['deadline']),
      completedAt: _parseDate(json['completed_at']),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

@immutable
class AssessmentModel {
  final String id;
  final String title;
  final String description;
  final bool isActive;
  final bool isDefault;
  final int passPercentage;
  final int? maxAttempts;
  final int? timeLimitMins;
  final int effectiveMaxAttempts;
  final int? effectiveTimeLimitMins;
  final int itemCount;
  final int assignedCount;
  final int pendingCount;
  final int inProgressCount;
  final int completedCount;
  final List<AssessmentCandidateModel> candidates;
  final DateTime? createdAt;

  const AssessmentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.isActive,
    required this.isDefault,
    required this.passPercentage,
    this.maxAttempts,
    this.timeLimitMins,
    required this.effectiveMaxAttempts,
    this.effectiveTimeLimitMins,
    required this.itemCount,
    required this.assignedCount,
    required this.pendingCount,
    required this.inProgressCount,
    required this.completedCount,
    required this.candidates,
    this.createdAt,
  });

  factory AssessmentModel.fromJson(Map<String, dynamic> json) {
    final candidatesJson = json['candidates'] as List<dynamic>? ?? [];
    return AssessmentModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      isDefault: json['is_default'] as bool? ?? false,
      passPercentage: json['pass_percentage'] as int? ?? 0,
      maxAttempts: json['max_attempts'] as int?,
      timeLimitMins: json['time_limit_mins'] as int?,
      effectiveMaxAttempts: json['effective_max_attempts'] as int? ?? 1,
      effectiveTimeLimitMins: json['effective_time_limit_mins'] as int?,
      itemCount: json['item_count'] as int? ?? 0,
      assignedCount: json['assigned_count'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      inProgressCount: json['in_progress_count'] as int? ?? 0,
      completedCount: json['completed_count'] as int? ?? 0,
      candidates: candidatesJson
          .map((e) => AssessmentCandidateModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: _parseDate(json['created_at']),
    );
  }
}

@immutable
class AssessmentItemModel {
  final String id;
  final String itemType; // video | quiz
  final String title;
  final int order;
  final String videoUrl;
  final int? durationSecs;
  final String question;
  final String optionA;
  final String optionB;
  final String optionC;
  final String optionD;
  final String correctOption; // a | b | c | d
  final int passScore;
  final DateTime? createdAt;

  const AssessmentItemModel({
    required this.id,
    required this.itemType,
    required this.title,
    required this.order,
    required this.videoUrl,
    this.durationSecs,
    required this.question,
    required this.optionA,
    required this.optionB,
    required this.optionC,
    required this.optionD,
    required this.correctOption,
    required this.passScore,
    this.createdAt,
  });

  factory AssessmentItemModel.fromJson(Map<String, dynamic> json) {
    return AssessmentItemModel(
      id: json['id']?.toString() ?? '',
      itemType: json['item_type'] as String? ?? AssessmentItemType.video,
      title: json['title'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      videoUrl: json['video_url'] as String? ?? '',
      durationSecs: json['duration_secs'] as int?,
      question: json['question'] as String? ?? '',
      optionA: json['option_a'] as String? ?? '',
      optionB: json['option_b'] as String? ?? '',
      optionC: json['option_c'] as String? ?? '',
      optionD: json['option_d'] as String? ?? '',
      correctOption: json['correct_option'] as String? ?? 'a',
      passScore: json['pass_score'] as int? ?? 0,
      createdAt: _parseDate(json['created_at']),
    );
  }
}

/// Employee row shown in the Assign dialog's checklist.
/// Sourced from GET /employees/ ({id, employee_id, full_name, email, department}) —
/// matches web's `AssignEmployee` interface exactly. `id` is the real User
/// UUID, which the assign endpoint accepts as `candidate_id` and resolves to
/// an employee (see AssignAssessmentView's UUID fallback path).
@immutable
class AssignableEmployeeModel {
  final String id;
  final String employeeId;
  final String fullName;
  final String email;
  final String department;

  const AssignableEmployeeModel({
    required this.id,
    required this.employeeId,
    required this.fullName,
    required this.email,
    required this.department,
  });

  factory AssignableEmployeeModel.fromJson(Map<String, dynamic> json) {
    return AssignableEmployeeModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      department: json['department'] as String? ?? '',
    );
  }
}

/// {name, display_name} option for the Assign dialog's notification email
/// template dropdown. Sourced from GET /assessments/email-template-options/.
@immutable
class EmailTemplateOptionModel {
  final String name;
  final String displayName;

  const EmailTemplateOptionModel({required this.name, required this.displayName});

  factory EmailTemplateOptionModel.fromJson(Map<String, dynamic> json) {
    return EmailTemplateOptionModel(
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
    );
  }
}

/// Mutable form-data for the Add/Edit Assessment dialog.
class AssessmentFormData {
  String title;
  String description;
  bool isActive;
  bool isDefault;
  int passPercentage;
  // null = inherit the org-wide default from Settings → Assessment Config;
  // 0 = unlimited attempts (per-assessment override) — matches
  // AssessmentCreateSerializer.validate_max_attempts on the backend.
  int? maxAttempts;
  // null = inherit the org-wide default (which may itself be null = no limit).
  int? timeLimitMins;

  AssessmentFormData({
    this.title = '',
    this.description = '',
    this.isActive = true,
    this.isDefault = false,
    this.passPercentage = 70,
    this.maxAttempts,
    this.timeLimitMins,
  });

  factory AssessmentFormData.fromModel(AssessmentModel model) => AssessmentFormData(
    title: model.title,
    description: model.description,
    isActive: model.isActive,
    isDefault: model.isDefault,
    passPercentage: model.passPercentage,
    maxAttempts: model.maxAttempts,
    timeLimitMins: model.timeLimitMins,
  );

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'is_active': isActive,
    'is_default': isDefault,
    'pass_percentage': passPercentage,
    'max_attempts': maxAttempts,
    'time_limit_mins': timeLimitMins,
  };

  /// Mirrors the backend's own validators (AssessmentCreateSerializer) so a
  /// bad value fails fast client-side with the same message the API would
  /// otherwise return after a round trip.
  String? validate() {
    if (title.trim().isEmpty) return 'Title is required.';
    if (passPercentage < 1 || passPercentage > 100) {
      return 'Pass % must be between 1 and 100.';
    }
    if (maxAttempts != null && maxAttempts! < 0) {
      return 'Max Attempts cannot be negative. Use 0 for unlimited.';
    }
    if (timeLimitMins != null && timeLimitMins! < 1) {
      return 'Time Limit must be at least 1 minute.';
    }
    return null;
  }
}

/// Mutable form-data for the Add/Edit Assessment Item dialog (video or quiz).
class AssessmentItemFormData {
  String itemType;
  int order;
  String title;
  String videoUrl;
  int? durationSecs;
  String question;
  String optionA;
  String optionB;
  String optionC;
  String optionD;
  String correctOption;
  int passScore;

  AssessmentItemFormData({
    this.itemType = AssessmentItemType.video,
    this.order = 1,
    this.title = '',
    this.videoUrl = '',
    this.durationSecs,
    this.question = '',
    this.optionA = '',
    this.optionB = '',
    this.optionC = '',
    this.optionD = '',
    this.correctOption = 'a',
    this.passScore = 0,
  });

  factory AssessmentItemFormData.fromModel(AssessmentItemModel model) => AssessmentItemFormData(
    itemType: model.itemType,
    order: model.order,
    title: model.title,
    videoUrl: model.videoUrl,
    durationSecs: model.durationSecs,
    question: model.question,
    optionA: model.optionA,
    optionB: model.optionB,
    optionC: model.optionC,
    optionD: model.optionD,
    correctOption: model.correctOption,
    passScore: model.passScore,
  );

  bool get isVideo => itemType == AssessmentItemType.video;

  Map<String, dynamic> toJson() {
    return {
      'item_type': itemType,
      'title': title.trim(),
      'order': order < 1 ? 1 : order,
      if (isVideo) ...{
        'video_url': _normalizeVideoUrl(videoUrl),
        'duration_secs': durationSecs,
      } else ...{
        'video_url': '',
        'duration_secs': null,
      },
      if (!isVideo) ...{
        'question': question.trim(),
        'option_a': optionA.trim(),
        'option_b': optionB.trim(),
        'option_c': optionC.trim(),
        'option_d': optionD.trim(),
        'correct_option': correctOption,
        'pass_score': passScore < 0 ? 0 : passScore,
      } else ...{
        'question': '',
        'option_a': '',
        'option_b': '',
        'option_c': '',
        'option_d': '',
        'correct_option': '',
        'pass_score': 0,
      },
    };
  }

  /// Validation order mirrors the reference web screen exactly — the first
  /// failing check wins and is shown as a single banner message:
  /// 1) title  2) video_url (video)  3) question (quiz)  4) options A+B (quiz)
  String? validate() {
    if (title.trim().isEmpty) return 'Title is required.';
    if (isVideo && videoUrl.trim().isEmpty) return 'Video URL is required.';
    if (!isVideo && question.trim().isEmpty) return 'Question is required.';
    if (!isVideo && (optionA.trim().isEmpty || optionB.trim().isEmpty)) {
      return 'At least options A and B are required.';
    }
    return null;
  }
}

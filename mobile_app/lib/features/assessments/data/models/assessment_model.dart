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

@immutable
class AssessmentCandidateModel {
  final String id;
  final int candidateId;
  final String candidateName;
  final String candidateEmail;
  final String status; // pending | in_progress | complete
  final int attemptCount;
  final int passScore; // max_score
  final int scoreAwarded; // score
  final String passPercentage; // pre-formatted e.g. "80%" or "N/A"
  final DateTime? completedAt;
  final DateTime? createdAt; // "assigned on"

  const AssessmentCandidateModel({
    required this.id,
    required this.candidateId,
    required this.candidateName,
    required this.candidateEmail,
    required this.status,
    required this.attemptCount,
    required this.passScore,
    required this.scoreAwarded,
    required this.passPercentage,
    this.completedAt,
    this.createdAt,
  });

  factory AssessmentCandidateModel.fromJson(Map<String, dynamic> json) {
    return AssessmentCandidateModel(
      id: json['id']?.toString() ?? '',
      candidateId: json['candidate_id'] as int? ?? 0,
      candidateName: json['candidate_name'] as String? ?? '',
      candidateEmail: json['candidate_email'] as String? ?? '',
      status: json['status'] as String? ?? AssessmentAssignStatus.pending,
      attemptCount: json['attempt_count'] as int? ?? 1,
      passScore: json['pass_score'] as int? ?? 0,
      scoreAwarded: json['score_awarded'] as int? ?? 0,
      passPercentage: json['pass_percentage']?.toString() ?? 'N/A',
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

/// Candidate row shown in the Assign dialog's dropdown.
/// Sourced from GET /recruitment/candidates/review/ ({id, name, email}).
@immutable
class ReviewCandidateModel {
  final int id;
  final String name;
  final String email;

  const ReviewCandidateModel({
    required this.id,
    required this.name,
    required this.email,
  });

  factory ReviewCandidateModel.fromJson(Map<String, dynamic> json) {
    return ReviewCandidateModel(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }
}

/// Mutable form-data for the Add/Edit Assessment dialog.
class AssessmentFormData {
  String title;
  String description;
  bool isActive;
  bool isDefault;

  AssessmentFormData({
    this.title = '',
    this.description = '',
    this.isActive = true,
    this.isDefault = false,
  });

  factory AssessmentFormData.fromModel(AssessmentModel model) => AssessmentFormData(
    title: model.title,
    description: model.description,
    isActive: model.isActive,
    isDefault: model.isDefault,
  );

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'description': description.trim(),
    'is_active': isActive,
    'is_default': isDefault,
  };

  /// Mirrors the reference web screen's exact copy: "Title is required."
  String? validate() {
    if (title.trim().isEmpty) return 'Title is required.';
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
        'video_url': videoUrl.trim(),
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

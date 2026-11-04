// Taking an assessment — production contract (apps/assessments/views/
// portal.py, serializers.py PortalItemSerializer / CandidateResponseSerializer).
//
// Item types: 'video' (watch, then mark as watched) and 'quiz' (one of four
// options a–d). Each response is saved on the server as soon as it is sent
// (POST /assessments/<a>/respond/<item>/); the assessment is graded by the
// server on POST /assessments/<a>/complete/.

int _int(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
String _s(Object? v) => v == null ? '' : '$v';

enum AssessmentItemType { video, quiz }

/// One video or quiz item (PortalItemSerializer). The correct answer is
/// never sent to the employee.
class AssessmentPortalItem {
  final String id;
  final AssessmentItemType type;
  final String title;
  final int order;
  final String? sectionTitle;
  final String videoUrl;
  final int? durationSecs;
  final String question;

  /// Non-empty options only, in a–d order: (key, text).
  final List<(String, String)> options;

  const AssessmentPortalItem({
    required this.id,
    required this.type,
    required this.title,
    required this.order,
    this.sectionTitle,
    this.videoUrl = '',
    this.durationSecs,
    this.question = '',
    this.options = const [],
  });

  factory AssessmentPortalItem.fromJson(Map<String, dynamic> json) {
    final options = <(String, String)>[
      for (final k in const ['a', 'b', 'c', 'd'])
        if (_s(json['option_$k']).trim().isNotEmpty) (k, _s(json['option_$k'])),
    ];
    final section = _s(json['section_title']).trim();
    return AssessmentPortalItem(
      id: _s(json['id']),
      type: json['item_type'] == 'video'
          ? AssessmentItemType.video
          : AssessmentItemType.quiz,
      title: _s(json['title']),
      order: _int(json['order']),
      sectionTitle: section.isEmpty ? null : section,
      videoUrl: _s(json['video_url']),
      durationSecs:
          json['duration_secs'] == null ? null : _int(json['duration_secs']),
      question: _s(json['question']),
      options: options,
    );
  }
}

/// The employee's saved response to one item (CandidateResponseSerializer).
class AssessmentItemResponse {
  final String itemId;
  final bool isWatched;

  /// 'a'–'d', or '' when not answered.
  final String selectedOption;
  final bool? isCorrect;
  final int scoreAwarded;

  const AssessmentItemResponse({
    required this.itemId,
    this.isWatched = false,
    this.selectedOption = '',
    this.isCorrect,
    this.scoreAwarded = 0,
  });

  factory AssessmentItemResponse.fromJson(Map<String, dynamic> json) =>
      AssessmentItemResponse(
        itemId: _s(json['item_id']),
        isWatched: json['is_watched'] == true,
        selectedOption: _s(json['selected_option']).toLowerCase(),
        isCorrect:
            json['is_correct'] is bool ? json['is_correct'] as bool : null,
        scoreAwarded: _int(json['score_awarded']),
      );
}

/// Reply to POST .../respond/<item>/ ("Response recorded.").
class AssessmentRespondResult {
  final String itemId;
  final bool? isCorrect;
  final int scoreAwarded;
  final int assignmentScore;

  const AssessmentRespondResult({
    required this.itemId,
    this.isCorrect,
    this.scoreAwarded = 0,
    this.assignmentScore = 0,
  });

  factory AssessmentRespondResult.fromJson(Object? data) {
    final m = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return AssessmentRespondResult(
      itemId: _s(m['item_id']),
      isCorrect: m['is_correct'] is bool ? m['is_correct'] as bool : null,
      scoreAwarded: _int(m['score_awarded']),
      assignmentScore: _int(m['assignment_score']),
    );
  }
}

/// Reply to POST .../complete/ ("Assessment submitted."). The server grades
/// the attempt (section weights included); the app only displays it.
class AssessmentCompleteResult {
  final int score;
  final int maxScore;
  final int scorePercentage;
  final int passPercentage;
  final bool passed;

  const AssessmentCompleteResult({
    required this.score,
    required this.maxScore,
    required this.scorePercentage,
    required this.passPercentage,
    required this.passed,
  });

  factory AssessmentCompleteResult.fromJson(Object? data) {
    final m = data is Map<String, dynamic> ? data : const <String, dynamic>{};
    return AssessmentCompleteResult(
      score: _int(m['score']),
      maxScore: _int(m['max_score']),
      scorePercentage: _int(m['score_percentage']),
      passPercentage: _int(m['pass_percentage']),
      passed: m['passed'] == true,
    );
  }
}

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:mobile_app/core/constants/api_constants.dart';

// A stand-in for the production assessment portal (apps/assessments/views/
// portal.py), applying its rules: respond saves one item (video: watched;
// quiz: a–d), refused once completed or past the deadline; complete refuses
// until every item is done and grades the attempt; retry resets a completed
// attempt within the attempt limit. Also answers GET /employees/me/.

ResponseBody json(int status, Object body) =>
    ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });

ResponseBody ok(String message, Object? data) =>
    json(200, {'status': 'success', 'message': message, 'data': data});

ResponseBody fail(int status, String message) =>
    json(status, {'status': 'error', 'message': message, 'data': {}});

Map<String, dynamic> quiz(String id, int order, String correct,
        {String question = 'Question?'}) =>
    {
      'id': id,
      'item_type': 'quiz',
      'title': 'Quiz $id',
      'order': order,
      'section_id': null,
      'section_title': null,
      'video_url': '',
      'duration_secs': null,
      'question': '$question ($id)',
      'option_a': 'Alpha',
      'option_b': 'Bravo',
      'option_c': 'Charlie',
      'option_d': '',
      '_correct': correct, // server-only, stripped from responses
    };

Map<String, dynamic> video(String id, int order) => {
      'id': id,
      'item_type': 'video',
      'title': 'Video $id',
      'order': order,
      'section_id': null,
      'section_title': null,
      'video_url': 'https://www.youtube.com/embed/abc',
      'duration_secs': 125,
      'question': '',
      'option_a': '',
      'option_b': '',
      'option_c': '',
      'option_d': '',
    };

class FakeAssignment {
  FakeAssignment(this.id,
      {required this.items,
      this.title = 'Workplace Safety',
      this.pass = 60,
      this.maxAttempts = 2,
      this.attemptCount = 1,
      this.timeLimitMins,
      this.timeRemainingSecs,
      this.deadline});

  final String id;
  final String title;
  final int pass;
  final int maxAttempts; // 0 = unlimited
  int attemptCount;
  final int? timeLimitMins;
  int? timeRemainingSecs;
  final String? deadline;
  final List<Map<String, dynamic>> items;
  String status = 'pending';
  int score = 0;
  int maxScore = 0;
  String? completedAt;
  final responses = <String, Map<String, dynamic>>{};

  /// Set to make the server treat the deadline as passed.
  bool expired = false;
  bool get pastDeadline =>
      expired ||
      (deadline != null && DateTime.now().isAfter(DateTime.parse(deadline!)));
  bool done(Map<String, dynamic> it) {
    final r = responses[it['id']];
    if (r == null) return false;
    return it['item_type'] == 'video'
        ? r['is_watched'] == true
        : (r['selected_option'] as String).isNotEmpty;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'assessment_title': title,
        'pass_percentage': pass,
        'status': status,
        'score': score,
        'max_score': maxScore,
        'total_items': items.length,
        'completed_items': items.where(done).length,
        'attempt_count': attemptCount,
        'effective_max_attempts': maxAttempts,
        'attempts_remaining':
            maxAttempts == 0 ? null : (maxAttempts - attemptCount).clamp(0, 99),
        'started_at': responses.isEmpty ? null : '2026-11-04T09:00:00Z',
        'time_limit_mins': timeLimitMins,
        'time_remaining_secs': timeRemainingSecs,
        'deadline': deadline,
        'completed_at': completedAt,
        'items': [for (final it in items) Map.of(it)..remove('_correct')],
        'responses': responses.values.toList(),
      };
}

class FakeAssessmentServer implements HttpClientAdapter {
  FakeAssessmentServer(this.assignments, {this.profileStatus = 'pending'});

  final List<FakeAssignment> assignments;
  String profileStatus;
  bool failMy = false;
  bool failProfile = false;

  /// When set, the next respond call fails with a connection error.
  bool dropNextRespond = false;

  /// When set, complete waits for this before answering.
  Completer<void>? holdComplete;
  final calls = <({String method, String path, Object? body})>[];

  int count(String method, String pathPart) => calls
      .where((c) => c.method == method && c.path.contains(pathPart))
      .length;

  FakeAssignment? _find(String id) {
    for (final a in assignments) {
      if (a.id == id) return a;
    }
    return null;
  }

  @override
  Future<ResponseBody> fetch(
      RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    calls.add((method: o.method, path: o.path, body: o.data));
    final p = o.path;
    if (p == ApiConstants.assessmentsMy) {
      if (failMy) return fail(500, 'Server error.');
      return ok('Assessments retrieved.', {
        'assignments': [for (final a in assignments) a.toJson()],
        'all_complete': assignments.every((a) => a.status == 'complete'),
      });
    }
    if (p == ApiConstants.myProfile) {
      if (failProfile) return fail(500, 'Server error.');
      return ok('Profile retrieved.', {
        'id': 'u1',
        'assessment_status': profileStatus,
        'profile': <String, dynamic>{}
      });
    }
    final m =
        RegExp(r'^/assessments/([^/]+)/(respond/([^/]+)|complete|retry)/$')
            .firstMatch(p);
    final a = m == null ? null : _find(m.group(1)!);
    if (m == null || a == null) return fail(404, 'Assignment not found.');
    final action = m.group(2)!;

    if (action.startsWith('respond')) {
      if (dropNextRespond) {
        dropNextRespond = false;
        throw DioException(
            requestOptions: o, type: DioExceptionType.connectionError);
      }
      if (a.status == 'complete') {
        return fail(409, 'This assessment is already completed.');
      }
      if (a.pastDeadline) {
        return fail(403, 'The deadline for this assessment has passed.');
      }
      final item =
          a.items.firstWhere((it) => it['id'] == m.group(3), orElse: () => {});
      if (item.isEmpty) return fail(404, 'Item not found in this assessment.');
      if (item['item_type'] == 'video') {
        a.responses[item['id']] = {
          'item_id': item['id'],
          'item_type': 'video',
          'is_watched': true,
          'selected_option': '',
          'is_correct': null,
          'score_awarded': 0
        };
      } else {
        final sel = ((o.data as Map?)?['selected_option'] as String? ?? '')
            .toLowerCase();
        if (!['a', 'b', 'c', 'd'].contains(sel)) {
          return fail(400, 'selected_option must be a, b, c, or d.');
        }
        final correct = sel == item['_correct'];
        a.responses[item['id']] = {
          'item_id': item['id'],
          'item_type': 'quiz',
          'is_watched': false,
          'selected_option': sel,
          'is_correct': correct,
          'score_awarded': correct ? 1 : 0
        };
      }
      if (a.status == 'pending') a.status = 'in_progress';
      final r = a.responses[item['id']]!;
      return ok('Response recorded.', {
        'item_id': item['id'],
        'item_type': item['item_type'],
        'is_correct': r['is_correct'],
        'score_awarded': r['score_awarded'],
        'assignment_score': a.responses.values
            .fold<int>(0, (s, x) => s + (x['score_awarded'] as int)),
      });
    }
    if (action == 'complete') {
      if (holdComplete != null) await holdComplete!.future;
      if (a.status == 'complete') {
        return fail(409, 'Assignment already completed.');
      }
      if (a.pastDeadline) {
        return fail(403, 'The deadline for this assessment has passed.');
      }
      final doneCount = a.items.where(a.done).length;
      if (doneCount < a.items.length) {
        return fail(400,
            'Complete all items first. $doneCount/${a.items.length} done.');
      }
      final quizzes = a.items.where((it) => it['item_type'] == 'quiz').toList();
      a.score = quizzes
          .where((it) => a.responses[it['id']]?['is_correct'] == true)
          .length;
      a.maxScore = quizzes.length;
      a.status = 'complete';
      a.completedAt = '2026-11-04T10:00:00Z';
      final pct = a.maxScore == 0 ? 100 : (a.score / a.maxScore * 100).round();
      if (assignments.every((x) => x.status == 'complete')) {
        profileStatus = 'complete';
      }
      return ok('Assessment submitted.', {
        'score': a.score,
        'max_score': a.maxScore,
        'score_percentage': pct,
        'pass_percentage': a.pass,
        'passed': pct >= a.pass,
      });
    }
    // retry
    if (a.status != 'complete') {
      return fail(409, 'Only completed assessments can be retried.');
    }
    if (a.maxAttempts != 0 && a.attemptCount >= a.maxAttempts) {
      return fail(403,
          'Maximum attempts (${a.maxAttempts}) reached. This assessment is locked.');
    }
    a.responses.clear();
    a.status = 'pending';
    a.score = 0;
    a.completedAt = null;
    a.attemptCount++;
    profileStatus = 'pending';
    return ok('Assessment reset. You can now retry.', null);
  }

  @override
  void close({bool force = false}) {}
}

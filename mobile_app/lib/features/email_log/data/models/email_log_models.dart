import '../../domain/entities/email_log_entity.dart';

class CandidateEmailModel extends CandidateEmailEntity {
  const CandidateEmailModel({
    required super.id,
    super.templateUsed,
    required super.subject,
    required super.toEmail,
    required super.status,
    super.sentByName,
    required super.sentAt,
    super.candidateId,
    super.candidateName,
    super.candidatePosition,
  });

  // Matches CandidateEmailSerializer exactly (apps/recruitment/serializers.py)
  // — 'candidate' is the plain FK pk (an int), not a nested object.
  factory CandidateEmailModel.fromJson(Map<String, dynamic> json) {
    return CandidateEmailModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      templateUsed: json['template_used'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      toEmail: json['to_email'] as String? ?? '',
      status: json['status'] as String? ?? 'sent',
      sentByName: json['sent_by_name'] as String? ?? '',
      sentAt: json['sent_at'] as String? ?? '',
      candidateId: (json['candidate'] as num?)?.toInt(),
      candidateName: json['candidate_name'] as String? ?? '',
      candidatePosition: json['candidate_position'] as String? ?? '',
    );
  }
}

class EmailLogPageModel extends EmailLogPageEntity {
  const EmailLogPageModel({
    required super.results,
    required super.count,
    required super.page,
    required super.pageSize,
    required super.totalPages,
  });

  factory EmailLogPageModel.fromJson(dynamic json) {
    if (json is! Map<String, dynamic>) {
      return const EmailLogPageModel(
          results: [], count: 0, page: 1, pageSize: 20, totalPages: 1);
    }
    final list = json['results'] as List<dynamic>? ?? [];
    return EmailLogPageModel(
      results: list
          .whereType<Map<String, dynamic>>()
          .map(CandidateEmailModel.fromJson)
          .toList(),
      count: (json['count'] as num?)?.toInt() ?? 0,
      page: (json['page'] as num?)?.toInt() ?? 1,
      pageSize: (json['page_size'] as num?)?.toInt() ?? 20,
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 1,
    );
  }
}

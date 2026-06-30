import '../../domain/entities/candidate_entity.dart';

class CandidateLogModel extends CandidateLogEntity {
  const CandidateLogModel({
    required super.id,
    required super.logType,
    required super.title,
    required super.description,
    required super.createdAt,
  });

  factory CandidateLogModel.fromJson(Map<String, dynamic> j) {
    return CandidateLogModel(
      id: j['id'] as int? ?? 0,
      logType: j['log_type'] as String? ?? 'info',
      title: j['title'] as String? ?? '',
      description: j['description'] as String? ?? '',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class CandidateModel extends CandidateEntity {
  const CandidateModel({
    required super.id,
    required super.name,
    required super.email,
    required super.phone,
    required super.positionApplied,
    super.branchId,
    required super.branchName,
    required super.interviewDate,
    required super.interviewMode,
    required super.status,
    required super.portalCredentialsSent,
    required super.addedByName,
    required super.createdAt,
    super.logs,
  });

  factory CandidateModel.fromJson(Map<String, dynamic> j) {
    final rawLogs = j['logs'] as List<dynamic>? ?? [];
    return CandidateModel(
      id: j['id'] as int,
      name: j['name'] as String? ?? '',
      email: j['email'] as String? ?? '',
      phone: j['phone'] as String? ?? '',
      positionApplied: j['position_applied'] as String? ?? '',
      branchId: j['branch'] as int?,
      branchName: j['branch_name'] as String? ?? '',
      interviewDate: j['interview_date'] as String? ?? '',
      interviewMode: j['interview_mode'] as String? ?? 'in_person',
      status: j['status'] as String? ?? 'pending',
      portalCredentialsSent:
          j['portal_credentials_sent'] as bool? ?? false,
      addedByName: j['added_by_name'] as String? ?? '',
      createdAt:
          DateTime.tryParse(j['created_at'] as String? ?? '') ??
              DateTime.now(),
      logs: rawLogs
          .map((l) =>
              CandidateLogModel.fromJson(l as Map<String, dynamic>))
          .toList(),
    );
  }
}

class CandidateStatsModel extends CandidateStatsEntity {
  const CandidateStatsModel({
    required super.total,
    required super.pending,
    required super.selected,
    required super.rejected,
  });

  factory CandidateStatsModel.fromJson(Map<String, dynamic> j) {
    return CandidateStatsModel(
      total: j['total'] as int? ?? 0,
      pending: j['pending'] as int? ?? 0,
      selected: j['selected'] as int? ?? 0,
      rejected: j['rejected'] as int? ?? 0,
    );
  }
}

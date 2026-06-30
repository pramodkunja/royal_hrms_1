class CandidateLogEntity {
  final int id;
  final String logType; // info | success | error | warn
  final String title;
  final String description;
  final DateTime createdAt;
  const CandidateLogEntity({
    required this.id,
    required this.logType,
    required this.title,
    required this.description,
    required this.createdAt,
  });
}

class CandidateStatsEntity {
  final int total;
  final int pending;
  final int selected;
  final int rejected;
  const CandidateStatsEntity({
    required this.total,
    required this.pending,
    required this.selected,
    required this.rejected,
  });
}

class CandidateEntity {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String positionApplied;
  final int? branchId;
  final String branchName;
  final String interviewDate;   // yyyy-MM-dd or empty
  final String interviewMode;   // in_person | phone | video_call
  final String status;
  final bool portalCredentialsSent;
  final String addedByName;
  final DateTime createdAt;
  final List<CandidateLogEntity> logs;

  const CandidateEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.positionApplied,
    this.branchId,
    required this.branchName,
    required this.interviewDate,
    required this.interviewMode,
    required this.status,
    required this.portalCredentialsSent,
    required this.addedByName,
    required this.createdAt,
    this.logs = const [],
  });

  // Convenience
  bool get isConverted     => status == 'converted';
  bool get isOfferSent     => status == 'offer_sent';
  bool get isSelected      => status == 'selected';
  bool get isRejected      => status == 'rejected';
  bool get canSendLogin    => isSelected && !portalCredentialsSent;
  bool get canResendLogin  => isOfferSent && portalCredentialsSent;
}

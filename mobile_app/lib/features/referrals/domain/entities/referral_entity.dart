class ReferralEntity {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String positionApplied;
  final String branchName;
  final String referralByName;
  final String status; // pending|screening|interview_scheduled|interview_done|selected|offer_sent|converted|rejected
  final DateTime createdAt;

  const ReferralEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.positionApplied,
    required this.branchName,
    required this.referralByName,
    required this.status,
    required this.createdAt,
  });

  bool get isInPipeline => status != 'rejected' && status != 'converted';
  bool get isSelectedOrOffered => status == 'selected' || status == 'offer_sent';
  bool get isConverted => status == 'converted';
}

class ReferralRuleEntity {
  final int id;
  final String icon;
  final String title;
  final String body;
  final int order;
  final bool isActive;

  const ReferralRuleEntity({
    required this.id,
    required this.icon,
    required this.title,
    required this.body,
    required this.order,
    required this.isActive,
  });
}

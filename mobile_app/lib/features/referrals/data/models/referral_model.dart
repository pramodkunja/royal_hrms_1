import '../../domain/entities/referral_entity.dart';

class ReferralModel extends ReferralEntity {
  const ReferralModel({
    required super.id,
    required super.name,
    required super.email,
    required super.phone,
    required super.positionApplied,
    required super.branchName,
    required super.referralByName,
    required super.status,
    required super.createdAt,
  });

  // Backend returns a CandidateListSerializer row: name, email, phone,
  // position_applied, branch_name (computed), referral_by_name (computed),
  // status, created_at.
  factory ReferralModel.fromJson(Map<String, dynamic> json) {
    return ReferralModel(
      id:              (json['id'] as num? ?? 0).toInt(),
      name:            json['name'] as String? ?? '',
      email:           json['email'] as String? ?? '',
      phone:           json['phone'] as String? ?? '',
      positionApplied: json['position_applied'] as String? ?? '',
      branchName:      json['branch_name'] as String? ?? '',
      referralByName:  json['referral_by_name'] as String? ?? '',
      status:          json['status'] as String? ?? 'pending',
      createdAt:       DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class ReferralRuleModel extends ReferralRuleEntity {
  const ReferralRuleModel({
    required super.id,
    required super.icon,
    required super.title,
    required super.body,
    required super.order,
    required super.isActive,
  });

  // Backend returns a ReferralRuleSerializer row: icon, title, body, order, is_active.
  factory ReferralRuleModel.fromJson(Map<String, dynamic> json) {
    return ReferralRuleModel(
      id:       (json['id'] as num? ?? 0).toInt(),
      icon:     json['icon'] as String? ?? '',
      title:    json['title'] as String? ?? '',
      body:     json['body'] as String? ?? '',
      order:    (json['order'] as num? ?? 1).toInt(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

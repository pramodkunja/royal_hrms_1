/// Dart port of web's `GlobalApprovalRule` (types/approvalMatrix.ts) — mirrors
/// backend's `ApprovalWorkflowRuleSerializer`. One row per workflow type
/// (leave/expense/resignation/loan); there are always exactly 4 rows — this
/// is a fixed config table, not a user-creatable list.
class ApprovalRuleModel {
  final String workflowType;
  final String workflowLabel;
  // Role FK primary key (see ApprovalWorkflowRuleSerializer.get_l1_approver_role
  // / get_l2_approver_role on the backend) — NOT a slug/choice string.
  final int? l1ApproverRole;
  final String l1ApproverLabel;
  final int? l2ApproverRole; // null = single-level (no L2)
  final String l2ApproverLabel;

  const ApprovalRuleModel({
    required this.workflowType,
    required this.workflowLabel,
    required this.l1ApproverRole,
    required this.l1ApproverLabel,
    required this.l2ApproverRole,
    required this.l2ApproverLabel,
  });

  factory ApprovalRuleModel.fromJson(Map<String, dynamic> json) {
    return ApprovalRuleModel(
      workflowType: json['workflow_type'] as String? ?? '',
      workflowLabel: json['workflow_label'] as String? ?? '',
      l1ApproverRole: json['l1_approver_role'] as int?,
      l1ApproverLabel: json['l1_approver_label'] as String? ?? '',
      l2ApproverRole: json['l2_approver_role'] as int?,
      l2ApproverLabel: json['l2_approver_label'] as String? ?? '',
    );
  }
}

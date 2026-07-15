/// Dart port of web's `GlobalApprovalRule` (types/approvalMatrix.ts) — mirrors
/// backend's `ApprovalWorkflowRuleSerializer`. One row per workflow type
/// (leave/expense/resignation/loan); there are always exactly 4 rows — this
/// is a fixed config table, not a user-creatable list.
class ApprovalRuleModel {
  final String workflowType;
  final String workflowLabel;
  final String l1ApproverRole;
  final String l1ApproverLabel;
  final String l2ApproverRole; // '' = single-level (no L2)
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
      l1ApproverRole: json['l1_approver_role'] as String? ?? '',
      l1ApproverLabel: json['l1_approver_label'] as String? ?? '',
      l2ApproverRole: json['l2_approver_role'] as String? ?? '',
      l2ApproverLabel: json['l2_approver_label'] as String? ?? '',
    );
  }
}

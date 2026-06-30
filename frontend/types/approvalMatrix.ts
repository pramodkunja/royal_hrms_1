export type ApprovalWorkflowType = "leave" | "expense" | "resignation" | "loan";
export type ApproverRole = "reporting_manager" | "hr_manager" | "admin";

export interface WorkflowMatrixRow {
  workflow_type:     ApprovalWorkflowType;
  workflow_label:    string;
  l1_approver_role:  ApproverRole;
  l1_approver_label: string;
  l1_override_id:    string | null;
  l1_override_name:  string | null;
  l2_approver_role:  ApproverRole | "";
  l2_approver_label: string;
  l2_override_id:    string | null;
  l2_override_name:  string | null;
}

export interface GlobalApprovalRule {
  workflow_type:     ApprovalWorkflowType;
  workflow_label:    string;
  l1_approver_role:  ApproverRole;
  l1_approver_label: string;
  l2_approver_role:  ApproverRole | "";
  l2_approver_label: string;
}

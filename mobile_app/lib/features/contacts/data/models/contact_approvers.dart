// Contact Matrix → "My Approvers" / "Employee Approvers" (Task 94, HO-42).
// Production contract (backend apps/accounts/views_policy.py
// ContactApproversView, read-only):
//   GET /company-contacts/approvers/?workflow=<leave|expense|
//       attendance_correction|wfh>  → {workflow, workflows: [{value,label}],
//       me: row, team: [row] | null}
//   row = {employee_id, name, department, branch, l1, l2}; l1/l2 =
//   {name, email, phone} or null.
//   `team` is null without employees.view; otherwise everyone (settings.edit),
//   a manager's direct reports, else the user's own branch (none when the
//   user has no branch). Web: frontend/lib/contactMatrix.ts +
//   app/dashboard/contacts/_components/ApproversSection.tsx.

/// Web NOT_ASSIGNED / DEFAULT_APPROVER_WORKFLOW.
const kApproverNotAssigned = 'Not Assigned';
const kDefaultApproverWorkflow = 'leave';

String _s(Object? v) => v == null ? '' : '$v';

class ApproverContact {
  const ApproverContact({required this.name, this.email = '', this.phone = ''});
  final String name;
  final String email;
  final String phone;

  static ApproverContact? fromJson(Object? j) {
    if (j is! Map) return null;
    return ApproverContact(name: _s(j['name']), email: _s(j['email']), phone: _s(j['phone']));
  }
}

class ApproverRow {
  const ApproverRow({
    required this.employeeId,
    required this.name,
    this.department = '',
    this.branch = '',
    this.l1,
    this.l2,
  });
  final String employeeId;
  final String name;
  final String department;
  final String branch;
  final ApproverContact? l1;
  final ApproverContact? l2;

  factory ApproverRow.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    return ApproverRow(
      employeeId: _s(m['employee_id']),
      name: _s(m['name']),
      department: _s(m['department']),
      branch: _s(m['branch']),
      l1: ApproverContact.fromJson(m['l1']),
      l2: ApproverContact.fromJson(m['l2']),
    );
  }

  /// Web: "EMP-1 · Department · Branch", empty parts left out.
  String get subtitle => [employeeId, department, branch].where((p) => p.isNotEmpty).join(' · ');
}

class ApproversResponse {
  const ApproversResponse({required this.workflow, required this.workflows, required this.me, this.team});
  final String workflow;
  final List<({String value, String label})> workflows;
  final ApproverRow me;

  /// Null = the caller lacks employees.view → web hides the team table.
  final List<ApproverRow>? team;

  factory ApproversResponse.fromJson(Object? j) {
    final m = j is Map ? j : const {};
    final ws = m['workflows'];
    final team = m['team'];
    return ApproversResponse(
      workflow: _s(m['workflow']),
      workflows: [
        for (final w in (ws is List ? ws : const []).whereType<Map>()) (value: _s(w['value']), label: _s(w['label'])),
      ],
      me: ApproverRow.fromJson(m['me']),
      team: team is List ? [for (final r in team) ApproverRow.fromJson(r)] : null,
    );
  }
}

/// Web filterApproverRows: name / employee ID / department / branch contain
/// the (trimmed, case-insensitive) query.
List<ApproverRow> filterApproverRows(List<ApproverRow> rows, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return [
    for (final r in rows)
      if ([r.name, r.employeeId, r.department, r.branch].any((v) => v.toLowerCase().contains(q))) r,
  ];
}

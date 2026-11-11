import '../../settings/data/models/roles_model.dart';
import '../data/models/branch_model.dart' show BranchAdminCandidate;

// Add Branch → "Assign Branch Admin (optional)": web
// app/dashboard/branches/_components/BranchManagement.tsx (LeaderForm,
// LeaderFields, isLeaderActive, validateLeaders, applyLeaderRole, the
// transfer confirm). Runs only after the branch itself was created; the
// branch is never blocked or rolled back by this optional step.
//
//  - "new": invites a new person through POST /employees/
//    (EmployeeListCreateView: a can_manage_branch role needs no department and
//    accepts a blank last name).
//  - "existing": moves an active employee in — PUT /employees/<code>/ with
//    only {role, branch}.

enum BranchLeaderMode { newPerson, existing }

class BranchLeaderForm {
  const BranchLeaderForm({
    this.mode = BranchLeaderMode.newPerson,
    this.name = '',
    this.email = '',
    this.designation = 'Branch Manager',
    this.employeeCode = '',
    this.search = '',
  });

  final BranchLeaderMode mode;
  final String name;
  final String email;

  /// Web pre-fills "Branch Manager" — shown and editable.
  final String designation;

  /// The chosen employee's code (employee list `id`).
  final String employeeCode;
  final String search;

  BranchLeaderForm copyWith({
    BranchLeaderMode? mode,
    String? name,
    String? email,
    String? designation,
    String? employeeCode,
    String? search,
  }) =>
      BranchLeaderForm(
        mode: mode ?? this.mode,
        name: name ?? this.name,
        email: email ?? this.email,
        designation: designation ?? this.designation,
        employeeCode: employeeCode ?? this.employeeCode,
        search: search ?? this.search,
      );

  /// Web isLeaderActive: the row is "in use" once touched — an employee
  /// picked, or a name or email typed. An untouched row is simply skipped.
  bool get isActive =>
      mode == BranchLeaderMode.existing ? employeeCode.isNotEmpty : (name.trim().isNotEmpty || email.trim().isNotEmpty);
}

/// Web EMAIL_RE.
final _emailRe = RegExp(
    r'^[A-Za-z0-9][A-Za-z0-9._%+-]*@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$');

/// Web validateLeaders — only for a row in use. Keys: employee, name, email,
/// designation.
Map<String, String> validateBranchLeader(BranchLeaderForm f) {
  final errs = <String, String>{};
  if (!f.isActive) return errs;
  if (f.mode == BranchLeaderMode.existing) {
    if (f.employeeCode.isEmpty) errs['employee'] = 'Select an employee.';
  } else {
    if (f.name.trim().isEmpty) errs['name'] = 'Name is required.';
    if (f.email.trim().isEmpty) {
      errs['email'] = 'Email is required.';
    } else if (!_emailRe.hasMatch(f.email.trim())) {
      errs['email'] = 'Enter a valid email.';
    }
    if (f.designation.trim().isEmpty) errs['designation'] = 'Designation is required.';
  }
  return errs;
}

/// Web: the Branch Admin role is found by capability, never by name — the
/// first role with can_manage_branch that does NOT carry settings.edit (a role
/// with both is company-wide, not branch-scoped).
RoleModel? branchAdminRole(List<RoleModel> roles) =>
    roles.where((r) => r.canManageBranch && !r.permissions.contains('settings.edit')).firstOrNull;

const kNoBranchAdminRole = 'No Branch Admin role is set up for this company yet.';

/// Web applyLeaderRole "new": POST /employees/ body. A single-word name is
/// kept as the first name with a blank last name (never duplicated).
Map<String, dynamic> newBranchAdminPayload(BranchLeaderForm f, RoleModel role, String branchName, DateTime today) {
  final name = f.name.trim();
  final splitAt = name.indexOf(' ');
  String two(int n) => n.toString().padLeft(2, '0');
  return {
    'first_name': splitAt == -1 ? name : name.substring(0, splitAt),
    'last_name': splitAt == -1 ? '' : name.substring(splitAt + 1).trim(),
    'email': f.email.trim(),
    'role': role.id,
    'designation': f.designation.trim(),
    'branch': branchName,
    'date_of_joining': '${today.year}-${two(today.month)}-${two(today.day)}',
  };
}

/// Web applyLeaderRole "existing": PUT /employees/<code>/ — role and branch
/// only (a transfer, not a new hire).
Map<String, dynamic> existingBranchAdminPayload(RoleModel role, String branchName) =>
    {'role': role.name, 'branch': branchName};

/// Web LeaderFields search: name, email or employee ID, case-insensitive.
List<BranchAdminCandidate> filterBranchLeaderCandidates(List<BranchAdminCandidate> all, String search) {
  final q = search.trim().toLowerCase();
  if (q.isEmpty) return all;
  return all
      .where((e) =>
          e.fullName.toLowerCase().contains(q) ||
          e.email.toLowerCase().contains(q) ||
          e.employeeId.toLowerCase().contains(q))
      .toList();
}

/// Web transfer confirm text.
String transferConfirmBody(BranchAdminCandidate e) =>
    '${e.fullName} currently belongs to ${e.branch.isEmpty ? 'no branch' : e.branch}. This will move them to the new '
    'branch and change their role to Branch Admin.';

String? reportsWarning(int n) => n > 0
    ? "They currently manage $n ${n == 1 ? 'employee' : 'employees'} — that reporting line won't be reassigned automatically."
    : null;

String? hrForWarning(int n) => n > 0
    ? "They're the assigned HR for $n ${n == 1 ? 'employee' : 'employees'} — that assignment won't be reassigned automatically."
    : null;

/// Web inviteAlert texts after the branch was created.
String branchLeaderSuccess(String branchName, BranchLeaderMode mode) => mode == BranchLeaderMode.newPerson
    ? '$branchName was created and its Branch Admin was invited by email.'
    : '$branchName was created and its Branch Admin was assigned.';

String branchLeaderFailure(String branchName, String reason) =>
    '$branchName was created, but assigning its Branch Admin failed: $reason — use the Employees page instead.';

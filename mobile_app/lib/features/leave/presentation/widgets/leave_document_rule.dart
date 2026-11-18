import '../../domain/entities/leave_entity.dart';

/// Web `LEAVE_TYPE_CONFIG[...].requiresDoc` (frontend/app/dashboard/leave
/// /_data.ts:25-30): the built-in default, used only while the type's policy
/// has not loaded (web documentRule `fallback`).
const kBuiltinLeaveTypesRequiringDoc = {'sick', 'maternity', 'paternity'};

/// Web `configForPolicy(...).requiresDoc` for a custom type, else the
/// built-in default.
bool leaveDocFallback(String code, LeaveTypeEntity? policy) {
  final c = code.toLowerCase();
  if (kBuiltinLeaveTypesRequiringDoc.contains(c)) return true;
  return policy != null && (policy.attachmentRequired || policy.medicalCertificateRequired);
}

/// Whether Apply Leave must ask for a supporting document — web
/// `documentRule` (leave/_data.ts:126-138), the same rule the server applies
/// (backend views/leave.py:539-545):
///   Attachment Required          → always required
///   Medical Certificate Required → required for leave of N or more days
///                                  (N = medical_certificate_after_days)
///   neither                      → optional
/// [days] is the server preview's `actual_leave_days`, or the local estimate
/// before it loads (web `preview?.actual_leave_days ?? workDays`).
/// [policy] null = not loaded yet → [fallback].
({bool required, String hint}) leaveDocumentRule(LeaveTypeEntity? policy, double days, {required bool fallback}) {
  if (policy == null) return (required: fallback, hint: '');
  if (policy.attachmentRequired) return (required: true, hint: '');
  if (policy.medicalCertificateRequired) {
    final n = policy.medicalCertificateAfterDays;
    final hint = 'A medical certificate is required for leave of $n or more day${n == 1 ? '' : 's'}.';
    return (required: days >= n, hint: hint);
  }
  return (required: false, hint: '');
}

/// Web submit message: the hint, else the generic one.
String leaveDocumentRequiredMessage(String hint) =>
    hint.isNotEmpty ? hint : 'Supporting document is required for this leave type.';

/// One persisted promotion — GET /employees/<id>/promotions/
/// (EmployeePromotionHistoryView; a PromotionRecord is created by
/// EmployeeDetailView.put whenever designation or role changes). The list is
/// ordered by the server: newest effective_date first, then newest created.
class PromotionRecordModel {
  const PromotionRecordModel({
    required this.id,
    required this.previousDesignation,
    required this.newDesignation,
    required this.previousRole,
    required this.newRole,
    required this.roleChanged,
    required this.effectiveDate,
    required this.remarks,
    required this.promotedBy,
    required this.createdAt,
  });

  final String id;
  final String previousDesignation;
  final String newDesignation;
  final String previousRole; // role slug, e.g. "hr_admin"
  final String newRole;
  final bool roleChanged;
  final String effectiveDate; // YYYY-MM-DD
  final String remarks;
  final String promotedBy; // full name, or "—"
  final String createdAt;

  /// Web toPromotionRecord: the API sends role_changed; designation change
  /// is derived.
  bool get designationChanged => previousDesignation != newDesignation;

  factory PromotionRecordModel.fromJson(Map<String, dynamic> j) => PromotionRecordModel(
        id: '${j['id'] ?? ''}',
        previousDesignation: j['previous_designation'] as String? ?? '',
        newDesignation: j['new_designation'] as String? ?? '',
        previousRole: j['previous_role'] as String? ?? '',
        newRole: j['new_role'] as String? ?? '',
        roleChanged:
            j['role_changed'] as bool? ?? ((j['previous_role'] as String? ?? '') != (j['new_role'] as String? ?? '')),
        effectiveDate: j['effective_date'] as String? ?? '',
        remarks: j['remarks'] as String? ?? '',
        promotedBy: j['promoted_by'] as String? ?? '',
        createdAt: j['created_at'] as String? ?? '',
      );
}

const _kMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// Web fmtDate (en-IN, 2-digit day, short month, numeric year): "05 Nov 2026".
String formatPromotionDate(String iso) {
  if (iso.isEmpty) return '—';
  final d = DateTime.tryParse(iso);
  if (d == null) return iso;
  return '${d.day.toString().padLeft(2, '0')} ${_kMonths[d.month - 1]} ${d.year}';
}

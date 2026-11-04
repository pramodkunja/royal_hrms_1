// Payslip queries — production contract (apps/payroll/views/payslips.py
// PayslipQueryListView, serializers.py PayslipQuerySerializer):
//   GET  /payroll/queries/?mine=1 → [query…] the caller's own queries, every
//        status, newest first (a flat list, not paginated). Without mine=1 a
//        payroll.view holder gets the HR queue instead, so mine=1 is always
//        sent.
//   POST /payroll/queries/ {payslip: <uuid>, description: <text>} — only on
//        the caller's own payslip, while it is "sent" or "acknowledged" and
//        its query_deadline has not passed; description required, at most
//        2000 characters. Raising one moves the payslip to "queried", so a
//        second query on it is refused.
// No categories, attachments, detail endpoint, reply, edit or delete exist;
// HR resolves a query with a resolution note. Client rules below mirror web
// (frontend/lib/payslipQuery.ts); the server stays the authority.

const kPayslipQueryMaxLength = 2000;

class PayslipQueryModel {
  final String id;
  final String payslipId;
  final String description;
  final String status; // open | resolved
  final String resolutionNote;
  final String? resolvedByName;
  final String? resolvedAt;
  final String? cycleStart;
  final String createdAt;

  const PayslipQueryModel({
    required this.id,
    required this.payslipId,
    required this.description,
    required this.status,
    this.resolutionNote = '',
    this.resolvedByName,
    this.resolvedAt,
    this.cycleStart,
    required this.createdAt,
  });

  bool get isResolved => status == 'resolved';

  factory PayslipQueryModel.fromJson(Map<String, dynamic> json) => PayslipQueryModel(
        id: '${json['id'] ?? ''}',
        payslipId: '${json['payslip'] ?? ''}',
        description: '${json['description'] ?? ''}',
        status: '${json['status'] ?? 'open'}',
        resolutionNote: '${json['resolution_note'] ?? ''}',
        resolvedByName: json['resolved_by_name'] as String?,
        resolvedAt: json['resolved_at'] as String?,
        cycleStart: json['cycle_start'] as String?,
        createdAt: '${json['created_at'] ?? ''}',
      );
}

/// Web QUERY_STATUS_LABEL.
String payslipQueryStatusLabel(String status) => switch (status) {
      'open' => 'Open',
      'resolved' => 'Resolved',
      _ => status,
    };

/// Web canRaiseQuery: sent or acknowledged, and the window still open.
({bool allowed, String? reason}) canRaisePayslipQuery(String payslipStatus, String? queryDeadline, {DateTime? now}) {
  if (payslipStatus == 'queried') return (allowed: false, reason: 'A query on this payslip is already open.');
  if (payslipStatus != 'sent' && payslipStatus != 'acknowledged') {
    return (allowed: false, reason: 'Queries can be raised once the payslip has been sent to you.');
  }
  final deadline = queryDeadline == null ? null : DateTime.tryParse(queryDeadline);
  if (deadline != null && (now ?? DateTime.now()).isAfter(deadline)) {
    return (allowed: false, reason: 'The query window for this payslip has closed.');
  }
  return (allowed: true, reason: null);
}

/// Web validateQueryText; null when acceptable.
String? validatePayslipQueryText(String text) {
  final t = text.trim();
  if (t.isEmpty) return 'Please describe your query.';
  if (t.length > kPayslipQueryMaxLength) return 'Please keep the query under $kPayslipQueryMaxLength characters.';
  return null;
}

/// Web queriesFor: one payslip's queries, newest first.
List<PayslipQueryModel> queriesForPayslip(List<PayslipQueryModel> all, String payslipId) =>
    all.where((q) => q.payslipId == payslipId).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

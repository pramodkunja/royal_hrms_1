import '../../domain/entities/document_entity.dart';

// Company Policy acknowledgement — production contract
// (apps/accounts/views_policy.py, origin/production 95fc10a):
//   GET  /documents/pending-acknowledgements/ → [{id, title, category,
//        version}] active documents needing acknowledgement that the caller
//        has not acknowledged in their current version (empty without
//        documents.view; branch documents only for that branch).
//   POST /documents/<id>/acknowledge/ {version} — documents.view; 400
//        "version is required.", 404 not found / not visible / not required,
//        409 when version is not the current one ("This document has been
//        updated. Please reopen it and read the latest version."); 201
//        "Acknowledged." or 200 "Already acknowledged." with
//        {document, version, acknowledged_at}.
//   GET  /documents/<id>/acknowledgements/ — documents.edit; {document:
//        {id, title, version}, total, acknowledged, employees: [{employee_id,
//        name, branch, department, acknowledged_at}]} for the requester's
//        scope (settings.edit everyone; a manager their direct reports;
//        otherwise their branch).
//   PATCH /documents/<id>/ {requires_acknowledgement} — documents.edit.
// The upload (POST /documents/) takes requires_acknowledgement too; web
// sends "true" only when ticked.

class PendingAcknowledgement {
  final int id;
  final String title;
  final String category;
  final int version;
  const PendingAcknowledgement({required this.id, required this.title, required this.category, required this.version});

  factory PendingAcknowledgement.fromJson(Map<String, dynamic> j) => PendingAcknowledgement(
        id: (j['id'] as num?)?.toInt() ?? 0,
        title: '${j['title'] ?? ''}',
        category: '${j['category'] ?? ''}',
        version: (j['version'] as num?)?.toInt() ?? 1,
      );
}

class AckReportRow {
  final String employeeId;
  final String name;
  final String branch;
  final String department;
  final String? acknowledgedAt;
  const AckReportRow(
      {required this.employeeId, required this.name, this.branch = '', this.department = '', this.acknowledgedAt});

  factory AckReportRow.fromJson(Map<String, dynamic> j) => AckReportRow(
        employeeId: '${j['employee_id'] ?? ''}',
        name: '${j['name'] ?? ''}',
        branch: '${j['branch'] ?? ''}',
        department: '${j['department'] ?? ''}',
        acknowledgedAt: j['acknowledged_at']?.toString(),
      );
}

class AckReport {
  final int documentId;
  final String title;
  final int version;
  final int total;
  final int acknowledged;
  final List<AckReportRow> employees;
  const AckReport({
    required this.documentId,
    required this.title,
    required this.version,
    required this.total,
    required this.acknowledged,
    required this.employees,
  });

  factory AckReport.fromJson(Map<String, dynamic> j) {
    final d = j['document'] is Map ? (j['document'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
    return AckReport(
      documentId: (d['id'] as num?)?.toInt() ?? 0,
      title: '${d['title'] ?? ''}',
      version: (d['version'] as num?)?.toInt() ?? 1,
      total: (j['total'] as num?)?.toInt() ?? 0,
      acknowledged: (j['acknowledged'] as num?)?.toInt() ?? 0,
      employees: (j['employees'] is List ? j['employees'] as List : const [])
          .whereType<Map>()
          .map((e) => AckReportRow.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

/// Web policyAck.ts ackState.
enum AckState { notRequired, pending, acknowledged }

AckState ackStateOf(DocumentEntity doc) {
  if (!doc.requiresAcknowledgement) return AckState.notRequired;
  return doc.myAcknowledgedAt == null ? AckState.pending : AckState.acknowledged;
}

/// Web filterAckRows.
enum AckFilter { pending, acknowledged, all }

List<AckReportRow> filterAckRows(List<AckReportRow> rows, AckFilter show) => switch (show) {
      AckFilter.pending => rows.where((r) => r.acknowledgedAt == null).toList(),
      AckFilter.acknowledged => rows.where((r) => r.acknowledgedAt != null).toList(),
      AckFilter.all => rows,
    };

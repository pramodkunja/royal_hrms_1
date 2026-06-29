import 'package:flutter/foundation.dart';

@immutable
class AuditLogEntry {
  final int id;
  final String actorName;     // actor_name
  final String actorEmail;    // actor_email
  final String actorRole;     // actor_role
  final String module;
  final String action;
  final String? objectId;     // object_id
  final String? ipAddress;    // ip_address
  final String createdAt;     // created_at

  const AuditLogEntry({
    required this.id,
    required this.actorName,
    required this.actorEmail,
    required this.actorRole,
    required this.module,
    required this.action,
    this.objectId,
    this.ipAddress,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
    id:          json['id'] as int? ?? 0,
    actorName:   json['actor_name'] as String? ?? json['performed_by'] as String? ?? '—',
    actorEmail:  json['actor_email'] as String? ?? '',
    actorRole:   json['actor_role'] as String? ?? '',
    module:      json['module'] as String? ?? '',
    action:      json['action'] as String? ?? '',
    objectId:    json['object_id']?.toString(),
    ipAddress:   json['ip_address'] as String?,
    createdAt:   json['created_at'] as String? ?? json['timestamp'] as String? ?? '',
  );
}

@immutable
class AuditLogFilters {
  final String search;
  final String module;
  final String dateFrom;
  final String dateTo;
  final int page;

  const AuditLogFilters({
    this.search = '',
    this.module = '',
    this.dateFrom = '',
    this.dateTo = '',
    this.page = 1,
  });

  Map<String, String> toQueryParams() => {
    if (search.isNotEmpty)   'search':    search,
    if (module.isNotEmpty)   'module':    module,
    if (dateFrom.isNotEmpty) 'date_from': dateFrom,
    if (dateTo.isNotEmpty)   'date_to':   dateTo,
    'page': page.toString(),
  };

  AuditLogFilters copyWith({
    String? search,
    String? module,
    String? dateFrom,
    String? dateTo,
    int? page,
  }) => AuditLogFilters(
    search:   search   ?? this.search,
    module:   module   ?? this.module,
    dateFrom: dateFrom ?? this.dateFrom,
    dateTo:   dateTo   ?? this.dateTo,
    page:     page     ?? this.page,
  );
}

@immutable
class AuditLogPage {
  final List<AuditLogEntry> entries;
  final int total;
  final int currentPage;
  final int totalPages;
  final bool hasNext;

  const AuditLogPage({
    required this.entries,
    required this.total,
    required this.currentPage,
    required this.totalPages,
    required this.hasNext,
  });

  factory AuditLogPage.empty() => const AuditLogPage(
    entries: [], total: 0, currentPage: 1, totalPages: 1, hasNext: false,
  );
}

// Settings → Notice Period, as web settings/notice-period/page.tsx,
// lib/noticePeriod.ts and NoticePeriodImportModal.tsx (production branch),
// against backend EmployeeDetailView.put (notice_period_days) and
// apps/accounts/views_notice_period_import.py.

/// Web MAX_NOTICE_PERIOD_DAYS (backend apps/accounts/notice_period.py).
const kMaxNoticePeriodDays = 365;

/// Web `formatNoticePeriod`.
String formatNoticePeriod(int? days) => days == null ? 'Not assigned' : '$days day${days == 1 ? '' : 's'}';

/// Web `noticePeriodInputError`: error text, or null when valid. Blank is
/// valid and means "clear (not assigned)".
String? noticePeriodInputError(String raw) {
  final text = raw.trim();
  if (text.isEmpty) return null;
  if (!RegExp(r'^\d+$').hasMatch(text)) return 'Enter a whole number of days.';
  final n = int.tryParse(text);
  if (n == null || n > kMaxNoticePeriodDays) return 'Maximum $kMaxNoticePeriodDays days.';
  return null;
}

/// The `notice_period_days` web sends for a valid input: null for blank,
/// else `Number(text)`.
int? noticePeriodPayloadValue(String raw) {
  final text = raw.trim();
  return text.isEmpty ? null : int.parse(text);
}

int? _intOrNull(Object? v) {
  if (v is int) return v;
  if (v is num && v == v.roundToDouble()) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

int _int(Object? v) => _intOrNull(v) ?? 0;

class NoticeEmployeeRow {
  const NoticeEmployeeRow({
    required this.employeeId,
    required this.fullName,
    required this.branch,
    required this.department,
    required this.designation,
    this.noticePeriodDays,
  });

  final String employeeId;
  final String fullName;
  final String branch;
  final String department;
  final String designation;
  final int? noticePeriodDays;

  factory NoticeEmployeeRow.fromJson(Map<String, dynamic> j) {
    final n = j['notice_period_days'];
    final days = _intOrNull(n);
    return NoticeEmployeeRow(
      employeeId: j['employee_id']?.toString() ?? '',
      fullName: j['full_name']?.toString() ?? '',
      branch: j['branch']?.toString() ?? '',
      department: j['department']?.toString() ?? '',
      designation: j['designation']?.toString() ?? '',
      noticePeriodDays: days != null && days >= 0 ? days : null,
    );
  }
}

/// Web page size for this screen.
const kNoticePageSize = 20;

class NoticeEmployeePage {
  const NoticeEmployeePage({required this.count, required this.results});
  final int count;
  final List<NoticeEmployeeRow> results;

  /// Web: `Math.max(1, Math.ceil(count / PAGE_SIZE))`.
  int get pages => count <= 0 ? 1 : (count + kNoticePageSize - 1) ~/ kNoticePageSize;

  factory NoticeEmployeePage.fromJson(Map<String, dynamic> j) {
    final list = j['results'];
    return NoticeEmployeePage(
      count: _int(j['count']),
      results: list is List
          ? list.whereType<Map>().map((m) => NoticeEmployeeRow.fromJson(Map<String, dynamic>.from(m))).toList()
          : const [],
    );
  }
}

// ── Import ────────────────────────────────────────────────────────────────────

/// Web NOTICE_IMPORT_STATUS_LABEL.
const kNoticeImportStatusLabel = {
  'update': 'Will update',
  'updated': 'Updated',
  'no_change': 'No change',
  'skipped': 'Skipped',
  'error': 'Error',
};

class NoticeImportRow {
  const NoticeImportRow({
    required this.row,
    required this.employeeId,
    required this.name,
    required this.status,
    required this.message,
    this.current,
    this.newDays,
  });

  final int row;
  final String employeeId;
  final String name;
  final int? current;
  final int? newDays;
  final String status;
  final String message;

  String get statusLabel => kNoticeImportStatusLabel[status] ?? status;

  /// Web: "Name (ID)", else the ID, else "—".
  String get employeeText => name.isNotEmpty ? '$name ($employeeId)' : (employeeId.isNotEmpty ? employeeId : '—');

  /// Web `noticeChangeText`.
  String get changeText {
    if (status == 'update' || status == 'updated') {
      return '${formatNoticePeriod(current)} → ${formatNoticePeriod(newDays)}';
    }
    if (status == 'no_change') return formatNoticePeriod(current);
    return '—';
  }

  /// Web shows the message only for error and skipped rows.
  String get details => status == 'error' || status == 'skipped' ? message : '';

  factory NoticeImportRow.fromJson(Map<String, dynamic> j) => NoticeImportRow(
        row: _int(j['row']),
        employeeId: j['employee_id']?.toString() ?? '',
        name: j['name']?.toString() ?? '',
        current: _intOrNull(j['current']),
        newDays: _intOrNull(j['new']),
        status: j['status']?.toString() ?? '',
        message: j['message']?.toString() ?? '',
      );
}

class NoticeImportSummary {
  const NoticeImportSummary({
    required this.total,
    required this.update,
    required this.noChange,
    required this.skipped,
    required this.error,
    this.updated,
  });

  final int total;
  final int update;
  final int noChange;
  final int skipped;
  final int error;

  /// Only on the confirm (non-dry-run) response.
  final int? updated;

  factory NoticeImportSummary.fromJson(Map<String, dynamic> j) => NoticeImportSummary(
        total: _int(j['total']),
        update: _int(j['update']),
        noChange: _int(j['no_change']),
        skipped: _int(j['skipped']),
        error: _int(j['error']),
        updated: _intOrNull(j['updated']),
      );
}

class NoticeImportResult {
  const NoticeImportResult({required this.summary, required this.rows});
  final NoticeImportSummary summary;
  final List<NoticeImportRow> rows;

  factory NoticeImportResult.fromJson(Map<String, dynamic> j) {
    final s = j['summary'];
    final rows = j['rows'];
    return NoticeImportResult(
      summary: NoticeImportSummary.fromJson(s is Map ? Map<String, dynamic>.from(s) : const {}),
      rows: rows is List
          ? rows.whereType<Map>().map((m) => NoticeImportRow.fromJson(Map<String, dynamic>.from(m))).toList()
          : const [],
    );
  }
}

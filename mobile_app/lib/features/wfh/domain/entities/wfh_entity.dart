class WfhRequestEntity {
  final String id; // UUID string
  final String startDate; // 'YYYY-MM-DD'
  final String endDate; // 'YYYY-MM-DD'
  final String reason;
  final String locationLabel;
  final double latitude;
  final double longitude;
  final String status; // pending|l2_pending|approved|rejected|cancelled
  final String employeeName;
  final String employeeCode;
  final String employeeDept;
  final String employeeBranch;
  final String l1ApproverName;
  final String? l1Status; // pending|approved|rejected
  final String l1Remarks;
  final String? l1ActionedAt;
  final String l2ApproverName;
  final String? l2Status;
  final String l2Remarks;
  final String? l2ActionedAt;
  final String createdAt;
  final bool canApprove; // can_approve — backend-computed
  final bool canCancel; // can_cancel — backend-computed

  const WfhRequestEntity({
    required this.id,
    required this.startDate,
    required this.endDate,
    this.reason = '',
    this.locationLabel = '',
    required this.latitude,
    required this.longitude,
    required this.status,
    this.employeeName = '',
    this.employeeCode = '',
    this.employeeDept = '',
    this.employeeBranch = '',
    this.l1ApproverName = '',
    this.l1Status,
    this.l1Remarks = '',
    this.l1ActionedAt,
    this.l2ApproverName = '',
    this.l2Status,
    this.l2Remarks = '',
    this.l2ActionedAt,
    this.createdAt = '',
    this.canApprove = false,
    this.canCancel = false,
  });

  bool get isPending => status == 'pending' || status == 'l2_pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isTerminal => !isPending;

  // Distinguishes the two pending sub-stages, unlike leave's single
  // "pending" pill — a manager and an HR approver see different pending
  // rows and this makes clear which stage a request is actually waiting on.
  String get statusLabel => wfhStatusLabel(status);
}

String wfhStatusLabel(String status) => switch (status) {
      'pending' => 'Pending (Manager)',
      'l2_pending' => 'Pending (HR)',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      _ => status,
    };

class WfhSavedLocationEntity {
  final String id; // UUID string
  final String label;
  final double latitude;
  final double longitude;
  final String createdAt;

  const WfhSavedLocationEntity({
    required this.id,
    required this.label,
    required this.latitude,
    required this.longitude,
    this.createdAt = '',
  });
}

// Page envelope for GET /wfh/requests/ — matches backend's
// {count, page, page_size, total_pages, results} pagination shape (see
// apps/hrms/views/workfromhome.py / core/pagination.py). Kept local to the
// wfh feature, matching this codebase's per-feature pagination type
// convention (see leave_entity.dart's LeaveRequestPageEntity).
class WfhRequestPageEntity {
  final List<WfhRequestEntity> results;
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;

  const WfhRequestPageEntity({
    required this.results,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory WfhRequestPageEntity.empty() => const WfhRequestPageEntity(
        results: [],
        count: 0,
        page: 1,
        pageSize: 20,
        totalPages: 1,
      );

  bool get hasMore => page < totalPages;
}

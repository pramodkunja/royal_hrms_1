// "Separation & Exit" is the user-facing name shown throughout the app.
// The backend model, fields, and every identifier below keep the original
// "separation" naming (apps/hrms/models.py SeparationRequest and friends) —
// there is no legacy "fnf" naming anywhere in this actual backend contract,
// so nothing here needs a compatibility shim.

class SeparationLookupOption {
  final String value;
  final String label;
  const SeparationLookupOption({required this.value, required this.label});
}

class ReportingManagerEntity {
  final String id; // employee_id code
  final String name;
  const ReportingManagerEntity({required this.id, required this.name});
}

class SeparationApprovalStageEntity {
  final String id;
  final String stage; // hr | manager | branch_admin
  final String stageDisplay;
  final int sequence;
  final String status; // pending | approved | rejected
  final String statusDisplay;
  final String approverName;
  final String remarks;
  final String? actionedAt;
  final bool canAction;

  const SeparationApprovalStageEntity({
    required this.id,
    required this.stage,
    required this.stageDisplay,
    required this.sequence,
    required this.status,
    required this.statusDisplay,
    required this.approverName,
    required this.remarks,
    this.actionedAt,
    required this.canAction,
  });
}

class SeparationRequestEntity {
  final String id;
  final String requestRef; // "SEP-<n>"
  final String separationType;
  final String separationTypeDisplay;
  final String reason;
  final String reasonDisplay;
  final String requestDate; // ISO date
  final String proposedLastWorkingDay; // ISO date
  final int noticePeriodDays;
  final String comments;
  final String status; // pending | stage2_pending | approved | rejected | cancelled
  final String statusDisplay; // server-computed, may show current stage name
  final String employeeName;
  final String employeeCode;
  final String employeeDepartment;
  final String employeeDesignation;
  final ReportingManagerEntity? reportingManager;
  final String? documentUrl;
  final String createdByName;
  final List<SeparationApprovalStageEntity> approvalStages;
  final bool canApprove;
  final bool canCancel;
  final bool canEdit;
  final bool canDelete;
  final bool isOwn;
  final String createdAt;

  const SeparationRequestEntity({
    required this.id,
    required this.requestRef,
    required this.separationType,
    required this.separationTypeDisplay,
    required this.reason,
    required this.reasonDisplay,
    required this.requestDate,
    required this.proposedLastWorkingDay,
    required this.noticePeriodDays,
    required this.comments,
    required this.status,
    required this.statusDisplay,
    required this.employeeName,
    required this.employeeCode,
    required this.employeeDepartment,
    required this.employeeDesignation,
    this.reportingManager,
    this.documentUrl,
    required this.createdByName,
    this.approvalStages = const [],
    this.canApprove = false,
    this.canCancel = false,
    this.canEdit = false,
    this.canDelete = false,
    this.isOwn = false,
    required this.createdAt,
  });

  bool get isPending => status == 'pending' || status == 'stage2_pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
}

// Matches the backend's {count, page, page_size, total_pages, results}
// envelope (core/pagination.py) — the separation list endpoint is always
// paginated, unlike leave's list which tolerates a plain array.
class SeparationRequestPageEntity {
  final List<SeparationRequestEntity> results;
  final int count;
  final int page;
  final int pageSize;
  final int totalPages;

  const SeparationRequestPageEntity({
    required this.results,
    required this.count,
    required this.page,
    required this.pageSize,
    required this.totalPages,
  });

  factory SeparationRequestPageEntity.empty() =>
      const SeparationRequestPageEntity(
          results: [], count: 0, page: 1, pageSize: 20, totalPages: 1);
}

// Accumulating "load more" state, mirrors LeaveLoadMoreState.
class SeparationLoadMoreState {
  final List<SeparationRequestEntity> items;
  final int page;
  final int totalPages;
  final int count;
  final bool loadingMore;

  const SeparationLoadMoreState({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.count,
    this.loadingMore = false,
  });

  bool get hasMore => page < totalPages;

  SeparationLoadMoreState copyWith({
    List<SeparationRequestEntity>? items,
    int? page,
    int? totalPages,
    int? count,
    bool? loadingMore,
  }) =>
      SeparationLoadMoreState(
        items: items ?? this.items,
        page: page ?? this.page,
        totalPages: totalPages ?? this.totalPages,
        count: count ?? this.count,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class SeparationHandoverTaskEntity {
  final String id;
  final String task;
  final String description;
  final String? assignedTo; // User UUID
  final String assignedToName;
  final String? dueDate; // ISO date
  final bool isCompleted;
  final String? completedAt;
  final String createdByName;
  final String createdAt;

  const SeparationHandoverTaskEntity({
    required this.id,
    required this.task,
    required this.description,
    this.assignedTo,
    required this.assignedToName,
    this.dueDate,
    required this.isCompleted,
    this.completedAt,
    required this.createdByName,
    required this.createdAt,
  });
}

class SeparationClearanceEntity {
  final String id;
  final String clearanceType; // manager | it | finance | hr
  final String clearanceTypeDisplay;
  final String status; // pending | approved | rejected
  final String statusDisplay;
  final String clearedByName;
  final String remarks;
  final String? actionedAt;
  final bool canAction;

  const SeparationClearanceEntity({
    required this.id,
    required this.clearanceType,
    required this.clearanceTypeDisplay,
    required this.status,
    required this.statusDisplay,
    required this.clearedByName,
    required this.remarks,
    this.actionedAt,
    required this.canAction,
  });
}

class SeparationDocumentEntity {
  final String id;
  final String documentType;
  final String documentTypeDisplay;
  final String? fileUrl;
  final String uploadedByName;
  final String createdAt;

  const SeparationDocumentEntity({
    required this.id,
    required this.documentType,
    required this.documentTypeDisplay,
    this.fileUrl,
    required this.uploadedByName,
    required this.createdAt,
  });
}

class SeparationActivityEntity {
  final String id;
  final String message;
  final String actorName;
  final String actorRole;
  final String createdAt;

  const SeparationActivityEntity({
    required this.id,
    required this.message,
    required this.actorName,
    required this.actorRole,
    required this.createdAt,
  });
}

// Lightweight employee search result, backed by GET /employees/ (search=).
// Kept local to this feature rather than reusing EmployeeModel because the
// picker only needs a handful of fields and specifically needs `uuid` (the
// real User pk, required as SeparationHandoverTask.assigned_to) alongside
// `code` (the employee_id, required as the separation request's employee_id
// field when filing on someone else's behalf) — see
// apps/accounts/views.py _employee_dict, which returns both.
class EmployeePickerOption {
  final String code; // employee_id
  final String uuid; // real User pk
  final String name;
  final String department;
  final String designation;

  const EmployeePickerOption({
    required this.code,
    required this.uuid,
    required this.name,
    required this.department,
    required this.designation,
  });
}

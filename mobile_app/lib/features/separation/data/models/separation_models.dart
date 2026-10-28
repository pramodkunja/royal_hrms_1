import '../../domain/entities/separation_entity.dart';

class SeparationLookupOptionModel extends SeparationLookupOption {
  const SeparationLookupOptionModel(
      {required super.value, required super.label});

  factory SeparationLookupOptionModel.fromJson(Map<String, dynamic> json) {
    return SeparationLookupOptionModel(
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
    );
  }
}

ReportingManagerEntity? _reportingManagerFromJson(dynamic json) {
  if (json is! Map<String, dynamic>) return null;
  final id = json['id'] as String?;
  final name = json['name'] as String?;
  if (id == null && name == null) return null;
  return ReportingManagerEntity(id: id ?? '', name: name ?? '');
}

class SeparationApprovalStageModel extends SeparationApprovalStageEntity {
  const SeparationApprovalStageModel({
    required super.id,
    required super.stage,
    required super.stageDisplay,
    required super.sequence,
    required super.status,
    required super.statusDisplay,
    required super.approverName,
    required super.remarks,
    super.actionedAt,
    required super.canAction,
  });

  factory SeparationApprovalStageModel.fromJson(Map<String, dynamic> json) {
    return SeparationApprovalStageModel(
      id: json['id']?.toString() ?? '',
      stage: json['stage'] as String? ?? '',
      stageDisplay: json['stage_display'] as String? ?? '',
      sequence: (json['sequence'] as num? ?? 0).toInt(),
      status: json['status'] as String? ?? 'pending',
      statusDisplay: json['status_display'] as String? ?? '',
      approverName: json['approver_name'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      actionedAt: json['actioned_at'] as String?,
      canAction: json['can_action'] as bool? ?? false,
    );
  }
}

class SeparationRequestModel extends SeparationRequestEntity {
  const SeparationRequestModel({
    required super.id,
    required super.requestRef,
    required super.separationType,
    required super.separationTypeDisplay,
    required super.reason,
    required super.reasonDisplay,
    required super.requestDate,
    required super.proposedLastWorkingDay,
    required super.noticePeriodDays,
    required super.comments,
    required super.status,
    required super.statusDisplay,
    required super.employeeName,
    required super.employeeCode,
    required super.employeeDepartment,
    required super.employeeDesignation,
    super.reportingManager,
    super.documentUrl,
    required super.createdByName,
    super.approvalStages,
    super.canApprove,
    super.canCancel,
    super.canEdit,
    super.canDelete,
    super.isOwn,
    required super.createdAt,
  });

  // Matches SeparationRequestSerializer (apps/hrms/serializers.py) exactly.
  factory SeparationRequestModel.fromJson(Map<String, dynamic> json) {
    final rawStages = json['approval_stages'] as List<dynamic>? ?? [];
    return SeparationRequestModel(
      id: json['id']?.toString() ?? '',
      requestRef: json['request_ref'] as String? ?? '',
      separationType: json['separation_type'] as String? ?? '',
      separationTypeDisplay: json['separation_type_display'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      reasonDisplay: json['reason_display'] as String? ?? '',
      requestDate: json['request_date'] as String? ?? '',
      proposedLastWorkingDay: json['proposed_last_working_day'] as String? ?? '',
      noticePeriodDays: (json['notice_period_days'] as num? ?? 0).toInt(),
      comments: json['comments'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      statusDisplay: json['status_display'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? '',
      employeeDepartment: json['employee_department'] as String? ?? '',
      employeeDesignation: json['employee_designation'] as String? ?? '',
      reportingManager: _reportingManagerFromJson(json['reporting_manager']),
      documentUrl: json['document_url'] as String?,
      createdByName: json['created_by_name'] as String? ?? '',
      approvalStages: rawStages
          .whereType<Map<String, dynamic>>()
          .map(SeparationApprovalStageModel.fromJson)
          .toList(),
      canApprove: json['can_approve'] as bool? ?? false,
      canCancel: json['can_cancel'] as bool? ?? false,
      canEdit: json['can_edit'] as bool? ?? false,
      canDelete: json['can_delete'] as bool? ?? false,
      isOwn: json['is_own'] as bool? ?? false,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class SeparationRequestPageModel extends SeparationRequestPageEntity {
  const SeparationRequestPageModel({
    required super.results,
    required super.count,
    required super.page,
    required super.pageSize,
    required super.totalPages,
  });

  // Backend always returns the paginated {count, page, page_size,
  // total_pages, results} envelope for GET /separation/requests/ (see
  // core/pagination.py paginated_data) — no plain-list fallback needed.
  factory SeparationRequestPageModel.fromJson(dynamic data) {
    if (data is Map<String, dynamic>) {
      final rawResults = data['results'] as List<dynamic>? ?? [];
      final results = rawResults
          .whereType<Map<String, dynamic>>()
          .map(SeparationRequestModel.fromJson)
          .toList();
      final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
      return SeparationRequestPageModel(
        results: results,
        count: (data['count'] as num?)?.toInt() ?? results.length,
        page: (data['page'] as num?)?.toInt() ?? 1,
        pageSize: (data['page_size'] as num?)?.toInt() ?? 20,
        totalPages: totalPages == 0 ? 1 : totalPages,
      );
    }
    return const SeparationRequestPageModel(
        results: [], count: 0, page: 1, pageSize: 20, totalPages: 1);
  }
}

class SeparationHandoverTaskModel extends SeparationHandoverTaskEntity {
  const SeparationHandoverTaskModel({
    required super.id,
    required super.task,
    required super.description,
    super.assignedTo,
    required super.assignedToName,
    super.dueDate,
    required super.isCompleted,
    super.completedAt,
    required super.createdByName,
    required super.createdAt,
  });

  factory SeparationHandoverTaskModel.fromJson(Map<String, dynamic> json) {
    return SeparationHandoverTaskModel(
      id: json['id']?.toString() ?? '',
      task: json['task'] as String? ?? '',
      description: json['description'] as String? ?? '',
      assignedTo: json['assigned_to']?.toString(),
      assignedToName: json['assigned_to_name'] as String? ?? '',
      dueDate: json['due_date'] as String?,
      isCompleted: json['is_completed'] as bool? ?? false,
      completedAt: json['completed_at'] as String?,
      createdByName: json['created_by_name'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class SeparationClearanceModel extends SeparationClearanceEntity {
  const SeparationClearanceModel({
    required super.id,
    required super.clearanceType,
    required super.clearanceTypeDisplay,
    required super.status,
    required super.statusDisplay,
    required super.clearedByName,
    required super.remarks,
    super.actionedAt,
    required super.canAction,
  });

  factory SeparationClearanceModel.fromJson(Map<String, dynamic> json) {
    return SeparationClearanceModel(
      id: json['id']?.toString() ?? '',
      clearanceType: json['clearance_type'] as String? ?? '',
      clearanceTypeDisplay: json['clearance_type_display'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      statusDisplay: json['status_display'] as String? ?? '',
      clearedByName: json['cleared_by_name'] as String? ?? '',
      remarks: json['remarks'] as String? ?? '',
      actionedAt: json['actioned_at'] as String?,
      canAction: json['can_action'] as bool? ?? false,
    );
  }
}

class SeparationDocumentModel extends SeparationDocumentEntity {
  const SeparationDocumentModel({
    required super.id,
    required super.documentType,
    required super.documentTypeDisplay,
    super.fileUrl,
    required super.uploadedByName,
    required super.createdAt,
  });

  factory SeparationDocumentModel.fromJson(Map<String, dynamic> json) {
    return SeparationDocumentModel(
      id: json['id']?.toString() ?? '',
      documentType: json['document_type'] as String? ?? 'other',
      documentTypeDisplay: json['document_type_display'] as String? ?? '',
      fileUrl: json['file_url'] as String?,
      uploadedByName: json['uploaded_by_name'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class SeparationActivityModel extends SeparationActivityEntity {
  const SeparationActivityModel({
    required super.id,
    required super.message,
    required super.actorName,
    required super.actorRole,
    required super.createdAt,
  });

  factory SeparationActivityModel.fromJson(Map<String, dynamic> json) {
    return SeparationActivityModel(
      id: json['id']?.toString() ?? '',
      message: json['message'] as String? ?? '',
      actorName: json['actor_name'] as String? ?? '',
      actorRole: json['actor_role'] as String? ?? 'system',
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class EmployeePickerOptionModel extends EmployeePickerOption {
  const EmployeePickerOptionModel({
    required super.code,
    required super.uuid,
    required super.name,
    required super.department,
    required super.designation,
  });

  // Matches _employee_dict (apps/accounts/views.py) — 'id'/'employee_id' are
  // both the human-readable employee code; 'uuid' is the real User pk.
  factory EmployeePickerOptionModel.fromJson(Map<String, dynamic> json) {
    return EmployeePickerOptionModel(
      code: json['employee_id'] as String? ?? json['id'] as String? ?? '',
      uuid: json['uuid'] as String? ?? '',
      name: json['full_name'] as String? ?? '',
      department: json['department'] as String? ?? '',
      designation: json['designation'] as String? ?? '',
    );
  }
}

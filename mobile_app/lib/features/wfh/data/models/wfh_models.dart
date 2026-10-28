import '../../domain/entities/wfh_entity.dart';

// Django DecimalFields (latitude/longitude) serialize as JSON strings (e.g.
// "12.345678"), not numbers — `as num?` throws on a String. Mirrors
// leave_models.dart's identical helper.
double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

class WfhRequestModel extends WfhRequestEntity {
  const WfhRequestModel({
    required super.id,
    required super.startDate,
    required super.endDate,
    super.reason,
    super.locationLabel,
    required super.latitude,
    required super.longitude,
    required super.status,
    super.employeeName,
    super.employeeCode,
    super.employeeDept,
    super.employeeBranch,
    super.l1ApproverName,
    super.l1Status,
    super.l1Remarks,
    super.l1ActionedAt,
    super.l2ApproverName,
    super.l2Status,
    super.l2Remarks,
    super.l2ActionedAt,
    super.createdAt,
    super.canApprove,
    super.canCancel,
  });

  // Backend fields (WorkFromHomeRequestSerializer, apps/hrms/serializers.py):
  // id, start_date, end_date, reason, location_label, latitude, longitude,
  // status, employee_name, employee_code, employee_dept, employee_branch,
  // l1_approver_name, l1_status, l1_remarks, l1_actioned_at,
  // l2_approver_name, l2_status, l2_remarks, l2_actioned_at, created_at,
  // can_approve, can_cancel.
  factory WfhRequestModel.fromJson(Map<String, dynamic> json) {
    return WfhRequestModel(
      id: json['id']?.toString() ?? '',
      startDate: json['start_date'] as String? ?? '',
      endDate: json['end_date'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      locationLabel: json['location_label'] as String? ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      status: json['status'] as String? ?? 'pending',
      employeeName: json['employee_name'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? '',
      employeeDept: json['employee_dept'] as String? ?? '',
      employeeBranch: json['employee_branch'] as String? ?? '',
      l1ApproverName: json['l1_approver_name'] as String? ?? '',
      l1Status: json['l1_status'] as String?,
      l1Remarks: json['l1_remarks'] as String? ?? '',
      l1ActionedAt: json['l1_actioned_at'] as String?,
      l2ApproverName: json['l2_approver_name'] as String? ?? '',
      l2Status: json['l2_status'] as String?,
      l2Remarks: json['l2_remarks'] as String? ?? '',
      l2ActionedAt: json['l2_actioned_at'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      canApprove: json['can_approve'] as bool? ?? false,
      canCancel: json['can_cancel'] as bool? ?? false,
    );
  }
}

class WfhSavedLocationModel extends WfhSavedLocationEntity {
  const WfhSavedLocationModel({
    required super.id,
    required super.label,
    required super.latitude,
    required super.longitude,
    super.createdAt,
  });

  // Backend fields (WFHSavedLocationSerializer): id, label, latitude,
  // longitude, created_at.
  factory WfhSavedLocationModel.fromJson(Map<String, dynamic> json) {
    return WfhSavedLocationModel(
      id: json['id']?.toString() ?? '',
      label: json['label'] as String? ?? '',
      latitude: _toDouble(json['latitude']),
      longitude: _toDouble(json['longitude']),
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class WfhRequestPageModel extends WfhRequestPageEntity {
  const WfhRequestPageModel({
    required super.results,
    required super.count,
    required super.page,
    required super.pageSize,
    required super.totalPages,
  });

  // Backend returns paginated {count, page, page_size, total_pages, results}
  // for GET /wfh/requests/ (core/pagination.py paginated_data) — but also
  // tolerate a plain list, mirroring LeaveRequestPageModel.fromJson.
  factory WfhRequestPageModel.fromJson(dynamic data) {
    if (data is List) {
      final results = data
          .whereType<Map<String, dynamic>>()
          .map(WfhRequestModel.fromJson)
          .toList();
      return WfhRequestPageModel(
        results: results,
        count: results.length,
        page: 1,
        pageSize: results.isEmpty ? 20 : results.length,
        totalPages: 1,
      );
    }
    if (data is Map<String, dynamic>) {
      final rawResults = data['results'] as List<dynamic>? ?? [];
      final results = rawResults
          .whereType<Map<String, dynamic>>()
          .map(WfhRequestModel.fromJson)
          .toList();
      final totalPages = (data['total_pages'] as num?)?.toInt() ?? 1;
      return WfhRequestPageModel(
        results: results,
        count: (data['count'] as num?)?.toInt() ?? results.length,
        page: (data['page'] as num?)?.toInt() ?? 1,
        pageSize: (data['page_size'] as num?)?.toInt() ?? 20,
        totalPages: totalPages == 0 ? 1 : totalPages,
      );
    }
    return const WfhRequestPageModel(
        results: [], count: 0, page: 1, pageSize: 20, totalPages: 1);
  }
}

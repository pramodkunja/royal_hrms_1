/// `GET/PATCH /api/notifications/settings/` — matches backend
/// `NotificationSettings` model / `NotificationSettingsSerializer` exactly.
/// A missing row (user has never saved settings) means every category
/// defaults to enabled, which the backend already handles via
/// `get_or_create` — the mobile default constructor mirrors that.
class NotificationSettingsModel {
  final bool isLeaveEnabled;
  final bool isExpenseEnabled;
  final bool isSeparationEnabled;
  final bool isPayrollEnabled;
  final bool isApprovalEnabled;
  final bool isDocumentEnabled;
  final bool isAttendanceEnabled;
  final bool isSystemEnabled;

  const NotificationSettingsModel({
    this.isLeaveEnabled = true,
    this.isExpenseEnabled = true,
    this.isSeparationEnabled = true,
    this.isPayrollEnabled = true,
    this.isApprovalEnabled = true,
    this.isDocumentEnabled = true,
    this.isAttendanceEnabled = true,
    this.isSystemEnabled = true,
  });

  factory NotificationSettingsModel.fromJson(Map<String, dynamic> json) {
    return NotificationSettingsModel(
      isLeaveEnabled: json['is_leave_enabled'] as bool? ?? true,
      isExpenseEnabled: json['is_expense_enabled'] as bool? ?? true,
      isSeparationEnabled: json['is_separation_enabled'] as bool? ?? true,
      isPayrollEnabled: json['is_payroll_enabled'] as bool? ?? true,
      isApprovalEnabled: json['is_approval_enabled'] as bool? ?? true,
      isDocumentEnabled: json['is_document_enabled'] as bool? ?? true,
      isAttendanceEnabled: json['is_attendance_enabled'] as bool? ?? true,
      isSystemEnabled: json['is_system_enabled'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_leave_enabled': isLeaveEnabled,
        'is_expense_enabled': isExpenseEnabled,
        'is_separation_enabled': isSeparationEnabled,
        'is_payroll_enabled': isPayrollEnabled,
        'is_approval_enabled': isApprovalEnabled,
        'is_document_enabled': isDocumentEnabled,
        'is_attendance_enabled': isAttendanceEnabled,
        'is_system_enabled': isSystemEnabled,
      };

  NotificationSettingsModel copyWith({
    bool? isLeaveEnabled,
    bool? isExpenseEnabled,
    bool? isSeparationEnabled,
    bool? isPayrollEnabled,
    bool? isApprovalEnabled,
    bool? isDocumentEnabled,
    bool? isAttendanceEnabled,
    bool? isSystemEnabled,
  }) {
    return NotificationSettingsModel(
      isLeaveEnabled: isLeaveEnabled ?? this.isLeaveEnabled,
      isExpenseEnabled: isExpenseEnabled ?? this.isExpenseEnabled,
      isSeparationEnabled: isSeparationEnabled ?? this.isSeparationEnabled,
      isPayrollEnabled: isPayrollEnabled ?? this.isPayrollEnabled,
      isApprovalEnabled: isApprovalEnabled ?? this.isApprovalEnabled,
      isDocumentEnabled: isDocumentEnabled ?? this.isDocumentEnabled,
      isAttendanceEnabled: isAttendanceEnabled ?? this.isAttendanceEnabled,
      isSystemEnabled: isSystemEnabled ?? this.isSystemEnabled,
    );
  }
}

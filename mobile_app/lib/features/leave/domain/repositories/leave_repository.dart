import 'package:dio/dio.dart';
import '../entities/leave_entity.dart';

abstract class LeaveRepository {
  Future<List<LeaveTypeEntity>> getLeaveTypes();
  Future<List<LeaveBalanceEntity>> getLeaveBalances();
  Future<LeaveStatsEntity> getLeaveStats();
  Future<List<LeaveRequestEntity>> getLeaveRequests(
      {String? status, String? scope, int? pageSize});
  Future<LeaveRequestPageEntity> getLeaveRequestsPaginated({
    String? status,
    String? scope,
    String? branch,
    String? department,
    int page = 1,
  });
  Future<LeaveRequestEntity> getLeaveRequestById(String id);
  Future<LeaveRequestPageEntity> getEmployeeLeaveRequestsPaginated({
    required String employeeId,
    required int year,
    int page = 1,
  });
  Future<LeaveStatsEntity> getEmployeeLeaveStats({
    required String employeeId,
    required int year,
  });
  Future<LeaveRequestEntity> applyLeave({
    required String leaveTypeCode,
    required String fromDate,
    required String toDate,
    required String reason,
    required String duration,
    String? handoverTo,
    String? contactDuringLeave,
    String? handoverNotes,
    MultipartFile? document,
  });
  Future<void> cancelLeave(String id);
  Future<void> approveLeave(String id);
  Future<void> rejectLeave(String id, String rejectReason);
  Future<List<LeaveCalendarEventEntity>> getLeaveCalendar({
    int? year,
    int? month,
  });
  Future<LeavePreviewEntity> getLeavePreview({
    required String leaveType,
    required String startDate,
    required String endDate,
    String? duration,
  });
}

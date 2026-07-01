import '../entities/leave_entity.dart';

abstract class LeaveRepository {
  Future<List<LeaveTypeEntity>> getLeaveTypes();
  Future<List<LeaveBalanceEntity>> getLeaveBalances();
  Future<LeaveStatsEntity> getLeaveStats();
  Future<List<LeaveRequestEntity>> getLeaveRequests({String? status});
  Future<LeaveRequestEntity> applyLeave({
    required String leaveTypeCode,
    required String fromDate,
    required String toDate,
    required String reason,
    required String duration,
  });
  Future<void> cancelLeave(String id);
  Future<void> approveLeave(String id);
  Future<void> rejectLeave(String id, String rejectReason);
}

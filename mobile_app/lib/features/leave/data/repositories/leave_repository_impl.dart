import '../../domain/entities/leave_entity.dart';
import '../../domain/repositories/leave_repository.dart';
import '../datasources/leave_remote_datasource.dart';

class LeaveRepositoryImpl implements LeaveRepository {
  final LeaveRemoteDataSource _ds;
  LeaveRepositoryImpl(this._ds);

  @override
  Future<List<LeaveTypeEntity>> getLeaveTypes() => _ds.fetchLeaveTypes();

  @override
  Future<List<LeaveBalanceEntity>> getLeaveBalances() =>
      _ds.fetchLeaveBalances();

  @override
  Future<LeaveStatsEntity> getLeaveStats() => _ds.fetchLeaveStats();

  @override
  Future<List<LeaveRequestEntity>> getLeaveRequests({String? status}) =>
      _ds.fetchLeaveRequests(status: status);

  @override
  Future<LeaveRequestEntity> applyLeave({
    required String leaveTypeCode,
    required String fromDate,
    required String toDate,
    required String reason,
    required String duration,
  }) =>
      _ds.applyLeave(
        leaveTypeCode: leaveTypeCode,
        fromDate:      fromDate,
        toDate:        toDate,
        reason:        reason,
        duration:      duration,
      );

  @override
  Future<void> cancelLeave(String id) => _ds.cancelLeave(id);

  @override
  Future<void> approveLeave(String id) => _ds.approveLeave(id);

  @override
  Future<void> rejectLeave(String id, String rejectReason) =>
      _ds.rejectLeave(id, rejectReason);
}

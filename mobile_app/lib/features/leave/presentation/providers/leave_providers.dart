import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/leave_remote_datasource.dart';
import '../../data/repositories/leave_repository_impl.dart';
import '../../domain/entities/leave_entity.dart';
import '../../domain/repositories/leave_repository.dart';

// ── Infrastructure ────────────────────────────────────────────────────────────

final leaveDataSourceProvider = Provider<LeaveRemoteDataSource>((ref) {
  return LeaveRemoteDataSource(ref.watch(dioProvider));
});

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepositoryImpl(ref.watch(leaveDataSourceProvider));
});

// ── Leave Types ───────────────────────────────────────────────────────────────

final leaveTypesProvider = AsyncNotifierProvider.autoDispose<
    LeaveTypesNotifier, List<LeaveTypeEntity>>(LeaveTypesNotifier.new);

class LeaveTypesNotifier
    extends AutoDisposeAsyncNotifier<List<LeaveTypeEntity>> {
  @override
  Future<List<LeaveTypeEntity>> build() =>
      ref.read(leaveRepositoryProvider).getLeaveTypes();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(leaveRepositoryProvider).getLeaveTypes());
  }
}

// ── Leave Balances ────────────────────────────────────────────────────────────

final leaveBalancesProvider = AsyncNotifierProvider.autoDispose<
    LeaveBalancesNotifier,
    List<LeaveBalanceEntity>>(LeaveBalancesNotifier.new);

class LeaveBalancesNotifier
    extends AutoDisposeAsyncNotifier<List<LeaveBalanceEntity>> {
  @override
  Future<List<LeaveBalanceEntity>> build() =>
      ref.read(leaveRepositoryProvider).getLeaveBalances();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(leaveRepositoryProvider).getLeaveBalances());
  }
}

// ── Leave Stats ───────────────────────────────────────────────────────────────

final leaveStatsProvider = AsyncNotifierProvider.autoDispose<
    LeaveStatsNotifier, LeaveStatsEntity>(LeaveStatsNotifier.new);

class LeaveStatsNotifier extends AutoDisposeAsyncNotifier<LeaveStatsEntity> {
  @override
  Future<LeaveStatsEntity> build() =>
      ref.read(leaveRepositoryProvider).getLeaveStats();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(leaveRepositoryProvider).getLeaveStats());
  }
}

// ── Leave Requests ────────────────────────────────────────────────────────────

final leaveRequestsProvider = AsyncNotifierProvider.autoDispose<
    LeaveRequestsNotifier,
    List<LeaveRequestEntity>>(LeaveRequestsNotifier.new);

class LeaveRequestsNotifier
    extends AutoDisposeAsyncNotifier<List<LeaveRequestEntity>> {
  @override
  Future<List<LeaveRequestEntity>> build() =>
      ref.read(leaveRepositoryProvider).getLeaveRequests();

  Future<String?> applyLeave({
    required String leaveTypeCode,
    required String fromDate,
    required String toDate,
    required String reason,
    required String duration,
    String? handoverTo,
    String? contactDuringLeave,
    String? handoverNotes,
    PlatformFile? document,
  }) async {
    try {
      final documentFile = document?.path == null
          ? null
          : await MultipartFile.fromFile(document!.path!, filename: document.name);
      final created = await ref.read(leaveRepositoryProvider).applyLeave(
            leaveTypeCode:      leaveTypeCode,
            fromDate:           fromDate,
            toDate:             toDate,
            reason:             reason,
            duration:           duration,
            handoverTo:         handoverTo,
            contactDuringLeave: contactDuringLeave,
            handoverNotes:      handoverNotes,
            document:           documentFile,
          );
      state = AsyncData([created, ...state.valueOrNull ?? []]);
      ref.invalidate(leaveStatsProvider);
      ref.invalidate(leaveBalancesProvider);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> approveRequest(String id) async {
    try {
      await ref.read(leaveRepositoryProvider).approveLeave(id);
      await refresh();
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> rejectRequest(String id, String reason) async {
    try {
      await ref.read(leaveRepositoryProvider).rejectLeave(id, reason);
      await refresh();
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<String?> cancelRequest(String id) async {
    try {
      await ref.read(leaveRepositoryProvider).cancelLeave(id);
      await refresh();
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(leaveRepositoryProvider).getLeaveRequests());
  }
}

// ── Leave Calendar ────────────────────────────────────────────────────────────

final leaveCalendarProvider = FutureProvider.autoDispose
    .family<List<LeaveCalendarEventEntity>, (int year, int month)>((ref, key) {
  final (year, month) = key;
  return ref
      .read(leaveRepositoryProvider)
      .getLeaveCalendar(year: year, month: month);
});

// ── Error helper ──────────────────────────────────────────────────────────────

String _friendly(Object e) {
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('400')) {
    final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(msg);
    if (match != null) return match.group(1)!;
    return 'Invalid request. Please check your inputs.';
  }
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('403')) return 'You do not have permission to do this.';
  if (msg.contains('409')) return 'Dates overlap with an existing leave.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return msg.replaceAll('Exception:', '').trim();
}

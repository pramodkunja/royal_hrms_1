import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../employees/presentation/providers/employee_providers.dart' show isUnrestrictedEmployeeUser;
import '../../domain/entities/attendance_entity.dart';
import 'attendance_providers.dart' show attendanceRepositoryProvider;

// Web UnpunchesTab state, one-to-one: its OWN date (default today), branch,
// department and page — independent of the Attendance tab's filters (the web
// tab is a separate component with its own useState, so a date picked on the
// Attendance tab never leaks into it). Everything is autoDispose: leaving the
// tab resets it, as unmounting does on the web.

String unpunchIsoDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final unpunchDateProvider = StateProvider.autoDispose<DateTime>((ref) => DateTime.now());

/// The branch the HR user picked (only used by unrestricted users).
final unpunchBranchProvider = StateProvider.autoDispose<String>((ref) => '');
final unpunchDepartmentProvider = StateProvider.autoDispose<String>((ref) => '');
final unpunchPageNumberProvider = StateProvider.autoDispose<int>((ref) => 1);

/// Web lib/auth.ts isUnrestrictedUser (is_superuser or settings.edit).
final unpunchUnrestrictedProvider = Provider.autoDispose<bool>(
  (ref) => isUnrestrictedEmployeeUser(ref.watch(authStateProvider).valueOrNull?.user),
);

/// Web getEffectiveBranch: '' for unrestricted users, otherwise their own branch.
final unpunchEffectiveBranchProvider = Provider.autoDispose<String>((ref) {
  if (ref.watch(unpunchUnrestrictedProvider)) return '';
  return ref.watch(authStateProvider).valueOrNull?.user?.branch ?? '';
});

/// The branch actually sent: `unrestricted ? branchInput : effectiveBranch`.
final unpunchQueryBranchProvider = Provider.autoDispose<String>((ref) {
  return ref.watch(unpunchUnrestrictedProvider)
      ? ref.watch(unpunchBranchProvider)
      : ref.watch(unpunchEffectiveBranchProvider);
});

/// `GET /attendance/un-punches/?date&branch&department&page&page_size=20`.
/// Riverpod drops the result of a superseded build, so a slow reply for an
/// earlier date / page can never replace the current one.
final unpunchPageProvider = FutureProvider.autoDispose<UnpunchPageEntity>((ref) {
  final date = ref.watch(unpunchDateProvider);
  final branch = ref.watch(unpunchQueryBranchProvider);
  final department = ref.watch(unpunchDepartmentProvider);
  final page = ref.watch(unpunchPageNumberProvider);
  return ref.watch(attendanceRepositoryProvider).getUnpunchesPage(
        date: unpunchIsoDate(date),
        branch: branch,
        department: department,
        page: page,
      );
});

dynamic _data(dynamic body) => (body is Map && body['data'] != null) ? body['data'] : body;

List<Map<String, dynamic>> _rows(dynamic body) {
  final d = _data(body);
  final list = d is List ? d : (d is Map ? (d['results'] as List? ?? const []) : const []);
  return list.whereType<Map<String, dynamic>>().toList();
}

/// Web `${API.branches.list}?page_size=100` → `branch_name` (unrestricted users only).
final unpunchBranchOptionsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  if (!ref.watch(unpunchUnrestrictedProvider)) return const [];
  final res = await ref.watch(dioProvider).get(ApiConstants.branches, queryParameters: {'page_size': 100});
  return [
    for (final r in _rows(res.data))
      if ('${r['branch_name'] ?? ''}'.isNotEmpty) '${r['branch_name']}'
  ];
});

/// Web useDepartmentOptions: unrestricted → every `/departments/` name; scoped →
/// the distinct departments of the user's own branch roster.
final unpunchDepartmentOptionsProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  final unrestricted = ref.watch(unpunchUnrestrictedProvider);
  final branch = ref.watch(unpunchEffectiveBranchProvider);
  final dio = ref.watch(dioProvider);
  if (unrestricted) {
    final res = await dio.get(ApiConstants.departments);
    return [
      for (final r in _rows(res.data))
        if ('${r['name'] ?? ''}'.isNotEmpty) '${r['name']}'
    ];
  }
  if (branch.isEmpty) return const [];
  final res = await dio.get(ApiConstants.employees, queryParameters: {'branch': branch, 'page_size': 200});
  final names = {
    for (final r in _rows(res.data))
      if ('${r['department'] ?? ''}'.isNotEmpty) '${r['department']}'
  }.toList()
    ..sort();
  return names;
});

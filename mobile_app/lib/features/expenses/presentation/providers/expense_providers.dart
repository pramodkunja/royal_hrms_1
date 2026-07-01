import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart' show MultipartFile;
import '../../../../core/network/api_client.dart';
import '../../data/datasources/expense_remote_datasource.dart';
import '../../data/models/expense_model.dart';

// ── DataSource ────────────────────────────────────────────────────────────────

final expenseDataSourceProvider = Provider<ExpenseRemoteDataSource>((ref) {
  return ExpenseRemoteDataSource(ref.watch(dioProvider));
});

// ── Category filter ───────────────────────────────────────────────────────────

final expenseCategoryFilterProvider =
    StateProvider.autoDispose<String>((ref) => 'all');

// ── Expense list ──────────────────────────────────────────────────────────────

final expenseListProvider =
    AsyncNotifierProvider.autoDispose<ExpenseListNotifier, List<ExpenseModel>>(
  ExpenseListNotifier.new,
);

class ExpenseListNotifier
    extends AutoDisposeAsyncNotifier<List<ExpenseModel>> {
  ExpenseRemoteDataSource get _ds => ref.read(expenseDataSourceProvider);

  @override
  Future<List<ExpenseModel>> build() {
    final category = ref.watch(expenseCategoryFilterProvider);
    return _ds.fetchExpenses(
      category: category == 'all' ? null : category,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }

  Future<String?> submit({
    required String title,
    required String amount,
    required String category,
    required String expenseDate,
    required String description,
    required List<MultipartFile> receipts,
  }) async {
    try {
      final created = await _ds.submitExpense(
        title:       title,
        amount:      amount,
        category:    category,
        expenseDate: expenseDate,
        description: description,
        receipts:    receipts,
      );
      final current = state.valueOrNull ?? [];
      state = AsyncData([created, ...current]);
      return null;
    } catch (e) {
      return _friendly(e);
    }
  }
}

// ── Stats ─────────────────────────────────────────────────────────────────────

final expenseStatsProvider =
    AsyncNotifierProvider.autoDispose<ExpenseStatsNotifier, ExpenseStats>(
  ExpenseStatsNotifier.new,
);

class ExpenseStatsNotifier extends AutoDisposeAsyncNotifier<ExpenseStats> {
  @override
  Future<ExpenseStats> build() =>
      ref.read(expenseDataSourceProvider).fetchStats();

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(expenseDataSourceProvider).fetchStats());
  }
}

// ── Error helper ──────────────────────────────────────────────────────────────

String _friendly(Object e) {
  final msg = e.toString();
  if (msg.contains('SocketException') || msg.contains('connection')) {
    return 'Cannot reach server. Check your connection.';
  }
  if (msg.contains('401')) return 'Session expired. Please log in again.';
  if (msg.contains('403')) return 'You do not have permission to do this.';
  if (msg.contains('500')) return 'Server error. Please try again later.';
  return msg.replaceAll('Exception:', '').trim();
}

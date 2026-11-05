import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../employees/data/models/employee_model.dart';
import '../../../employees/presentation/providers/employee_providers.dart';
import '../navigation/nav_config.dart';

// Header "Search anything…" — web components/dashboard/GlobalSearch.tsx
// (rendered by DashboardShell for every signed-in user). Two result types:
//
//  • Employees: GET /employees/?search=<trimmed>&page_size=5 after a 300 ms
//    debounce, only for users whose permissions include employees.view
//    (no request otherwise). The server (EmployeeListCreateView) scopes it:
//    managers see their direct reports, everyone else without settings.edit
//    their own branch. A failed or refused request shows no employees.
//  • Pages: the user's own sidebar items (buildNav) whose label contains the
//    query, first five, in sidebar order.
//
// Results are kept only while the search is open (autoDispose) and dropped
// on sign-out.

const kGlobalSearchDebounce = Duration(milliseconds: 300);
const kGlobalSearchEmployeeLimit = 5;
const kGlobalSearchPageLimit = 5;

/// Web: (session.permissions ?? []).includes("employees.view").
bool canSearchEmployees(UserEntity? user) => user?.permissions.contains('employees.view') ?? false;

/// Web matchingPages: sidebar items whose label contains [query]
/// (case-insensitive), first five.
List<NavItem> matchingPages(UserEntity? user, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  return buildNav(user)
      .whereType<NavItem>()
      .where((i) => i.label.toLowerCase().contains(q))
      .take(kGlobalSearchPageLimit)
      .toList();
}

class GlobalSearchState {
  const GlobalSearchState({this.query = '', this.employees = const [], this.loading = false});

  final String query;

  /// The latest employee results (web keeps the previous list on screen
  /// while the next query is debouncing).
  final List<EmployeeModel> employees;
  final bool loading;

  String get trimmed => query.trim();
}

final globalSearchProvider =
    NotifierProvider.autoDispose<GlobalSearchController, GlobalSearchState>(GlobalSearchController.new);

class GlobalSearchController extends AutoDisposeNotifier<GlobalSearchState> {
  Timer? _debounce;
  int _seq = 0;
  bool _disposed = false;

  /// Query currently being fetched, and the one [state.employees] is for.
  String? _inFlight;
  String? _resultsFor;

  @override
  GlobalSearchState build() {
    // A different (or no) signed-in user starts from nothing.
    ref.watch(authStateProvider.select((a) => a.valueOrNull?.user?.id));
    ref.onDispose(() {
      _disposed = true;
      _debounce?.cancel();
    });
    _debounce?.cancel();
    _seq++;
    _inFlight = null;
    _resultsFor = null;
    return const GlobalSearchState();
  }

  UserEntity? get _user => ref.read(authStateProvider).valueOrNull?.user;

  void setQuery(String value) {
    _debounce?.cancel();
    final q = value.trim();
    if (!canSearchEmployees(_user) || q.isEmpty) {
      _seq++; // anything still running is now stale
      _inFlight = null;
      _resultsFor = null;
      state = GlobalSearchState(query: value);
      return;
    }
    state = GlobalSearchState(query: value, employees: state.employees, loading: state.loading);
    _debounce = Timer(kGlobalSearchDebounce, () => _search(q));
  }

  /// Clears the query and results (web goTo / an emptied box).
  void clear() => setQuery('');

  Future<void> _search(String q) async {
    if (_disposed) return;
    // Already fetching, or already showing, this exact query.
    if (_inFlight == q || (_inFlight == null && _resultsFor == q)) return;
    final seq = ++_seq;
    _inFlight = q;
    state = GlobalSearchState(query: state.query, employees: state.employees, loading: true);
    List<EmployeeModel> results;
    try {
      final page = await ref.read(employeesDataSourceProvider).fetchEmployeesPage(
            page: 1,
            filters: EmployeeFilters(search: q),
            pageSize: kGlobalSearchEmployeeLimit,
          );
      results = page.items.take(kGlobalSearchEmployeeLimit).toList();
    } catch (_) {
      results = const []; // web: catch → no employees
    }
    if (_disposed || seq != _seq) return; // a newer query (or a clear) won
    _inFlight = null;
    _resultsFor = q;
    state = GlobalSearchState(query: state.query, employees: results);
  }
}

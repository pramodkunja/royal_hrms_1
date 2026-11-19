import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/dashboard/data/datasources/dashboard_remote_datasource.dart';
import 'package:mobile_app/features/dashboard/data/models/employee_dashboard_models.dart';

// Task 95: GET /dashboard/employee/action-items/ and /recent-requests/ answer
// with core.pagination.paginated_data — {count, page, page_size, total_pages,
// results} — not {action_items, total} / {requests, total}, so the Employee
// dashboard's Action Items and Recent Activity were always empty against the
// real server (backend apps/dashboard/views/people.py:389-410 and the recent
// requests view). Synthetic rows.

void main() {
  datasourceTests();

  test('action items: the paginated envelope is read', () {
    final r = ActionItemsResponse.fromJson({
      'count': 2,
      'page': 1,
      'page_size': 5,
      'total_pages': 1,
      'results': [
        {
          'action_type': 'profile_incomplete',
          'title': 'Complete Your Profile',
          'description': 'Some required profile fields are missing.',
          'status': 'pending',
          'navigation_url': '/dashboard/profile',
        },
        {'action_type': 'missing_document', 'title': 'Upload PAN Card', 'status': 'pending'},
      ],
    });
    expect(r.total, 2);
    expect(r.actionItems.map((i) => i.title), ['Complete Your Profile', 'Upload PAN Card']);
  });

  test('action items: the older key names still work; empty is empty', () {
    final r = ActionItemsResponse.fromJson({
      'total': 1,
      'action_items': [
        {'action_type': 'x', 'title': 'Old shape', 'status': 'pending'}
      ],
    });
    expect((r.total, r.actionItems.length), (1, 1));
    final e = ActionItemsResponse.fromJson(const {});
    expect(e.total, 0);
    expect(e.actionItems, isEmpty);
  });

  test('recent requests: the paginated envelope is read', () {
    final r = RecentRequestsResponse.fromJson({
      'count': 1,
      'results': [
        {
          'request_type': 'leave',
          'title': 'Casual Leave',
          'applied_date': '2026-11-01',
          'status': 'pending',
          'details': {'days': 1},
        }
      ],
    });
    expect(r.total, 1);
    expect(r.requests.single.requestType, 'leave');
  });
}

// ── Through the real datasource and HTTP parsing (Task 96, Phase 5) ─────────
// Stand-in for EmployeeActionItemsView / EmployeeRecentRequestsView
// (backend apps/dashboard/views/people.py): success(message, data=
// paginated_data(...)) → {status, message, data: {count, page, page_size,
// total_pages, results}}; page size 5. Synthetic rows.

class _PagedServer implements HttpClientAdapter {
  _PagedServer({this.status = 200, this.message = 'Action items retrieved.', required this.rows});
  final int status;
  final String message;
  final List<Map<String, dynamic>> rows;
  final queries = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    queries.add(Map.of(o.queryParameters));
    if (status != 200) {
      return ResponseBody.fromString(jsonEncode({'status': 'error', 'message': message, 'data': null}), status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    final page = int.tryParse('${o.queryParameters['page'] ?? 1}') ?? 1;
    final slice = rows.skip((page - 1) * 5).take(5).toList();
    return ResponseBody.fromString(
        jsonEncode({
          'status': 'success',
          'message': message,
          'data': {
            'count': rows.length,
            'page': page,
            'page_size': 5,
            'total_pages': rows.isEmpty ? 1 : (rows.length / 5).ceil(),
            'results': slice,
          },
        }),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

DashboardRemoteDataSource _ds(_PagedServer s) =>
    DashboardRemoteDataSource(Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = s);

List<Map<String, dynamic>> _items(int n) => [
      for (var i = 1; i <= n; i++)
        {
          'action_type': 'missing_document',
          'title': 'Upload item $i',
          'description': 'Synthetic.',
          'status': 'pending',
          'navigation_url': '/dashboard/profile',
        }
    ];

void datasourceTests() {
  group('through the datasource (paginated_data envelope)', () {
    test('action items: first page of a longer list — rows and the overall count', () async {
      final r = await _ds(_PagedServer(rows: _items(7))).fetchEmployeeActionItems();
      expect(r.total, 7, reason: 'count is the total across pages, not the page length');
      expect(r.actionItems.length, 5);
      expect(r.actionItems.first.title, 'Upload item 1');
      expect(r.actionItems.first.navigationUrl, '/dashboard/profile');
    });

    test('action items: an empty page is empty, not an error', () async {
      final r = await _ds(_PagedServer(rows: const [])).fetchEmployeeActionItems();
      expect(r.total, 0);
      expect(r.actionItems, isEmpty);
    });

    test('recent requests: rows with request_type, applied_date and details', () async {
      final s = _PagedServer(message: 'Recent requests retrieved.', rows: [
        {
          'request_type': 'expense',
          'title': 'Taxi',
          'applied_date': '2026-11-02',
          'status': 'approved',
          'details': {'amount': '450.00', 'category': 'travel'},
        },
        {
          'request_type': 'leave',
          'title': 'Casual Leave',
          'applied_date': '2026-11-01',
          'status': 'pending',
          'details': {'days': 1},
        },
      ]);
      final r = await _ds(s).fetchEmployeeRecentRequests();
      expect(r.total, 2);
      expect(r.requests.map((e) => e.requestType), ['expense', 'leave']);
      expect(r.requests.first.appliedDate, '2026-11-02');
      expect(r.requests.first.details['category'], 'travel');
    });

    test('recent requests: an empty page', () async {
      final r = await _ds(_PagedServer(rows: const [])).fetchEmployeeRecentRequests();
      expect((r.total, r.requests.length), (0, 0));
    });

    test('errors reach the caller (403 permission and 500), never an empty list', () async {
      await expectLater(
          _ds(_PagedServer(status: 403, message: 'You do not have permission.', rows: const []))
              .fetchEmployeeActionItems(),
          throwsA(isA<DioException>()));
      await expectLater(
          _ds(_PagedServer(status: 500, message: 'Server error.', rows: const [])).fetchEmployeeRecentRequests(),
          throwsA(isA<DioException>()));
    });

    test('a body with an unexpected shape yields empty, not a crash', () {
      expect(ActionItemsResponse.fromJson(const {'results': 'oops'}).actionItems, isEmpty);
      expect(RecentRequestsResponse.fromJson(const {'results': null}).requests, isEmpty);
      expect(ActionItemsResponse.fromJson(const {'count': 'x'}).total, 0);
    });
  });
}

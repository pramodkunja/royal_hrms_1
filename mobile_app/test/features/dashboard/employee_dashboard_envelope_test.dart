import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/dashboard/data/models/employee_dashboard_models.dart';

// Task 95: GET /dashboard/employee/action-items/ and /recent-requests/ answer
// with core.pagination.paginated_data — {count, page, page_size, total_pages,
// results} — not {action_items, total} / {requests, total}, so the Employee
// dashboard's Action Items and Recent Activity were always empty against the
// real server (backend apps/dashboard/views/people.py:389-410 and the recent
// requests view). Synthetic rows.

void main() {
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

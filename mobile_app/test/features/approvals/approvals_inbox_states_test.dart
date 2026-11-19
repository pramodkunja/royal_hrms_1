// Task 101.3: the inbox's distinct "nothing to show" states, the compact filter
// sheet with removable chips, and the action row's measured one-line/stacked rule.
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/approvals/presentation/providers/approvals_providers.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/approvals_kit.dart';

import 'team_approvals_redesign_test.dart' as t;

Finder stateKind(ApprovalsStateKind k) => find.byWidgetPredicate((w) => w is ApprovalsEmptyState && w.kind == k);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('empty states are different things', () {
    testWidgets('nothing pending: calm "caught up", no action, no filter chip noise', (tester) async {
      await t.pump(tester, t.approver, t.Server());
      expect(stateKind(ApprovalsStateKind.empty), findsOneWidget);
      expect(find.text('You’re all caught up!'), findsOneWidget);
      expect(find.byKey(const Key('approvals-empty-action')), findsNothing);
      expect(stateKind(ApprovalsStateKind.error), findsNothing);
    });

    testWidgets('a filter that matches nothing: says so and offers Clear filters, which restores the list',
        (tester) async {
      await t.pump(tester, t.approver, t.Server(leaves: [t.leave('l1', 'Lena Leave')]));
      await tester.enterText(find.byKey(const Key('approvals-search')), 'zzzz');
      await t.settle(tester);
      expect(stateKind(ApprovalsStateKind.noMatch), findsOneWidget);
      expect(stateKind(ApprovalsStateKind.empty), findsNothing);
      expect(find.text('No requests match the current filters.'), findsOneWidget);
      await t.tap(tester, find.byKey(const Key('approvals-empty-action')));
      expect(find.text('Lena Leave'), findsOneWidget);
      expect(stateKind(ApprovalsStateKind.noMatch), findsNothing);
    });

    testWidgets('a failed load is an error with Retry — never the success look; Retry recovers', (tester) async {
      final s = t.Server(leaves: [t.leave('l1', 'Lena Leave')])..listStatus = 500;
      await t.pump(tester, t.approver, s);
      expect(stateKind(ApprovalsStateKind.error), findsOneWidget);
      expect(find.text('You’re all caught up!'), findsNothing);
      expect(find.text('Server error.'), findsOneWidget);
      s.listStatus = 200;
      await t.tap(tester, find.byKey(const Key('approvals-empty-action')));
      expect(find.text('Lena Leave'), findsOneWidget);
      expect(stateKind(ApprovalsStateKind.error), findsNothing);
    });

    testWidgets('no approval permission: denied lock, no Retry, nothing fetched', (tester) async {
      await t.pump(tester, t.user(['leave.view']), t.Server());
      expect(stateKind(ApprovalsStateKind.denied), findsOneWidget);
      expect(find.byKey(const Key('approvals-empty-action')), findsNothing);
      expect(t.server.gets, 0);
    });

    testWidgets('errors map to kinds: 403 denied, no network offline, 500 error (Retry only when it can help)',
        (tester) async {
      DioException dio({int? status, DioExceptionType type = DioExceptionType.badResponse}) {
        final ro = RequestOptions(path: '/x');
        return DioException(
          requestOptions: ro,
          type: type,
          response: status == null
              ? null
              : Response(requestOptions: ro, statusCode: status, data: {'status': 'error', 'message': 'm'}),
        );
      }

      final denied = ApprovalsEmptyState.forError(dio(status: 403), onRetry: () {});
      final server = ApprovalsEmptyState.forError(dio(status: 500), onRetry: () {});
      final offline = ApprovalsEmptyState.forError(dio(type: DioExceptionType.connectionError), onRetry: () {});
      expect(denied.kind, ApprovalsStateKind.denied);
      expect(denied.onAction, isNull); // retrying a 403 cannot help
      expect(server.kind, ApprovalsStateKind.error);
      expect(server.onAction, isNotNull);
      expect(offline.kind, ApprovalsStateKind.offline);
      expect(offline.onAction, isNotNull);
    });
  });

  group('filter sheet and chips', () {
    testWidgets('default shows one "Pending" chip and no active-count badge noise; Clear all is hidden',
        (tester) async {
      await t.pump(tester, t.approver, t.mixed());
      expect(find.byKey(const Key('approvals-chip-status')), findsOneWidget);
      expect(find.byKey(const Key('approvals-chip-sort')), findsNothing);
      expect(find.byKey(const Key('approvals-clear-filters')), findsNothing);
    });

    testWidgets('every web filter is in the sheet; a changed filter shows as a chip; Clear all resets', (tester) async {
      await t.pump(tester, t.approver, t.mixed());
      await t.openFilters(tester);
      expect(find.text('Submitted from'), findsOneWidget);
      expect(find.text('Submitted to'), findsOneWidget);
      await tester.tap(find.byKey(const Key('approvals-sort-employee')));
      await t.settle(tester);
      await t.closeFilters(tester);
      expect(find.byKey(const Key('approvals-chip-sort')), findsOneWidget);
      expect(t.container.read(approvalsSortKeyProvider), ApprovalsSortKey.employee);
      await t.tap(tester, find.byKey(const Key('approvals-clear-filters')));
      expect(find.byKey(const Key('approvals-chip-sort')), findsNothing);
      expect(t.container.read(approvalsSortKeyProvider), ApprovalsSortKey.submitted);
      expect(t.container.read(approvalsStatusFilterProvider), 'pending');
    });

    testWidgets('a date chip is removable on its own', (tester) async {
      await t.pump(tester, t.approver, t.mixed());
      t.container.read(approvalsDateFromProvider.notifier).state = DateTime(2026, 11, 14);
      await t.settle(tester);
      expect(find.byKey(const Key('approvals-chip-from')), findsOneWidget);
      await tester
          .tap(find.descendant(of: find.byKey(const Key('approvals-chip-from')), matching: find.byIcon(Icons.close)));
      await t.settle(tester);
      expect(t.container.read(approvalsDateFromProvider), isNull);
    });
  });

  group('action row', () {
    testWidgets('with room: Details · Reject · Approve on one line', (tester) async {
      await t.pump(tester, t.approver, t.Server(leaves: [t.leave('l1', 'Ann')]), size: const Size(1000, 800));
      final d = tester.getRect(find.byKey(const Key('approval-details-l1')));
      final r = tester.getRect(find.byKey(const Key('approval-reject-l1')));
      final a = tester.getRect(find.byKey(const Key('approval-approve-l1')));
      expect(d.center.dy, closeTo(a.center.dy, 1));
      expect(r.center.dy, closeTo(a.center.dy, 1));
      expect(d.right, lessThanOrEqualTo(r.left));
      expect(r.right, lessThanOrEqualTo(a.left));
    });

    testWidgets('without room (320dp, 2× text): stacked, whole, no overflow', (tester) async {
      await t.pump(tester, t.approver, t.Server(leaves: [t.leave('l1', 'Ann')]),
          size: const Size(320, 700), textScale: 2);
      await t.scrollTo(tester, find.byKey(const Key('approval-approve-l1')));
      final r = tester.getRect(find.byKey(const Key('approval-reject-l1')));
      final a = tester.getRect(find.byKey(const Key('approval-approve-l1')));
      expect(a.top, greaterThanOrEqualTo(r.bottom));
      expect(a.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
    });
  });
}

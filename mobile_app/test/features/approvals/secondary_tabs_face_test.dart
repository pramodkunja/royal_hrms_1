import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/core/constants/api_constants.dart';
import 'package:mobile_app/features/approvals/presentation/widgets/face_registration_approvals_tab.dart';

import 'secondary_tabs_harness.dart';

// Task 101 — Approvals → Face Registration against web
// FaceRegistrationApprovalsTab.tsx.

const _pending = ApiConstants.faceRegistrationPending;
String _review(String id) => ApiConstants.faceRegistrationReview(id);

Map<String, dynamic> _row(String id, {String name = 'Asha Rao', bool passed = true, double? score = 0.923}) => {
      'id': id,
      'employee_name': name,
      'employee_email': 'asha@example.test',
      'liveness_passed': passed,
      'liveness_score': score,
      'status': 'pending',
      'created_at': '2026-09-05T10:00:00',
    };

Map<String, dynamic> _page(List<Map<String, dynamic>> rows, {int page = 1, int totalPages = 1}) =>
    {'count': rows.length, 'page': page, 'page_size': 20, 'total_pages': totalPages, 'results': rows};

FakeServer _server({List<Map<String, dynamic>>? rows}) {
  final s = FakeServer();
  s.on('GET $_pending', (_) => ok(_page(rows ?? [_row('f1')])));
  s.on('PATCH ${_review('f1')}', (_) => ok(_row('f1')));
  return s;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('web strings: Passed/Failed, score percent, padded date, Approve before Reject', (tester) async {
    final s = _server(rows: [_row('f1'), _row('f2', name: 'Ravi Menon', passed: false, score: null)]);
    await pumpTab(tester, const FaceRegistrationApprovalsTab(), s);
    expect(find.text('Passed'), findsOneWidget);
    expect(find.text('Failed'), findsOneWidget);
    expect(find.text('92%'), findsOneWidget);
    expect(find.text('—'), findsOneWidget);
    expect(find.text('Submitted 05 Sept 2026'), findsNWidgets(2));
    expect(find.textContaining('Liveness passed'), findsNothing);
    expect(tester.getTopLeft(byKey('face-approve-f1')).dx < tester.getTopLeft(byKey('face-reject-f1')).dx, isTrue);
  });

  testWidgets('loading and empty strings', (tester) async {
    final s = _server()..holdKeys.add('GET $_pending');
    await pumpTab(tester, const FaceRegistrationApprovalsTab(), s);
    expect(find.text('Loading…'), findsOneWidget);
    s.release();
    await settle(tester);

    await pumpTab(tester, const FaceRegistrationApprovalsTab(), _server(rows: []));
    expect(find.text('No pending face registration requests.'), findsOneWidget);
  });

  testWidgets('list error shows Retry and recovers', (tester) async {
    final s = _server();
    var fails = true;
    s.on('GET $_pending', (_) => fails ? refuse(500, 'Server exploded') : ok(_page([_row('f1')])));
    await pumpTab(tester, const FaceRegistrationApprovalsTab(), s);
    expect(find.text('Server exploded'), findsOneWidget);
    fails = false;
    await tester.tap(find.text('Retry'));
    await settle(tester);
    expect(find.text('Asha Rao'), findsOneWidget);
  });

  testWidgets('403 shows the web permission text', (tester) async {
    final s = _server();
    s.on('GET $_pending', (_) => refuse(403, 'Forbidden by server'));
    await pumpTab(tester, const FaceRegistrationApprovalsTab(), s);
    expect(find.text("You don't have permission to review face registration requests."), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });

  testWidgets('approve and reject send the exact payload, no notes', (tester) async {
    final s = _server();
    await pumpTab(tester, const FaceRegistrationApprovalsTab(), s);
    await tapKey(tester, 'face-approve-f1');
    expect(s.bodies('PATCH ${_review('f1')}'), [
      {'status': 'approved'}
    ]);
    await tapKey(tester, 'face-reject-f1');
    expect(s.bodies('PATCH ${_review('f1')}').last, {'status': 'rejected'});
  });

  testWidgets('server message shows under the row, fallback is the web text', (tester) async {
    final s = _server();
    s.on('PATCH ${_review('f1')}', (_) => refuse(400, 'Already reviewed.'));
    await pumpTab(tester, const FaceRegistrationApprovalsTab(), s);
    await tapKey(tester, 'face-approve-f1');
    expect(find.text('Already reviewed.'), findsOneWidget);

    s.on('PATCH ${_review('f1')}', (_) => refuse(500));
    await tapKey(tester, 'face-approve-f1');
    expect(find.text('Failed to review request.'), findsOneWidget);
    expect(find.text('Already reviewed.'), findsNothing);
  });

  testWidgets('double tap sends exactly one request', (tester) async {
    final s = _server()..holdKeys.add('PATCH ${_review('f1')}');
    await pumpTab(tester, const FaceRegistrationApprovalsTab(), s);
    await tester.ensureVisible(byKey('face-approve-f1'));
    await tester.tap(byKey('face-approve-f1'));
    await tester.tap(byKey('face-approve-f1'), warnIfMissed: false);
    await tester.tap(byKey('face-reject-f1'), warnIfMissed: false);
    await settle(tester);
    expect(s.count('PATCH ${_review('f1')}'), 1);
    s.release();
    await settle(tester);
    expect(s.count('PATCH ${_review('f1')}'), 1);
  });

  testWidgets('pager shows only with several pages and requests the next page', (tester) async {
    final s = _server();
    s.on('GET $_pending', (o) => ok(_page([_row('f1')], page: o.queryParameters['page'] as int, totalPages: 3)));
    await pumpTab(tester, const FaceRegistrationApprovalsTab(), s);
    expect(find.text('Page 1 of 3'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(find.text('Page 2 of 3'), findsOneWidget);
    expect(s.calls.last.queryParameters, {'page': 2, 'page_size': 20});
  });

  for (final (name, size, scale) in responsiveCases) {
    testWidgets('responsive $name: no overflow', (tester) async {
      const long = 'Venkata Subramaniam Ramachandran Iyer-Krishnamurthy the Third';
      final s = _server(rows: [_row('f1', name: long)]);
      await pumpTab(tester, const FaceRegistrationApprovalsTab(), s, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);

      // Error and 403 states too.
      s.on('GET $_pending', (_) => refuse(403));
      await pumpTab(tester, const FaceRegistrationApprovalsTab(), s, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
      s.on('GET $_pending', (_) => refuse(500, 'Server exploded with a rather long explanation of what went wrong'));
      await pumpTab(tester, const FaceRegistrationApprovalsTab(), s, size: size, textScale: scale);
      expect(tester.takeException(), isNull);
    });
  }
}

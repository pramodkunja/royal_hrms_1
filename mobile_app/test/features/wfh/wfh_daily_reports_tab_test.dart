import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/wfh/data/models/wfh_daily_report_model.dart';
import 'package:mobile_app/shared/widgets/app_button.dart';
import 'package:mobile_app/features/wfh/domain/entities/wfh_daily_report_entity.dart';
import 'package:mobile_app/features/wfh/domain/repositories/wfh_report_repository.dart';
import 'package:mobile_app/features/wfh/presentation/providers/wfh_report_providers.dart';
import 'package:mobile_app/features/wfh/presentation/screens/wfh_screen.dart';
import 'package:mobile_app/features/wfh/presentation/wfh_report_strings.dart';
import 'package:mobile_app/features/wfh/presentation/widgets/wfh_daily_reports_tab.dart';
import 'package:mobile_app/features/wfh/presentation/widgets/wfh_report_form.dart';

import 'wfh_report_data_test.dart' show reportJson;

WfhDailyReportEntity _r({int id = 1, String status = 'pending', bool canReview = false}) =>
    WfhDailyReportModel.fromJson(reportJson(id: id, status: status, canReview: canReview));

class _FakeRepo implements WfhReportRepository {
  Future<List<WfhDailyReportEntity>> Function() mine = () async => const [];
  Future<List<WfhDailyReportEntity>> Function() review = () async => const [];
  Completer<WfhReportSaveResult>? submitGate;
  Object? submitError;
  final submits = <Map<String, String>>[];
  final reviews = <(int, WfhReportReviewStatus, String)>[];

  @override
  Future<List<WfhDailyReportEntity>> getMyReports() => mine();
  @override
  Future<List<WfhDailyReportEntity>> getReviewableReports() => review();

  @override
  Future<WfhReportSaveResult> submitReport(
      {required String date, required String completedWork, required String pendingWork, required String updates}) async {
    submits.add({'date': date, 'completed': completedWork, 'pending': pendingWork, 'updates': updates});
    if (submitError != null) throw submitError!;
    if (submitGate != null) return submitGate!.future;
    return (message: 'Report submitted.', report: _r());
  }

  @override
  Future<WfhReportSaveResult> reviewReport(
      {required int id, required WfhReportReviewStatus outcome, required String remarks}) async {
    reviews.add((id, outcome, remarks));
    return (message: 'Report reviewed.', report: _r(id: id, status: outcome.apiValue));
  }
}

DioException _refusal(String msg) => DioException(
      requestOptions: RequestOptions(path: '/wfh/reports/'),
      type: DioExceptionType.badResponse,
      response: Response(requestOptions: RequestOptions(path: '/wfh/reports/'), statusCode: 400, data: {'status': 'error', 'message': msg}),
    );

Future<void> _pump(WidgetTester tester, _FakeRepo repo, {Widget? child}) async {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [wfhReportRepositoryProvider.overrideWithValue(repo)],
    child: MaterialApp(home: Scaffold(body: child ?? const WfhDailyReportsTab())),
  ));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('loading, then the empty state; no review block for a plain employee', (tester) async {
    final gate = Completer<List<WfhDailyReportEntity>>();
    final repo = _FakeRepo()..mine = (() => gate.future);
    await _pump(tester, repo);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    gate.complete(const []);
    await tester.pumpAndSettle();
    expect(find.text(WfhReportStrings.noReports), findsOneWidget);
    expect(find.text(WfhReportStrings.toReview), findsNothing);
  });

  testWidgets('a load failure shows the server message and Retry reloads', (tester) async {
    var calls = 0;
    final repo = _FakeRepo()
      ..mine = () async {
        calls++;
        if (calls == 1) throw _refusal('Work From Home is not enabled for your company.');
        return [_r(id: 3, status: 'full_day')];
      };
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Work From Home is not enabled for your company.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Accepted — Full Day'), findsOneWidget);
  });

  testWidgets('own reports render status, late flag and reviewer remarks; no review controls', (tester) async {
    final repo = _FakeRepo()
      ..mine = () async => [
            WfhDailyReportModel.fromJson({...reportJson(id: 4, status: 'not_accepted'), 'submitted_late': true, 'review_remarks': 'No output'}),
          ];
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text('Not accepted'), findsOneWidget);
    expect(find.text(WfhReportStrings.submittedLate), findsOneWidget);
    expect(find.textContaining('No output', findRichText: true), findsOneWidget);
    expect(find.text(WfhReportStrings.saveReview), findsNothing);
  });

  testWidgets('reviewers see the review block; controls only where can_review is true', (tester) async {
    final repo = _FakeRepo()..review = () async => [_r(id: 10, canReview: true), _r(id: 11, status: 'full_day')];
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    expect(find.text(WfhReportStrings.toReview), findsOneWidget);
    expect(find.textContaining('Pat Person', findRichText: true), findsNWidgets(2));
    expect(find.text(WfhReportStrings.saveReview), findsOneWidget);
  });

  testWidgets('review: Not accepted needs remarks; a valid review is sent once', (tester) async {
    final repo = _FakeRepo()..review = () async => [_r(id: 10, canReview: true)];
    await _pump(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text(WfhReportStrings.saveReview));
    await tester.pump();
    expect(find.text(WfhReportStrings.outcomeRequired), findsOneWidget);
    await tester.tap(find.text(WfhReportStrings.notAccepted));
    await tester.tap(find.text(WfhReportStrings.saveReview));
    await tester.pump();
    expect(find.text(WfhReportStrings.remarksRequired), findsOneWidget);
    expect(repo.reviews, isEmpty);
    await tester.enterText(find.byKey(const Key('wfh-review-remarks-10')), '  No output  ');
    await tester.tap(find.text(WfhReportStrings.saveReview));
    await tester.pumpAndSettle();
    expect(repo.reviews, [(10, WfhReportReviewStatus.notAccepted, 'No output')]);
  });

  testWidgets('submit: empty work is rejected locally; today is sent; success clears the form', (tester) async {
    final repo = _FakeRepo();
    await _pump(tester, repo, child: WfhReportForm(now: () => DateTime(2026, 11, 3, 21, 30)));
    await tester.tap(find.text(WfhReportStrings.submit));
    await tester.pump();
    expect(find.text(WfhReportStrings.completedRequired), findsOneWidget);
    expect(repo.submits, isEmpty);
    expect(find.text('2026-11-03'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'Shipped the export');
    await tester.tap(find.text(WfhReportStrings.submit));
    await tester.pumpAndSettle();
    expect(repo.submits.single, {'date': '2026-11-03', 'completed': 'Shipped the export', 'pending': '', 'updates': ''});
    expect(find.text('Report submitted.'), findsOneWidget);
    expect(find.text('Shipped the export'), findsNothing);
  });

  testWidgets('submit: a backend refusal is shown and the text is kept', (tester) async {
    final repo = _FakeRepo()..submitError = _refusal('You have no approved work-from-home request for this date.');
    await _pump(tester, repo, child: const WfhReportForm());
    await tester.enterText(find.byType(TextField).first, 'Work');
    await tester.tap(find.text(WfhReportStrings.submit));
    await tester.pumpAndSettle();
    expect(find.text('You have no approved work-from-home request for this date.'), findsOneWidget);
    expect(find.text('Work'), findsOneWidget);
  });

  testWidgets('submit: repeated taps while saving send one request', (tester) async {
    final repo = _FakeRepo()..submitGate = Completer();
    await _pump(tester, repo, child: const WfhReportForm());
    await tester.enterText(find.byType(TextField).first, 'Work');
    // Two taps before the frame rebuilds: the second reaches _submit while the
    // first is in flight, so only the in-flight guard can stop it.
    await tester.tap(find.byType(AppButton));
    await tester.tap(find.byType(AppButton));
    await tester.pump();
    expect(repo.submits, hasLength(1));
    // After the rebuild the button is disabled as well.
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNull);
    await tester.tap(find.byType(AppButton), warnIfMissed: false);
    await tester.pump();
    expect(repo.submits, hasLength(1));
    repo.submitGate!.complete((message: 'Report submitted.', report: _r()));
    await tester.pumpAndSettle();
    expect(tester.widget<AppButton>(find.byType(AppButton)).onPressed, isNotNull);
  });

  testWidgets('the date picker stops at today (the backend refuses future dates)', (tester) async {
    await _pump(tester, _FakeRepo(), child: WfhReportForm(now: () => DateTime(2026, 11, 3)));
    await tester.tap(find.byKey(const Key('wfh-report-date')));
    await tester.pumpAndSettle();
    final picker = tester.widget<CalendarDatePicker>(find.byType(CalendarDatePicker));
    expect(picker.lastDate, DateTime(2026, 11, 3));
  });

  testWidgets('navigation: the WFH screen has a Daily Work Report tab that opens the form', (tester) async {
    await _pump(tester, _FakeRepo(), child: const WfhScreen());
    await tester.pumpAndSettle();
    expect(find.text(WfhReportStrings.tabLabel), findsOneWidget);
    await tester.tap(find.text(WfhReportStrings.tabLabel));
    await tester.pumpAndSettle();
    expect(find.text(WfhReportStrings.formTitle), findsOneWidget);
    expect(find.text(WfhReportStrings.myReports), findsOneWidget);
  });

  group('D2: "Reports to Review" appears only when reviewable reports exist (web rule)', () {
    const disabled = 'Work From Home is not enabled for your company.';
    Finder reviewBlock() => find.text(WfhReportStrings.toReview);

    testWidgets('employee with an empty review list: no review block', (tester) async {
      await _pump(tester, _FakeRepo()..mine = () async => [_r(id: 1)]);
      await tester.pumpAndSettle();
      expect(reviewBlock(), findsNothing);
      expect(find.text(WfhReportStrings.myReports), findsOneWidget);
    });

    testWidgets('employee whose review request returns 403: no review block, no reviewer error', (tester) async {
      final repo = _FakeRepo()
        ..mine = (() async => [_r(id: 1)])
        ..review = () async => throw _refusal('You do not have permission to perform this action.');
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(reviewBlock(), findsNothing);
      expect(find.text('You do not have permission to perform this action.'), findsNothing);
      expect(find.text('Retry'), findsNothing);
    });

    testWidgets('reviewer with reviewable reports: block shown with server-controlled controls', (tester) async {
      await _pump(tester, _FakeRepo()..review = () async => [_r(id: 20, canReview: true), _r(id: 21)]);
      await tester.pumpAndSettle();
      expect(reviewBlock(), findsOneWidget);
      expect(find.text(WfhReportStrings.saveReview), findsOneWidget);
    });

    testWidgets('reviewer with an empty review list: no block', (tester) async {
      await _pump(tester, _FakeRepo()..review = () async => const []);
      await tester.pumpAndSettle();
      expect(reviewBlock(), findsNothing);
    });

    testWidgets('review list fails while My Reports succeeds: own reports shown, no reviewer error', (tester) async {
      final repo = _FakeRepo()
        ..mine = (() async => [_r(id: 5, status: 'full_day')])
        ..review = () async => throw _refusal('Server error.');
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Accepted — Full Day'), findsOneWidget);
      expect(reviewBlock(), findsNothing);
      expect(find.text('Server error.'), findsNothing);
    });

    testWidgets('module disabled (both lists fail): the message is shown once, with one Retry', (tester) async {
      final repo = _FakeRepo()
        ..mine = (() async => throw _refusal(disabled))
        ..review = () async => throw _refusal(disabled);
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text(disabled), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(reviewBlock(), findsNothing);
    });

    testWidgets('My Reports failure stays visible and Retry reloads it', (tester) async {
      var calls = 0;
      final repo = _FakeRepo()
        ..mine = () async {
          if (++calls == 1) throw _refusal('Could not reach the server.');
          return [_r(id: 9)];
        };
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(find.text('Could not reach the server.'), findsOneWidget);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Could not reach the server.'), findsNothing);
      expect(find.text('Pending review'), findsOneWidget);
    });

    testWidgets('a reviewer whose refresh fails keeps the block and sees the error with Retry', (tester) async {
      var fail = false;
      final repo = _FakeRepo()
        ..review = () async {
          if (fail) throw _refusal('Server error.');
          return [_r(id: 30, canReview: true)];
        };
      await _pump(tester, repo);
      await tester.pumpAndSettle();
      expect(reviewBlock(), findsOneWidget);
      fail = true;
      ProviderScope.containerOf(tester.element(find.byType(WfhDailyReportsTab))).invalidate(wfhReviewReportsProvider);
      await tester.pumpAndSettle();
      expect(reviewBlock(), findsOneWidget);
      expect(find.text('Server error.'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

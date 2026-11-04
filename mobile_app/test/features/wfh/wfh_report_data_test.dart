import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/features/wfh/data/datasources/wfh_report_remote_datasource.dart';
import 'package:mobile_app/features/wfh/data/models/wfh_daily_report_model.dart';
import 'package:mobile_app/features/wfh/domain/entities/wfh_daily_report_entity.dart';
import 'package:mobile_app/features/wfh/presentation/wfh_report_strings.dart';

// Shapes copied from WFHDailyReportSerializer (apps/hrms/views/wfh_reports.py)
// and core.responses.success/error ({status, message, data}).

Map<String, dynamic> reportJson({int id = 7, String status = 'pending', bool canReview = false}) => {
      'id': id,
      'date': '2026-11-02',
      'completed_work': 'Built the export',
      'pending_work': 'Tests',
      'updates': '',
      'submitted_at': '2026-11-02T18:05:00+05:30',
      'submitted_late': false,
      'review_status': status,
      'reviewed_by_name': '',
      'reviewed_at': null,
      'review_remarks': '',
      'employee_name': 'Pat Person',
      'employee_code': 'EMP-7',
      'can_review': canReview,
    };

ResponseBody _json(int status, Object body) => ResponseBody.fromString(jsonEncode(body), status,
    headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});

class _Adapter implements HttpClientAdapter {
  _Adapter(this.reply);
  final ResponseBody Function(RequestOptions) reply;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? _, Future<void>? __) async {
    requests.add(o);
    return reply(o);
  }

  @override
  void close({bool force = false}) {}
}

(WfhReportRemoteDataSource, _Adapter) _ds(ResponseBody Function(RequestOptions) reply) {
  final adapter = _Adapter(reply);
  final dio = Dio(BaseOptions(baseUrl: 'https://test.invalid/api'))..httpClientAdapter = adapter;
  return (WfhReportRemoteDataSource(dio), adapter);
}

void main() {
  group('parsing', () {
    test('every serializer field maps onto the entity', () {
      final r = WfhDailyReportModel.fromJson({
        ...reportJson(status: 'half_day', canReview: true),
        'submitted_late': true,
        'reviewed_by_name': 'Manager M',
        'reviewed_at': '2026-11-03T10:00:00+05:30',
        'review_remarks': 'Partial',
      });
      expect(r.id, 7);
      expect(r.date, '2026-11-02');
      expect(r.completedWork, 'Built the export');
      expect(r.pendingWork, 'Tests');
      expect(r.updates, '');
      expect(r.submittedLate, isTrue);
      expect(r.reviewStatus, WfhReportReviewStatus.halfDay);
      expect(r.reviewStatus.label, 'Accepted — Half Day');
      expect(r.reviewedByName, 'Manager M');
      expect(r.reviewedAt, isNotNull);
      expect(r.reviewRemarks, 'Partial');
      expect((r.employeeName, r.employeeCode, r.canReview), ('Pat Person', 'EMP-7', true));
    });

    test('all four review statuses, and unknown/missing values default to pending', () {
      expect(
        ['pending', 'full_day', 'half_day', 'not_accepted'].map(WfhReportReviewStatus.fromApi),
        WfhReportReviewStatus.values,
      );
      expect(WfhReportReviewStatus.fromApi('weird'), WfhReportReviewStatus.pending);
      expect(WfhDailyReportModel.fromJson({'id': 1}).reviewStatus, WfhReportReviewStatus.pending);
      expect(WfhDailyReportModel.fromJson({'id': 1}).canReview, isFalse);
    });
  });

  group('API calls', () {
    test('own reports: GET /wfh/reports/?mine=1, no paging or date parameters', () async {
      final (ds, a) = _ds((_) => _json(200, {'status': 'success', 'message': 'WFH reports.', 'data': [reportJson()]}));
      final rows = await ds.fetchReports(mine: true);
      expect(rows.single.id, 7);
      expect(a.requests.single.path, '/wfh/reports/');
      expect(a.requests.single.queryParameters, {'mine': '1'});
    });

    test('reviewable reports: GET /wfh/reports/ with no parameters', () async {
      final (ds, a) = _ds((_) => _json(200, {'status': 'success', 'message': 'WFH reports.', 'data': []}));
      expect(await ds.fetchReports(mine: false), isEmpty);
      expect(a.requests.single.queryParameters, isEmpty);
    });

    test('submit posts exactly the serializer fields and returns the server message', () async {
      final (ds, a) = _ds((_) => _json(200, {'status': 'success', 'message': 'Report updated.', 'data': reportJson()}));
      final res = await ds.submitReport(date: '2026-11-02', completedWork: 'A', pendingWork: '', updates: 'U');
      expect(res.message, 'Report updated.');
      expect(a.requests.single.method, 'POST');
      expect(a.requests.single.data, {'date': '2026-11-02', 'completed_work': 'A', 'pending_work': '', 'updates': 'U'});
    });

    test('review posts outcome and remarks to /wfh/reports/<id>/review/', () async {
      final (ds, a) = _ds((_) => _json(200, {'status': 'success', 'message': 'Report reviewed.', 'data': reportJson(status: 'full_day')}));
      final res = await ds.reviewReport(id: 7, outcome: 'full_day', remarks: '');
      expect(res.report.reviewStatus, WfhReportReviewStatus.fullDay);
      expect(a.requests.single.path, '/wfh/reports/7/review/');
      expect(a.requests.single.data, {'outcome': 'full_day', 'remarks': ''});
    });

    test('a backend refusal surfaces as a DioException carrying the message', () async {
      final (ds, _) = _ds((_) => _json(400, {'status': 'error', 'message': 'You have no approved work-from-home request for this date.'}));
      expect(
        () => ds.submitReport(date: '2026-11-02', completedWork: 'A', pendingWork: '', updates: ''),
        throwsA(isA<DioException>().having((e) => (e.response?.data as Map)['message'], 'message',
            'You have no approved work-from-home request for this date.')),
      );
    });
  });

  group('validation (mirrors web + serializer)', () {
    test('work completed is required; whitespace does not count', () {
      expect(wfhReportFormError(completed: ''), WfhReportStrings.completedRequired);
      expect(wfhReportFormError(completed: '   \n'), WfhReportStrings.completedRequired);
      expect(wfhReportFormError(completed: 'Done'), isNull);
    });

    test('each field is limited to 5000 characters', () {
      final long = 'x' * (kWfhReportMaxLength + 1);
      expect(wfhReportFormError(completed: 'x' * kWfhReportMaxLength), isNull);
      expect(wfhReportFormError(completed: long), WfhReportStrings.tooLong);
      expect(wfhReportFormError(completed: 'ok', pending: long), WfhReportStrings.tooLong);
      expect(wfhReportFormError(completed: 'ok', updates: long), WfhReportStrings.tooLong);
    });

    test('review needs an outcome, and a reason when not accepting', () {
      expect(wfhReviewError(null, ''), WfhReportStrings.outcomeRequired);
      expect(wfhReviewError(WfhReportReviewStatus.pending, 'x'), WfhReportStrings.outcomeRequired);
      expect(wfhReviewError(WfhReportReviewStatus.notAccepted, '  '), WfhReportStrings.remarksRequired);
      expect(wfhReviewError(WfhReportReviewStatus.notAccepted, 'No output'), isNull);
      expect(wfhReviewError(WfhReportReviewStatus.fullDay, ''), isNull);
      expect(wfhReviewError(WfhReportReviewStatus.halfDay, ''), isNull);
    });

    test('dates go to the API as yyyy-MM-dd', () {
      expect(wfhReportIsoDate(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
    });
  });
}

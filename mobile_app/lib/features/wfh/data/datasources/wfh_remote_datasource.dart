import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/wfh_models.dart';

class WfhRemoteDataSource {
  final Dio _dio;
  WfhRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  // GET /wfh/requests/ — always the caller's own requests (no scope param),
  // used by "My Requests". status: csv-list, e.g. 'approved,rejected'.
  Future<List<WfhRequestModel>> fetchWfhRequests({String? status}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    final res =
        await _dio.get(ApiConstants.wfhRequests, queryParameters: params);
    final data = _unwrap(res.data);
    final List<dynamic> list = switch (data) {
      List d => d,
      Map<String, dynamic> d => (d['results'] as List<dynamic>? ?? []),
      _ => [],
    };
    return list
        .whereType<Map<String, dynamic>>()
        .map(WfhRequestModel.fromJson)
        .toList();
  }

  // Paginated variant — used by the Approvals tab (scope='team', only works
  // when the caller holds wfh.approve) and the employee_id-filtered lookup
  // (requires employees.view or wfh.approve server-side).
  Future<WfhRequestPageModel> fetchWfhRequestsPage({
    String? status,
    String? scope,
    String? employeeId,
    int page = 1,
    int? pageSize,
  }) async {
    final params = <String, dynamic>{'page': page};
    if (status != null) params['status'] = status;
    if (scope != null) params['scope'] = scope;
    if (employeeId != null && employeeId.isNotEmpty) {
      params['employee_id'] = employeeId;
    }
    if (pageSize != null) params['page_size'] = pageSize;
    final res =
        await _dio.get(ApiConstants.wfhRequests, queryParameters: params);
    return WfhRequestPageModel.fromJson(_unwrap(res.data));
  }

  // Single-fetch used to refresh the detail sheet's background state.
  Future<WfhRequestModel> fetchWfhRequestById(String id) async {
    final res = await _dio.get(ApiConstants.wfhRequestDetail(id));
    return WfhRequestModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // POST /wfh/requests/ — plain JSON body (no document upload on this
  // endpoint). Server always sets employee=self; overlap validation (own
  // WFH, own leave) happens server-side and surfaces as a plain string
  // message — do not re-validate client-side.
  Future<WfhRequestModel> createWfhRequest({
    required String startDate,
    required String endDate,
    String? reason,
    String? locationLabel,
    required double latitude,
    required double longitude,
  }) async {
    final body = <String, dynamic>{
      'start_date': startDate,
      'end_date': endDate,
      'latitude': latitude,
      'longitude': longitude,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (locationLabel != null && locationLabel.isNotEmpty)
        'location_label': locationLabel,
    };
    final res = await _dio.post(ApiConstants.wfhRequests, data: body);
    return WfhRequestModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  // PATCH .../wfh/requests/<id>/ — ALWAYS a cancel; there is no field-edit
  // capability on this endpoint at all (see WorkFromHomeRequestDetailView).
  Future<void> cancelWfhRequest(String id) async {
    await _dio.patch(ApiConstants.wfhRequestDetail(id));
  }

  // POST .../wfh/requests/<id>/approve/ — remarks is OPTIONAL server-side;
  // omit the key entirely rather than sending an empty string.
  Future<void> approveWfhRequest(String id, {String? remarks}) async {
    await _dio.post(ApiConstants.wfhRequestAction(id), data: {
      'action': 'approve',
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
  }

  Future<void> rejectWfhRequest(String id, {String? remarks}) async {
    await _dio.post(ApiConstants.wfhRequestAction(id), data: {
      'action': 'reject',
      if (remarks != null && remarks.isNotEmpty) 'remarks': remarks,
    });
  }

  Future<List<WfhSavedLocationModel>> fetchSavedLocations() async {
    final res = await _dio.get(ApiConstants.wfhSavedLocations);
    final data = _unwrap(res.data);
    final List<dynamic> list = data is List ? data : [];
    return list
        .whereType<Map<String, dynamic>>()
        .map(WfhSavedLocationModel.fromJson)
        .toList();
  }

  // Duplicate label (case-insensitive) per employee rejects with a plain
  // error message server-side — surfaced verbatim, no client-side dedupe.
  Future<WfhSavedLocationModel> createSavedLocation({
    required String label,
    required double latitude,
    required double longitude,
  }) async {
    final res = await _dio.post(ApiConstants.wfhSavedLocations, data: {
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
    });
    return WfhSavedLocationModel.fromJson(
        _unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteSavedLocation(String id) async {
    await _dio.delete(ApiConstants.wfhSavedLocationDetail(id));
  }
}

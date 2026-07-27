import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/holiday_model.dart';

class HolidayRemoteDataSource {
  final Dio _dio;
  HolidayRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  // branchName filters to that branch (+ company-wide holidays) — omit to let
  // the backend default to company-wide + the caller's own branch
  // (Q(branch__isnull=True) | Q(branch__branch_name=user.branch)).
  Future<List<HolidayModel>> fetchHolidays({
    required int year,
    String? branchName,
  }) async {
    final res = await _dio.get(ApiConstants.holidays, queryParameters: {
      'year': year,
      if (branchName != null && branchName.isNotEmpty) 'branch': branchName,
    });
    final data = _unwrap(res.data);
    final list = (data is Map<String, dynamic> ? data['holidays'] : null) as List<dynamic>? ?? [];
    return list.whereType<Map<String, dynamic>>().map(HolidayModel.fromJson).toList();
  }

  Future<HolidayModel> createHoliday(HolidayFormData form) async {
    final res = await _dio.post(ApiConstants.holidays, data: _body(form));
    return HolidayModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<HolidayModel> updateHoliday(String id, HolidayFormData form) async {
    final res = await _dio.patch(ApiConstants.holidayDetail(id), data: _body(form));
    return HolidayModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<HolidayModel> setActive(String id, bool isActive) async {
    final res = await _dio.patch(ApiConstants.holidayDetail(id), data: {'is_active': isActive});
    return HolidayModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteHoliday(String id) async {
    await _dio.delete(ApiConstants.holidayDetail(id));
  }

  Map<String, dynamic> _body(HolidayFormData form) => {
    'name': form.name.trim(),
    'date':
        '${form.date!.year.toString().padLeft(4, '0')}-${form.date!.month.toString().padLeft(2, '0')}-${form.date!.day.toString().padLeft(2, '0')}',
    'holiday_type': form.type,
    'is_optional': form.isOptional,
    'description': form.description.trim(),
    'branch': form.branchId,
    'is_active': form.isActive,
  };
}

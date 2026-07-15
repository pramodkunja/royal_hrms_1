import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../domain/entities/birthday_entity.dart';
import '../models/birthday_model.dart';

class HrmsRemoteDataSource {
  final Dio _dio;
  HrmsRemoteDataSource(this._dio);

  dynamic _unwrap(dynamic body) {
    if (body is Map && body['data'] != null) return body['data'];
    return body;
  }

  // Backend envelope: {success, data: {today: [...], upcoming: [...]}}.
  // Requires the 'employees.view' permission server-side (403 without it) —
  // callers must gate this behind that permission before invoking.
  Future<BirthdaysResult> fetchBirthdays() async {
    final res = await _dio.get(ApiConstants.hrmsBirthdays);
    final data = _unwrap(res.data);
    final map = data is Map<String, dynamic> ? data : <String, dynamic>{};
    List<BirthdayEntity> parse(String key) {
      final list = map[key] as List<dynamic>? ?? [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(BirthdayModel.fromJson)
          .toList();
    }

    return BirthdaysResult(today: parse('today'), upcoming: parse('upcoming'));
  }
}

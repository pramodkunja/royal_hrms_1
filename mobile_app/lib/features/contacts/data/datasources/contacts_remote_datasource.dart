import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/company_contact.dart';

/// The Contact Matrix endpoints (see company_contact.dart for the contract).
/// Failures are rethrown as the app's typed exceptions carrying the server's
/// own message (parseDioException).
class ContactsRemoteDatasource {
  const ContactsRemoteDatasource(this._dio);
  final Dio _dio;

  static Object? _data(Object? body) => body is Map && body.containsKey('data') ? body['data'] : body;

  Future<T> _call<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on DioException catch (e) {
      throw parseDioException(e);
    }
  }

  Future<ContactMatrix> fetch() => _call(() async {
        final res = await _dio.get(ApiConstants.companyContacts);
        return ContactMatrix.fromJson(_data(res.data));
      });

  Future<CompanyContact> create(ContactForm form) => _call(() async {
        final res = await _dio.post(ApiConstants.companyContacts, data: form.toJson());
        return CompanyContact.fromJson((_data(res.data) as Map).cast<String, dynamic>());
      });

  Future<CompanyContact> update(int id, ContactForm form) => _call(() async {
        final res = await _dio.patch(ApiConstants.companyContactDetail(id), data: form.toJson());
        return CompanyContact.fromJson((_data(res.data) as Map).cast<String, dynamic>());
      });

  Future<void> delete(int id) => _call(() async {
        await _dio.delete(ApiConstants.companyContactDetail(id));
      });

  /// Branch choices for the form — web asks for `?page_size=100` and reads
  /// either a plain list or `results`.
  Future<List<ContactBranchOption>> fetchBranches() => _call(() async {
        final res = await _dio.get(ApiConstants.branches, queryParameters: {'page_size': 100});
        final data = _data(res.data);
        final rows = data is List ? data : (data is Map ? data['results'] : null);
        return [
          for (final b in (rows is List ? rows : const []).whereType<Map>())
            if (b['id'] is num) ContactBranchOption((b['id'] as num).toInt(), '${b['branch_name'] ?? ''}'),
        ];
      });
}

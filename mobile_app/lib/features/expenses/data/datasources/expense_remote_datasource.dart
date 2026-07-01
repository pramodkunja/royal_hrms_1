import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../models/expense_model.dart';

class ExpenseRemoteDataSource {
  final Dio _dio;
  ExpenseRemoteDataSource(this._dio);

  // ── Fetch list ─────────────────────────────────────────────────────────────

  Future<List<ExpenseModel>> fetchExpenses({String? category}) async {
    final params = <String, dynamic>{};
    if (category != null && category.isNotEmpty) params['category'] = category;

    try {
      final res = await _dio.get(ApiConstants.expenses, queryParameters: params);
      final data = _unwrap(res.data);

      // Handle both plain list and paginated (results key)
      final List<dynamic> list = switch (data) {
        List d           => d,
        Map<String, dynamic> d => (d['results'] as List<dynamic>? ?? []),
        _                => [],
      };

      return list
          .whereType<Map<String, dynamic>>()
          .map(ExpenseModel.fromJson)
          .toList();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
  }

  // ── Fetch stats ─────────────────────────────────────────────────────────────

  Future<ExpenseStats> fetchStats() async {
    try {
      final res = await _dio.get(ApiConstants.expenseStats);
      final data = _unwrap(res.data);
      if (data is! Map<String, dynamic>) return ExpenseStats.empty();
      return ExpenseStats.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return ExpenseStats.empty();
      rethrow;
    }
  }

  // ── Submit expense ──────────────────────────────────────────────────────────

  Future<ExpenseModel> submitExpense({
    required String title,
    required String amount,
    required String category,
    required String expenseDate,
    required String description,
    required List<MultipartFile> receipts,
  }) async {
    final formData = FormData.fromMap({
      'title':        title.trim(),
      'amount':       amount,
      'category':     category,
      'expense_date': expenseDate,
      'description':  description.trim(),
    });
    for (final file in receipts) {
      formData.files.add(MapEntry('receipts', file));
    }

    try {
      final res = await _dio.post(
        ApiConstants.expenses,
        data:    formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      final data = _unwrap(res.data);
      return ExpenseModel.fromJson(data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw _extractError(e);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  // Unwrap the standard {"success": bool, "message": str, "data": any} envelope.
  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  // Extract a human-readable message from a DioException response body.
  Exception _extractError(DioException e) {
    final body = e.response?.data;
    if (body is Map<String, dynamic>) {
      final msg = body['message'];
      if (msg is String && msg.isNotEmpty) return Exception(msg);
      final detail = body['detail'];
      if (detail is String && detail.isNotEmpty) return Exception(detail);
    }
    final status = e.response?.statusCode;
    if (status == 400) return Exception('Validation error. Check all fields.');
    if (status == 401) return Exception('Session expired. Please log in again.');
    if (status == 403) return Exception('You do not have permission to submit expenses.');
    if (status == 404) return Exception('Expense service is not available yet.');
    if (status != null && status >= 500) return Exception('Server error. Please try again later.');
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return Exception('Cannot reach server. Check your connection.');
    }
    return Exception(e.message ?? 'An unexpected error occurred.');
  }
}

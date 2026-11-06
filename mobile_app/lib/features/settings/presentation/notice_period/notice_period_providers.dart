import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../employees/presentation/providers/employee_providers.dart' show employeeDetailProvider;
import '../../data/models/monthly_leave_models.dart' show kMonthlyImportMaxBytes;
import '../../data/models/notice_period_models.dart';
import '../leave_policy/monthly_leave/monthly_leave_providers.dart'
    show PickedFile, monthlyImportFilePickerProvider, monthlySampleSaverProvider;

/// The server's gate for saving and importing notice periods:
/// EmployeeDetailView.put and NoticePeriodImportView both check
/// `has_perm(user, 'employees.edit')` — superuser or the role's codename —
/// as web's `usePermission("employees.edit")` does.
const kNoticePeriodEditPermission = 'employees.edit';
const kNoticePeriodDenied = 'You do not have permission to change notice periods.';

bool canEditNoticePeriods(UserEntity? user) =>
    user != null && (user.isSuperuser || user.permissions.contains(kNoticePeriodEditPermission));

/// Web `checkImportFile` (lib/assetImport.ts), used by the import modal.
String? checkNoticeImportFile(PickedFile f) {
  final name = f.name.toLowerCase();
  if (!name.endsWith('.csv') && !name.endsWith('.xlsx')) return 'Upload a .csv or .xlsx file.';
  if (f.size > kMonthlyImportMaxBytes) return 'File must not exceed 5 MB.';
  if (f.size == 0) return 'The file is empty.';
  return null;
}

class NoticePeriodRemoteDataSource {
  NoticePeriodRemoteDataSource(this._dio);
  final Dio _dio;

  static Map<String, dynamic> _data(Object? body) {
    final d = body is Map ? body['data'] : null;
    return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
  }

  /// GET /employees/?search&department&page&page_size=20 — no status filter,
  /// as web (onboarding employees need a notice period too).
  Future<NoticeEmployeePage> fetchPage({required String search, required String department, required int page}) async {
    final res = await _dio.get(ApiConstants.employees, queryParameters: {
      if (search.isNotEmpty) 'search': search,
      if (department.isNotEmpty) 'department': department,
      'page': page,
      'page_size': kNoticePageSize,
    });
    return NoticeEmployeePage.fromJson(_data(res.data));
  }

  /// PUT /employees/<code>/ with only `notice_period_days` (int or null).
  Future<void> save(String employeeId, int? days) async {
    await _dio.put(ApiConstants.employeeDetail(employeeId), data: {'notice_period_days': days});
  }

  /// POST /employees/notice-period/import/ (multipart `file`, plus
  /// `dry_run=true` for the preview).
  Future<NoticeImportResult> import(PickedFile file, {required bool dryRun}) async {
    final res = await _dio.post(ApiConstants.employeeNoticePeriodImport,
        data: FormData.fromMap({
          'file': MultipartFile.fromBytes(file.bytes, filename: file.name),
          if (dryRun) 'dry_run': 'true',
        }));
    return NoticeImportResult.fromJson(_data(res.data));
  }

  /// GET /employees/notice-period/import/sample/?format=csv|xlsx — file bytes.
  Future<List<int>> sample(String format) async {
    try {
      final res = await _dio.get(ApiConstants.employeeNoticePeriodImportSample,
          queryParameters: {'format': format}, options: Options(responseType: ResponseType.bytes));
      return res.data as List<int>;
    } on DioException catch (e) {
      // A refusal arrives as bytes here; decode it so its message can be shown.
      final res = e.response;
      final data = res?.data;
      if (res != null && data is List<int>) {
        Object? decoded;
        try {
          decoded = jsonDecode(utf8.decode(data, allowMalformed: true));
        } catch (_) {}
        if (decoded is Map) {
          throw DioException(
            requestOptions: e.requestOptions,
            response: Response(requestOptions: res.requestOptions, statusCode: res.statusCode, data: decoded),
            type: e.type,
            error: e.error,
          );
        }
      }
      rethrow;
    }
  }
}

final noticePeriodDataSourceProvider =
    Provider<NoticePeriodRemoteDataSource>((ref) => NoticePeriodRemoteDataSource(ref.watch(dioProvider)));

typedef NoticeQuery = ({String search, String department, int page});

/// One page of employees with their notice period (employees.view on the server).
final noticePeriodPageProvider = FutureProvider.autoDispose.family<NoticeEmployeePage, NoticeQuery>((ref, q) =>
    ref.read(noticePeriodDataSourceProvider).fetchPage(search: q.search, department: q.department, page: q.page));

/// The same .csv/.xlsx picker and sample saver as Monthly Leave import (tests override them).
final noticeImportFilePickerProvider =
    Provider<Future<PickedFile?> Function()>((ref) => ref.watch(monthlyImportFilePickerProvider));
final noticeSampleSaverProvider = Provider<Future<String?> Function(String fileName, Uint8List bytes)>(
    (ref) => ref.watch(monthlySampleSaverProvider));

/// Refused before any request: the user lacks employees.edit.
class NoticePeriodDenied implements Exception {
  const NoticePeriodDenied();
  @override
  String toString() => kNoticePeriodDenied;
}

/// Refused before any request: an import or sample download is already running.
class NoticePeriodBusy implements Exception {
  const NoticePeriodBusy();
}

/// The server's `message` (validation, permission, scope), else [fallback].
String noticePeriodError(Object e, String fallback) {
  if (e is NoticePeriodDenied) return e.toString();
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map && body['message'] is String && (body['message'] as String).isNotEmpty) {
      return body['message'] as String;
    }
    if (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
  }
  return fallback;
}

final noticePeriodServiceProvider = Provider<NoticePeriodService>((ref) => NoticePeriodService(ref));

/// Writes go through here: employees.edit first; saves are one at a time per
/// employee, imports one at a time; after a confirmed change the list (and
/// the employee's detail, if loaded) reload.
class NoticePeriodService {
  NoticePeriodService(this._ref);
  final Ref _ref;
  final _saving = <String>{};
  bool _importing = false;

  UserEntity? get _user => _ref.read(authStateProvider).valueOrNull?.user;
  NoticePeriodRemoteDataSource get _ds => _ref.read(noticePeriodDataSourceProvider);

  void _guard() {
    if (!canEditNoticePeriods(_user)) throw const NoticePeriodDenied();
  }

  /// [raw] is the text field's value; it must already pass [noticePeriodInputError].
  Future<void> save(String employeeId, String raw) async {
    _guard();
    final problem = noticePeriodInputError(raw);
    if (problem != null) throw ArgumentError(problem);
    if (!_saving.add(employeeId)) throw const NoticePeriodBusy();
    try {
      await _ds.save(employeeId, noticePeriodPayloadValue(raw));
      _ref
        ..invalidate(noticePeriodPageProvider)
        ..invalidate(employeeDetailProvider(employeeId));
    } finally {
      _saving.remove(employeeId);
    }
  }

  Future<T> _import<T>(Future<T> Function() run) async {
    _guard();
    if (_importing) throw const NoticePeriodBusy();
    _importing = true;
    try {
      return await run();
    } finally {
      _importing = false;
    }
  }

  /// dry_run=true: nothing is saved.
  Future<NoticeImportResult> preview(PickedFile file) => _import(() => _ds.import(file, dryRun: true));

  /// The confirm request; the list reloads when anything was updated (web `onImported`).
  Future<NoticeImportResult> apply(PickedFile file) => _import(() async {
        final r = await _ds.import(file, dryRun: false);
        if ((r.summary.updated ?? 0) > 0) _ref.invalidate(noticePeriodPageProvider);
        return r;
      });

  Future<List<int>> sample(String format) => _import(() => _ds.sample(format));
}

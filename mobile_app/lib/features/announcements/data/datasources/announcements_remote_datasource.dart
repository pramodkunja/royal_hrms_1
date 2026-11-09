import 'package:dio/dio.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../settings/data/models/departments_model.dart';
import '../models/announcement_model.dart';

class AnnouncementsRemoteDataSource {
  final Dio _dio;
  AnnouncementsRemoteDataSource(this._dio);

  // ── List ───────────────────────────────────────────────────────────────────

  Future<AnnouncementPage> fetchAnnouncements({
    String? category,
    int page = 1,
    int pageSize = 20,
  }) async {
    final res = await _dio.get(
      ApiConstants.announcements,
      queryParameters: <String, dynamic>{
        'page': page,
        'page_size': pageSize,
        if (category != null && category.isNotEmpty) 'category': category,
      },
    );
    final data = _unwrap(res.data) as Map<String, dynamic>;
    final results = (data['results'] as List<dynamic>? ?? [])
        .map((e) => AnnouncementModel.fromJson(e as Map<String, dynamic>))
        .toList();

    return AnnouncementPage(
      announcements: results,
      stats:         AnnouncementStats.fromJson(data),
      currentPage:   data['page'] as int? ?? page,
      totalPages:    data['total_pages'] as int? ?? 1,
    );
  }

  // ── Create / Update / Delete ───────────────────────────────────────────────

  /// Web uses a longer timeout than its client default for posting/updating
  /// (`{ timeout: 30000 }` — sending with email can be slow). Set explicitly
  /// here so it holds even if the app-wide defaults change.
  static const saveTimeout = Duration(seconds: 30);
  static final _saveOptions = Options(sendTimeout: saveTimeout, receiveTimeout: saveTimeout);

  Future<AnnouncementModel> createAnnouncement(AnnouncementFormData form) async {
    final res = await _dio.post(ApiConstants.announcements, data: form.toJson(), options: _saveOptions);
    return AnnouncementModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<AnnouncementModel> updateAnnouncement(String id, AnnouncementFormData form) async {
    final res = await _dio.put(ApiConstants.announcementDetail(id), data: form.toJson(), options: _saveOptions);
    return AnnouncementModel.fromJson(_unwrap(res.data) as Map<String, dynamic>);
  }

  Future<void> deleteAnnouncement(String id) async {
    await _dio.delete(ApiConstants.announcementDetail(id));
  }

  // ── Reaction ───────────────────────────────────────────────────────────────

  Future<({bool hasReacted, int reactionsCount})> toggleReaction(String id) async {
    final res = await _dio.post(ApiConstants.announcementReact(id));
    final data = _unwrap(res.data) as Map<String, dynamic>;
    return (
      hasReacted:     data['has_reacted'] as bool? ?? false,
      reactionsCount: data['reactions_count'] as int? ?? 0,
    );
  }

  // ── View tracking (fire-and-forget) ───────────────────────────────────────

  Future<void> trackView(String id) async {
    try {
      await _dio.post(ApiConstants.announcementView(id));
    } catch (_) {}
  }

  // ── Branches for form dropdown ─────────────────────────────────────────────

  /// Active branches for the form, as web (`?status=active&page_size=100`).
  Future<List<BranchSimple>> fetchBranches() async {
    final res = await _dio.get(ApiConstants.branches,
        queryParameters: {'status': 'active', 'page_size': 100});
    final data = _unwrap(res.data);
    final list = data is List
        ? data
        : (data is Map<String, dynamic> ? data['results'] as List<dynamic>? ?? [] : []);
    return list
        .map((e) => BranchSimple.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Departments for the form. Web passes `?branch=<own branch name>` for a
  /// branch-scoped poster (departments with active employees there) and no
  /// branch for an org-wide one.
  Future<List<DepartmentModel>> fetchDepartments({String? branch}) async {
    final res = await _dio.get(ApiConstants.departments, queryParameters: {
      'page_size': 200,
      if (branch != null && branch.isNotEmpty) 'branch': branch,
    });
    final data = _unwrap(res.data);
    final list = data is List
        ? data
        : (data is Map<String, dynamic> ? data['results'] as List<dynamic>? ?? [] : []);
    return list.map((e) => DepartmentModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // ── Helper ─────────────────────────────────────────────────────────────────

  dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }
}

import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';

// Settings → Assets (asset catalogue) — web settings/assets/page.tsx,
// types/assets.ts and lib/assetHolder.ts over backend apps/assets
// (views.py, serializers.py):
//  - GET  /assets/?search&status&category&asset_type&branch&page&page_size=20
//    (assets.view; non-admins see only their own branch's assets)
//  - POST /assets/ (assets.create; non-admins only for their own branch),
//    PUT /assets/<id>/ (assets.edit), DELETE /assets/<id>/ (assets.delete;
//    409 while assigned), GET /assets/<id>/ (current holder)
//  - GET/POST /assets/categories/, GET/POST /assets/types/?category=<id>
//    (view: assets.view; quick-add: assets.create)
//  - POST /assets/<id>/send-to-maintenance/ (assets.edit; damaged assets),
//    POST /assets/maintenance/<record id>/complete/ (assets.edit)
//  - branches for the filter / form: GET /branch/branches/ (as web)
// The server validates everything (unique tag / serial, category and type
// from the master lists or "Other" with a name, warranty dates, branch).

const kAssetOther = 'Other';

/// Web ASSET_STATUS_OPTIONS (= backend STATUS_CHOICES).
const kAssetStatuses = <(String, String)>[
  ('available', 'Available'),
  ('assigned', 'Assigned'),
  ('under_repair', 'Under Repair'),
  ('lost', 'Lost'),
  ('damaged', 'Damaged'),
  ('retired', 'Retired'),
  ('disposed', 'Disposed'),
];

/// Web MAINTENANCE_OUTCOME_OPTIONS.
const kMaintenanceOutcomes = <(String, String)>[
  ('repaired', 'Repaired'),
  ('not_repairable', 'Not Repairable'),
];

String _s(Object? v) => v == null ? '' : '$v';
String? _n(Object? v) => v == null || '$v'.isEmpty ? null : '$v';

class ActiveMaintenance {
  const ActiveMaintenance({required this.id, required this.issue});
  final String id;
  final String issue;
}

class ActiveAssignment {
  const ActiveAssignment({
    required this.statusDisplay,
    required this.assignedDate,
    required this.expectedReturnDate,
    required this.employeeHidden,
    required this.employeeName,
    required this.employeeCode,
  });
  final String statusDisplay;
  final String assignedDate;
  final String? expectedReturnDate;
  final bool employeeHidden;
  final String? employeeName;
  final String? employeeCode;
}

class CatalogueAsset {
  const CatalogueAsset(this.raw);
  final Map<String, dynamic> raw;

  String get id => _s(raw['id']);
  String get assetTag => _s(raw['asset_tag']);
  String get assetName => _s(raw['asset_name']);
  String get category => _s(raw['category']);
  String get categoryOther => _s(raw['category_other']);
  String get assetType => _s(raw['asset_type']);
  String get assetTypeOther => _s(raw['asset_type_other']);
  String get branchName => _s(raw['branch_name']);
  String get status => _s(raw['status']);
  String get statusDisplay => _s(raw['status_display']);
  String get conditionDisplay => _s(raw['condition_display']);

  /// Web table: "Other (<name>)" for a custom category / type.
  String get categoryLabel => category == kAssetOther && categoryOther.isNotEmpty ? 'Other ($categoryOther)' : category;
  String get typeLabel => assetType == kAssetOther && assetTypeOther.isNotEmpty ? 'Other ($assetTypeOther)' : assetType;

  ActiveMaintenance? get activeMaintenance {
    final m = raw['active_maintenance'];
    return m is Map ? ActiveMaintenance(id: _s(m['id']), issue: _s(m['issue'])) : null;
  }

  ActiveAssignment? get activeAssignment {
    final a = raw['active_assignment'];
    if (a is! Map) return null;
    return ActiveAssignment(
      statusDisplay: _s(a['status_display']),
      assignedDate: _s(a['assigned_date']),
      expectedReturnDate: _n(a['expected_return_date']),
      employeeHidden: a['employee_hidden'] == true,
      employeeName: _n(a['employee_name']),
      employeeCode: _n(a['employee_code']),
    );
  }
}

/// Web lib/assetHolder.ts holderView.
sealed class HolderView {
  const HolderView();
}

class HolderAssigned extends HolderView {
  const HolderAssigned({
    required this.employee,
    required this.code,
    required this.hidden,
    required this.status,
    required this.assignedDate,
    required this.expectedReturn,
  });
  final String employee;
  final String? code;
  final bool hidden;
  final String status;
  final String assignedDate;
  final String? expectedReturn;
}

class HolderNone extends HolderView {
  const HolderNone(this.message);
  final String message;
}

HolderView holderView(CatalogueAsset asset) {
  final a = asset.activeAssignment;
  if (a != null) {
    final hidden = a.employeeHidden || a.employeeName == null;
    return HolderAssigned(
      employee: a.employeeHidden ? 'Not visible to you' : (a.employeeName ?? 'Employee details not available'),
      code: hidden ? null : a.employeeCode,
      hidden: hidden,
      status: a.statusDisplay.isNotEmpty ? a.statusDisplay : 'Assigned',
      assignedDate: a.assignedDate,
      expectedReturn: a.expectedReturnDate,
    );
  }
  if (asset.status == 'assigned') {
    return const HolderNone('Marked Assigned, but no active assignment record was found.');
  }
  return const HolderNone('Not currently assigned.');
}

class AssetPage {
  const AssetPage({required this.results, required this.page, required this.totalPages});
  final List<CatalogueAsset> results;
  final int page;
  final int totalPages;
}

class NamedOption {
  const NamedOption({required this.id, required this.name});
  final String id;
  final String name;
}

/// Web BLANK_FORM fields, in order.
const kAssetFormFields = [
  'asset_tag', 'asset_name', 'category', 'category_other', 'asset_type', 'asset_type_other', 'brand', 'model', //
  'serial_number', 'purchase_date', 'purchase_price', 'vendor', 'warranty_start_date', 'warranty_end_date', //
  'branch', 'condition', 'description',
];

Map<String, String> blankAssetForm() => {for (final f in kAssetFormFields) f: f == 'condition' ? 'new' : ''};

/// Web openEdit: the form from an asset row.
Map<String, String> assetFormFrom(CatalogueAsset a) => {
      for (final f in kAssetFormFields) f: _s(a.raw[f]),
    };

/// Web save(): the form, with blank dates / price / serial sent as null.
Map<String, dynamic> assetPayload(Map<String, String> form) => {
      ...form,
      'purchase_price': (form['purchase_price'] ?? '').isEmpty ? null : form['purchase_price'],
      'purchase_date': (form['purchase_date'] ?? '').isEmpty ? null : form['purchase_date'],
      'warranty_start_date': (form['warranty_start_date'] ?? '').isEmpty ? null : form['warranty_start_date'],
      'warranty_end_date': (form['warranty_end_date'] ?? '').isEmpty ? null : form['warranty_end_date'],
      'serial_number': (form['serial_number'] ?? '').isEmpty ? null : form['serial_number'],
    };

/// A refused request: the server's message and, for a save, its field errors.
class AssetRequestError implements Exception {
  const AssetRequestError(this.message, [this.fields = const {}]);
  final String message;
  final Map<String, String> fields;
}

AssetRequestError assetError(Object e, String fallback) {
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map) {
      final fields = <String, String>{};
      final data = body['data'];
      if (data is Map) {
        for (final entry in data.entries) {
          final v = entry.value;
          fields['${entry.key}'] = v is List ? (v.isEmpty ? '' : '${v.first}') : '$v';
        }
      }
      final msg = body['message'];
      return AssetRequestError(msg is String && msg.isNotEmpty ? msg : fallback, fields);
    }
  }
  return AssetRequestError(fallback);
}

class AssetCatalogueApi {
  AssetCatalogueApi(this._dio);
  final Dio _dio;

  static dynamic _data(dynamic body) => body is Map && body.containsKey('data') ? body['data'] : body;

  static List<Map<String, dynamic>> _rows(dynamic d) {
    final list = d is Map ? d['results'] : d;
    return [for (final r in (list is List ? list : const [])) if (r is Map) r.cast<String, dynamic>()];
  }

  Future<AssetPage> list({
    String search = '',
    String status = '',
    String category = '',
    String assetType = '',
    String branch = '',
    int page = 1,
  }) async {
    final res = await _dio.get(ApiConstants.assets, queryParameters: {
      if (search.isNotEmpty) 'search': search,
      if (status.isNotEmpty) 'status': status,
      if (category.isNotEmpty) 'category': category,
      if (assetType.isNotEmpty) 'asset_type': assetType,
      if (branch.isNotEmpty) 'branch': branch,
      'page': page,
      'page_size': 20,
    });
    final d = _data(res.data);
    return AssetPage(
      results: _rows(d).map(CatalogueAsset.new).toList(),
      page: (d is Map ? d['page'] as num? : null)?.toInt() ?? page,
      totalPages: (d is Map ? d['total_pages'] as num? : null)?.toInt() ?? 1,
    );
  }

  Future<CatalogueAsset> detail(String id) async =>
      CatalogueAsset((_data((await _dio.get(ApiConstants.assetDetail(id))).data) as Map).cast<String, dynamic>());

  Future<void> create(Map<String, dynamic> payload) => _dio.post(ApiConstants.assets, data: payload);
  Future<void> update(String id, Map<String, dynamic> payload) => _dio.put(ApiConstants.assetDetail(id), data: payload);
  Future<void> delete(String id) => _dio.delete(ApiConstants.assetDetail(id));

  Future<List<NamedOption>> categories() async => [
        for (final r in _rows(_data((await _dio.get(ApiConstants.assetCategories)).data)))
          NamedOption(id: _s(r['id']), name: _s(r['name'])),
      ];

  Future<List<NamedOption>> types(String? categoryId) async => [
        for (final r in _rows(_data((await _dio.get(ApiConstants.assetTypes, queryParameters: {
          if (categoryId != null && categoryId.isNotEmpty) 'category': categoryId,
        })).data)))
          NamedOption(id: _s(r['id']), name: _s(r['name'])),
      ];

  /// Returns the created name (web uses res.data.data.name).
  Future<String> addCategory(String name) async {
    final d = _data((await _dio.post(ApiConstants.assetCategories, data: {'name': name})).data);
    return d is Map ? _s(d['name']) : name;
  }

  Future<String> addType(String name, String categoryId) async {
    final d = _data((await _dio.post(ApiConstants.assetTypes, data: {'name': name, 'category': int.tryParse(categoryId) ?? categoryId})).data);
    return d is Map ? _s(d['name']) : name;
  }

  Future<List<NamedOption>> branches() async => [
        for (final r in _rows(_data((await _dio.get(ApiConstants.branches)).data)))
          NamedOption(id: _s(r['id']), name: _s(r['branch_name'])),
      ];

  /// POST multipart {file, dry_run=true for the preview} — web
  /// BulkImportAssetsModal / BulkAssignAssetsModal. Returns `data`.
  Future<Map<String, dynamic>> bulkUpload(String path, {required String fileName, required List<int> bytes, required bool dryRun}) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      if (dryRun) 'dry_run': 'true',
    });
    final d = _data((await _dio.post(path, data: form)).data);
    return d is Map ? d.cast<String, dynamic>() : <String, dynamic>{};
  }

  /// GET <sample>?format=csv|xlsx as bytes.
  Future<List<int>> sample(String path, String format) async {
    final res = await _dio.get<List<int>>(path,
        queryParameters: {'format': format}, options: Options(responseType: ResponseType.bytes));
    return res.data ?? const [];
  }

  Future<void> sendToMaintenance(String id, Map<String, dynamic> body) =>
      _dio.post(ApiConstants.assetSendToMaintenance(id), data: body);

  Future<void> completeMaintenance(String recordId, Map<String, dynamic> body) =>
      _dio.post(ApiConstants.assetCompleteMaintenance(recordId), data: body);
}

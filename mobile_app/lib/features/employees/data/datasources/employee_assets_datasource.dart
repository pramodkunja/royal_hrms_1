import 'package:dio/dio.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';

// Employee Profile → Assets, as web employees/[id]/_components/AssetsTab.tsx
// over backend apps/assets (views.EmployeeAssetsView / AssignAssetView /
// ReturnAssetView, serializers.AssetAssignmentSerializer /
// AssignAssetSerializer / ReturnAssetSerializer):
//  - GET  /assets/employees/<user uuid>/  → {current: [...], history: [...]}
//    (self always; others need assets.view and branch/manager scope, else
//    403 / 404).
//  - GET  /assets/?status=available&page_size=200 → paginated {results}
//    (assets.view; the server caps page_size at 100).
//  - POST /assets/employees/<user uuid>/assign/ {asset, assigned_date,
//    condition_at_assignment, expected_return_date|null, remarks}
//    (assets.edit; 409 when the asset was taken meanwhile; 400 with the
//    first field error, e.g. an expected return date before the assigned
//    date or an unavailable asset).
//  - POST /assets/assignments/<assignment uuid>/return/ {return_date,
//    return_condition, return_reason, remarks} (assets.edit; 400 e.g. a
//    return date before the assignment date; 404 when no longer active).

/// Web types/assets.ts ASSET_CONDITION_OPTIONS (= backend CONDITION_CHOICES).
const kAssetConditions = <(String, String)>[
  ('new', 'New'),
  ('good', 'Good'),
  ('fair', 'Fair'),
  ('damaged', 'Damaged'),
];

String _s(Object? v) => v == null ? '' : '$v';

/// One row of AssetAssignmentSerializer (read-only).
class AssetAssignment {
  const AssetAssignment({
    required this.id,
    required this.assetId,
    required this.assetTag,
    required this.assetName,
    required this.assetType,
    required this.serialNumber,
    required this.status,
    required this.statusDisplay,
    required this.assignedDate,
    required this.conditionAtAssignment,
    required this.expectedReturnDate,
    required this.returnDate,
    required this.returnCondition,
    required this.returnReason,
  });

  final String id;
  final String assetId;
  final String assetTag;
  final String assetName;
  final String assetType;
  final String serialNumber;
  final String status;
  final String statusDisplay;
  final String assignedDate;
  final String conditionAtAssignment;
  final String expectedReturnDate;
  final String returnDate;
  final String returnCondition;
  final String returnReason;

  factory AssetAssignment.fromJson(Map<String, dynamic> j) => AssetAssignment(
        id: _s(j['id']),
        assetId: _s(j['asset']),
        assetTag: _s(j['asset_tag']),
        assetName: _s(j['asset_name']),
        assetType: _s(j['asset_type']),
        serialNumber: _s(j['serial_number']),
        status: _s(j['status']),
        statusDisplay: _s(j['status_display']),
        assignedDate: _s(j['assigned_date']),
        conditionAtAssignment: _s(j['condition_at_assignment']),
        expectedReturnDate: _s(j['expected_return_date']),
        returnDate: _s(j['return_date']),
        returnCondition: _s(j['return_condition']),
        returnReason: _s(j['return_reason']),
      );
}

/// {current, history} from GET /assets/employees/<uuid>/.
class EmployeeAssets {
  const EmployeeAssets({required this.current, required this.history});
  final List<AssetAssignment> current;
  final List<AssetAssignment> history;

  static List<AssetAssignment> _rows(Object? v) => [
        for (final r in (v is List ? v : const []))
          if (r is Map<String, dynamic>) AssetAssignment.fromJson(r),
      ];

  factory EmployeeAssets.fromResponse(Object? body) {
    final data = body is Map && body['data'] is Map ? body['data'] as Map : const {};
    return EmployeeAssets(current: _rows(data['current']), history: _rows(data['history']));
  }
}

/// An asset offered in the Assign picker (web "<tag> — <name>").
class AvailableAsset {
  const AvailableAsset({required this.id, required this.assetTag, required this.assetName});
  final String id;
  final String assetTag;
  final String assetName;
  String get label => '$assetTag — $assetName';
}

class EmployeeAssetsDataSource {
  EmployeeAssetsDataSource(this._dio);
  final Dio _dio;

  Future<T> _guard<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on DioException catch (e) {
      throw parseDioException(e);
    }
  }

  Future<EmployeeAssets> fetch(String employeeUuid) => _guard(() async {
        final res = await _dio.get(ApiConstants.employeeAssets(employeeUuid));
        return EmployeeAssets.fromResponse(res.data);
      });

  /// Web openAssign: a failed load just offers no assets.
  Future<List<AvailableAsset>> fetchAvailable() async {
    try {
      final res = await _dio.get(ApiConstants.assets, queryParameters: {'status': 'available', 'page_size': 200});
      final body = res.data;
      final data = body is Map ? body['data'] : null;
      final results = data is Map ? data['results'] : null;
      return [
        for (final a in (results is List ? results : const []))
          if (a is Map && a['id'] != null)
            AvailableAsset(id: _s(a['id']), assetTag: _s(a['asset_tag']), assetName: _s(a['asset_name'])),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> assign(
    String employeeUuid, {
    required String assetId,
    required String assignedDate,
    required String condition,
    required String expectedReturnDate,
    required String remarks,
  }) =>
      _guard(() => _dio.post(ApiConstants.employeeAssetAssign(employeeUuid), data: {
            'asset': assetId,
            'assigned_date': assignedDate,
            'condition_at_assignment': condition,
            // Web: `expected_return_date || null`.
            'expected_return_date': expectedReturnDate.isEmpty ? null : expectedReturnDate,
            'remarks': remarks,
          }));

  Future<void> returnAsset(
    String assignmentId, {
    required String returnDate,
    required String condition,
    required String reason,
    required String remarks,
  }) =>
      _guard(() => _dio.post(ApiConstants.assetReturn(assignmentId), data: {
            'return_date': returnDate,
            'return_condition': condition,
            'return_reason': reason,
            'remarks': remarks,
          }));
}

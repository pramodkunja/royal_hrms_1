import 'package:flutter/foundation.dart';
import '../../domain/entities/branch_entity.dart';

@immutable
class StateModel extends StateEntity {
  const StateModel({
    required super.id,
    required super.name,
    required super.code,
  });

  factory StateModel.fromJson(Map<String, dynamic> json) => StateModel(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        code: json['code'] as String? ?? '',
      );
}

@immutable
class CityModel extends CityEntity {
  const CityModel({
    required super.id,
    required super.name,
    required super.stateId,
    required super.stateName,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) => CityModel(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        stateId: json['state'] as int? ?? 0,
        stateName: json['state_name'] as String? ?? '',
      );
}

@immutable
class BranchModel extends BranchEntity {
  const BranchModel({
    required super.id,
    required super.branchCode,
    required super.branchName,
    required super.address,
    required super.stateId,
    required super.stateName,
    required super.cityId,
    required super.cityName,
    super.hrName,
    super.hrEmail,
    required super.employeesCount,
    required super.status,
    required super.isHeadquarter,
    super.latitude,
    super.longitude,
    super.allowedRadiusMeters,
    super.geofencingEnabled,
    super.hasCoordinates,
    super.createdAt,
    super.updatedAt,
  });

  factory BranchModel.fromJson(Map<String, dynamic> json) => BranchModel(
        id: json['id'] as int,
        branchCode: json['branch_code'] as String? ?? '',
        branchName: json['branch_name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        stateId: json['state'] as int? ?? 0,
        stateName: json['state_name'] as String? ?? '',
        cityId: json['city'] as int? ?? 0,
        cityName: json['city_name'] as String? ?? '',
        hrName: json['hr_name'] as String?,
        hrEmail: json['hr_email'] as String?,
        employeesCount: json['employees_count'] as int? ?? 0,
        status: json['status'] as String? ?? 'active',
        isHeadquarter: json['is_headquarter'] as bool? ?? false,
        latitude: _parseDouble(json['latitude']),
        longitude: _parseDouble(json['longitude']),
        // Backend default (PositiveIntegerField default=150).
        allowedRadiusMeters: (json['allowed_radius_meters'] as num?)?.toInt() ?? 150,
        geofencingEnabled: json['geofencing_enabled'] as bool? ?? false,
        hasCoordinates: json['has_coordinates'] as bool? ?? false,
        createdAt: _parseDate(json['created_at']),
        updatedAt: _parseDate(json['updated_at']),
      );

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }
}

@immutable
class BranchDistributionModel extends BranchDistributionEntity {
  const BranchDistributionModel({
    required super.branch,
    required super.branchCode,
    required super.employees,
  });

  factory BranchDistributionModel.fromJson(Map<String, dynamic> json) =>
      BranchDistributionModel(
        branch: json['branch'] as String? ?? '',
        branchCode: json['branch_code'] as String? ?? '',
        employees: json['employees'] as int? ?? 0,
      );
}

@immutable
class BranchStatsModel extends BranchStatsEntity {
  const BranchStatsModel({
    required super.totalBranches,
    required super.totalActiveBranches,
    required super.totalInactiveBranches,
    required super.totalCities,
    required super.totalEmployees,
  });

  factory BranchStatsModel.fromJson(Map<String, dynamic> json) =>
      BranchStatsModel(
        totalBranches: json['total_branches'] as int? ?? 0,
        totalActiveBranches: json['total_active_branches'] as int? ?? 0,
        totalInactiveBranches: json['total_inactive_branches'] as int? ?? 0,
        totalCities: json['total_cities'] as int? ?? 0,
        totalEmployees: json['total_employees'] as int? ?? 0,
      );
}

/// An employee offered in "Change Branch Admin" (web ApiEmployeeOption from
/// GET /employees/: `id` is the employee **code**, which is what
/// reassign-admin expects as `employee_id`).
class BranchAdminCandidate {
  const BranchAdminCandidate({
    required this.code,
    required this.fullName,
    required this.email,
    required this.employeeId,
    required this.branch,
    required this.role,
  });

  final String code;
  final String fullName;
  final String email;
  final String employeeId;
  final String branch;
  final String role;

  factory BranchAdminCandidate.fromJson(Map<String, dynamic> j) {
    String s(String k) => j[k]?.toString() ?? '';
    final employeeId = s('employee_id');
    return BranchAdminCandidate(
      code: s('id').isNotEmpty ? s('id') : employeeId,
      fullName: s('full_name'),
      email: s('email'),
      employeeId: employeeId,
      branch: s('branch'),
      role: s('role'),
    );
  }

  /// Web: "<name> (<employee ID>) — <branch or 'no branch'>".
  String get label => '$fullName ($employeeId) — ${branch.isEmpty ? 'no branch' : branch}';

  /// Web search: name, email or employee ID, case-insensitive.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    return q.isEmpty ||
        fullName.toLowerCase().contains(q) ||
        email.toLowerCase().contains(q) ||
        employeeId.toLowerCase().contains(q);
  }
}

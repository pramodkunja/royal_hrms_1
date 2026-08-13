import 'package:flutter/foundation.dart';

@immutable
class StateEntity {
  final int id;
  final String name;
  final String code;

  const StateEntity({
    required this.id,
    required this.name,
    required this.code,
  });
}

@immutable
class CityEntity {
  final int id;
  final String name;
  final int stateId;
  final String stateName;

  const CityEntity({
    required this.id,
    required this.name,
    required this.stateId,
    required this.stateName,
  });
}

@immutable
class BranchEntity {
  final int id;
  final String branchCode;
  final String branchName;
  final String address;
  final int stateId;
  final String stateName;
  final int cityId;
  final String cityName;
  final String? hrName;
  final int employeesCount;
  final String status; // 'active' | 'inactive'
  final bool isHeadquarter;
  final double? latitude;
  final double? longitude;
  final int allowedRadiusMeters;
  final bool geofencingEnabled;
  final bool hasCoordinates;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const BranchEntity({
    required this.id,
    required this.branchCode,
    required this.branchName,
    required this.address,
    required this.stateId,
    required this.stateName,
    required this.cityId,
    required this.cityName,
    this.hrName,
    required this.employeesCount,
    required this.status,
    required this.isHeadquarter,
    this.latitude,
    this.longitude,
    this.allowedRadiusMeters = 0,
    this.geofencingEnabled = false,
    this.hasCoordinates = false,
    this.createdAt,
    this.updatedAt,
  });

  bool get isActive => status == 'active';

  bool get hasHr => hrName != null && hrName!.trim().isNotEmpty;

  String get employeesLabel =>
      employeesCount == 1 ? '1 Employee' : '$employeesCount Employees';
}

@immutable
class BranchDistributionEntity {
  final String branch;
  final String branchCode;
  final int employees;

  const BranchDistributionEntity({
    required this.branch,
    required this.branchCode,
    required this.employees,
  });
}

@immutable
class BranchStatsEntity {
  final int totalBranches;
  final int totalActiveBranches;
  final int totalInactiveBranches;
  final int totalCities;
  final int totalEmployees;

  const BranchStatsEntity({
    required this.totalBranches,
    required this.totalActiveBranches,
    required this.totalInactiveBranches,
    required this.totalCities,
    required this.totalEmployees,
  });
}

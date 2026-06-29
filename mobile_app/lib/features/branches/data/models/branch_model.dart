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
    required super.employeesCount,
    required super.status,
    required super.isHeadquarter,
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
        employeesCount: json['employees_count'] as int? ?? 0,
        status: json['status'] as String? ?? 'active',
        isHeadquarter: json['is_headquarter'] as bool? ?? false,
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

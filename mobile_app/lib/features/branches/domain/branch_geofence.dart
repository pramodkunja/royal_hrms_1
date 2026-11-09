import 'entities/branch_entity.dart';

/// Branch geofencing as the web Add/Edit Branch form sends it
/// (BranchManagement.tsx doSave), inside the branch POST/PATCH payload:
///  - enabled → latitude / longitude (degrees) and allowed_radius_meters;
///  - disabled → latitude null, longitude null, allowed_radius_meters 150
///    (the column is non-nullable, default 150). Turning geofencing off
///    therefore clears the saved coordinates, as on web.
/// Backend (BranchSerializer): enabling needs coordinates (request or saved);
/// coordinates are DecimalField(12, 8) — returned as strings like
/// "19.07600000" and rejected beyond 8 decimal places.
class BranchGeofence {
  const BranchGeofence({required this.enabled, this.latitude, this.longitude, this.radiusMeters = kDefaultRadius});

  static const kDefaultRadius = 150;
  static const kMinRadius = 10;
  static const kMaxRadius = 5000;

  final bool enabled;
  final double? latitude;
  final double? longitude;
  final num radiusMeters;

  const BranchGeofence.disabled() : this(enabled: false);

  Map<String, dynamic> toPayload() => {
        'geofencing_enabled': enabled,
        'latitude': enabled ? latitude : null,
        'longitude': enabled ? longitude : null,
        'allowed_radius_meters': enabled ? radiusMeters : kDefaultRadius,
      };
}

/// Field errors keyed latitude / longitude / allowed_radius_meters, or the
/// parsed value when valid — web BranchManagement validate() messages.
({Map<String, String> errors, BranchGeofence? value}) validateBranchGeofence({
  required bool enabled,
  required String latitude,
  required String longitude,
  required String radius,
}) {
  if (!enabled) return (errors: const {}, value: const BranchGeofence.disabled());
  final errors = <String, String>{};
  final lat = latitude.trim();
  final lon = longitude.trim();
  if (lat.isEmpty && lon.isEmpty) {
    errors['latitude'] = 'Latitude and longitude are required to enable geofencing.';
  } else if (lat.isEmpty || lon.isEmpty) {
    if (lat.isEmpty) errors['latitude'] = 'Both latitude and longitude must be provided together.';
    if (lon.isEmpty) errors['longitude'] = 'Both latitude and longitude must be provided together.';
  } else {
    if (double.tryParse(lat) == null) errors['latitude'] = 'Latitude must be a valid number.';
    if (double.tryParse(lon) == null) errors['longitude'] = 'Longitude must be a valid number.';
  }
  final r = radius.trim();
  final rNum = num.tryParse(r);
  if (r.isEmpty) {
    errors['allowed_radius_meters'] = 'Allowed radius is required.';
  } else if (rNum == null || rNum < BranchGeofence.kMinRadius || rNum > BranchGeofence.kMaxRadius) {
    errors['allowed_radius_meters'] = 'Allowed radius must be between 10 and 5000 metres.';
  }
  if (errors.isNotEmpty) return (errors: errors, value: null);
  return (
    errors: const {},
    value: BranchGeofence(
      enabled: true,
      latitude: double.parse(lat),
      longitude: double.parse(lon),
      // A whole number is sent as an int (PositiveIntegerField); a fraction
      // is sent as typed and the server rejects it, as on web.
      radiusMeters: rNum! == rNum.roundToDouble() ? rNum.toInt() : rNum,
    ),
  );
}

/// Web geofenceBadge: Disabled / No Coordinates / Active.
String geofenceStatusLabel(BranchEntity b) {
  if (!b.geofencingEnabled) return 'Disabled';
  if (!b.hasCoordinates) return 'No Coordinates';
  return 'Active';
}

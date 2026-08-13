const _kMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Formats an API timestamp for humans, e.g. "04 Aug 2026, 04:42 PM".
/// Never surfaces a raw ISO string or "null".
String formatBranchDateTime(DateTime? dt) {
  if (dt == null) return 'Not available';
  final local = dt.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = _kMonthNames[local.month - 1];
  final hour24 = local.hour;
  final period = hour24 >= 12 ? 'PM' : 'AM';
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day $month ${local.year}, ${hour12.toString().padLeft(2, '0')}:$minute $period';
}

/// "17.462548, 78.369564" or a safe fallback when coordinates aren't set.
String formatBranchCoordinates({
  required bool hasCoordinates,
  double? latitude,
  double? longitude,
}) {
  if (!hasCoordinates || latitude == null || longitude == null) {
    return 'Coordinates not configured';
  }
  return '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

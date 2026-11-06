import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/attendance_entity.dart';

// Web AttendanceDetailDrawer.tsx, "Punch History & Location": a Clock In
// Location and a Clock Out Location block, shown when either punch has a
// latitude. Each block, when it has both coordinates: the place
// (location_display ?? location_label, else "Location name unavailable"),
// the GPS accuracy line (not for office punches), Latitude / Longitude to 8
// decimals and "View on map"; otherwise "—". Accuracy is display guidance
// only — nothing here affects attendance.

/// Opens a map for the coordinates (tests replace it).
typedef MapOpener = Future<void> Function(Uri uri);

Future<void> _openExternally(Uri uri) async {
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class PunchLocationSection extends StatelessWidget {
  const PunchLocationSection({super.key, required this.clockIn, required this.clockOut, this.openMap});

  final PunchLocationEntity? clockIn;
  final PunchLocationEntity? clockOut;
  final MapOpener? openMap;

  @override
  Widget build(BuildContext context) {
    // Web: data.clock_in_latitude !== null || data.clock_out_latitude !== null
    if (clockIn?.latitude == null && clockOut?.latitude == null) return const SizedBox.shrink();
    return Column(
      key: const Key('punch-location-section'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        _PunchLocationBlock(
          key: const Key('punch-location-in'),
          title: 'Clock In Location',
          location: clockIn,
          openMap: openMap ?? _openExternally,
        ),
        const SizedBox(height: 10),
        _PunchLocationBlock(
          key: const Key('punch-location-out'),
          title: 'Clock Out Location',
          location: clockOut,
          openMap: openMap ?? _openExternally,
        ),
      ],
    );
  }
}

class _PunchLocationBlock extends StatelessWidget {
  const _PunchLocationBlock({super.key, required this.title, required this.location, required this.openMap});

  final String title;
  final PunchLocationEntity? location;
  final MapOpener openMap;

  @override
  Widget build(BuildContext context) {
    final loc = location;
    final mono = TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textPrimary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        if (loc == null || !loc.hasCoordinates)
          Text('—', style: AppTextStyles.bodySmall.copyWith(fontSize: 12, color: AppColors.textSecondary))
        else ...[
          if (loc.placeName != null)
            Text(loc.placeName!,
                style: AppTextStyles.bodySmall
                    .copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))
          else
            Text('Location name unavailable',
                style: AppTextStyles.bodySmall
                    .copyWith(fontSize: 13, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
          if (!loc.isOffice) GpsAccuracyLine(text: loc.accuracyText, level: loc.accuracyLevel),
          Text('Latitude: ${loc.latitude!.toStringAsFixed(8)}', style: mono),
          Text('Longitude: ${loc.longitude!.toStringAsFixed(8)}', style: mono),
          InkWell(
            onTap: () => openMap(Uri.parse('https://www.google.com/maps?q=${loc.latitude},${loc.longitude}')),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.place_outlined, size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text('View on map', style: TextStyle(fontSize: 11, color: AppColors.primary)),
              ]),
            ),
          ),
        ],
      ],
    );
  }
}

/// Web GpsAccuracyLine: "GPS accuracy: <text | unknown>", with " — location
/// approximate" (amber) or " — location very approximate" (red). The warning
/// icon shows for any level other than none or precise — an unrecognised
/// level gets it too, in the neutral colour and with no suffix, as on web.
class GpsAccuracyLine extends StatelessWidget {
  const GpsAccuracyLine({super.key, required this.text, required this.level});

  final String? text;
  final GpsAccuracyLevel? level;

  @override
  Widget build(BuildContext context) {
    final color = switch (level) {
      GpsAccuracyLevel.veryApproximate => AppColors.error,
      GpsAccuracyLevel.approximate => AppColors.warning,
      _ => AppColors.textSecondary,
    };
    final suffix = switch (level) {
      GpsAccuracyLevel.approximate => ' — location approximate',
      GpsAccuracyLevel.veryApproximate => ' — location very approximate',
      _ => '',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (level != null && level != GpsAccuracyLevel.precise) ...[
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.warning_amber_rounded, key: const Key('gps-accuracy-warning'), size: 12, color: color),
            ),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text('GPS accuracy: ${text ?? 'unknown'}$suffix',
                key: const Key('gps-accuracy-line'), style: TextStyle(fontSize: 11, color: color)),
          ),
        ],
      ),
    );
  }
}

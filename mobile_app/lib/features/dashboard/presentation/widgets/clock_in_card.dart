import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_app/core/location/location_service.dart';
import 'package:mobile_app/core/theme/app_colors.dart';
import 'package:mobile_app/core/utils/device_identifier.dart';
import 'package:mobile_app/core/theme/app_text_styles.dart';
import 'package:mobile_app/features/attendance/domain/entities/attendance_entity.dart';
import 'package:mobile_app/features/attendance/presentation/providers/attendance_providers.dart';
import 'dashboard_section.dart';

/// Today's Attendance / Clock In-Out card — shared by the Employee and HR
/// dashboards (web embeds the same `<ClockInButton />`/`HrAttendanceCard` on
/// both; Admin and Manager dashboards don't show it). Extracted out of
/// `home_screen.dart` so both role dashboards use one real implementation
/// instead of duplicating the punch/location logic.
class ClockInCard extends ConsumerStatefulWidget {
  const ClockInCard({super.key});

  @override
  ConsumerState<ClockInCard> createState() => _ClockInCardState();
}

class _ClockInCardState extends ConsumerState<ClockInCard> {
  bool _punching = false;

  Future<void> _toggleClock(TodayAttendanceEntity today) async {
    if (_punching) return;
    setState(() => _punching = true);

    final position =
        await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;

    final error = await ref.read(todayAttendanceProvider.notifier).punch(
          isCurrentlyClockedIn: today.isClockedIn,
          attendanceMode: 'office',
          latitude: position?.latitude,
          longitude: position?.longitude,
          accuracy: position?.accuracy,
          deviceName: kIsWeb
              ? 'Web'
              : Platform.isAndroid
                  ? 'Android'
                  : Platform.isIOS
                      ? 'iOS'
                      : null,
          operatingSystem: kIsWeb ? 'web' : Platform.operatingSystem,
          deviceId: await ref.read(deviceIdProvider.future),
        );

    if (!mounted) return;
    setState(() => _punching = false);

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayAsync = ref.watch(todayAttendanceProvider);

    return SectionCard(
      title: "Today's Attendance",
      icon: Icons.access_time_outlined,
      accentColor: const Color(0xFF1B8A6B),
      child: todayAsync.when(
        data: (today) {
          final lastPunch = today.punches.isEmpty ? null : today.punches.last;
          return Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (today.isClockedIn
                          ? AppColors.success
                          : AppColors.textHint)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  today.isClockedIn
                      ? Icons.timer_outlined
                      : Icons.timer_off_outlined,
                  color: today.isClockedIn
                      ? AppColors.success
                      : AppColors.textHint,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today.isClockedIn ? 'Clocked In' : 'Clocked Out',
                      style: AppTextStyles.body
                          .copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lastPunch == null
                          ? today.dateDisplay
                          : 'Last punch: ${lastPunch.type} at ${lastPunch.time}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: ElevatedButton(
                  onPressed: _punching ? null : () => _toggleClock(today),
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        today.isClockedIn ? AppColors.error : AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _punching
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(
                          today.isClockedIn ? 'Clock Out' : 'Clock In',
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          );
        },
        loading: () => const SectionMessage(
          icon: Icons.timer_outlined,
          label: 'Loading…',
        ),
        error: (e, _) => SectionError(
          message: friendlyAttendanceError(e),
          onRetry: () => ref.invalidate(todayAttendanceProvider),
        ),
      ),
    );
  }
}

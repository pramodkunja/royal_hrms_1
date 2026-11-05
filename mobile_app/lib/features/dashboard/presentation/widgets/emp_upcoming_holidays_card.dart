import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/upcoming_holidays.dart';
import '../providers/dashboard_providers.dart';
import 'dashboard_section.dart';

/// Web EmpUpcomingHolidays: "Upcoming Holidays", up to three active
/// holidays from today on — a purple day/month tile, the name, "<day> ·
/// <type>" and a "Today" / "In Nd" badge — or "No upcoming holidays
/// scheduled." No "View all" link (web has none). A failed load shows the
/// dashboard's usual error with Retry (web falls back to the empty text).
class EmpUpcomingHolidaysCard extends ConsumerWidget {
  const EmpUpcomingHolidaysCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final holidaysAsync = ref.watch(employeeHolidaysProvider);
    final dates = ref.watch(upcomingHolidayDatesProvider);

    return SectionCard(
      key: const Key('emp-upcoming-holidays'),
      title: 'Upcoming Holidays',
      icon: Icons.event_outlined,
      accentColor: AppColors.accentPurple,
      child: holidaysAsync.when(
        data: (all) {
          final upcoming = upcomingHolidays(all, dates);
          if (upcoming.isEmpty) {
            return const SectionMessage(icon: Icons.event_outlined, label: 'No upcoming holidays scheduled.');
          }
          return Column(
            children: [
              for (var i = 0; i < upcoming.length; i++)
                _HolidayRow(holiday: upcoming[i], localDate: dates.localDate, last: i == upcoming.length - 1),
            ],
          );
        },
        loading: () => const SectionMessage(icon: Icons.event_outlined, label: 'Loading…'),
        error: (e, _) => SectionError(
          message: friendlyDashboardError(e),
          onRetry: () => ref.invalidate(employeeHolidaysProvider),
        ),
      ),
    );
  }
}

class _HolidayRow extends StatelessWidget {
  const _HolidayRow({required this.holiday, required this.localDate, required this.last});
  final DashboardHoliday holiday;
  final DateTime localDate;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final h = holiday;
    final subtitle = h.subtitle;
    return Container(
      key: Key('upcoming-holiday-${h.date.toIso8601String().substring(0, 10)}-${h.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(color: AppColors.accentPurpleContainer, borderRadius: BorderRadius.circular(8)),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(h.dayOfMonth,
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1, color: AppColors.accentPurple)),
                Text(h.monthShort, style: TextStyle(fontSize: 9, color: AppColors.accentPurple)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(h.name.isEmpty ? 'Holiday' : h.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textPrimary)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(999)),
            child: Text(h.badge(localDate),
                style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

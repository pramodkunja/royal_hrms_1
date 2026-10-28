import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/separation_providers.dart';
import 'separation_status.dart';

/// Audit-trail feed — `message` is the fully-formatted sentence the backend
/// already built (e.g. "Manager Approval approved by Ravi Kumar."), rendered
/// as-is per SeparationActivitySerializer's doc comment. Newest first.
class SeparationActivitySection extends ConsumerWidget {
  final String requestId;
  const SeparationActivitySection({super.key, required this.requestId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(separationActivitiesProvider(requestId));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SeparationSectionHeader(title: 'Activity'),
          activityAsync.when(
            data: (items) => items.isEmpty
                ? Text('No activity recorded yet.',
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.textHint))
                : Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(height: 10),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(top: 5),
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(items[i].message,
                                      style: AppTextStyles.body.copyWith(fontSize: 13)),
                                  Text(
                                    [
                                      items[i].actorName,
                                      formatSeparationDate(items[i].createdAt),
                                    ].where((s) => s.isNotEmpty).join(' · '),
                                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (_, __) => Text('Could not load activity.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

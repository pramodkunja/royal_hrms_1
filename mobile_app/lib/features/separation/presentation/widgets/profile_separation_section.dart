import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/separation_providers.dart';
import 'separation_form_sheet.dart';
import 'separation_status.dart';

// Self-service filter — the viewer's own requests, newest first (backend
// default ordering), matches web's ProfileClient SeparationCard.
const _kOwnFilter = (scope: '', status: '');

/// Self-service "Separation" card on the employee's own Profile page —
/// mirrors web's app/dashboard/profile/_components/SeparationCard.tsx. Shows
/// either a prompt to file a request, or a summary of the most recent
/// still-active one (pending/stage2_pending/approved — a rejected/cancelled
/// past request doesn't block filing a new one, matching the backend's own
/// _ACTIVE_STATUSES uniqueness check in SeparationRequestListCreateView.post).
class ProfileSeparationSection extends ConsumerWidget {
  const ProfileSeparationSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(separationListProvider(_kOwnFilter));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SeparationSectionHeader(title: 'Separation'),
          listAsync.when(
            data: (state) {
              final activeList =
                  state.items.where((r) => r.isPending || r.isApproved);
              final active = activeList.isEmpty ? null : activeList.first;
              if (active == null) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("You don't have an active separation request.",
                        style: AppTextStyles.bodySecondary),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Create Separation Request',
                      variant: AppButtonVariant.outline,
                      leadingIcon: Icons.logout_outlined,
                      onPressed: () => showSeparationFormSheet(context),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(active.separationTypeDisplay,
                                style: AppTextStyles.label.copyWith(fontSize: 13)),
                            Text(
                              'Requested ${formatSeparationDate(active.requestDate)} · '
                              'LWD ${formatSeparationDate(active.proposedLastWorkingDay)}',
                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      SeparationStatusChip(
                          status: active.status, label: active.statusDisplay),
                    ],
                  ),
                  const SizedBox(height: 12),
                  AppButton(
                    label: 'View Request',
                    variant: AppButtonVariant.outline,
                    onPressed: () => context.push(
                      AppRoutes.separationDetailPath(active.id),
                      extra: active,
                    ),
                  ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (_, __) => Text('Could not load separation status.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

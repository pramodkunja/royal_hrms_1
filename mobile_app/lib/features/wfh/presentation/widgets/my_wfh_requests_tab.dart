import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../domain/entities/wfh_entity.dart';
import '../providers/wfh_providers.dart';
import 'wfh_request_detail_sheet.dart';
import 'wfh_status_chip.dart';

String _fmtIso(String iso) {
  if (iso.isEmpty) return '—';
  try {
    final d = DateTime.parse(iso);
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${m[d.month]}';
  } catch (_) {
    return iso;
  }
}

class MyWfhRequestsTab extends ConsumerStatefulWidget {
  const MyWfhRequestsTab({super.key});

  @override
  ConsumerState<MyWfhRequestsTab> createState() => _MyWfhRequestsTabState();
}

class _MyWfhRequestsTabState extends ConsumerState<MyWfhRequestsTab> {
  bool _cancelling = false;

  Future<void> _cancel(String id) async {
    setState(() => _cancelling = true);
    final err = await ref.read(wfhMyRequestsProvider.notifier).cancelRequest(id);
    if (!mounted) return;
    setState(() => _cancelling = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestsAsync = ref.watch(wfhMyRequestsProvider);

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(wfhMyRequestsProvider.notifier).refresh(),
      child: requestsAsync.isLoading
          ? const Center(child: CircularProgressIndicator())
          : requestsAsync.hasError
              ? AppErrorState(
                  message: friendlyWfhError(requestsAsync.error!),
                  padding: const EdgeInsets.all(32),
                  onRetry: () => ref.invalidate(wfhMyRequestsProvider),
                )
              : (requestsAsync.valueOrNull ?? const []).isEmpty
                  ? ListView(
                      children: const [
                        AppEmptyState(
                          icon: Icons.home_work_outlined,
                          title: 'No WFH requests yet',
                          message:
                              'Use the Request tab to apply for work from home.',
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                      itemCount: requestsAsync.value!.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final r = requestsAsync.value![i];
                        return GestureDetector(
                          onTap: () => showWfhRequestDetailSheet(ctx, initial: r),
                          child: _MyRequestCard(
                            request: r,
                            cancelling: _cancelling,
                            onCancel: () => _cancel(r.id),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _MyRequestCard extends StatelessWidget {
  final WfhRequestEntity request;
  final bool cancelling;
  final VoidCallback onCancel;

  const _MyRequestCard({
    required this.request,
    required this.cancelling,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final sc = wfhStatusColor(request.status);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(height: 3, color: sc),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_month_outlined,
                        size: 13, color: AppColors.textHint),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        '${_fmtIso(request.startDate)} – ${_fmtIso(request.endDate)}',
                        style: AppTextStyles.label.copyWith(fontSize: 13),
                      ),
                    ),
                    WfhStatusChip(status: request.status),
                  ],
                ),
                if (request.locationLabel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.place_outlined, size: 12, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Text(request.locationLabel,
                          style: AppTextStyles.caption.copyWith(fontSize: 11)),
                    ],
                  ),
                ],
                if (request.reason.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(request.reason,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
                if (request.canCancel) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: cancelling ? null : onCancel,
                      icon: const Icon(Icons.cancel_outlined, size: 14),
                      label: const Text('Cancel Request',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

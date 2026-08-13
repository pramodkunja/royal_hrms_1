import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../facial_recognition/domain/entities/face_registration_entity.dart';
import '../../../facial_recognition/presentation/providers/facial_recognition_providers.dart';
import '../../../facial_recognition/presentation/widgets/face_status_badge.dart';

const _kMonthShort = [
  '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];
String _fmtDate(DateTime d) => '${d.day} ${_kMonthShort[d.month]} ${d.year}';
String _fmtScore(double? score) => score == null ? '—' : '${(score * 100).round()}%';

/// Ports web's app/dashboard/approvals/_components/FaceRegistrationApprovalsTab.tsx
/// — the pending Face ID self-submission queue (distinct from HR-assisted
/// registration, which is auto-approved and never appears here).
class FaceRegistrationApprovalsTab extends ConsumerWidget {
  const FaceRegistrationApprovalsTab({super.key});

  Future<void> _review(BuildContext context, WidgetRef ref, String id, bool approve) async {
    try {
      await ref.read(facialRecognitionRepositoryProvider).reviewRegistration(id: id, approve: approve);
      ref.invalidate(facePendingRegistrationsProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not review request: $e'), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(facePendingRegistrationsProvider);
    final page = ref.watch(facePendingRegistrationsPageProvider);

    return pendingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: '$e',
        onRetry: () => ref.invalidate(facePendingRegistrationsProvider),
      ),
      data: (result) {
        final rows = result.results;
        if (rows.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(facePendingRegistrationsProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 40),
                Icon(Icons.face_outlined, size: 44, color: AppColors.textHint),
                const SizedBox(height: 12),
                Text(
                  page > 1 ? 'No more requests on this page.' : 'No pending face registration requests.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(facePendingRegistrationsProvider),
          child: ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: rows.length + (result.totalPages > 1 ? 1 : 0),
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              if (index >= rows.length) {
                return _Pager(
                  page: result.page,
                  totalPages: result.totalPages,
                  onPrev: () => ref.read(facePendingRegistrationsPageProvider.notifier).state = result.page - 1,
                  onNext: () => ref.read(facePendingRegistrationsPageProvider.notifier).state = result.page + 1,
                );
              }
              return _PendingRow(
                row: rows[index],
                onApprove: () => _review(context, ref, rows[index].id, true),
                onReject: () => _review(context, ref, rows[index].id, false),
              );
            },
          ),
        );
      },
    );
  }
}

/// Matches web's page/page_size=20 Prev/Next pager exactly (not infinite
/// scroll) — see FaceRegistrationApprovalsTab.tsx.
class _Pager extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  const _Pager({required this.page, required this.totalPages, required this.onPrev, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Page $page of $totalPages', style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
          Row(
            children: [
              TextButton.icon(
                onPressed: page > 1 ? onPrev : null,
                icon: const Icon(Icons.chevron_left, size: 16),
                label: const Text('Prev'),
              ),
              TextButton.icon(
                onPressed: page < totalPages ? onNext : null,
                icon: const Icon(Icons.chevron_right, size: 16),
                label: const Text('Next'),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PendingRow extends StatefulWidget {
  final FaceRegistrationEntity row;
  final Future<void> Function() onApprove;
  final Future<void> Function() onReject;

  const _PendingRow({required this.row, required this.onApprove, required this.onReject});

  @override
  State<_PendingRow> createState() => _PendingRowState();
}

class _PendingRowState extends State<_PendingRow> {
  bool _busy = false;

  Future<void> _handle(Future<void> Function() action) async {
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaceInitialsAvatar(name: row.employeeName, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.employeeName, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                    Text(row.employeeEmail, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _badge(
                row.livenessPassed ? 'Liveness passed' : 'Liveness failed',
                row.livenessPassed ? AppColors.success : AppColors.error,
              ),
              _badge('Score ${_fmtScore(row.livenessScore)}', AppColors.textSecondary),
              _badge('Submitted ${_fmtDate(row.createdAt)}', AppColors.textSecondary),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _handle(widget.onReject),
                  icon: const Icon(Icons.close, size: 16, color: Colors.red),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _handle(widget.onApprove),
                  icon: _busy
                      ? const SizedBox(
                          width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 16),
                  label: const Text('Approve'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10.5, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, style: AppTextStyles.body, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

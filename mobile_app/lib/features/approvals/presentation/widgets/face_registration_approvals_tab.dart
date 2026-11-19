import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/formatters/en_in_format.dart';
import '../../../facial_recognition/domain/entities/face_registration_entity.dart';
import '../../../facial_recognition/presentation/providers/facial_recognition_providers.dart';
import 'approvals_kit.dart';
import 'approvals_ui.dart';

// Web fmtDate: { day: "2-digit", month: "short", year: "numeric" }, "—" if empty.
String _fmtDate(DateTime d) => formatEnInDate(d.toLocal(), padDay: true);
String _fmtScore(double? score) => score == null ? '—' : '${(score * 100).round()}%';

const _kForbiddenMessage = "You don't have permission to review face registration requests.";

bool _isForbidden(Object e) => e is DioException && e.response?.statusCode == 403;

/// Web: response.data.message, else "Failed to review request.".
String _reviewError(Object e) {
  if (e is DioException) {
    final body = e.response?.data;
    final m = body is Map ? body['message'] : null;
    if (m is String && m.trim().isNotEmpty) return m;
  }
  return 'Failed to review request.';
}

/// Ports web's app/dashboard/approvals/_components/FaceRegistrationApprovalsTab.tsx
/// — the pending Face ID self-submission queue (distinct from HR-assisted
/// registration, which is auto-approved and never appears here).
///
/// Deliberate differences from web: load errors get a Retry button; the
/// "Awaiting an approver" branch is unreachable (the tab is permission-gated).
class FaceRegistrationApprovalsTab extends ConsumerWidget {
  const FaceRegistrationApprovalsTab({super.key});

  /// Returns null on success, else the message to show under the row.
  Future<String?> _review(WidgetRef ref, String id, bool approve) async {
    try {
      await ref.read(facialRecognitionRepositoryProvider).reviewRegistration(id: id, approve: approve);
      ref.invalidate(facePendingRegistrationsProvider);
      return null;
    } catch (e) {
      return _reviewError(e);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(facePendingRegistrationsProvider);

    return pendingAsync.when(
      loading: () => const Center(child: ApprovalsLoading(key: Key('face-loading'), label: 'Loading…')),
      error: (e, _) => Center(
        child: SingleChildScrollView(
          child: _isForbidden(e)
              ? const ApprovalsEmptyState(
                  key: Key('face-forbidden'),
                  kind: ApprovalsStateKind.denied,
                  title: 'Access denied',
                  message: _kForbiddenMessage,
                )
              : ApprovalsEmptyState.forError(e, onRetry: () => ref.invalidate(facePendingRegistrationsProvider)),
        ),
      ),
      data: (result) {
        final rows = result.results;
        final pager = result.totalPages > 1
            ? _Pager(
                page: result.page,
                totalPages: result.totalPages,
                onPrev: () => ref.read(facePendingRegistrationsPageProvider.notifier).state = result.page - 1,
                onNext: () => ref.read(facePendingRegistrationsPageProvider.notifier).state = result.page + 1,
              )
            : null;

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(facePendingRegistrationsProvider),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (rows.isEmpty)
                result.page > 1
                    ? ApprovalsEmptyState(
                        kind: ApprovalsStateKind.noMatch,
                        title: 'Nothing on this page',
                        message: 'No pending face registration requests.',
                        icon: Icons.face_outlined,
                        actionLabel: 'Back to first page',
                        onAction: () => ref.read(facePendingRegistrationsPageProvider.notifier).state = 1,
                      )
                    : const ApprovalsEmptyState(
                        kind: ApprovalsStateKind.empty,
                        title: 'No face registrations to review',
                        message: 'No pending face registration requests.',
                        icon: Icons.face_outlined,
                      ),
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PendingRow(
                    key: ValueKey(r.id),
                    row: r,
                    onReview: (approve) => _review(ref, r.id, approve),
                  ),
                ),
              if (pager != null) pager,
            ],
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
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        runSpacing: 4,
        children: [
          Text('Page $page of $totalPages', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                onPressed: page > 1 ? onPrev : null,
                icon: const Icon(Icons.chevron_left, size: 18),
                label: const Text('Prev'),
                style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
              ),
              TextButton.icon(
                onPressed: page < totalPages ? onNext : null,
                icon: const Icon(Icons.chevron_right, size: 18),
                label: const Text('Next'),
                iconAlignment: IconAlignment.end,
                style: TextButton.styleFrom(minimumSize: const Size(64, 44)),
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
  final Future<String?> Function(bool approve) onReview;

  const _PendingRow({super.key, required this.row, required this.onReview});

  @override
  State<_PendingRow> createState() => _PendingRowState();
}

class _PendingRowState extends State<_PendingRow> {
  bool _busy = false;
  String? _error;

  Future<void> _handle(bool approve) async {
    // Disable immediately on the first tap, before any await.
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onReview(approve);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final approve = FilledButton.icon(
      key: Key('face-approve-${row.id}'),
      onPressed: _busy ? null : () => _handle(true),
      icon: _busy
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.check, size: 16),
      label: const Text('Approve'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        minimumSize: const Size(0, 44),
        textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    final reject = OutlinedButton.icon(
      key: Key('face-reject-${row.id}'),
      onPressed: _busy ? null : () => _handle(false),
      icon: const Icon(Icons.close, size: 16),
      label: const Text('Reject'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error.withValues(alpha: 0.6)),
        minimumSize: const Size(0, 44),
        textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    final passed = row.livenessPassed;
    final score = row.livenessScore;
    return ApprovalsCardShell(
      name: row.employeeName,
      meta: row.employeeEmail,
      badge: const ApprovalsBadge('Pending', ApprovalsTone.warning),
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Web order: Approve, then Reject.
          LayoutBuilder(builder: (context, c) {
            if (c.maxWidth < 260 || scale > 1.3) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [approve, const SizedBox(height: 8), reject],
              );
            }
            return Row(children: [Expanded(child: approve), const SizedBox(width: 10), Expanded(child: reject)]);
          }),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!,
                  key: Key('face-error-${row.id}'), style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ApprovalsChip(
                passed ? 'Passed' : 'Failed',
                icon: passed ? Icons.check_circle_outline : Icons.cancel_outlined,
                tone: passed ? ApprovalsTone.success : ApprovalsTone.error,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text('liveness', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(width: 120, child: ApprovalsKeyFigure(_fmtScore(score), caption: 'score')),
                ),
              ),
            ],
          ),
          if (score != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: score.clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: AppColors.border,
                color: AppColors.primary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          ApprovalsFineprint('Submitted ${_fmtDate(row.createdAt)}'),
        ],
      ),
    );
  }
}

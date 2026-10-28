import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/separation_entity.dart';
import '../providers/separation_providers.dart';
import 'separation_status.dart';

/// Fixed 4-item clearance checklist (Manager/IT/Finance/HR — auto-created
/// server-side alongside the request). Each item is a simple approve/reject
/// checkbox with remarks; there is no linked asset-return or FNF-amount
/// record behind IT/Finance today (see backend audit — clearance_type has
/// no supporting model beyond this approve/reject flag).
class SeparationClearanceSection extends ConsumerStatefulWidget {
  final String requestId;
  const SeparationClearanceSection({super.key, required this.requestId});

  @override
  ConsumerState<SeparationClearanceSection> createState() =>
      _SeparationClearanceSectionState();
}

class _SeparationClearanceSectionState
    extends ConsumerState<SeparationClearanceSection> {
  String? _actioningId;

  void _showError(String err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _approve(SeparationClearanceEntity c) async {
    setState(() => _actioningId = c.id);
    final err = await ref.read(separationActionsProvider).actionClearance(
          requestId: widget.requestId,
          clearanceId: c.id,
          action: 'approve',
        );
    if (!mounted) return;
    setState(() => _actioningId = null);
    if (err != null) _showError(err);
  }

  Future<void> _reject(SeparationClearanceEntity c) async {
    final ctrl = TextEditingController();
    final remarks = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Reject ${c.clearanceTypeDisplay}', style: AppTextStyles.label),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 300,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Remarks (required)…'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: ctrl.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Confirm Reject'),
          ),
        ],
      ),
    );
    if (remarks == null || remarks.isEmpty || !mounted) return;
    setState(() => _actioningId = c.id);
    final err = await ref.read(separationActionsProvider).actionClearance(
          requestId: widget.requestId,
          clearanceId: c.id,
          action: 'reject',
          remarks: remarks,
        );
    if (!mounted) return;
    setState(() => _actioningId = null);
    if (err != null) _showError(err);
  }

  @override
  Widget build(BuildContext context) {
    final clearancesAsync =
        ref.watch(separationClearancesProvider(widget.requestId));

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
          SeparationSectionHeader(
            title: clearancesAsync.maybeWhen(
              data: (items) =>
                  'Clearance (${items.where((c) => c.status == 'approved').length}/${items.length})',
              orElse: () => 'Clearance',
            ),
          ),
          clearancesAsync.when(
            data: (items) => items.isEmpty
                ? Text('No clearance items.',
                    style:
                        AppTextStyles.caption.copyWith(color: AppColors.textHint))
                : Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0) Divider(height: 20, color: AppColors.border),
                        _ClearanceRow(
                          item: items[i],
                          loading: _actioningId == items[i].id,
                          onApprove: () => _approve(items[i]),
                          onReject: () => _reject(items[i]),
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
            error: (_, __) => Text('Could not load clearances.',
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _ClearanceRow extends StatelessWidget {
  final SeparationClearanceEntity item;
  final bool loading;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  const _ClearanceRow({
    required this.item,
    required this.loading,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
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
                  Text(item.clearanceTypeDisplay,
                      style: AppTextStyles.label.copyWith(fontSize: 13)),
                  if (item.clearedByName.isNotEmpty)
                    Text('Cleared by ${item.clearedByName}',
                        style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  if (item.remarks.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('"${item.remarks}"',
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 11, color: AppColors.textSecondary)),
                    ),
                ],
              ),
            ),
            SeparationStatusChip(status: item.status, label: item.statusDisplay),
          ],
        ),
        if (item.canAction) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: loading ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Reject',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: loading ? null : onApprove,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                  child: const Text('Approve',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

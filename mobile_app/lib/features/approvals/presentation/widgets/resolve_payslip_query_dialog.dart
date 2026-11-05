import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/approvals_providers.dart';

// Web: app/dashboard/payroll/_components/ResolveQueryModal.tsx, opened from
// Team Approvals for a payslip query. Shows who raised it and what they
// asked, takes a required resolution note, and posts
// {resolution_note} to /payroll/queries/<id>/resolve/. The dialog closes only
// once the server has confirmed; a refusal is shown inside it and the note
// is kept.

/// Opens the resolve dialog for [item]. Returns true when the query was
/// resolved (the inbox has already been reloaded by then).
Future<bool> showResolvePayslipQueryDialog(BuildContext context, UnifiedApprovalItem item) async {
  final resolved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => ResolvePayslipQueryDialog(item: item),
  );
  return resolved == true;
}

class ResolvePayslipQueryDialog extends ConsumerStatefulWidget {
  const ResolvePayslipQueryDialog({super.key, required this.item});
  final UnifiedApprovalItem item;

  @override
  ConsumerState<ResolvePayslipQueryDialog> createState() => _ResolvePayslipQueryDialogState();
}

class _ResolvePayslipQueryDialogState extends ConsumerState<ResolvePayslipQueryDialog> {
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return; // one request at a time
    if (_note.text.trim().isEmpty) {
      setState(() => _error = kResolutionNoteRequired);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final err = await ref.read(unifiedTeamApprovalsProvider.notifier).resolvePayslipQuery(widget.item, _note.text);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _saving = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    final q = widget.item.payslipQuery;
    final raisedBy = widget.item.employeeName.isNotEmpty ? widget.item.employeeName : 'Unknown';
    final canSubmit = !_saving && _note.text.trim().isNotEmpty;
    return AlertDialog(
      key: const Key('resolve-payslip-query-dialog'),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Resolve Payslip Query', style: AppTextStyles.h4.copyWith(fontSize: 16)),
          const SizedBox(height: 2),
          Text('Raised by $raisedBy',
              style: AppTextStyles.caption.copyWith(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Employee's query", style: AppTextStyles.label.copyWith(fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 160),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.backgroundLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  (q?.description ?? widget.item.reason).isNotEmpty ? (q?.description ?? widget.item.reason) : '—',
                  key: const Key('resolve-query-text'),
                  style: AppTextStyles.body.copyWith(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text.rich(TextSpan(children: [
              TextSpan(text: 'Resolution note ', style: AppTextStyles.label.copyWith(fontSize: 12)),
              TextSpan(text: '*', style: AppTextStyles.label.copyWith(fontSize: 12, color: AppColors.error)),
            ])),
            const SizedBox(height: 4),
            TextField(
              key: const Key('resolve-note-field'),
              controller: _note,
              enabled: !_saving,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                hintText: 'e.g. Corrected HRA calculation, revised payslip has been re-sent…',
                isDense: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, size: 16, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(_error!,
                        key: const Key('resolve-error'),
                        style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12)),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('resolve-submit'),
          onPressed: canSubmit ? _submit : null,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Resolve Query'),
        ),
      ],
    );
  }
}

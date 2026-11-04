import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/policy_ack_models.dart';
import '../../domain/entities/document_entity.dart';
import '../providers/document_providers.dart';

String _when(String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (d == null) return iso ?? '';
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${m[d.month - 1]} ${d.year}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

/// Company Policy acknowledgement inside the document detail (web:
/// components/policy/AcknowledgementPanel.tsx). Employees confirm they have
/// read and accept the current version; HR with documents.edit can switch
/// acknowledgement on or off and see who has and hasn't acknowledged.
class AcknowledgementPanel extends ConsumerStatefulWidget {
  const AcknowledgementPanel({super.key, required this.doc, required this.canManage, required this.onChanged});

  final DocumentEntity doc;
  final bool canManage;
  final ValueChanged<DocumentEntity> onChanged;

  @override
  ConsumerState<AcknowledgementPanel> createState() => _AcknowledgementPanelState();
}

class _AcknowledgementPanelState extends ConsumerState<AcknowledgementPanel> {
  bool _accepted = false;
  bool _busy = false;
  String? _error;
  bool _showReport = false;
  AckFilter _show = AckFilter.pending;

  Future<void> _acknowledge() async {
    if (_busy) return; // one request at a time
    setState(() {
      _busy = true;
      _error = null;
    });
    final out = await ref.read(policyAckActionsProvider).acknowledge(widget.doc);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = out.error;
      if (out.conflict) _accepted = false; // must read the new version first
    });
    if (out.document != null) widget.onChanged(out.document!);
  }

  Future<void> _setRequired(bool value) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final out = await ref.read(policyAckActionsProvider).setRequired(widget.doc, value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = out.error;
      if (out.document != null) _showReport = false;
    });
    if (out.document != null) widget.onChanged(out.document!);
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.doc;
    final state = ackStateOf(doc);
    if (state == AckState.notRequired && !widget.canManage) return const SizedBox.shrink();

    return Container(
      key: const Key('ack-panel'),
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.draw_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Text('Acknowledgement', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
          if (doc.requiresAcknowledgement)
            Text(' · version ${doc.version}', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        ]),
        const SizedBox(height: 8),
        if (state == AckState.acknowledged)
          Text('You acknowledged this version on ${_when(doc.myAcknowledgedAt)}.',
              key: const Key('ack-done'), style: AppTextStyles.bodySmall.copyWith(color: AppColors.success)),
        if (state == AckState.pending) ...[
          Text('Please open and read this document, then confirm below.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          Material(
            type: MaterialType.transparency,
            child: CheckboxListTile(
              key: const Key('ack-accept'),
              value: _accepted,
              onChanged: _busy ? null : (v) => setState(() => _accepted = v ?? false),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              title: Text('I have read this document and accept the guidelines in it.', style: AppTextStyles.bodySmall),
            ),
          ),
          FilledButton.icon(
            key: const Key('ack-submit'),
            onPressed: !_accepted || _busy ? null : _acknowledge,
            icon: _busy
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 16),
            label: Text(_busy ? 'Saving…' : 'Acknowledge'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ],
        if (widget.canManage) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (doc.requiresAcknowledgement) ...[
              OutlinedButton.icon(
                key: const Key('ack-view-report'),
                onPressed: _busy ? null : () => setState(() => _showReport = true),
                icon: const Icon(Icons.groups_outlined, size: 16),
                label: const Text('View acknowledgements'),
              ),
              TextButton(
                key: const Key('ack-stop'),
                onPressed: _busy ? null : () => _setRequired(false),
                child: const Text('Stop asking for acknowledgement'),
              ),
            ] else
              OutlinedButton.icon(
                key: const Key('ack-require'),
                onPressed: _busy ? null : () => _setRequired(true),
                icon: const Icon(Icons.draw_outlined, size: 16),
                label: const Text('Require employees to acknowledge'),
              ),
          ]),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, key: const Key('ack-error'), style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
        ],
        if (_showReport && widget.canManage && doc.requiresAcknowledgement)
          _Report(
            documentId: doc.id,
            show: _show,
            onShow: (v) => setState(() => _show = v),
          ),
      ]),
    );
  }
}

class _Report extends ConsumerWidget {
  const _Report({required this.documentId, required this.show, required this.onShow});
  final int documentId;
  final AckFilter show;
  final ValueChanged<AckFilter> onShow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(acknowledgementReportProvider(documentId));
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, _) => Row(children: [
          Expanded(
              child: Text(userFriendlyMessage(e), style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
          TextButton(
              onPressed: () => ref.invalidate(acknowledgementReportProvider(documentId)), child: const Text('Retry')),
        ]),
        data: (r) {
          final rows = filterAckRows(r.employees, show);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('${r.acknowledged} of ${r.total} acknowledged version ${r.version}',
                    key: const Key('ack-report-summary'),
                    style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              ),
              DropdownButton<AckFilter>(
                key: const Key('ack-report-filter'),
                value: show,
                isDense: true,
                onChanged: (v) => v == null ? null : onShow(v),
                items: const [
                  DropdownMenuItem(value: AckFilter.pending, child: Text('Not yet')),
                  DropdownMenuItem(value: AckFilter.acknowledged, child: Text('Acknowledged')),
                  DropdownMenuItem(value: AckFilter.all, child: Text('Everyone')),
                ],
              ),
            ]),
            const SizedBox(height: 6),
            if (rows.isEmpty)
              Text('No one here.', style: AppTextStyles.caption.copyWith(color: AppColors.textHint))
            else
              for (final row in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Expanded(
                      child: Text('${row.name} · ${row.employeeId}${row.branch.isEmpty ? '' : ' · ${row.branch}'}',
                          style: AppTextStyles.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    Text(row.acknowledgedAt == null ? '—' : _when(row.acknowledgedAt),
                        style: AppTextStyles.caption
                            .copyWith(color: row.acknowledgedAt == null ? AppColors.textHint : AppColors.success)),
                  ]),
                ),
          ]);
        },
      ),
    );
  }
}

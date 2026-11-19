import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/documents/document_links.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/formatters/en_in_format.dart' show formatMoney;
import '../providers/approvals_providers.dart';
import 'approvals_ui.dart';
import 'approve_reject_dialog.dart';
import 'resolve_payslip_query_dialog.dart';

Future<void> showApprovalDetailSheet(BuildContext context, UnifiedApprovalItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ApprovalDetailSheet(item: item),
  );
}


String _statusLabel(String status) => switch (status) {
      'pending' => 'Pending',
      'l2_pending' => 'Pending HR',
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      'cancelled' => 'Cancelled',
      _ => status,
    };

Color _decisionColor(String? status) => switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };

String _decisionLabel(String? status) => switch (status) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending',
    };

class ApprovalDetailSheet extends ConsumerStatefulWidget {
  final UnifiedApprovalItem item;
  const ApprovalDetailSheet({super.key, required this.item});

  @override
  ConsumerState<ApprovalDetailSheet> createState() => _ApprovalDetailSheetState();
}

class _ApprovalDetailSheetState extends ConsumerState<ApprovalDetailSheet> {
  bool _loading = false;

  /// The map link (web: a plain link opening in a new tab).
  Future<void> _openUrl(String url) => openDocumentLinkExternally(context, ref, url,
      failureMessage: "Couldn't open the map. Please try again.");

  /// An attachment: web RequestDetailDrawer shows it in DocPreviewModal —
  /// the app's document viewer here.
  Future<void> _preview(String label, String url) => previewDocumentInApp(context, ref, url: url, title: label);

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  /// One guarded path for Approve and Reject: the busy flag is set before the
  /// dialog opens, so a second tap can't open a second dialog or send a second
  /// request, and nothing is marked decided until the server confirms.
  Future<void> _decide({required bool approve}) async {
    if (_loading) return;
    setState(() => _loading = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final item = widget.item;
      String remarks = '';
      if (item.kind == UnifiedApprovalKind.expense) {
        final confirmed = await showConfirmDialog(context, forReject: !approve);
        if (!confirmed || !mounted) return;
      } else {
        final result = await showRemarksDialog(context, forReject: !approve);
        if (result == null || !mounted) return;
        remarks = result;
      }
      final notifier = ref.read(unifiedTeamApprovalsProvider.notifier);
      final err = approve ? await notifier.approve(item, remarks: remarks) : await notifier.reject(item, remarks: remarks);
      if (!mounted) return;
      if (err == null) {
        Navigator.of(context).pop();
        messenger.showSnackBar(SnackBar(
          content: Text(approvalSuccessMessage(item, approve: approve)),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      } else {
        _showSnack(err, isError: true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approve() => _decide(approve: true);
  Future<void> _reject() => _decide(approve: false);

  Future<void> _resolve() async {
    final resolved = await showResolvePayslipQueryDialog(context, widget.item);
    if (!resolved || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(SnackBar(
      content: const Text('Payslip query resolved.'),
      backgroundColor: AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final showActions = item.canAction && item.isPending;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Handle + identity header (My Profile's header, in a sheet) ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ApprovalsAvatar(item.employeeName, radius: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.employeeName.isNotEmpty ? item.employeeName : 'Unknown',
                              style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (item.employeeCode.isNotEmpty) ApprovalsIdChip(item.employeeCode),
                              if ((item.department.isNotEmpty ? item.department : item.secondaryText).isNotEmpty)
                                ApprovalsMeta(Icons.business_outlined,
                                    item.department.isNotEmpty ? item.department : item.secondaryText),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ApprovalsBadge(item.isPayslipQuery ? 'Payslip Query' : '${item.typeLabel} Request',
                                  ApprovalsTone.info,
                                  icon: _iconFor(item.kind)),
                              ApprovalsBadge(_statusLabel(item.status), _toneFor(item.status)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),

              // ── Body: section cards ─────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ApprovalsSection(
                        icon: Icons.description_outlined,
                        title: 'Request Details',
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _spec(_buildRequestDetails(item))),
                      ),
                      const SizedBox(height: 12),
                      // Reason (the employee's query text for a payslip query)
                      ApprovalsSection(
                        icon: Icons.notes_outlined,
                        title: item.isPayslipQuery ? 'Query' : 'Reason',
                        child: Text(item.reason.isNotEmpty ? item.reason : '—',
                            style: AppTextStyles.body.copyWith(fontSize: 14)),
                      ),
                      if (_hasAttachments(item)) ...[
                        const SizedBox(height: 12),
                        ApprovalsSection(
                          icon: Icons.attach_file,
                          title: 'Attachments',
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildAttachments(item)),
                        ),
                      ],
                      const SizedBox(height: 12),
                      ApprovalsSection(
                        icon: Icons.timeline_outlined,
                        title: 'Approval Timeline',
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildTimeline(item)),
                      ),
                      if (_hasComments(item)) ...[
                        const SizedBox(height: 12),
                        ApprovalsSection(
                          icon: Icons.chat_bubble_outline,
                          title: 'Comments',
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: _buildComments(item)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Footer actions ───────────────────────────────────────────
              if (showActions)
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: SafeArea(
                    top: false,
                    child: item.isPayslipQuery
                        ? FilledButton.icon(
                            key: const Key('detail-resolve'),
                            onPressed: _resolve,
                            icon: const Icon(Icons.task_alt, size: 16),
                            label: const Text('Resolve Query'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              minimumSize: const Size.fromHeight(46),
                              textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                            ),
                          )
                        : ApprovalsDecisionButtons(
                            busy: _loading,
                            onApprove: _approve,
                            onReject: _reject,
                          ),
                  ),
                )
              else
                SizedBox(
                    height:
                        MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 8),
            ],
          ),
        ),
      ),
    );
  }

  ApprovalsTone _toneFor(String status) => switch (approvalDisplayStatus(status)) {
        'approved' => ApprovalsTone.success,
        'rejected' => ApprovalsTone.error,
        'cancelled' => ApprovalsTone.neutral,
        _ => ApprovalsTone.warning,
      };

  IconData _iconFor(UnifiedApprovalKind kind) => switch (kind) {
        UnifiedApprovalKind.leave => Icons.event_busy_outlined,
        UnifiedApprovalKind.expense => Icons.receipt_long_outlined,
        UnifiedApprovalKind.attendanceCorrection => Icons.fact_check_outlined,
        UnifiedApprovalKind.wfh => Icons.home_work_outlined,
        UnifiedApprovalKind.separation => Icons.logout_outlined,
        UnifiedApprovalKind.payslip => Icons.chat_bubble_outline,
      };

  List<Widget> _buildRequestDetails(UnifiedApprovalItem item) {
    switch (item.kind) {
      // Not shown in this sheet — separation opens its own detail screen.
      case UnifiedApprovalKind.separation:
        return [
          _kv('Type', item.primaryLine),
          _kv('Proposed last day', item.separation?.proposedLastWorkingDay ?? '—'),
        ];
      case UnifiedApprovalKind.payslip:
        final q = item.payslipQuery!;
        return [
          if ((q.cycleStart ?? '').isNotEmpty) _kv('Pay period from', q.cycleStart!),
          _kv('Raised on', q.createdAt.length >= 10 ? q.createdAt.substring(0, 10) : (q.createdAt.isEmpty ? '—' : q.createdAt)),
          _kv('Status', q.isResolved ? 'Resolved' : 'Open'),
        ];
      case UnifiedApprovalKind.leave:
        final r = item.leave!;
        return [
          // Web RequestDetailDrawer: Leave Type, Duration, Dates, Total Days, LOP Days.
          _kv('Leave Type', r.leaveType.isNotEmpty ? r.leaveType : '—'),
          _kv('Duration', r.durationDisplay.isNotEmpty ? r.durationDisplay : '—'),
          _kv('Dates', item.secondaryLine),
          _kv('Total Days', '${r.days}'),
          if (r.hasLopDays) _kv('LOP Days', approvalsNumber(r.lopDays)),
          if (r.appliedOn.isNotEmpty) _kv('Applied On', approvalsDate(r.appliedOn)),
        ];
      case UnifiedApprovalKind.expense:
        final e = item.expense!;
        return [
          _kv('Title', e.title.isNotEmpty ? e.title : '—'),
          _kv('Category', e.category.isEmpty ? '—' : '${e.category[0].toUpperCase()}${e.category.substring(1)}'),
          _kv('Amount', formatMoney(e.amount)),
          _kv('Expense Date', approvalsDate(e.expenseDate)),
        ];
      case UnifiedApprovalKind.attendanceCorrection:
        final c = item.correction!;
        return [
          // Web: Correction Type, Date, then each affected punch as "original → requested".
          _kv('Correction Type', item.primaryLine),
          _kv('Date', item.tertiaryLine),
          if (!c.isLateJustification) ...[
            if (c.punchType != 'OUT')
              _kv('Check-in', '${approvalsTime12(c.originalIn)} → ${approvalsTime12(c.requestedInTime)}'),
            if (c.punchType != 'IN')
              _kv('Check-out', '${approvalsTime12(c.originalOut)} → ${approvalsTime12(c.requestedOutTime)}'),
          ],
          if ((c.notes ?? '').isNotEmpty) _kv('Notes', c.notes!),
        ];
      case UnifiedApprovalKind.wfh:
        final w = item.wfh!;
        return [
          _kv('Dates', item.secondaryLine),
          _kv('Total Days', item.tertiaryLine),
          if (w.locationLabel.isNotEmpty) _kv('Location', w.locationLabel),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                    width: 110,
                    child: Text('Coordinates',
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 11, color: AppColors.textHint))),
                Expanded(
                  child: InkWell(
                    onTap: () => _openUrl(
                        'https://maps.google.com/?q=${w.latitude},${w.longitude}'),
                    child: Text(
                      '${w.latitude.toStringAsFixed(6)}, ${w.longitude.toStringAsFixed(6)} · View on map',
                      style: AppTextStyles.body.copyWith(
                          fontSize: 12.5, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ];
    }
  }

  /// One specification row: the label on the left, its value on the right.
  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: Text(k, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))),
            const SizedBox(width: 12),
            Expanded(
              flex: 6,
              child: Text(v.isEmpty ? '—' : v,
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  /// The specification rows separated by hairlines (a list, not a form).
  List<Widget> _spec(List<Widget> items) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) out.add(Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)));
      out.add(items[i]);
    }
    return out;
  }

  bool _hasAttachments(UnifiedApprovalItem item) {
    if (item.kind == UnifiedApprovalKind.leave) {
      return (item.leave?.documentUrl ?? '').isNotEmpty;
    }
    // Web RequestDetailDrawer: a medical WFH request's proof ("Medical Proof").
    if (item.kind == UnifiedApprovalKind.wfh) {
      return (item.wfh?.supportingDocumentUrl ?? '').isNotEmpty;
    }
    if (item.kind == UnifiedApprovalKind.expense) {
      return (item.expense?.receipts ?? []).any((r) => (r.url ?? '').isNotEmpty);
    }
    return false;
  }

  List<Widget> _buildAttachments(UnifiedApprovalItem item) {
    if (item.kind == UnifiedApprovalKind.leave) {
      final url = item.leave?.documentUrl;
      if (url == null || url.isEmpty) return [];
      return [_attachmentRow('Supporting document', url)];
    }
    if (item.kind == UnifiedApprovalKind.wfh) {
      final url = item.wfh?.supportingDocumentUrl;
      if (url == null || url.isEmpty) return [];
      return [_attachmentRow('Medical Proof', url)];
    }
    if (item.kind == UnifiedApprovalKind.expense) {
      final receipts = item.expense?.receipts ?? [];
      return receipts
          .where((r) => (r.url ?? '').isNotEmpty)
          .toList()
          .asMap()
          .entries
          .map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: _attachmentRow('Receipt ${e.key + 1}', e.value.url!),
              ))
          .toList();
    }
    return [];
  }

  Widget _attachmentRow(String label, String url) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          key: Key('approval-attachment-$label'),
          onTap: () => _preview(label, url),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const ApprovalsIconBox(Icons.attach_file, size: 32),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(label,
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                ),
                Icon(Icons.chevron_right, size: 18, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      );

  List<Widget> _buildTimeline(UnifiedApprovalItem item) {
    final submitted = _TimelineRow(
      label: 'Submitted',
      color: AppColors.success,
      detail: approvalsSubmitted(item.submittedAt),
    );

    if (item.kind == UnifiedApprovalKind.payslip) {
      final q = item.payslipQuery;
      final resolved = q?.isResolved ?? false;
      return [
        submitted,
        const SizedBox(height: 12),
        _TimelineRow(
          label: 'Resolution',
          color: resolved ? AppColors.success : AppColors.warning,
          detail: resolved
              ? 'Resolved${(q?.resolvedByName ?? '').isNotEmpty ? ' — ${q!.resolvedByName}' : ''}'
              : 'Open',
        ),
      ];
    }

    if (item.kind == UnifiedApprovalKind.expense) {
      return [
        submitted,
        const SizedBox(height: 12),
        _TimelineRow(
          label: 'Decision',
          color: _decisionColor(item.status == 'approved' || item.status == 'rejected' ? item.status : null),
          detail: _decisionLabel(item.status == 'approved' || item.status == 'rejected' ? item.status : null),
        ),
      ];
    }

    final l1Status = switch (item.kind) {
      UnifiedApprovalKind.leave => item.leave?.l1Status,
      UnifiedApprovalKind.wfh => item.wfh?.l1Status,
      _ => item.correction?.l1Status,
    };
    final l1Name = switch (item.kind) {
      UnifiedApprovalKind.leave => item.leave?.l1ApproverName,
      UnifiedApprovalKind.wfh => item.wfh?.l1ApproverName,
      _ => item.correction?.l1ApproverName,
    };
    final l2Status = switch (item.kind) {
      UnifiedApprovalKind.leave => item.leave?.l2Status,
      UnifiedApprovalKind.wfh => item.wfh?.l2Status,
      _ => item.correction?.l2Status,
    };
    final l2Name = switch (item.kind) {
      UnifiedApprovalKind.leave => item.leave?.l2ApproverName,
      UnifiedApprovalKind.wfh => item.wfh?.l2ApproverName,
      _ => item.correction?.l2ApproverName,
    };

    final rows = <Widget>[submitted];
    rows.add(const SizedBox(height: 12));
    rows.add(_TimelineRow(
      label: 'Manager Approval',
      color: _decisionColor(l1Status),
      detail: '${_decisionLabel(l1Status)}${(l1Name?.isNotEmpty ?? false) ? ' · $l1Name' : ''}',
    ));
    if (l2Status != null || (l2Name?.isNotEmpty ?? false)) {
      rows.add(const SizedBox(height: 12));
      rows.add(_TimelineRow(
        label: 'HR Approval',
        color: _decisionColor(l2Status),
        detail: '${_decisionLabel(l2Status)}${(l2Name?.isNotEmpty ?? false) ? ' · $l2Name' : ''}',
      ));
    }
    return rows;
  }

  bool _hasComments(UnifiedApprovalItem item) {
    if (item.kind == UnifiedApprovalKind.leave) {
      return (item.leave?.l1Remarks?.isNotEmpty ?? false) || (item.leave?.l2Remarks?.isNotEmpty ?? false);
    }
    if (item.kind == UnifiedApprovalKind.attendanceCorrection) {
      return (item.correction?.l1Remarks.isNotEmpty ?? false) || (item.correction?.l2Remarks.isNotEmpty ?? false);
    }
    if (item.kind == UnifiedApprovalKind.wfh) {
      return (item.wfh?.l1Remarks.isNotEmpty ?? false) || (item.wfh?.l2Remarks.isNotEmpty ?? false);
    }
    return false;
  }

  List<Widget> _buildComments(UnifiedApprovalItem item) {
    final comments = <String>[];
    if (item.kind == UnifiedApprovalKind.leave) {
      if ((item.leave?.l1Remarks ?? '').isNotEmpty) comments.add('Manager: "${item.leave!.l1Remarks}"');
      if ((item.leave?.l2Remarks ?? '').isNotEmpty) comments.add('HR: "${item.leave!.l2Remarks}"');
    } else if (item.kind == UnifiedApprovalKind.attendanceCorrection) {
      if (item.correction!.l1Remarks.isNotEmpty) comments.add('Manager: "${item.correction!.l1Remarks}"');
      if (item.correction!.l2Remarks.isNotEmpty) comments.add('HR: "${item.correction!.l2Remarks}"');
    } else if (item.kind == UnifiedApprovalKind.wfh) {
      if (item.wfh!.l1Remarks.isNotEmpty) comments.add('Manager: "${item.wfh!.l1Remarks}"');
      if (item.wfh!.l2Remarks.isNotEmpty) comments.add('HR: "${item.wfh!.l2Remarks}"');
    }
    return comments
        .map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(c, style: AppTextStyles.caption.copyWith(fontSize: 11.5)),
              ),
            ))
        .toList();
  }
}

class _TimelineRow extends StatelessWidget {
  final String label;
  final Color color;
  final String detail;
  const _TimelineRow({required this.label, required this.color, required this.detail});

  @override
  Widget build(BuildContext context) {
    final icon = color == AppColors.success ? Icons.check : (color == AppColors.error ? Icons.close : Icons.schedule);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700)),
              Text(detail, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

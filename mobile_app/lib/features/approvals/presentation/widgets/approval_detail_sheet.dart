import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/approvals_providers.dart';
import 'approve_reject_dialog.dart';

Future<void> showApprovalDetailSheet(BuildContext context, UnifiedApprovalItem item) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ApprovalDetailSheet(item: item),
  );
}

Color _statusColor(String status) => switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      'cancelled' => AppColors.textSecondary,
      _ => AppColors.warning,
    };

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

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _approve() async {
    final item = widget.item;
    String? remarks;
    if (item.kind == UnifiedApprovalKind.expense) {
      final confirmed = await showConfirmDialog(context, forReject: false);
      if (!confirmed || !mounted) return;
    } else {
      final result = await showRemarksDialog(context, forReject: false);
      if (result == null || !mounted) return;
      remarks = result;
    }
    setState(() => _loading = true);
    final err =
        await ref.read(unifiedTeamApprovalsProvider.notifier).approve(item, remarks: remarks);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      _showSnack(err, isError: true);
    }
  }

  Future<void> _reject() async {
    final item = widget.item;
    String remarks = '';
    if (item.kind == UnifiedApprovalKind.expense) {
      final confirmed = await showConfirmDialog(context, forReject: true);
      if (!confirmed || !mounted) return;
    } else {
      final result = await showRemarksDialog(context, forReject: true);
      if (result == null || !mounted) return;
      remarks = result;
    }
    setState(() => _loading = true);
    final err =
        await ref.read(unifiedTeamApprovalsProvider.notifier).reject(item, remarks: remarks);
    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      _showSnack(err, isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final showActions = item.canAction && item.isPending;
    final sc = _statusColor(item.status);

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
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_iconFor(item.kind), size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('${item.typeLabel} Request',
                              style: AppTextStyles.h4.copyWith(fontSize: 15)),
                          Text(item.employeeName,
                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),

              // ── Body ─────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Employee info
                      _sectionLabel('EMPLOYEE'),
                      const SizedBox(height: 3),
                      Text(item.employeeName.isNotEmpty ? item.employeeName : 'Unknown',
                          style: AppTextStyles.label.copyWith(fontSize: 13)),
                      Text(
                        [item.employeeCode, item.department.isNotEmpty ? item.department : item.secondaryText]
                                .where((s) => s.isNotEmpty)
                                .join(' · ')
                                .isEmpty
                            ? '—'
                            : [item.employeeCode, item.department.isNotEmpty ? item.department : item.secondaryText]
                                .where((s) => s.isNotEmpty)
                                .join(' · '),
                        style: AppTextStyles.caption.copyWith(fontSize: 11),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(item.typeLabel,
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: sc.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_statusLabel(item.status),
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 10, fontWeight: FontWeight.w700, color: sc)),
                        ),
                      ]),

                      _divider(),

                      // Request details
                      _sectionLabel('REQUEST DETAILS'),
                      const SizedBox(height: 6),
                      ..._buildRequestDetails(item),

                      _divider(),

                      // Reason
                      _sectionLabel('REASON'),
                      const SizedBox(height: 3),
                      Text(item.reason.isNotEmpty ? item.reason : '—',
                          style: AppTextStyles.body.copyWith(fontSize: 13)),

                      // Attachments
                      if (_hasAttachments(item)) ...[
                        _divider(),
                        _sectionLabel('ATTACHMENTS'),
                        const SizedBox(height: 6),
                        ..._buildAttachments(item),
                      ],

                      _divider(),

                      // Approval timeline
                      _sectionLabel('APPROVAL TIMELINE'),
                      const SizedBox(height: 10),
                      ..._buildTimeline(item),

                      // Comments
                      if (_hasComments(item)) ...[
                        _divider(),
                        _sectionLabel('COMMENTS'),
                        const SizedBox(height: 6),
                        ..._buildComments(item),
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
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _reject,
                            icon: const Icon(Icons.close, size: 14),
                            label: const Text('Reject',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.error,
                              side: BorderSide(color: AppColors.error),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _approve,
                            icon: _loading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.check, size: 14),
                            label: const Text('Approve',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
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

  IconData _iconFor(UnifiedApprovalKind kind) => switch (kind) {
        UnifiedApprovalKind.leave => Icons.event_busy_outlined,
        UnifiedApprovalKind.expense => Icons.receipt_long_outlined,
        UnifiedApprovalKind.attendanceCorrection => Icons.fact_check_outlined,
        UnifiedApprovalKind.wfh => Icons.home_work_outlined,
      };

  Widget _sectionLabel(String text) => Text(text,
      style: AppTextStyles.caption
          .copyWith(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.5));

  Widget _divider() => Column(children: [
        const SizedBox(height: 14),
        Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 12),
      ]);

  List<Widget> _buildRequestDetails(UnifiedApprovalItem item) {
    switch (item.kind) {
      case UnifiedApprovalKind.leave:
        final r = item.leave!;
        return [
          _kv('Leave Type', r.leaveType.isNotEmpty ? r.leaveType : '—'),
          _kv('Dates', '${r.from} → ${r.to}'),
          _kv('Duration',
              r.hasLopDays ? '${r.days} day(s) (incl. ${r.lopDays} LOP)' : '${r.days} day(s)'),
          if (r.appliedOn.isNotEmpty) _kv('Applied On', r.appliedOn),
        ];
      case UnifiedApprovalKind.expense:
        final e = item.expense!;
        return [
          _kv('Title', e.title.isNotEmpty ? e.title : '—'),
          _kv('Category', e.category),
          _kv('Amount', '₹${e.amount.toStringAsFixed(2)}'),
          _kv('Expense Date', e.expenseDate),
        ];
      case UnifiedApprovalKind.attendanceCorrection:
        final c = item.correction!;
        return [
          _kv('Date', c.date),
          _kv('Punch Type', c.punchType),
          _kv('Requested In', c.requestedInTime ?? '—'),
          _kv('Requested Out', c.requestedOutTime ?? '—'),
          if ((c.notes ?? '').isNotEmpty) _kv('Notes', c.notes!),
        ];
      case UnifiedApprovalKind.wfh:
        final w = item.wfh!;
        return [
          _kv('Dates', '${w.startDate} → ${w.endDate}'),
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

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(k, style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.textHint))),
            Expanded(child: Text(v, style: AppTextStyles.body.copyWith(fontSize: 12.5))),
          ],
        ),
      );

  bool _hasAttachments(UnifiedApprovalItem item) {
    if (item.kind == UnifiedApprovalKind.leave) {
      return (item.leave?.documentUrl ?? '').isNotEmpty;
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

  Widget _attachmentRow(String label, String url) => InkWell(
        onTap: () => _openUrl(url),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.attach_file, size: 15, color: AppColors.primary),
            const SizedBox(width: 5),
            Text(label,
                style: AppTextStyles.label.copyWith(
                    fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  List<Widget> _buildTimeline(UnifiedApprovalItem item) {
    final submitted = _TimelineRow(
      label: 'Submitted',
      color: AppColors.success,
      detail: item.employeeName,
    );

    if (item.kind == UnifiedApprovalKind.expense) {
      return [
        submitted,
        const SizedBox(height: 8),
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
    rows.add(const SizedBox(height: 8));
    rows.add(_TimelineRow(
      label: 'Manager (L1)',
      color: _decisionColor(l1Status),
      detail: '${_decisionLabel(l1Status)}${(l1Name?.isNotEmpty ?? false) ? ' — $l1Name' : ''}',
    ));
    if (l2Status != null || (l2Name?.isNotEmpty ?? false)) {
      rows.add(const SizedBox(height: 8));
      rows.add(_TimelineRow(
        label: 'HR (L2)',
        color: _decisionColor(l2Status),
        detail: '${_decisionLabel(l2Status)}${(l2Name?.isNotEmpty ?? false) ? ' — $l2Name' : ''}',
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.label.copyWith(fontSize: 12)),
              Text(detail, style: AppTextStyles.caption.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

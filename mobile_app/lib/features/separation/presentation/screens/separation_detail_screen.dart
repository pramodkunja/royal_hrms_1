import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../../../shared/widgets/app_loading_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../domain/entities/separation_entity.dart';
import '../providers/separation_providers.dart';
import '../widgets/separation_activity_section.dart';
import '../widgets/separation_approval_section.dart';
import '../widgets/separation_clearance_section.dart';
import '../widgets/separation_documents_section.dart';
import '../widgets/separation_form_sheet.dart';
import '../widgets/separation_handover_section.dart';
import '../widgets/separation_status.dart';

/// Full detail page for one separation request — pushed via
/// /dashboard/separation/:id. Rich enough (approval timeline, KT/handover,
/// clearance, documents, activity log) that a bottom sheet (as used for the
/// simpler Leave request detail) would be cramped — this mirrors web's
/// dedicated /dashboard/separation/[id] page instead.
class SeparationDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  final SeparationRequestEntity? initial;
  const SeparationDetailScreen({
    super.key,
    required this.requestId,
    this.initial,
  });

  @override
  ConsumerState<SeparationDetailScreen> createState() =>
      _SeparationDetailScreenState();
}

class _SeparationDetailScreenState
    extends ConsumerState<SeparationDetailScreen> {
  bool _actionLoading = false;

  void _showError(String err) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _cancel(SeparationRequestEntity r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Request?'),
        content: const Text(
            'This will cancel your separation request. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Request')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionLoading = true);
    final err = await ref.read(separationActionsProvider).cancelRequest(r.id);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err != null) _showError(err);
  }

  Future<void> _reject(SeparationRequestEntity r) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reject Request?'),
        content: Text(
            'This permanently removes ${r.employeeName}\'s separation request. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep Request')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _actionLoading = true);
    final err = await ref.read(separationActionsProvider).deleteRequest(r.id);
    if (!mounted) return;
    setState(() => _actionLoading = false);
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      _showError(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(separationDetailProvider(widget.requestId));
    final r = detailAsync.valueOrNull ?? widget.initial;
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    // A broad, session-level "is this viewer an approver at all" capability
    // — distinct from r.canApprove/r.canDelete, which only reflect whether
    // there's a currently-pending stage actionable by them right now (false
    // once the request is fully approved, exactly when handover/document
    // management is still needed through the exit period).
    final canManage = (user?.hasPermission('separation.approve') ?? false) ||
        (user?.hasPermission('settings.edit') ?? false);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(r?.requestRef.isNotEmpty == true
            ? r!.requestRef
            : 'Separation Request'),
      ),
      body: r == null
          ? detailAsync.isLoading
              ? const AppLoadingWidget()
              : AppErrorState(
                  message: 'Request not found.',
                  onRetry: () =>
                      ref.invalidate(separationDetailProvider(widget.requestId)),
                )
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(separationDetailProvider(widget.requestId)),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ────────────────────────────────────────────
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(r.employeeName,
                                  style: AppTextStyles.h4.copyWith(fontSize: 17)),
                              Text(
                                [r.employeeCode, r.employeeDepartment]
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        SeparationStatusChip(
                            status: r.status, label: r.statusDisplay),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── Employee Details ─────────────────────────────────
                    _SectionCard(
                      title: 'Employee Details',
                      rows: [
                        ('Employee Name', r.employeeName),
                        ('Employee Code', r.employeeCode),
                        ('Department', r.employeeDepartment),
                        ('Designation', r.employeeDesignation),
                        ('Reporting Manager', r.reportingManager?.name ?? '—'),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // ── Separation Details ───────────────────────────────
                    _SectionCard(
                      title: 'Separation Details',
                      rows: [
                        ('Request Reference', r.requestRef),
                        ('Created By', r.createdByName),
                        ('Separation Type', r.separationTypeDisplay),
                        ('Reason', r.reasonDisplay),
                        ('Request Date', formatSeparationDate(r.requestDate)),
                        ('Proposed Last Working Day',
                            formatSeparationDate(r.proposedLastWorkingDay)),
                        ('Notice Period', '${r.noticePeriodDays} days'),
                        if (r.comments.isNotEmpty) ('Comments', r.comments),
                      ],
                      trailingChild: r.documentUrl != null
                          ? Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: OutlinedButton.icon(
                                onPressed: () => _openDocument(r.documentUrl!),
                                icon: const Icon(Icons.attach_file, size: 15),
                                label: const Text('View / Download Document',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 12),

                    if (r.canEdit || r.canCancel) ...[
                      Row(
                        children: [
                          if (r.canEdit)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _actionLoading
                                    ? null
                                    : () => showSeparationFormSheet(context,
                                        existing: r),
                                icon: const Icon(Icons.edit_outlined, size: 15),
                                label: const Text('Edit',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ),
                          if (r.canEdit && r.canCancel) const SizedBox(width: 10),
                          if (r.canCancel)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed:
                                    _actionLoading ? null : () => _cancel(r),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: BorderSide(color: AppColors.error),
                                ),
                                icon: const Icon(Icons.cancel_outlined, size: 15),
                                label: const Text('Cancel Request',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (r.canDelete) ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _actionLoading ? null : () => _reject(r),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: BorderSide(color: AppColors.error),
                          ),
                          icon: const Icon(Icons.block, size: 15),
                          label: const Text('Reject Request',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // ── Approval ──────────────────────────────────────────
                    SeparationApprovalSection(
                        requestId: r.id, stages: r.approvalStages),
                    const SizedBox(height: 12),

                    // ── KT / Handover ─────────────────────────────────────
                    SeparationHandoverSection(
                      requestId: r.id,
                      canManage: canManage,
                      isOwn: r.isOwn,
                    ),
                    const SizedBox(height: 12),

                    // ── Clearance ─────────────────────────────────────────
                    SeparationClearanceSection(requestId: r.id),
                    const SizedBox(height: 12),

                    // ── Documents ─────────────────────────────────────────
                    SeparationDocumentsSection(
                      requestId: r.id,
                      canUpload: r.isOwn || canManage,
                    ),
                    const SizedBox(height: 12),

                    // ── Activity ──────────────────────────────────────────
                    SeparationActivitySection(requestId: r.id),
                  ],
                ),
              ),
            ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  final Widget? trailingChild;
  const _SectionCard({
    required this.title,
    required this.rows,
    this.trailingChild,
  });

  @override
  Widget build(BuildContext context) {
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
          SeparationSectionHeader(title: title),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 150,
                    child: Text(label,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: Text(value.isEmpty ? '—' : value,
                        style: AppTextStyles.body.copyWith(fontSize: 13)),
                  ),
                ],
              ),
            ),
          if (trailingChild != null) trailingChild!,
        ],
      ),
    );
  }
}

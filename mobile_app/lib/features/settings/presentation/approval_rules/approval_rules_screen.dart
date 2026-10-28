import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_loading_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../branches/presentation/widgets/branch_dlg_header.dart';
import '../../data/models/approval_rule_model.dart';
import '../../data/models/roles_model.dart';
import '../providers/approval_rules_providers.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_page_header.dart';

// Dart port of web's WORKFLOW_ICONS map
// (frontend/app/dashboard/settings/approval-rules/page.tsx).
const _kWorkflowIcons = <String, IconData>{
  'leave': Icons.beach_access_outlined,
  'expense': Icons.account_balance_wallet_outlined,
  'resignation': Icons.logout_outlined,
  'loan': Icons.payments_outlined,
  'attendance_correction': Icons.edit_calendar_outlined,
};

class ApprovalRulesScreen extends ConsumerWidget {
  const ApprovalRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(approvalRulesProvider);
    final permissions = ref.watch(authStateProvider).valueOrNull?.user?.permissions ?? const [];
    final canEdit = permissions.contains('settings.edit');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Approval Rules'),
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => _ErrorView(
          message: friendlyApprovalRulesError(e),
          onRetry: () => ref.invalidate(approvalRulesProvider),
        ),
        data: (rules) {
          return RefreshIndicator(
            onRefresh: () => ref.read(approvalRulesProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                const SettingsPageHeader(
                  icon: Icons.rule_folder_outlined,
                  title: 'Approval Rules',
                  subtitle:
                      'Who approves each workflow type — globally, with per-employee '
                      'overrides available on the employee profile.',
                ),
                const SizedBox(height: 20),
                SettingsSectionHeading(
                  icon: Icons.list_alt_outlined,
                  label: 'Workflows (${rules.length})',
                  color: const Color(0xFF1B3A6B),
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < rules.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _RuleRow(
                    rule: rules[i],
                    canEdit: canEdit,
                    onEdit: () => _openEditor(context, ref, rules[i]),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, ApprovalRuleModel rule) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: _RuleEditorDialog(rule: rule),
      ),
    );
  }
}

// ── Rule row ───────────────────────────────────────────────────────────────────

class _RuleRow extends StatelessWidget {
  final ApprovalRuleModel rule;
  final bool canEdit;
  final VoidCallback onEdit;

  const _RuleRow({required this.rule, required this.canEdit, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final hasL2 = rule.l2ApproverRole != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _kWorkflowIcons[rule.workflowType] ?? Icons.rule_outlined,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.workflowLabel,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _ApproverChip(label: 'L1', value: rule.l1ApproverLabel),
                    _ApproverChip(
                      label: 'L2',
                      value: hasL2 ? rule.l2ApproverLabel : 'Single level',
                      dim: !hasL2,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textSecondary,
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _ApproverChip extends StatelessWidget {
  final String label;
  final String value;
  final bool dim;

  const _ApproverChip({required this.label, required this.value, this.dim = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label ',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700, color: AppColors.textSecondary),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.caption.copyWith(
                color: dim ? AppColors.textHint : AppColors.textPrimary,
                fontStyle: dim ? FontStyle.italic : FontStyle.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Edit dialog ────────────────────────────────────────────────────────────────

class _RuleEditorDialog extends ConsumerStatefulWidget {
  final ApprovalRuleModel rule;

  const _RuleEditorDialog({required this.rule});

  @override
  ConsumerState<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends ConsumerState<_RuleEditorDialog> {
  late int? _l1;
  late int? _l2; // null = single level
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _l1 = widget.rule.l1ApproverRole;
    _l2 = widget.rule.l2ApproverRole;
  }

  // Backend Role ids drift over time (roles get renamed/deactivated) — if the
  // currently-assigned role isn't in the active list, keep it selectable so
  // the dropdown doesn't crash on a value with no matching item.
  List<DropdownMenuItem<int?>> _roleItems(List<RoleModel> roles, int? currentId, String currentLabel) {
    final items = roles
        .map((r) => DropdownMenuItem<int?>(value: r.id as int, child: Text(r.displayName, overflow: TextOverflow.ellipsis)))
        .toList();
    if (currentId != null && !roles.any((r) => r.id == currentId)) {
      items.insert(0, DropdownMenuItem<int?>(value: currentId, child: Text(currentLabel, overflow: TextOverflow.ellipsis)));
    }
    return items;
  }

  Future<void> _save() async {
    if (_l1 == null) {
      setState(() => _error = 'Select an L1 approver role.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await ref.read(approvalRulesProvider.notifier).updateRule(
          workflowType: widget.rule.workflowType,
          l1ApproverRole: _l1!,
          l2ApproverRole: _l2,
        );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final roles = (ref.watch(rolesProvider).valueOrNull ?? []).where((r) => r.isActive).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BranchDlgHeader(
            icon: _kWorkflowIcons[widget.rule.workflowType] ?? Icons.rule_outlined,
            title: 'Edit Rule — ${widget.rule.workflowLabel}',
            subtitle: 'Choose which role approves this workflow at each level',
            onClose: () => Navigator.of(context).pop(),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _Field(
                      label: 'L1 Approver Role *',
                      child: DropdownButtonFormField<int?>(
                        initialValue: _l1,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: _roleItems(roles, _l1, widget.rule.l1ApproverLabel),
                        onChanged: (v) => setState(() => _l1 = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: 'L2 Approver Role (leave blank for single-level)',
                      child: DropdownButtonFormField<int?>(
                        initialValue: _l2,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('— Single level (no L2) —')),
                          ..._roleItems(roles, _l2, widget.rule.l2ApproverLabel),
                        ],
                        onChanged: (v) => setState(() => _l2 = v),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: Text(_saving ? 'Saving…' : 'Save Rule'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;

  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

// ── Error state ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load approval rules', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

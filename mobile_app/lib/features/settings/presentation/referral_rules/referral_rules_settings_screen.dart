import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_loading_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../branches/presentation/widgets/branch_dlg_header.dart';
import '../../../referrals/domain/entities/referral_entity.dart';
import '../../../referrals/presentation/providers/referral_providers.dart';
import '../../../referrals/presentation/widgets/referral_rule_card.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_page_header.dart';

class ReferralRulesSettingsScreen extends ConsumerWidget {
  const ReferralRulesSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(referralRulesAdminProvider);
    final permissions = ref.watch(authStateProvider).valueOrNull?.user?.permissions ?? const [];
    // Backend (ReferralRuleListCreateView/ReferralRuleDetailView) actually
    // authorizes create/update/delete on 'settings.view', not 'settings.edit'.
    final canEdit = permissions.contains('settings.view');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Referral Rules'),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context, ref, null),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Add Rule', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            )
          : null,
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => _ErrorView(message: friendlyReferralError(e), onRetry: () => ref.invalidate(referralRulesAdminProvider)),
        data: (rules) {
          return RefreshIndicator(
            onRefresh: () => ref.read(referralRulesAdminProvider.notifier).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              children: [
                const SettingsPageHeader(
                  icon: Icons.card_giftcard_outlined,
                  title: 'Referral Rules',
                  subtitle: 'Shown to employees on the Referral page. Changes take effect immediately.',
                ),
                const SizedBox(height: 20),
                SettingsSectionHeading(
                  icon: Icons.list_alt_outlined,
                  label: 'Configured Rules (${rules.length})',
                  color: const Color(0xFF7C3AED),
                ),
                const SizedBox(height: 12),
                if (rules.isEmpty)
                  _EmptyView(canEdit: canEdit, onAdd: () => _openEditor(context, ref, null))
                else
                  for (var i = 0; i < rules.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    _RuleRow(
                      rule: rules[i],
                      displayIndex: i + 1,
                      canEdit: canEdit,
                      onEdit: () => _openEditor(context, ref, rules[i]),
                      onDelete: () => _confirmDelete(context, ref, rules[i]),
                    ),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, WidgetRef ref, ReferralRuleEntity? rule) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: _RuleEditorDialog(rule: rule, ref: ref),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, ReferralRuleEntity rule) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete rule?'),
        content: Text('Delete "${rule.title}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final error = await ref.read(referralRulesAdminProvider.notifier).remove(rule.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? '"${rule.title}" deleted.'),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Rule row ───────────────────────────────────────────────────────────────────

class _RuleRow extends StatelessWidget {
  final ReferralRuleEntity rule;
  final int displayIndex;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RuleRow({
    required this.rule,
    required this.displayIndex,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
              color: rule.isActive ? AppColors.primary.withValues(alpha: 0.10) : AppColors.backgroundLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              referralRuleIcon(rule.icon),
              color: rule.isActive ? AppColors.primary : AppColors.textHint,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RULE $displayIndex',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 0.4),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        rule.title,
                        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!rule.isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.backgroundMid, borderRadius: BorderRadius.circular(6)),
                        child: Text('Hidden', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 10)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(rule.body, style: AppTextStyles.bodySecondary),
              ],
            ),
          ),
          if (canEdit) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textSecondary,
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.error,
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Add / Edit dialog ──────────────────────────────────────────────────────────

class _RuleEditorDialog extends StatefulWidget {
  final ReferralRuleEntity? rule;
  final WidgetRef ref;

  const _RuleEditorDialog({required this.rule, required this.ref});

  @override
  State<_RuleEditorDialog> createState() => _RuleEditorDialogState();
}

class _RuleEditorDialogState extends State<_RuleEditorDialog> {
  late String _icon;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _orderCtrl;
  late final TextEditingController _bodyCtrl;
  late bool _isActive;
  bool _saving = false;
  String? _error;

  bool get _isAdd => widget.rule == null;

  @override
  void initState() {
    super.initState();
    final r = widget.rule;
    _icon = r?.icon ?? 'ti-info-circle';
    _titleCtrl = TextEditingController(text: r?.title ?? '');
    _orderCtrl = TextEditingController(text: '${r?.order ?? 1}');
    _bodyCtrl = TextEditingController(text: r?.body ?? '');
    _isActive = r?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _orderCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = 'Title and description are required.');
      return;
    }
    final order = int.tryParse(_orderCtrl.text.trim()) ?? 1;

    setState(() {
      _saving = true;
      _error = null;
    });

    final notifier = widget.ref.read(referralRulesAdminProvider.notifier);
    final error = _isAdd
        ? await notifier.create(icon: _icon, title: title, body: body, order: order, isActive: _isActive)
        : await notifier.edit(widget.rule!.id, icon: _icon, title: title, body: body, order: order, isActive: _isActive);

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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BranchDlgHeader(
            icon: Icons.card_giftcard_outlined,
            title: _isAdd ? 'Add Referral Rule' : 'Edit Rule',
            subtitle: _isAdd ? 'Shown to employees on the Referrals screen' : 'Update this rule\'s details',
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
                        decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: _Field(
                            label: 'Icon',
                            child: DropdownButtonFormField<String>(
                              initialValue: _icon,
                              isExpanded: true,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                              items: kReferralRuleIconOptions
                                  .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (v) => setState(() => _icon = v ?? _icon),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: _Field(
                            label: 'Order',
                            child: TextField(
                              controller: _orderCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: 'Rule Title *',
                      child: TextField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(hintText: 'e.g. Eligibility', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: 'Description *',
                      child: TextField(
                        controller: _bodyCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: 'Explain this rule clearly so employees understand it…',
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show this rule to employees'),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
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

// ── Empty / Error ──────────────────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final bool canEdit;
  final VoidCallback onAdd;

  const _EmptyView({required this.canEdit, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(20)),
              child: Icon(Icons.description_outlined, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No rules configured', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              canEdit ? 'Click "Add Rule" to create the first referral rule.' : 'An admin has not configured any referral rules yet.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            if (canEdit) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Rule'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ],
          ],
        ),
      ),
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
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load referral rules', style: AppTextStyles.h4),
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

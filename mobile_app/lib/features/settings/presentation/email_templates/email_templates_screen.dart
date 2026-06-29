import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/email_template_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import 'widgets/template_card.dart';
import 'widgets/template_editor_sheet.dart';
import 'widgets/template_preview_sheet.dart';

// ── Type metadata ─────────────────────────────────────────────────────────────

class _TypeMeta {
  final Color color;
  final IconData icon;
  final String label;
  const _TypeMeta(this.color, this.icon, this.label);
}

const _kTypeMeta = {
  'document':     _TypeMeta(Color(0xFF1B3A6B), Icons.description_outlined,    'Document Templates'),
  'notification': _TypeMeta(Color(0xFF0D7490), Icons.notifications_outlined,   'Notification Templates'),
  'reminder':     _TypeMeta(Color(0xFFB45309), Icons.alarm_outlined,           'Reminder Templates'),
  'wish':         _TypeMeta(Color(0xFF059669), Icons.celebration_outlined,     'Wish Templates'),
};

const _kTypeOrder = ['document', 'notification', 'reminder', 'wish'];

_TypeMeta _meta(String? type) =>
    _kTypeMeta[type] ?? const _TypeMeta(Color(0xFF6B7280), Icons.mail_outline, 'Other Templates');

// ── Screen ────────────────────────────────────────────────────────────────────

class EmailTemplatesScreen extends ConsumerStatefulWidget {
  const EmailTemplatesScreen({super.key});

  @override
  ConsumerState<EmailTemplatesScreen> createState() => _EmailTemplatesScreenState();
}

class _EmailTemplatesScreenState extends ConsumerState<EmailTemplatesScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(emailTemplatesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Email Templates'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Template',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(message: err.toString()),
        data: (templates) => _buildBody(context, templates),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<EmailTemplateModel> templates) {
    if (templates.isEmpty) return _EmptyView(onAdd: () => _openEditor(context, null));

    final filtered = _search.isEmpty
        ? templates
        : templates.where((t) {
            final q = _search;
            return t.displayName.toLowerCase().contains(q) ||
                t.subject.toLowerCase().contains(q) ||
                (t.description ?? '').toLowerCase().contains(q);
          }).toList();

    // Build grouped flat list: section header + cards
    final groups = <String, List<EmailTemplateModel>>{};
    for (final t in filtered) {
      groups.putIfAbsent(t.templateType ?? 'other', () => []).add(t);
    }

    // Ordered keys (known types first, then any others)
    final orderedKeys = [
      ..._kTypeOrder.where(groups.containsKey),
      ...groups.keys.where((k) => !_kTypeOrder.contains(k)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SubHeader(),
        _SearchBar(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _search = v.toLowerCase()),
        ),
        if (_search.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              '${filtered.length} of ${templates.length} template${templates.length == 1 ? '' : 's'}',
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
            ),
          ),
        Expanded(
          child: filtered.isEmpty
              ? const _NoResultsView()
              : _buildGroupedList(context, orderedKeys, groups),
        ),
      ],
    );
  }

  Widget _buildGroupedList(
    BuildContext context,
    List<String> keys,
    Map<String, List<EmailTemplateModel>> groups,
  ) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: keys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, index) {
        final key = keys[index];
        final templates = groups[key] ?? [];
        return _GroupCard(
          type: key,
          templates: templates,
          onEdit:    (t) => _openEditor(context, t),
          onPreview: (t) => _openPreview(context, t),
          onDelete:  (t) => _confirmDelete(context, t),
          onToggle:  (id, v) => _toggleActive(context, id, v),
        );
      },
    );
  }

  Future<void> _openEditor(BuildContext context, EmailTemplateModel? t) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: TemplateEditorSheet(template: t, ref: ref),
      ),
    );
  }

  Future<void> _openPreview(BuildContext context, EmailTemplateModel t) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: TemplatePreviewSheet(template: t),
      ),
    );
  }

  Future<void> _toggleActive(BuildContext context, int id, bool isActive) async {
    final error = await ref.read(emailTemplatesProvider.notifier).toggleActive(id, isActive);
    if (!context.mounted || error == null) return;
    _toast(context, error, false);
  }

  Future<void> _confirmDelete(BuildContext context, EmailTemplateModel t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete template?'),
        content: Text('Delete "${t.displayName}"? This cannot be undone.'),
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
    final error = await ref.read(emailTemplatesProvider.notifier).remove(t.id);
    if (context.mounted) _toast(context, error ?? '"${t.displayName}" deleted.', error == null);
  }

  void _toast(BuildContext context, String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Group card — header banner fused to the top of the card ──────────────────

class _GroupCard extends StatelessWidget {
  final String type;
  final List<EmailTemplateModel> templates;
  final void Function(EmailTemplateModel) onEdit;
  final void Function(EmailTemplateModel) onPreview;
  final void Function(EmailTemplateModel) onDelete;
  final void Function(int id, bool v) onToggle;

  const _GroupCard({
    required this.type,
    required this.templates,
    required this.onEdit,
    required this.onPreview,
    required this.onDelete,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final meta = _meta(type);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Colored banner — clipped to card's rounded top corners ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: meta.color,
            child: Row(
              children: [
                Icon(meta.icon, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    meta.label,
                    style: AppTextStyles.label.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '${templates.length} template${templates.length == 1 ? '' : 's'}',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          // ── Template rows with dividers ──────────────────────────────
          ...List.generate(templates.length, (i) {
            final t = templates[i];
            return Column(
              children: [
                const Divider(height: 1, color: AppColors.border),
                TemplateCard(
                  flat: true,
                  template: t,
                  onEdit:         () => onEdit(t),
                  onPreview:      () => onPreview(t),
                  onDelete:       t.isBuiltin ? null : () => onDelete(t),
                  onToggleActive: (v) => onToggle(t.id, v),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Sub-header ────────────────────────────────────────────────────────────────

class _SubHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        'Customize transactional email messages sent by Royal HRMS',
        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: controller,
        style: AppTextStyles.body,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: 'Search templates...',
          hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textHint),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () { controller.clear(); onChanged(''); },
                )
              : null,
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
    );
  }
}

// ── Empty / Error / No results ────────────────────────────────────────────────

class _EmptyView extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyView({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.mail_outline, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('No email templates', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Create templates to personalise transactional emails sent by the system.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Template'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultsView extends StatelessWidget {
  const _NoResultsView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off, size: 40, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('No templates match your search', style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text('Try a different keyword.', style: AppTextStyles.bodySecondary),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load templates', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../approvals/presentation/widgets/approvals_kit.dart';
import '../../../../approvals/presentation/widgets/approvals_ui.dart' show ApprovalsIconBox;
import '../../../data/models/email_template_model.dart';

/// Icon, accent colour (theme tokens only) and heading for a template type.
IconData templateTypeIcon(String? type) => switch (type) {
      'document' => Icons.description_outlined,
      'notification' => Icons.notifications_outlined,
      'reminder' => Icons.alarm_outlined,
      'wish' => Icons.celebration_outlined,
      _ => Icons.mail_outline,
    };

Color templateTypeColor(String? type) => switch (type) {
      'document' => AppColors.primary,
      'notification' => AppColors.info,
      'reminder' => AppColors.warning,
      'wish' => AppColors.success,
      _ => AppColors.textSecondary,
    };

/// One email template as a card: type icon + accent edge, name, status and
/// origin chips, the Active switch, description, the subject line, and
/// labelled Preview / Edit (/ Delete for custom templates) actions.
class TemplateCard extends StatelessWidget {
  final EmailTemplateModel template;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback? onDelete;
  final ValueChanged<bool> onToggleActive;

  const TemplateCard({
    super.key,
    required this.template,
    required this.onEdit,
    required this.onPreview,
    this.onDelete,
    required this.onToggleActive,
  });

  ButtonStyle _action(Color color) => TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
      );

  @override
  Widget build(BuildContext context) {
    final t = template;
    final accent = templateTypeColor(t.templateType);
    final description = (t.description ?? '').trim();
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    final toggle = Semantics(
      label: 'Active',
      toggled: t.isActive,
      child: Tooltip(
        message: t.isActive ? 'Deactivate' : 'Activate',
        child: Switch(
          key: Key('template-toggle-${t.id}'),
          value: t.isActive,
          onChanged: onToggleActive,
          activeThumbColor: Colors.white,
          activeTrackColor: AppColors.primary,
          materialTapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );

    return Container(
      key: Key('template-card-${t.id}'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // Type-coloured accent edge (as the Assets and Announcements cards).
        Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: accent)),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Opacity(
                opacity: t.isActive ? 1 : 0.72,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  LayoutBuilder(builder: (context, c) {
                    final stacked = c.maxWidth < 250 || scale > 1.3;
                    final title = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(t.displayName,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.label.copyWith(fontSize: 15, fontWeight: FontWeight.w700, height: 1.3)),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        _StatusPill(active: t.isActive),
                        ApprovalsChip(t.isBuiltin ? 'Built-in' : 'Custom',
                            icon: t.isBuiltin ? Icons.lock_outline : Icons.edit_note_outlined),
                      ]),
                    ]);
                    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (!stacked) ...[
                        ApprovalsIconBox(templateTypeIcon(t.templateType), color: accent, size: 40),
                        const SizedBox(width: 10)
                      ],
                      Expanded(child: title),
                    ]);
                  }),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary, height: 1.4)),
                  ],
                  const SizedBox(height: 10),
                  Container(
                    key: Key('template-subject-${t.id}'),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: AppColors.backgroundLow, borderRadius: BorderRadius.circular(10)),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.mail_outline, size: 15, color: AppColors.textSecondary),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Subject',
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 10.5, color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 1),
                          Text(t.subject,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary)),
                        ]),
                      ),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 6),
              Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
              Row(children: [
                Expanded(
                  child: Wrap(spacing: 2, children: [
                    TextButton.icon(
                      key: Key('template-preview-${t.id}'),
                      onPressed: onPreview,
                      style: _action(AppColors.primary),
                      icon: const Icon(Icons.visibility_outlined, size: 18),
                      label: const Text('Preview'),
                    ),
                    TextButton.icon(
                      key: Key('template-edit-${t.id}'),
                      onPressed: onEdit,
                      style: _action(AppColors.primary),
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                    ),
                    if (onDelete != null)
                      TextButton.icon(
                        key: Key('template-delete-${t.id}'),
                        onPressed: onDelete,
                        style: _action(AppColors.error),
                        icon: const Icon(Icons.delete_outline, size: 18),
                        label: const Text('Delete'),
                      ),
                  ]),
                ),
                toggle,
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Active / Inactive: a word and a dot, so colour is never the only signal.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    final c = active ? AppColors.success : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(active ? 'Active' : 'Inactive',
            style: AppTextStyles.caption.copyWith(color: c, fontWeight: FontWeight.w700, fontSize: 11.5)),
      ]),
    );
  }
}

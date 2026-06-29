import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/email_template_model.dart';

// Type-to-icon/color helpers shared with screen
IconData _typeIcon(String? type) => switch (type) {
  'document'     => Icons.description_outlined,
  'notification' => Icons.notifications_outlined,
  'reminder'     => Icons.alarm_outlined,
  'wish'         => Icons.celebration_outlined,
  _              => Icons.mail_outline,
};

Color _typeColor(String? type) => switch (type) {
  'document'     => const Color(0xFF1B3A6B),
  'notification' => const Color(0xFF0D7490),
  'reminder'     => const Color(0xFFB45309),
  'wish'         => const Color(0xFF059669),
  _              => AppColors.primary,
};

class TemplateCard extends StatelessWidget {
  final EmailTemplateModel template;
  final VoidCallback onEdit;
  final VoidCallback onPreview;
  final VoidCallback? onDelete;
  final ValueChanged<bool> onToggleActive;
  // flat=true: no outer card box — used when card lives inside a group container
  final bool flat;

  const TemplateCard({
    super.key,
    required this.template,
    required this.onEdit,
    required this.onPreview,
    this.onDelete,
    required this.onToggleActive,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(template.templateType);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardBody(template: template, color: color, onPreview: onPreview, onEdit: onEdit),
        _CardFooter(
          template: template,
          onDelete: onDelete,
          onToggleActive: onToggleActive,
        ),
      ],
    );

    if (flat) return content;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: content,
    );
  }
}

// ── Card body ─────────────────────────────────────────────────────────────────

class _CardBody extends StatelessWidget {
  final EmailTemplateModel template;
  final Color color;
  final VoidCallback onPreview;
  final VoidCallback onEdit;

  const _CardBody({
    required this.template,
    required this.color,
    required this.onPreview,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TypeIcon(color: color, type: template.templateType),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.displayName,
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (template.description != null && template.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    template.description!,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  template.subject,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint,
                    fontFamily: 'monospace',
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _ActionButtons(onPreview: onPreview, onEdit: onEdit),
        ],
      ),
    );
  }
}

class _TypeIcon extends StatelessWidget {
  final Color color;
  final String? type;
  const _TypeIcon({required this.color, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(_typeIcon(type), color: color, size: 20),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VoidCallback onPreview;
  final VoidCallback onEdit;
  const _ActionButtons({required this.onPreview, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconBtn(
          icon: Icons.visibility_outlined,
          tooltip: 'Preview',
          onTap: onPreview,
        ),
        _IconBtn(
          icon: Icons.edit_outlined,
          tooltip: 'Edit',
          onTap: onEdit,
          color: AppColors.primary,
        ),
      ],
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color color;
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color = AppColors.textSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }
}

// ── Card footer ───────────────────────────────────────────────────────────────

class _CardFooter extends StatelessWidget {
  final EmailTemplateModel template;
  final VoidCallback? onDelete;
  final ValueChanged<bool> onToggleActive;

  const _CardFooter({
    required this.template,
    required this.onDelete,
    required this.onToggleActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 8, 10, 8),
      child: Row(
        children: [
          _StatusBadge(isActive: template.isActive),
          if (template.isBuiltin) ...[
            const SizedBox(width: 8),
            _BuiltinBadge(),
          ],
          const Spacer(),
          if (onDelete != null)
            _IconBtn(
              icon: Icons.delete_outline,
              tooltip: 'Delete',
              onTap: onDelete!,
              color: AppColors.error,
            ),
          const SizedBox(width: 4),
          Transform.scale(
            scale: 0.8,
            alignment: Alignment.centerRight,
            child: Switch(
              value: template.isActive,
              onChanged: onToggleActive,
              activeThumbColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isActive;
  const _StatusBadge({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isActive ? AppColors.success : AppColors.textHint).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: (isActive ? AppColors.success : AppColors.border).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5, height: 5,
            decoration: BoxDecoration(
              color: isActive ? AppColors.success : AppColors.textHint,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isActive ? 'Active' : 'Inactive',
            style: AppTextStyles.caption.copyWith(
              color: isActive ? AppColors.success : AppColors.textHint,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _BuiltinBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        'Built-in',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

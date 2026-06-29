import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/smtp_model.dart';

class SmtpCard extends StatelessWidget {
  final SmtpModel entry;
  final VoidCallback onEdit;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  final VoidCallback onTest;

  const SmtpCard({
    super.key,
    required this.entry,
    required this.onEdit,
    required this.onActivate,
    required this.onDelete,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: entry.isActive ? AppColors.primary : AppColors.border,
          width: entry.isActive ? 1.5 : 1,
        ),
        boxShadow: entry.isActive
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.10), blurRadius: 12, offset: const Offset(0, 4))]
            : AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardHeader(entry: entry),
          const Divider(height: 1, color: AppColors.border),
          _FieldGrid(entry: entry),
          const Divider(height: 1, color: AppColors.border),
          _CardFooter(
            entry: entry,
            onEdit: onEdit,
            onActivate: onActivate,
            onDelete: onDelete,
            onTest: onTest,
          ),
        ],
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _CardHeader extends StatelessWidget {
  final SmtpModel entry;
  const _CardHeader({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (entry.isActive ? AppColors.primary : AppColors.textHint)
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              entry.smtpType == 'server' ? Icons.dns_outlined : Icons.home_outlined,
              size: 20,
              color: entry.isActive ? AppColors.primary : AppColors.textHint,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.smtpTypeDisplay.isNotEmpty
                      ? '${entry.name} — ${entry.smtpTypeDisplay}'
                      : entry.name,
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  'Updated ${_formatDate(entry.updatedAt)}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textHint, fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusBadge(isActive: entry.isActive),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final m = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour >= 12 ? 'pm' : 'am';
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m $ampm';
    } catch (_) {
      return iso;
    }
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
        color: isActive
            ? AppColors.success.withValues(alpha: 0.10)
            : AppColors.textHint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isActive) ...[
            Container(
              width: 6, height: 6,
              decoration: const BoxDecoration(color: AppColors.success, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
          ],
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

// ── Field grid ────────────────────────────────────────────────────────────────

class _FieldGrid extends StatelessWidget {
  final SmtpModel entry;
  const _FieldGrid({required this.entry});

  @override
  Widget build(BuildContext context) {
    final portLabel = entry.useTls ? '${entry.port} · TLS' : '${entry.port}';
    final priorityLabel = switch (entry.priority) {
      SmtpPriority.high   => 'High',
      SmtpPriority.normal => 'Normal',
      SmtpPriority.low    => 'Low',
      SmtpPriority.none   => '—',
    };
    final receiverLabel = entry.receiverEmailType == ReceiverEmailType.personalEmailId
        ? 'Personal Email ID'
        : 'Email ID';

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        children: [
          _FieldRow(
            left:  _FieldCell(label: 'HOST', value: entry.host.isNotEmpty ? entry.host : '—'),
            right: _FieldCell(
              label: 'PORT',
              value: portLabel,
              valueColor: entry.useTls ? AppColors.success : null,
            ),
          ),
          const SizedBox(height: 10),
          _FieldRow(
            left:  _FieldCell(label: 'FROM EMAIL', value: entry.fromEmail.isNotEmpty ? entry.fromEmail : '—'),
            right: _FieldCell(label: 'SENDER NAME', value: entry.senderName.isNotEmpty ? entry.senderName : '—'),
          ),
          const SizedBox(height: 10),
          _FieldRow(
            left:  _FieldCell(label: 'USERNAME', value: entry.username.isNotEmpty ? entry.username : '—'),
            right: _FieldCell(
              label: 'PASSWORD',
              value: entry.passwordDisplay.isNotEmpty ? entry.passwordDisplay : '—',
              monospace: true,
            ),
          ),
          const SizedBox(height: 10),
          _FieldRow(
            left:  _FieldCell(label: 'BCC EMAIL', value: entry.bccEmail.isNotEmpty ? entry.bccEmail : '—'),
            right: _FieldCell(label: 'PRIORITY', value: priorityLabel),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: _FieldCell(label: 'RECEIVER EMAIL', value: receiverLabel),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const _FieldRow({required this.left, required this.right});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: left),
      const SizedBox(width: 12),
      Expanded(child: right),
    ],
  );
}

class _FieldCell extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final bool monospace;
  const _FieldCell({
    required this.label,
    required this.value,
    this.valueColor,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            fontSize: 10,
            color: AppColors.textHint,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: AppTextStyles.caption.copyWith(
            color: valueColor ?? AppColors.textPrimary,
            fontWeight: FontWeight.w500,
            fontFamily: monospace ? 'monospace' : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

class _CardFooter extends StatelessWidget {
  final SmtpModel entry;
  final VoidCallback onEdit;
  final VoidCallback onActivate;
  final VoidCallback onDelete;
  final VoidCallback onTest;

  const _CardFooter({
    required this.entry,
    required this.onEdit,
    required this.onActivate,
    required this.onDelete,
    required this.onTest,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          if (!entry.isActive) ...[
            _FooterBtn(
              icon: Icons.star_outline,
              label: 'Set Active',
              color: AppColors.primary,
              onTap: onActivate,
            ),
            const SizedBox(width: 6),
          ],
          _FooterBtn(
            icon: Icons.send_outlined,
            label: 'Test',
            color: AppColors.textSecondary,
            onTap: onTest,
          ),
          const Spacer(),
          _FooterIconBtn(
            icon: Icons.delete_outline,
            color: AppColors.error,
            tooltip: 'Delete',
            onTap: onDelete,
          ),
          const SizedBox(width: 4),
          _FooterIconBtn(
            icon: Icons.edit_outlined,
            color: AppColors.primary,
            tooltip: 'Edit',
            onTap: onEdit,
            filled: true,
          ),
        ],
      ),
    );
  }
}

class _FooterBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _FooterBtn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _FooterIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  final bool filled;
  const _FooterIconBtn({required this.icon, required this.color, required this.tooltip, required this.onTap, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: filled ? color : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: filled ? 0 : 0.2)),
          ),
          child: Icon(icon, size: 16, color: filled ? Colors.white : color),
        ),
      ),
    );
  }
}

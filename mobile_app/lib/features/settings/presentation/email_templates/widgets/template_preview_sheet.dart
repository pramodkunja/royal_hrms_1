import 'package:flutter/material.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/email_template_model.dart';

class TemplatePreviewSheet extends StatelessWidget {
  final EmailTemplateModel template;
  const TemplatePreviewSheet({super.key, required this.template});

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DlgHeader(
            template: template,
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  children: [
                    _subjectSection(),
                    const SizedBox(height: 16),
                    _bodySection(),
                    if (template.availableVariables.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _variablesSection(),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subjectSection() => _Section(
    label: 'SUBJECT',
    child: Text(
      template.subject,
      style: AppTextStyles.body.copyWith(fontFamily: 'monospace'),
    ),
  );

  Widget _bodySection() => _Section(
    label: 'BODY PREVIEW',
    note: 'HTML tags stripped for readability',
    child: Text(
      _stripHtml(template.body),
      style: AppTextStyles.body.copyWith(height: 1.6),
    ),
  );

  Widget _variablesSection() => _Section(
    label: 'AVAILABLE VARIABLES',
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: template.availableVariables
          .map((v) => _VarChip(label: v))
          .toList(),
    ),
  );
}

class _Section extends StatelessWidget {
  final String label;
  final String? note;
  final Widget child;
  const _Section({required this.label, required this.child, this.note});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                color: AppColors.textHint,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            if (note != null) ...[
              const SizedBox(width: 8),
              Text(
                '· $note',
                style: AppTextStyles.caption.copyWith(fontSize: 10, color: AppColors.textHint),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: child,
        ),
      ],
    );
  }
}

class _VarChip extends StatelessWidget {
  final String label;
  const _VarChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(
        '{$label}',
        style: AppTextStyles.caption.copyWith(
          fontFamily: 'monospace',
          color: AppColors.primary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _DlgHeader extends StatelessWidget {
  final EmailTemplateModel template;
  final VoidCallback onClose;
  const _DlgHeader({required this.template, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.visibility_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.displayName,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(template.category ?? 'Email Template',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

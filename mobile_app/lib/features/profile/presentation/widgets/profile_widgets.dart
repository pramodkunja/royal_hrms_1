import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Two-up field layout that stacks when the row is too narrow or the system
/// text is enlarged, so labels, values and inputs never clip or overflow.
class ProfileTwoUp extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double gap;
  const ProfileTwoUp({super.key, required this.left, required this.right, this.gap = 12});

  /// Below this width, or above this text scale, the pair becomes a column.
  static const double kMinPairWidth = 300;
  static const double kMaxPairTextScale = 1.3;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < kMinPairWidth || scale > kMaxPairTextScale;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [left, SizedBox(height: gap + 2), right],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Expanded(child: left), SizedBox(width: gap), Expanded(child: right)],
        );
      },
    );
  }
}

/// Card section with icon + title header and divider.
class ProfileSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;
  const ProfileSectionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: AppTextStyles.label.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Labeled, editable text field for profile forms. A password field gets a
/// show/hide toggle (as on web).
class ProfileField extends StatefulWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int maxLines;
  const ProfileField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  @override
  State<ProfileField> createState() => _ProfileFieldState();
}

class _ProfileFieldState extends State<ProfileField> {
  bool _hidden = true;

  OutlineInputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));

  @override
  Widget build(BuildContext context) {
    final obscured = widget.obscureText && _hidden;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: widget.controller,
          obscureText: obscured,
          keyboardType: widget.keyboardType,
          minLines: widget.obscureText ? 1 : null,
          maxLines: widget.obscureText ? 1 : widget.maxLines,
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            filled: true,
            fillColor: AppColors.surface,
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.primary, 1.5),
            suffixIcon: widget.obscureText
                ? IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    icon: Icon(_hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        size: 18, color: AppColors.textHint),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

/// Two editable fields side by side (stacked on narrow screens / large text).
class ProfileFieldRow extends StatelessWidget {
  final Widget left;
  final Widget right;
  const ProfileFieldRow({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) => ProfileTwoUp(left: left, right: right);
}

/// Read-only label + value. Plain text under a small label (no boxed input
/// look, so it doesn't read as editable); long values wrap instead of being
/// cut off, and an empty value shows the "—" placeholder.
class ProfileDisplayField extends StatelessWidget {
  final String label;
  final String value;
  final bool padBottom;
  final int? maxLines;
  final IconData? trailingIcon;
  const ProfileDisplayField({
    super.key,
    required this.label,
    required this.value,
    this.padBottom = true,
    this.maxLines,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = value.isEmpty || value == '—';
    return Padding(
      padding: EdgeInsets.only(bottom: padBottom ? 14 : 0),
      child: Semantics(
        container: true,
        label: label,
        value: isEmpty ? 'Not provided' : value,
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      isEmpty ? '—' : value,
                      style: AppTextStyles.body.copyWith(
                        color: isEmpty ? AppColors.textHint : AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                      maxLines: maxLines,
                      overflow: maxLines == null ? TextOverflow.clip : TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, size: 14, color: AppColors.textHint),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two read-only display fields placed side by side (stacked when narrow).
class ProfileDisplayFieldRow extends StatelessWidget {
  final String label1;
  final String value1;
  final String label2;
  final String value2;
  final bool padBottom;
  const ProfileDisplayFieldRow({
    super.key,
    required this.label1,
    required this.value1,
    required this.label2,
    required this.value2,
    this.padBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: padBottom ? 14 : 0),
      child: ProfileTwoUp(
        left: ProfileDisplayField(label: label1, value: value1, padBottom: false),
        right: ProfileDisplayField(label: label2, value: value2, padBottom: false),
      ),
    );
  }
}

/// Single document list item with file icon, metadata and a "View" action
/// that opens [fileUrl] externally (mirrors the pattern used by
/// features/leave/presentation/widgets/leave_request_detail_sheet.dart and
/// features/documents/presentation/widgets/document_detail_dialog.dart).
class ProfileDocumentItem extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback? onView;
  const ProfileDocumentItem({
    super.key,
    required this.name,
    this.subtitle = '',
    this.onView,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.insert_drive_file_outlined, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          if (onView != null)
            GestureDetector(
              onTap: onView,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLow,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.visibility_outlined, size: 16, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../../shared/formatters/en_in_format.dart';
import '../../../data/models/company_model.dart';
import '../../../domain/company_validation.dart' show isSvgLogo;
import '../company_logo_svg.dart';

// Building blocks for the Company Information screen (Premium Minimal, as My
// Profile): plain label-over-value read-only fields, light cards, one primary
// action.

/// Upper-cases as the user types (web `handleField(…, value.toUpperCase())`).
class UpperCaseFormatter extends TextInputFormatter {
  const UpperCaseFormatter();
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Editable field: label above (web's label, `*` when required), input below,
/// the validation message under it.
class CompanyField extends StatelessWidget {
  const CompanyField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
    this.hint,
    this.errorText,
    this.maxLines = 1,
    this.maxLength,
    this.keyboardType,
    this.formatters = const [],
    this.capitalization = TextCapitalization.none,
    this.fieldKey,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? errorText;
  final int maxLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter> formatters;
  final TextCapitalization capitalization;
  final ValueChanged<String> onChanged;
  final GlobalKey? fieldKey;

  OutlineInputBorder _border(Color c, [double w = 1]) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: c, width: w));

  @override
  Widget build(BuildContext context) {
    return Column(
      key: fieldKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          minLines: 1,
          maxLines: maxLines,
          onChanged: onChanged,
          inputFormatters: [...formatters, if (maxLength != null) LengthLimitingTextInputFormatter(maxLength)],
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            errorText: errorText,
            errorMaxLines: 3,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            filled: true,
            fillColor: AppColors.surface,
            border: _border(AppColors.border),
            enabledBorder: _border(AppColors.border),
            focusedBorder: _border(AppColors.primary, 1.5),
            errorBorder: _border(AppColors.error),
            focusedErrorBorder: _border(AppColors.error, 1.5),
          ),
        ),
      ],
    );
  }
}

enum CompanyBadgeTone { success, warn, neutral, error, info }

/// Small status pill (web's `badge badge-*`).
class CompanyBadge extends StatelessWidget {
  const CompanyBadge(this.text, this.tone, {super.key});
  final String text;
  final CompanyBadgeTone tone;

  Color get _color => switch (tone) {
        CompanyBadgeTone.success => AppColors.success,
        CompanyBadgeTone.warn => AppColors.warning,
        CompanyBadgeTone.error => AppColors.error,
        CompanyBadgeTone.info => AppColors.info,
        CompanyBadgeTone.neutral => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: _color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(
          text,
          style: AppTextStyles.caption.copyWith(color: _color, fontWeight: FontWeight.w700, fontSize: 11),
        ),
      );
}

/// The company logo, `contain`-fitted (web `objectFit: contain`): JPEG, PNG
/// and WebP as images, SVG through flutter_svg. A saved SVG is fetched once
/// (see company_logo_svg.dart). Anything that can't be drawn — a malformed or
/// unsupported SVG, a broken link — shows the logo icon instead of an error.
class CompanyLogoView extends ConsumerWidget {
  const CompanyLogoView({super.key, this.url, this.file, this.size = 72});
  final String? url;
  final File? file;
  final double size;

  Widget _icon() => Center(child: Icon(Icons.business_outlined, size: size * 0.42, color: AppColors.textHint));

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget child = _icon();
    if (file != null) {
      child = isSvgLogo(file!)
          ? SvgPicture.file(file!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _icon())
          : Image.file(file!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _icon());
    } else if (url != null && url!.isNotEmpty) {
      if (isSvgUrl(url!)) {
        final bytes = ref.watch(companyLogoSvgProvider(url!)).valueOrNull;
        if (bytes != null) child = SvgPicture.memory(bytes, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _icon());
      } else {
        child = Image.network(url!, fit: BoxFit.contain, errorBuilder: (_, __, ___) => _icon());
      }
    }
    return Semantics(
      label: 'Company logo',
      image: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.backgroundLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(6),
        child: child,
      ),
    );
  }
}

/// Identity header: logo, company name, trade name, location and when the
/// details were last saved — only what the company APIs return.
class CompanyHeaderCard extends StatelessWidget {
  const CompanyHeaderCard({super.key, required this.company, this.logoUrl, this.logoFile});

  final CompanyModel company;

  /// The logo to show (null when removed or none).
  final String? logoUrl;
  final File? logoFile;

  @override
  Widget build(BuildContext context) {
    final location = [company.city, company.state].where((s) => s.trim().isNotEmpty).join(', ');
    final saved = DateTime.tryParse(company.updatedAt ?? '');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CompanyLogoView(url: logoUrl, file: logoFile),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  company.companyName.isEmpty ? 'Your Company' : company.companyName,
                  style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700),
                ),
                if (company.tradeName.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    company.tradeName,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 13, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(location, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                      ),
                    ],
                  ),
                ],
                if (saved != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.schedule, size: 13, color: AppColors.textHint),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          'Last saved: ${formatEnInDateTime(saved.toLocal())}',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Company Settings sections (web shows the tab bar to settings.edit only).
enum CompanyTab {
  info('Company Information', Icons.business_outlined),
  plan('Plan Details', Icons.workspace_premium_outlined);

  const CompanyTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class CompanyTabStrip extends StatelessWidget {
  const CompanyTabStrip({super.key, required this.selected, required this.onSelected});
  final CompanyTab selected;
  final ValueChanged<CompanyTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final t in CompanyTab.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Semantics(
                button: true,
                selected: t == selected,
                label: t.label,
                child: ChoiceChip(
                  key: ValueKey('company-tab-${t.name}'),
                  avatar: Icon(t.icon, size: 16, color: t == selected ? Colors.white : AppColors.textSecondary),
                  label: Text(t.label),
                  selected: t == selected,
                  showCheckmark: false,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(color: t == selected ? AppColors.primary : AppColors.border),
                  labelStyle: AppTextStyles.bodySmall.copyWith(
                    color: t == selected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  onSelected: (_) => onSelected(t),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

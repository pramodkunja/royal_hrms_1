import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../settings/data/models/email_template_model.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/models/employee_model.dart';
import '../providers/employee_providers.dart';

/// Bottom sheet for manually sending a "wish" email to an employee — mirrors
/// web's `SendWishModal.tsx`. Shared by all three occasion cards on the
/// Wishes tab (birthday / anniversary / other); [occasionKey] just biases
/// which active template gets pre-selected.
class SendWishSheet extends ConsumerStatefulWidget {
  final EmployeeModel employee;
  final String occasionKey;

  const SendWishSheet({
    super.key,
    required this.employee,
    required this.occasionKey,
  });

  static Future<bool> show(
    BuildContext context, {
    required EmployeeModel employee,
    required String occasionKey,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          SendWishSheet(employee: employee, occasionKey: occasionKey),
    );
    return result ?? false;
  }

  @override
  ConsumerState<SendWishSheet> createState() => _SendWishSheetState();
}

class _SendWishSheetState extends ConsumerState<SendWishSheet> {
  // null = no explicit user pick yet → auto-preferred template wins.
  EmailTemplateModel? _manualSelected;
  bool _sending = false;
  String? _error;

  // ── Template variable substitution ────────────────────────────────────────
  // Mirrors frontend/lib/emailPreview.ts's `renderTemplateVars` /
  // `normalizeExtraContext`, and SendWishModal.tsx's `employeeVars()`.

  Map<String, String> _employeeVars(String companyName) {
    final emp = widget.employee;
    final parts = emp.fullName.trim().split(RegExp(r'\s+'));
    final firstName = parts.isNotEmpty && parts.first.isNotEmpty
        ? parts.first
        : emp.fullName;
    final lastName = parts.length > 1 ? parts.last : '';
    return {
      'employee_name': emp.fullName,
      'full_name': emp.fullName,
      'name': emp.fullName,
      'recipient_name': emp.fullName,
      'first_name': firstName,
      'last_name': lastName,
      'fname': firstName,
      'lname': lastName,
      'email': emp.email,
      'department': emp.department,
      'designation': emp.designation,
      'company_name': companyName,
      'company': companyName,
    };
  }

  /// Expands every key into its original, lowercase, and uppercase form so
  /// the backend substitutes {FNAME}, {fname}, {Fname} from the same value —
  /// same purpose as the frontend's `normalizeExtraContext`.
  Map<String, String> _normalizeExtraContext(Map<String, String> vars) {
    final out = <String, String>{};
    for (final entry in vars.entries) {
      out[entry.key] = entry.value;
      out[entry.key.toLowerCase()] = entry.value;
      out[entry.key.toUpperCase()] = entry.value;
    }
    return out;
  }

  /// Replaces every {anything} placeholder, case-insensitively. Unrecognised
  /// placeholders are left visible — same behaviour as `renderTemplateVars`.
  String _renderTemplateVars(String text, Map<String, String> vars) {
    final lookup = <String, String>{
      for (final e in vars.entries) e.key.toLowerCase(): e.value,
    };
    return text.replaceAllMapped(RegExp(r'\{([^}]+)\}'), (m) {
      final tag = m.group(1)!;
      final normalized = tag.toLowerCase();
      if (lookup.containsKey(normalized)) {
        final v = lookup[normalized]!;
        return v.isEmpty ? '[$tag]' : v;
      }
      return '{$tag}';
    });
  }

  static String _stripHtml(String html) => html
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();

  Future<void> _confirm(EmailTemplateModel template, String companyName) async {
    setState(() {
      _sending = true;
      _error = null;
    });
    final vars = _employeeVars(companyName);
    final err = await sendEmployeeWishEmail(
      ref,
      employeeId: widget.employee.employeeId,
      templateName: template.name,
      extraContext: _normalizeExtraContext(vars),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (err == null) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(emailTemplatesProvider);
    final companyAsync = ref.watch(companyProvider);

    final loadingTemplates = templatesAsync.isLoading && !templatesAsync.hasValue;
    final activeTemplates =
        (templatesAsync.valueOrNull ?? []).where((t) => t.isActive).toList();

    final preferred = activeTemplates.isEmpty
        ? null
        : activeTemplates.firstWhere(
            (t) => t.name.toLowerCase().contains(widget.occasionKey),
            orElse: () => activeTemplates.first,
          );
    final manualStillValid = _manualSelected != null &&
        activeTemplates.any((t) => t.id == _manualSelected!.id);
    final selected = manualStillValid ? _manualSelected : preferred;

    final company = companyAsync.valueOrNull;
    final companyName =
        (company?.companyName.isNotEmpty ?? false) ? company!.companyName : '[Company]';

    final vars = _employeeVars(companyName);
    final subjectPreview =
        selected == null ? '' : _renderTemplateVars(selected.subject, vars);
    final bodyPreview = selected == null
        ? ''
        : _stripHtml(_renderTemplateVars(selected.body, vars));

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Header ───────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 14),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.celebration_outlined,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Send Wish — ${widget.employee.fullName}',
                        style: AppTextStyles.h4.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: AppColors.textHint,
                      onPressed: () => Navigator.pop(context, false),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),

              // ── Body ─────────────────────────────────────────────────────
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 16, color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: AppTextStyles.body.copyWith(
                                    fontSize: 12,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Recipient info
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.infoContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.send_outlined,
                                size: 15, color: AppColors.info),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  style: AppTextStyles.body
                                      .copyWith(fontSize: 12, color: AppColors.textPrimary),
                                  children: [
                                    const TextSpan(text: 'Sending a wish email to '),
                                    TextSpan(
                                      text: widget.employee.fullName,
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                    if (widget.employee.email.isNotEmpty) ...[
                                      const TextSpan(text: ' at '),
                                      TextSpan(
                                        text: widget.employee.email,
                                        style: const TextStyle(fontWeight: FontWeight.w700),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Template selector
                      Text(
                        'Wish Template *',
                        style: AppTextStyles.caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (loadingTemplates)
                        Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text('Loading templates…',
                                style: AppTextStyles.caption),
                          ],
                        )
                      else if (activeTemplates.isEmpty)
                        Text(
                          'No active templates — create one in Settings → Email Templates.',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.warning),
                        )
                      else
                        DropdownButtonFormField<EmailTemplateModel>(
                          initialValue: selected,
                          isExpanded: true,
                          style: AppTextStyles.body,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: BorderSide(
                                  color: AppColors.primary, width: 1.5),
                            ),
                            isDense: true,
                          ),
                          items: activeTemplates
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(
                                      t.category == null || t.category!.isEmpty
                                          ? t.displayName
                                          : '${t.displayName}  ·  ${t.category}',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ))
                              .toList(),
                          onChanged: (t) => setState(() => _manualSelected = t),
                        ),

                      if (selected != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'EMAIL PREVIEW',
                          style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textHint,
                            letterSpacing: 0.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.employee.email.isNotEmpty) ...[
                                Text.rich(
                                  TextSpan(
                                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                                    children: [
                                      const TextSpan(
                                          text: 'To: ',
                                          style: TextStyle(fontWeight: FontWeight.w700)),
                                      TextSpan(text: widget.employee.email),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 4),
                              ],
                              Text.rich(
                                TextSpan(
                                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                                  children: [
                                    const TextSpan(
                                        text: 'Subject: ',
                                        style: TextStyle(fontWeight: FontWeight.w700)),
                                    TextSpan(text: subjectPreview),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Divider(height: 1, color: AppColors.border),
                              const SizedBox(height: 10),
                              Text(
                                bodyPreview,
                                style: AppTextStyles.body.copyWith(height: 1.5, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // ── Footer ───────────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: (_sending || loadingTemplates || selected == null)
                            ? null
                            : () => _confirm(selected, companyName),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.celebration_outlined, size: 16),
                        label: Text(_sending ? 'Sending…' : 'Confirm & Send Wish'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

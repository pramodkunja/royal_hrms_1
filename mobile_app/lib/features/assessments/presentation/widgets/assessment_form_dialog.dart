import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FilteringTextInputFormatter;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import '../providers/assessments_providers.dart';

class AssessmentFormDialog extends StatefulWidget {
  final AssessmentModel? assessment;
  final WidgetRef ref;

  const AssessmentFormDialog({super.key, this.assessment, required this.ref});

  @override
  State<AssessmentFormDialog> createState() => _AssessmentFormDialogState();
}

class _AssessmentFormDialogState extends State<AssessmentFormDialog> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  // String-backed (not int) so the field can be genuinely blank — matches
  // the backend/web semantics where blank means "inherit the org-wide
  // default from Settings → Assessment Config", not zero.
  late final TextEditingController _passPercentageCtrl;
  late final TextEditingController _maxAttemptsCtrl;
  late final TextEditingController _timeLimitCtrl;
  late bool _isActive;
  late bool _isDefault;
  bool _saving = false;
  String? _error;

  bool get _isAdd => widget.assessment == null;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.assessment?.title ?? '');
    _descCtrl = TextEditingController(text: widget.assessment?.description ?? '');
    _passPercentageCtrl =
        TextEditingController(text: '${widget.assessment?.passPercentage ?? 70}');
    _maxAttemptsCtrl =
        TextEditingController(text: widget.assessment?.maxAttempts?.toString() ?? '');
    _timeLimitCtrl =
        TextEditingController(text: widget.assessment?.timeLimitMins?.toString() ?? '');
    _isActive = widget.assessment?.isActive ?? true;
    _isDefault = widget.assessment?.isDefault ?? false;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _passPercentageCtrl.dispose();
    _maxAttemptsCtrl.dispose();
    _timeLimitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _DlgHeader(
            title: _isAdd ? 'New Assessment' : 'Edit Assessment',
            subtitle: 'Build pre-onboarding assessments for candidates',
            onClose: () => Navigator.pop(context),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      _ErrorBanner(message: _error!),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _titleCtrl,
                      style: AppTextStyles.body,
                      autofocus: true,
                      maxLength: 200,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: _dec('Title *', hint: 'e.g. Onboarding Assessment'),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _descCtrl,
                      style: AppTextStyles.body,
                      maxLines: 3,
                      decoration: _dec('Description (optional)'),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _passPercentageCtrl,
                            style: AppTextStyles.body,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() => _error = null),
                            decoration: _dec('Pass % *', hint: '70'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _maxAttemptsCtrl,
                            style: AppTextStyles.body,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() => _error = null),
                            decoration: _dec('Max Attempts', hint: 'Use global'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _timeLimitCtrl,
                            style: AppTextStyles.body,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (_) => setState(() => _error = null),
                            decoration: _dec('Time Limit (min)', hint: 'None'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Leave Max Attempts / Time Limit blank to inherit the global '
                      'default from Settings → Assessment Config.',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                    ),
                    const SizedBox(height: 12),
                    _ToggleRow(
                      icon: Icons.check_circle_outline,
                      title: 'Active',
                      subtitle: 'Visible and assignable to candidates',
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                    const SizedBox(height: 10),
                    _ToggleRow(
                      icon: Icons.auto_awesome_outlined,
                      title: 'Default (auto-assign)',
                      subtitle: 'Automatically assign to new candidates',
                      value: _isDefault,
                      onChanged: (v) => setState(() => _isDefault = v),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(_isAdd ? 'Save' : 'Save Changes',
                              style: AppTextStyles.label.copyWith(color: Colors.white)),
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

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: AppTextStyles.caption,
    hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  );

  Future<void> _submit() async {
    final form = AssessmentFormData(
      title: _titleCtrl.text,
      description: _descCtrl.text,
      isActive: _isActive,
      isDefault: _isDefault,
      passPercentage: int.tryParse(_passPercentageCtrl.text.trim()) ?? 0,
      // Blank means "inherit the global default" — mirrors web's
      // `form.max_attempts !== "" ? Number(...) : null` exactly.
      maxAttempts: _maxAttemptsCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_maxAttemptsCtrl.text.trim()),
      timeLimitMins: _timeLimitCtrl.text.trim().isEmpty
          ? null
          : int.tryParse(_timeLimitCtrl.text.trim()),
    );
    final validationError = form.validate();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final notifier = widget.ref.read(assessmentsProvider.notifier);
    final result = _isAdd
        ? await notifier.createAssessment(form)
        : await notifier.editAssessment(widget.assessment!.id, form);
    if (!mounted) return;
    if (result == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = result;
      });
    }
  }
}

// ── Toggle row ─────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: value ? AppColors.success.withValues(alpha: 0.07) : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? AppColors.success.withValues(alpha: 0.40) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: value ? AppColors.success : AppColors.textHint, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

// ── Dialog header ─────────────────────────────────────────────────────────────

class _DlgHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _DlgHeader({required this.title, required this.subtitle, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.assignment_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
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

// ── Error banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.error),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))),
        ],
      ),
    );
  }
}

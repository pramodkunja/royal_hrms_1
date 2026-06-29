import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/employee_code_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';

class EmployeeCodeScreen extends ConsumerStatefulWidget {
  const EmployeeCodeScreen({super.key});

  @override
  ConsumerState<EmployeeCodeScreen> createState() => _EmployeeCodeScreenState();
}

class _EmployeeCodeScreenState extends ConsumerState<EmployeeCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  EmployeeCodeModel? _draft;
  bool _saving = false;
  Map<String, String?> _errors = {};

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(employeeCodeProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SettingsAppBar(
        title: 'Employee ID Format',
        trailing: async.hasValue
            ? TextButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : Text('Save',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w700)),
              )
            : null,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorBody(message: err.toString()),
        data: (model) {
          _draft ??= model;
          return _EmployeeCodeForm(
            formKey: _formKey,
            model: _draft!,
            errors: _errors,
            onChanged: (updated) => setState(() {
              _draft = updated;
              _errors = {};
            }),
          );
        },
      ),
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final validationErrors = _draft!.validate();
    if (validationErrors.isNotEmpty) {
      setState(() => _errors = validationErrors);
      return;
    }
    setState(() => _saving = true);
    final error = await ref.read(employeeCodeProvider.notifier).save(_draft!);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Employee ID format saved successfully.'),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Form ──────────────────────────────────────────────────────────────────────

class _EmployeeCodeForm extends StatefulWidget {
  final GlobalKey<FormState> formKey;
  final EmployeeCodeModel model;
  final Map<String, String?> errors;
  final ValueChanged<EmployeeCodeModel> onChanged;

  const _EmployeeCodeForm({
    required this.formKey,
    required this.model,
    required this.errors,
    required this.onChanged,
  });

  @override
  State<_EmployeeCodeForm> createState() => _EmployeeCodeFormState();
}

class _EmployeeCodeFormState extends State<_EmployeeCodeForm> {
  late final TextEditingController _prefixCtrl;
  late final TextEditingController _paddingCtrl;
  late final TextEditingController _startCtrl;

  @override
  void initState() {
    super.initState();
    _prefixCtrl  = TextEditingController(text: widget.model.prefix);
    _paddingCtrl = TextEditingController(text: widget.model.padding.toString());
    _startCtrl   = TextEditingController(text: widget.model.nextSequence.toString());
  }

  @override
  void dispose() {
    _prefixCtrl.dispose();
    _paddingCtrl.dispose();
    _startCtrl.dispose();
    super.dispose();
  }

  EmployeeCodeModel _current() => widget.model.copyWith(
    prefix:       _prefixCtrl.text.trim().toUpperCase(),
    padding:      int.tryParse(_paddingCtrl.text) ?? 4,
    nextSequence: int.tryParse(_startCtrl.text) ?? 1,
  );

  void _notify() => widget.onChanged(_current());

  @override
  Widget build(BuildContext context) {
    final preview = _current().localPreview;

    return Form(
      key: widget.formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PreviewCard(preview: preview),
            const SizedBox(height: 28),

            const _SectionHeader(title: 'Configuration'),
            const SizedBox(height: 14),

            _buildField(
              controller: _prefixCtrl,
              label: 'Prefix',
              hint: 'e.g. EMP, ROYAL',
              icon: Icons.label_outline,
              errorText: widget.errors['prefix'],
              inputFormatters: [UpperCaseTextFormatter()],
              onChanged: (_) => _notify(),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Prefix is required' : null,
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildField(
                    controller: _paddingCtrl,
                    label: 'Zero Padding',
                    hint: '3–8',
                    icon: Icons.format_list_numbered_outlined,
                    errorText: widget.errors['padding'],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _notify(),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 3 || n > 8) return 'Must be 3–8';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField(
                    controller: _startCtrl,
                    label: 'Next Sequence',
                    hint: 'e.g. 1',
                    icon: Icons.tag,
                    errorText: widget.errors['startNumber'],
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (_) => _notify(),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      if (n == null || n < 1) return 'Must be ≥ 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _ExamplesRow(model: _current()),
            const SizedBox(height: 20),
            const _HintCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? errorText,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required ValueChanged<String> onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: AppTextStyles.body,
      onChanged: onChanged,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textHint),
        labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final String preview;
  const _PreviewCard({required this.preview});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF2A6ACC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.badge_outlined, size: 16, color: Colors.white70),
              const SizedBox(width: 6),
              Text('Live Preview', style: AppTextStyles.caption.copyWith(
                color: Colors.white70, letterSpacing: 0.5,
              )),
            ],
          ),
          const SizedBox(height: 12),
          Text(preview,
            style: AppTextStyles.h2.copyWith(
              color: Colors.white,
              letterSpacing: 4,
              fontWeight: FontWeight.w800,
              fontSize: 32,
            ),
          ),
          const SizedBox(height: 6),
          Text('First employee identifier', style: AppTextStyles.caption.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
          )),
        ],
      ),
    );
  }
}

class _ExamplesRow extends StatelessWidget {
  final EmployeeCodeModel model;
  const _ExamplesRow({required this.model});

  @override
  Widget build(BuildContext context) {
    final examples = List.generate(
      3,
      (i) {
        final n = (model.nextSequence + i).toString().padLeft(model.padding, '0');
        return '${model.prefix}$n';
      },
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Generated codes will look like:',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: examples.map((code) => _CodeBubble(code: code)).toList(),
          ),
        ],
      ),
    );
  }
}

class _CodeBubble extends StatelessWidget {
  final String code;
  const _CodeBubble({required this.code});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Text(code,
        style: AppTextStyles.label.copyWith(
          color: AppColors.primary, fontWeight: FontWeight.w600, letterSpacing: 1,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: AppTextStyles.caption.copyWith(
      color: AppColors.textHint,
      letterSpacing: 0.8,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _HintCard extends StatelessWidget {
  const _HintCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Format: Prefix + Zero-padded sequence number.\n'
              'The "Next Sequence" is the number that will be assigned to the next new employee.',
              style: AppTextStyles.caption.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  final String message;
  const _ErrorBody({required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
          const SizedBox(height: 12),
          Text('Could not load settings', style: AppTextStyles.h4),
          const SizedBox(height: 6),
          Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(text: newValue.text.toUpperCase());
  }
}

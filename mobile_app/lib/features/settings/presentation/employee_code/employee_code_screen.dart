import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/employee_code_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';

/// Settings → Employee ID Format — web app/dashboard/settings/employee-code/
/// page.tsx: one editable field (Prefix: letters only, max 10, saved
/// uppercase), the "prefix + DDMM + initials" example preview, and Save
/// Changes / Cancel (both only once something changed). Needs settings.edit,
/// as the API (CanManageRoles); without it nothing is requested.
class EmployeeCodeScreen extends ConsumerWidget {
  const EmployeeCodeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Employee ID Format'),
      body: !canManageEmployeeCode(user)
          ? const _Message(
              key: Key('employee-code-denied'),
              icon: Icons.lock_outline,
              text: kEmployeeCodeDenied,
            )
          : ref.watch(employeeCodeProvider).when(
                skipLoadingOnRefresh: false,
                loading: () => Center(
                  key: const Key('employee-code-loading'),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
                    const SizedBox(width: 10),
                    Text('Loading settings…', style: AppTextStyles.bodySecondary),
                  ]),
                ),
                error: (e, _) => _Message(
                  key: const Key('employee-code-load-error'),
                  icon: Icons.error_outline,
                  text: employeeCodeSaveError(e).message ?? 'Could not load settings.',
                  onRetry: () => ref.invalidate(employeeCodeProvider),
                ),
                data: (settings) => _EmployeeCodeForm(settings: settings),
              ),
    );
  }
}

class _EmployeeCodeForm extends ConsumerStatefulWidget {
  const _EmployeeCodeForm({required this.settings});
  final EmployeeCodeSettings settings;

  @override
  ConsumerState<_EmployeeCodeForm> createState() => _EmployeeCodeFormState();
}

class _EmployeeCodeFormState extends ConsumerState<_EmployeeCodeForm> {
  late final _prefix = TextEditingController(text: widget.settings.prefix);
  late String _base = widget.settings.prefix;
  String? _prefixError;
  String? _apiError;
  bool _saved = false;
  bool _saving = false;

  bool get _dirty => _prefix.text != _base;

  @override
  void dispose() {
    _prefix.dispose();
    super.dispose();
  }

  void _onChanged(String _) => setState(() {
        _saved = false;
        _apiError = null;
        _prefixError = null;
      });

  void _cancel() => setState(() {
        _prefix.text = _base;
        _prefixError = null;
        _saved = false;
        _apiError = null;
      });

  Future<void> _save() async {
    final err = validateEmployeeCodePrefix(_prefix.text);
    if (err != null) {
      setState(() => _prefixError = err);
      return;
    }
    setState(() {
      _saving = true;
      _apiError = null;
    });
    final result = await ref.read(employeeCodeProvider.notifier).save(_prefix.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (result == null) {
        // Web: the form shows exactly what the server saved.
        final saved = ref.read(employeeCodeProvider).valueOrNull?.prefix ?? _prefix.text;
        _base = saved;
        _prefix.text = saved;
        _saved = true;
      } else {
        _prefixError = result.fieldErrors['prefix'];
        // Fields that aren't editable here (padding / next_sequence) or a
        // general refusal go to the banner.
        final others =
            result.fieldErrors.entries.where((e) => e.key != 'prefix').map((e) => '${_label(e.key)}: ${e.value}');
        _apiError = [if (result.message != null) result.message!, ...others].join('\n');
        if (_apiError!.isEmpty) _apiError = null;
      }
    });
  }

  static String _label(String key) => switch (key) {
        'padding' => 'Padding',
        'next_sequence' => 'Starting number',
        _ => key,
      };

  @override
  Widget build(BuildContext context) {
    final preview = employeeCodePreview(_prefix.text);
    final canAct = _dirty && !_saving;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Text('Configure the prefix used for new employee codes', style: AppTextStyles.bodySecondary),
        const SizedBox(height: 12),
        if (_apiError != null)
          _Banner(
              key: const Key('employee-code-error'),
              text: _apiError!,
              color: AppColors.error,
              icon: Icons.error_outline),
        if (_saved)
          _Banner(
              key: const Key('employee-code-saved'),
              text: 'Employee ID format saved successfully.',
              color: AppColors.success,
              icon: Icons.check_circle_outline),
        _Card(
          icon: Icons.badge_outlined,
          title: 'Configuration',
          child: TextField(
            key: const Key('employee-code-prefix'),
            controller: _prefix,
            enabled: !_saving,
            onChanged: _onChanged,
            inputFormatters: [LengthLimitingTextInputFormatter(kEmployeeCodePrefixMaxLength)],
            decoration: InputDecoration(
              labelText: 'Prefix *',
              hintText: 'e.g. RSS',
              errorText: _prefixError,
              helperText: 'Letters only, max 10 characters. Saved as uppercase.',
              helperMaxLines: 2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _Card(
          icon: Icons.visibility_outlined,
          title: 'Preview',
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Format: prefix + date of joining (DDMM) + name initials. Example IDs:',
                style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            for (final (i, row) in preview.indexed)
              Container(
                key: Key('employee-code-preview-$i'),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(row.code,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(row.label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  if (row.note != null)
                    Text(row.note!, style: AppTextStyles.caption.copyWith(fontSize: 11, color: AppColors.primary)),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Expanded(
            child: OutlinedButton(
              key: const Key('employee-code-cancel'),
              onPressed: canAct ? _cancel : null,
              child: const Text('Cancel'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              key: const Key('employee-code-save'),
              onPressed: canAct ? _save : null,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              icon: _saving
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Saving…' : 'Save Changes'),
            ),
          ),
        ]),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.child});
  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: color))),
        ]),
      );
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: AppTextStyles.bodySecondary),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('employee-code-retry'),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ]),
        ),
      );
}

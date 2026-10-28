import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_loading_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../branches/presentation/widgets/branch_dlg_header.dart';
import '../../data/models/assessment_config_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_page_header.dart';

enum _FieldKey { passPercentage, maxAttempts, timeLimit }

class AssessmentConfigScreen extends ConsumerWidget {
  const AssessmentConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(assessmentConfigProvider);
    final permissions = ref.watch(authStateProvider).valueOrNull?.user?.permissions ?? const [];
    final canEdit = permissions.contains('assessments.edit');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Assessment Config'),
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(assessmentConfigProvider)),
        data: (config) => _Body(config: config, canEdit: canEdit),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final AssessmentConfigModel config;
  final bool canEdit;

  const _Body({required this.config, required this.canEdit});

  Future<void> _edit(BuildContext context, WidgetRef ref, _FieldKey field) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: _EditFieldDialog(field: field, config: config, ref: ref),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = [
      (
        field: _FieldKey.passPercentage,
        icon: Icons.percent,
        color: AppColors.primary,
        label: 'Pass Percentage',
        desc: 'Minimum score a candidate must achieve to pass an assessment',
        value: '${config.defaultPassPercentage}%',
      ),
      (
        field: _FieldKey.maxAttempts,
        icon: Icons.refresh,
        color: AppColors.success,
        label: 'Maximum Attempts',
        desc: 'How many times a candidate can retake before being locked out (0 = unlimited)',
        value: config.maxAttempts == 0 ? 'Unlimited' : '${config.maxAttempts}',
      ),
      (
        field: _FieldKey.timeLimit,
        icon: Icons.schedule_outlined,
        color: AppColors.warning,
        label: 'Time Limit',
        desc: 'Whether assessments are timed globally and the default maximum duration',
        value: config.timeLimitMins != null ? '${config.timeLimitMins} min' : 'No limit',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SettingsPageHeader(
            icon: Icons.fact_check_outlined,
            title: 'Assessment Config',
            subtitle: 'Global defaults — override per-assessment in the assessment form',
          ),
          const SizedBox(height: 20),
          const SettingsSectionHeading(
            icon: Icons.tune_outlined,
            label: 'Global Defaults',
            color: Color(0xFF00695C),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
              boxShadow: AppColors.cardShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: AppColors.border),
                  _ConfigRow(
                    icon: rows[i].icon,
                    color: rows[i].color,
                    label: rows[i].label,
                    desc: rows[i].desc,
                    value: rows[i].value,
                    canEdit: canEdit,
                    onEdit: () => _edit(context, ref, rows[i].field),
                  ),
                ],
              ],
            ),
          ),
          if (config.updatedAt != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.backgroundLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 14, color: AppColors.textHint),
                  const SizedBox(width: 6),
                  Text(
                    'Last updated: ${_formatDate(config.updatedAt!)}',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatDate(String iso) {
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final dt = parsed.toLocal();
    const m = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '${dt.day} ${m[dt.month]} ${dt.year}, ${h.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm';
  }
}

class _ConfigRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String desc;
  final String value;
  final bool canEdit;
  final VoidCallback onEdit;

  const _ConfigRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.desc,
    required this.value,
    required this.canEdit,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(desc, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text(value, style: AppTextStyles.label.copyWith(color: color, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 18),
              color: AppColors.textSecondary,
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

// ── Edit dialog ────────────────────────────────────────────────────────────────

class _EditFieldDialog extends StatefulWidget {
  final _FieldKey field;
  final AssessmentConfigModel config;
  final WidgetRef ref;

  const _EditFieldDialog({required this.field, required this.config, required this.ref});

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late final TextEditingController _passCtrl;
  late final TextEditingController _attemptsCtrl;
  late final TextEditingController _timeLimitCtrl;
  late bool _timeLimitEnabled;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _passCtrl = TextEditingController(text: '${widget.config.defaultPassPercentage}');
    _attemptsCtrl = TextEditingController(text: '${widget.config.maxAttempts}');
    _timeLimitEnabled = widget.config.timeLimitMins != null;
    _timeLimitCtrl = TextEditingController(text: widget.config.timeLimitMins != null ? '${widget.config.timeLimitMins}' : '');
  }

  @override
  void dispose() {
    _passCtrl.dispose();
    _attemptsCtrl.dispose();
    _timeLimitCtrl.dispose();
    super.dispose();
  }

  String get _title => switch (widget.field) {
        _FieldKey.passPercentage => 'Edit — Pass Percentage',
        _FieldKey.maxAttempts => 'Edit — Maximum Attempts',
        _FieldKey.timeLimit => 'Edit — Time Limit',
      };

  Future<void> _save() async {
    AssessmentConfigModel updated = widget.config;

    switch (widget.field) {
      case _FieldKey.passPercentage:
        final v = int.tryParse(_passCtrl.text.trim());
        if (v == null || v < 1 || v > 100) {
          setState(() => _error = 'Enter a value between 1 and 100.');
          return;
        }
        updated = updated.copyWith(defaultPassPercentage: v);
      case _FieldKey.maxAttempts:
        final v = int.tryParse(_attemptsCtrl.text.trim());
        if (v == null || v < 0) {
          setState(() => _error = 'Enter 0 (unlimited) or a positive number.');
          return;
        }
        updated = updated.copyWith(maxAttempts: v);
      case _FieldKey.timeLimit:
        if (!_timeLimitEnabled) {
          updated = updated.copyWith(clearTimeLimit: true);
        } else {
          final v = int.tryParse(_timeLimitCtrl.text.trim());
          if (v == null || v < 1) {
            setState(() => _error = 'Enter a duration of at least 1 minute.');
            return;
          }
          updated = updated.copyWith(timeLimitMins: v);
        }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.ref.read(assessmentConfigProvider.notifier).save(updated);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BranchDlgHeader(
            icon: Icons.fact_check_outlined,
            title: _title,
            subtitle: 'Used as the default when creating a new assessment',
            onClose: () => Navigator.of(context).pop(),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_error != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
                        child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.field == _FieldKey.passPercentage) ...[
                      _Field(
                        label: 'Default Pass Percentage *',
                        child: TextField(
                          controller: _passCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '70', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Override per-assessment in the assessment form.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                      ),
                    ],
                    if (widget.field == _FieldKey.maxAttempts) ...[
                      _Field(
                        label: 'Default Maximum Attempts',
                        child: TextField(
                          controller: _attemptsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '3', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Set to 0 for unlimited attempts globally. Individual assessments can override this.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                      ),
                    ],
                    if (widget.field == _FieldKey.timeLimit) ...[
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Global Time Limit'),
                        subtitle: const Text('Enable a default time limit for assessments'),
                        value: _timeLimitEnabled,
                        onChanged: (v) => setState(() => _timeLimitEnabled = v),
                      ),
                      if (_timeLimitEnabled) ...[
                        const SizedBox(height: 8),
                        _Field(
                          label: 'Duration (minutes) *',
                          child: TextField(
                            controller: _timeLimitCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(hintText: 'e.g. 30', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        "Per-assessment overrides take precedence. Disabled = no global limit.",
                        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _saving ? null : () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: _saving ? null : _save,
                            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                            child: _saving
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Save'),
                          ),
                        ),
                      ],
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
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;

  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        child,
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 48, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load assessment config', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

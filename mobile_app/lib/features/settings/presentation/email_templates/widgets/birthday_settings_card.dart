import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../data/models/birthday_settings_model.dart';
import '../birthday_settings_providers.dart';

/// Web "Automatic Birthday Wishes" card on Settings → Email Templates: the
/// master switch plus the dashboard banner and notification texts. Hidden for
/// users who may not read them (no request is made); Edit only with
/// settings.edit.
class BirthdaySettingsCard extends ConsumerWidget {
  const BirthdaySettingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    if (!canViewBirthdaySettings(user)) return const SizedBox.shrink();
    final canEdit = canEditBirthdaySettings(user);
    final async = ref.watch(birthdaySettingsProvider);
    final settings = async.valueOrNull;

    Widget body;
    if (async.isLoading && settings == null) {
      body = Text('Loading birthday settings…',
          key: const Key('birthday-settings-loading'), style: AppTextStyles.caption.copyWith(fontSize: 12));
    } else if (async.hasError && settings == null) {
      body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(birthdaySettingsError(async.error!, 'Could not load birthday settings.'),
            key: const Key('birthday-settings-error'),
            style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.error)),
        TextButton(
          key: const Key('birthday-settings-retry'),
          style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
          onPressed: () => ref.invalidate(birthdaySettingsProvider),
          child: const Text('Retry'),
        ),
      ]);
    } else {
      body = Text(
        "Dashboard banner and notification copy shown to the employee, their team, and their manager on someone's "
        'birthday. The birthday email subject/body is edited below, in the Wish template.',
        style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary),
      );
    }

    return Container(
      key: const Key('birthday-settings-card'),
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.cake_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text('Automatic Birthday Wishes',
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
          if (settings != null) ...[
            const SizedBox(width: 6),
            Text(settings.isEnabled ? 'Enabled' : 'Disabled',
                key: const Key('birthday-settings-status'),
                style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: settings.isEnabled ? AppColors.success : AppColors.textSecondary)),
          ],
          const Spacer(),
          if (canEdit && settings != null)
            TextButton.icon(
              key: const Key('birthday-settings-edit'),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                isDismissible: false,
                builder: (_) => BirthdaySettingsEditorSheet(initial: settings),
              ),
              icon: const Icon(Icons.edit_outlined, size: 15),
              label: const Text('Edit'),
            )
          else
            const SizedBox(height: 40),
        ]),
        body,
      ]),
    );
  }
}

/// The edit form (web's open card): switch, four texts, Cancel / Save.
class BirthdaySettingsEditorSheet extends ConsumerStatefulWidget {
  const BirthdaySettingsEditorSheet({super.key, required this.initial});
  final BirthdaySettingsModel initial;

  @override
  ConsumerState<BirthdaySettingsEditorSheet> createState() => _BirthdaySettingsEditorSheetState();
}

class _BirthdaySettingsEditorSheetState extends ConsumerState<BirthdaySettingsEditorSheet> {
  late bool _enabled = widget.initial.isEnabled;
  late final _banner = TextEditingController(text: widget.initial.bannerMessage);
  late final _employee = TextEditingController(text: widget.initial.employeeNotification);
  late final _team = TextEditingController(text: widget.initial.teamNotification);
  late final _manager = TextEditingController(text: widget.initial.managerNotification);
  bool _saving = false;
  String? _error;
  Set<String> _emptyFields = const {};

  @override
  void dispose() {
    for (final c in [_banner, _employee, _team, _manager]) {
      c.dispose();
    }
    super.dispose();
  }

  BirthdaySettingsModel get _form => widget.initial.copyWith(
        isEnabled: _enabled,
        bannerMessage: _banner.text,
        employeeNotification: _employee.text,
        teamNotification: _team.text,
        managerNotification: _manager.text,
      );

  Future<void> _save() async {
    if (_saving) return;
    final form = _form;
    final empty = form.emptyFields().toSet();
    if (empty.isNotEmpty) {
      setState(() {
        _emptyFields = empty;
        _error = null;
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _emptyFields = const {};
    });
    try {
      await ref.read(birthdaySettingsProvider.notifier).save(form);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
          SnackBar(content: const Text('Birthday wishes settings updated'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = birthdaySettingsError(e, 'Failed to save birthday settings');
        });
      }
    }
  }

  Widget _text(String field, String label, TextEditingController c, {String? help}) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: TextField(
          key: Key('birthday-$field'),
          controller: c,
          enabled: !_saving,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) {
            if (_emptyFields.contains(field)) setState(() => _emptyFields = {..._emptyFields}..remove(field));
          },
          decoration: InputDecoration(
            labelText: label,
            helperText: help,
            helperMaxLines: 3,
            errorText: _emptyFields.contains(field) ? 'This text cannot be empty.' : null,
            alignLabelWithHint: true,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            key: const Key('birthday-settings-sheet'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
              Text('Automatic Birthday Wishes', style: AppTextStyles.h4),
              const SizedBox(height: 8),
              if (_error != null) ...[
                Container(
                  key: const Key('birthday-settings-save-error'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12)),
                ),
                const SizedBox(height: 10),
              ],
              SwitchListTile(
                key: const Key('birthday-is-enabled'),
                contentPadding: EdgeInsets.zero,
                value: _enabled,
                onChanged: _saving ? null : (v) => setState(() => _enabled = v),
                title: Text('Enable automatic birthday wishes', style: AppTextStyles.label.copyWith(fontSize: 13)),
                subtitle: Text('When off, no birthday email, dashboard banner, or notification is sent to anyone.',
                    style: AppTextStyles.caption.copyWith(fontSize: 11)),
              ),
              const SizedBox(height: 8),
              _text('banner_message_template', 'Dashboard birthday banner message', _banner,
                  help: 'Shown under "Happy Birthday, [Name]!" on every employee\'s dashboard, company-wide, whenever '
                      'it\'s someone\'s birthday.'),
              _text('employee_notification_template', 'Employee in-app notification text', _employee),
              _text('team_notification_template', 'Teammate notification / card text', _team,
                  help:
                      'Use {employee_name} as a placeholder — shown to teammates sharing the same reporting manager.'),
              _text('manager_notification_template', 'Manager notification / card text', _manager,
                  help: 'Use {employee_name} as a placeholder — shown to the employee\'s reporting manager.'),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(
                  key: const Key('birthday-settings-cancel'),
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  key: const Key('birthday-settings-save'),
                  onPressed: _saving ? null : _save,
                  child: Text(_saving ? 'Saving…' : 'Save Birthday Settings'),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

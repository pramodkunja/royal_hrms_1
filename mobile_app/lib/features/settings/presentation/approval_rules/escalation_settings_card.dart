import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/data/approval_workflows.dart';
import '../../../approvals/presentation/widgets/delegations_tab.dart' show approvalWorkflowsApiProvider;

// Settings → Approval Rules → "Automatic Reminders & Escalation" — web
// settings/approval-rules/_components/EscalationSettingsCard.tsx over
// GET/PUT /approvals/escalation-settings/ (read: settings.view or
// settings.edit — hidden on 403; edit: the server's can_edit = settings.edit)
// and GET …/head-candidates/ (settings.edit only). The server runs the
// reminders / escalations on its own schedule; this card only configures
// them and describes the steps.

final escalationSettingsProvider = FutureProvider.autoDispose<EscalationSettings>(
    (ref) => ref.read(approvalWorkflowsApiProvider).escalationSettings());

final escalationHeadCandidatesProvider = FutureProvider.autoDispose<List<PersonRef>>(
    (ref) => ref.read(approvalWorkflowsApiProvider).escalationHeadCandidates());

class EscalationSettingsCard extends ConsumerStatefulWidget {
  const EscalationSettingsCard({super.key});

  @override
  ConsumerState<EscalationSettingsCard> createState() => _EscalationSettingsCardState();
}

class _EscalationSettingsCardState extends ConsumerState<EscalationSettingsCard> {
  EscalationForm? _draft; // unsaved edits; null → the saved settings
  bool _saving = false;
  bool _saved = false;
  String? _apiError;
  final _ctrls = <String, TextEditingController>{};

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctrl(String key, int? value) =>
      _ctrls.putIfAbsent(key, () => TextEditingController(text: value?.toString() ?? ''));

  void _set(EscalationForm next) => setState(() {
        _draft = next;
        _saved = false;
      });

  Future<void> _save(EscalationForm form) async {
    if (_saving || validateEscalation(form).isNotEmpty) return;
    setState(() {
      _saving = true;
      _apiError = null;
    });
    try {
      await ref.read(approvalWorkflowsApiProvider).saveEscalationSettings(form);
      if (mounted) setState(() => _saved = true);
    } catch (e) {
      if (mounted) setState(() => _apiError = approvalWorkflowError(e, 'Failed to save escalation settings.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// A checkbox row (a ListTile inside the card's coloured box would trip
  /// Flutter's ListTile/Material check).
  Widget _check(Key key, bool value, String label, ValueChanged<bool>? onChanged) => GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: Row(children: [
          Checkbox(value: value, onChanged: onChanged == null ? null : (v) => onChanged(v ?? false)),
          Expanded(child: Text(label, style: AppTextStyles.bodySmall)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(escalationSettingsProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => e is DioException && e.response?.statusCode == 403
          ? const SizedBox.shrink() // web: not shown without settings access
          : Container(
              key: const Key('escalation-load-error'),
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(10),
              decoration:
                  BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
              child: Text(approvalWorkflowError(e, "Couldn't load escalation settings."),
                  style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            ),
      data: (data) => _card(data),
    );
  }

  Widget _card(EscalationSettings data) {
    final canEdit = data.canEdit;
    final heads = canEdit
        ? (ref.watch(escalationHeadCandidatesProvider).valueOrNull ?? const <PersonRef>[])
        : const <PersonRef>[];
    final form = _draft ?? EscalationForm.from(data);
    final errors = validateEscalation(form);
    String headName = '';
    for (final h in heads) {
      if (h.id == form.escalationHead) headName = h.name;
    }
    if (headName.isEmpty && data.escalationHead?.id == form.escalationHead) headName = data.escalationHead?.name ?? '';
    final timeline = escalationTimeline(form, headName);
    final caption = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);

    final headOptions = <PersonRef>[
      if (data.escalationHead != null && !heads.any((h) => h.id == data.escalationHead!.id)) data.escalationHead!,
      ...heads,
    ];

    Widget num(String key, String label, String hint, int? value, EscalationForm Function(int?) apply) => Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              key: Key('esc-$key'),
              controller: _ctrl(key, value),
              enabled: canEdit,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                  labelText: label, helperText: hint, isDense: true, border: const OutlineInputBorder()),
              onChanged: (t) => _set(apply(int.tryParse(t))),
            ),
            if (errors[key] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(errors[key]!,
                    key: Key('esc-error-$key'),
                    style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12)),
              ),
          ]),
        );

    EscalationForm copy({
      bool? isEnabled,
      int? Function()? reminder,
      int? Function()? first,
      int? Function()? second,
      String? head,
      bool? leave,
      bool? attendance,
    }) =>
        EscalationForm(
          isEnabled: isEnabled ?? form.isEnabled,
          reminderAfterDays: reminder != null ? reminder() : form.reminderAfterDays,
          firstEscalationAfterDays: first != null ? first() : form.firstEscalationAfterDays,
          secondEscalationAfterDays: second != null ? second() : form.secondEscalationAfterDays,
          escalationHead: head ?? form.escalationHead,
          appliesToLeave: leave ?? form.appliesToLeave,
          appliesToAttendance: attendance ?? form.appliesToAttendance,
        );

    return Container(
      key: const Key('escalation-settings'),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.alarm, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Automatic Reminders & Escalation',
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 15)),
          ),
          Text(form.isEnabled ? 'On' : 'Off', style: AppTextStyles.caption),
          Switch(
            key: const Key('esc-enabled'),
            value: form.isEnabled,
            onChanged: canEdit ? (v) => _set(copy(isEnabled: v)) : null,
          ),
        ]),
        Text(
          'Pending leave and attendance requests remind the approver, then move up the chain. Days are working days; '
          'each step happens once per approval stage, and the count restarts when the request reaches HR.',
          style: caption,
        ),
        num('reminder_after_days', 'Reminder after (working days)', '0 = no reminder', form.reminderAfterDays,
            (v) => copy(reminder: () => v)),
        num('first_escalation_after_days', 'First escalation after (working days)',
            "To the approver's reporting manager", form.firstEscalationAfterDays, (v) => copy(first: () => v)),
        num('second_escalation_after_days', 'Second escalation after (more working days)',
            'Counted after the first; 0 = none', form.secondEscalationAfterDays, (v) => copy(second: () => v)),
        const SizedBox(height: 12),
        KeyedSubtree(
          key: const Key('esc-head'),
          child: DropdownButtonFormField<String>(
            key: ValueKey('head-${headOptions.length}'),
            initialValue: form.escalationHead,
            isExpanded: true,
            decoration: const InputDecoration(
                labelText: 'Escalation head (HR Head / Admin Head)', isDense: true, border: OutlineInputBorder()),
            items: [
              const DropdownMenuItem(value: '', child: Text('— Not set (second escalation skipped) —')),
              for (final h in headOptions)
                DropdownMenuItem(
                    value: h.id, child: Text(h.employeeId.isNotEmpty ? '${h.name} (${h.employeeId})' : h.name)),
            ],
            onChanged: canEdit ? (v) => _set(copy(head: v ?? '')) : null,
          ),
        ),
        _check(const Key('esc-leave'), form.appliesToLeave, 'Leave requests', canEdit ? (v) => _set(copy(leave: v)) : null),
        _check(const Key('esc-attendance'), form.appliesToAttendance, 'Attendance corrections & late justifications', canEdit ? (v) => _set(copy(attendance: v)) : null),
        if (errors['applies_to_leave'] != null)
          Text(errors['applies_to_leave']!,
              key: const Key('esc-error-applies'),
              style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12)),
        const SizedBox(height: 10),
        Column(key: const Key('escalation-timeline'), crossAxisAlignment: CrossAxisAlignment.start, children: [
          for (var i = 0; i < timeline.length; i++)
            Text.rich(TextSpan(style: caption, children: [
              TextSpan(text: '${i + 1}. Day ${timeline[i].$1}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: timeline[i].$2),
            ])),
        ]),
        if (_apiError != null)
          Container(
            key: const Key('esc-api-error'),
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(10),
            decoration:
                BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
            child: Text(_apiError!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        if (canEdit)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              if (_saved)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: Text('Saved',
                      key: const Key('esc-saved'), style: AppTextStyles.caption.copyWith(color: AppColors.success)),
                ),
              FilledButton(
                key: const Key('esc-save'),
                onPressed: _saving || errors.isNotEmpty ? null : () => _save(form),
                child: Text(_saving ? 'Saving…' : 'Save Escalation Settings'),
              ),
            ]),
          ),
      ]),
    );
  }
}

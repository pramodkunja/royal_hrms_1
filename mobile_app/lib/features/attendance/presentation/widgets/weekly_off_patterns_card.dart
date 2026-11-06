import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/weekly_off_assignment_models.dart' show WeeklyOffPattern, kWeekdayKeys;
import '../../data/models/weekly_off_pattern_models.dart';
import '../providers/weekly_off_pattern_providers.dart';
import 'assignment_form_widgets.dart';

/// Web WeeklyOffPatternsCard on Settings → Attendance Rules: every pattern
/// (Default / Inactive badges) three per page with its off days and usage,
/// "Add Pattern" (attendance.create), Edit (attendance.edit) and Deactivate
/// (attendance.delete; not for the default or an assigned pattern). Shown
/// to users who may list patterns (attendance.view).
class WeeklyOffPatternsCard extends ConsumerWidget {
  const WeeklyOffPatternsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    if (!canViewWeeklyOffPatterns(user)) return const SizedBox.shrink();
    final canCreate = canCreateWeeklyOffPatterns(user);
    final canEdit = canEditWeeklyOffPatterns(user);
    final canDelete = canDeleteWeeklyOffPatterns(user);
    final pageAsync = ref.watch(weeklyOffPatternCardProvider);
    final pageNo = ref.watch(weeklyOffPatternPageNumberProvider);
    final muted = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);
    void setPage(int p) => ref.read(weeklyOffPatternPageNumberProvider.notifier).state = p;

    void showMessage(String? message) {
      if (message != null && context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.success));
      }
    }

    Future<void> openForm([WeeklyOffPattern? pattern]) async {
      showMessage(await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        builder: (_) => WeeklyOffPatternFormSheet(pattern: pattern),
      ));
    }

    Future<void> confirmDeactivate(WeeklyOffPattern p, int shownOnPage) async {
      final message = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => DeactivatePatternDialog(pattern: p),
      );
      if (message == null) return;
      // Web: the last pattern on a later page moves back a page.
      if (shownOnPage == 1 && pageNo > 1) setPage(pageNo - 1);
      showMessage(message);
    }

    return Container(
      key: const Key('weekly-off-patterns-card'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.event_repeat_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 6),
          Expanded(
              child: Text('Weekly Off Patterns', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700))),
          if (canCreate)
            FilledButton.icon(
              key: const Key('wop-add'),
              onPressed: () => openForm(),
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add Pattern'),
            ),
        ]),
        const SizedBox(height: 8),
        Text(
          'Configure reusable weekly-off schedules and assign them to employees from Attendance & Time → Weekly '
          'Off Assignment.',
          style: muted,
        ),
        const SizedBox(height: 10),
        // Only from a settled, successfully loaded page 1 — never while (re)loading (which may still
        // hold another page's rows) or after a failure.
        if (noActiveDefaultPattern(
                requestedPage: pageNo,
                page: pageAsync.isLoading || pageAsync.hasError ? null : pageAsync.valueOrNull) ==
            true) ...[
          const _NoDefaultWarning(),
          const SizedBox(height: 10),
        ],
        pageAsync.when(
          loading: () => Text('Loading…', key: const Key('wop-loading'), style: muted),
          error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AssignmentErrorBox(
                key: const Key('wop-error'), text: weeklyOffPatternError(e, 'Failed to load weekly off patterns.')),
            TextButton(
              key: const Key('wop-retry'),
              onPressed: () => ref.invalidate(weeklyOffPatternCardProvider),
              child: const Text('Retry'),
            ),
          ]),
          data: (page) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (page.patterns.isEmpty) Text('No patterns created yet.', key: const Key('wop-empty'), style: muted),
            for (final p in page.patterns)
              _PatternRow(
                pattern: p,
                canEdit: canEdit,
                canDelete: canDelete,
                onEdit: () => openForm(p),
                onDeactivate: () => confirmDeactivate(p, page.patterns.length),
              ),
            if (page.totalPages > 1)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  key: const Key('wop-prev'),
                  onPressed: pageNo <= 1 ? null : () => setPage(pageNo - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('${page.page} / ${page.totalPages}', key: const Key('wop-page'), style: muted),
                IconButton(
                  key: const Key('wop-next'),
                  onPressed: pageNo >= page.totalPages ? null : () => setPage(pageNo + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ]),
          ]),
        ),
      ]),
    );
  }
}

class _PatternRow extends StatelessWidget {
  const _PatternRow({
    required this.pattern,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDeactivate,
  });

  final WeeklyOffPattern pattern;
  final bool canEdit;
  final bool canDelete;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  Widget _badge(String text, Color color, Key key) => Container(
        key: key,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 10, color: color)),
      );

  @override
  Widget build(BuildContext context) {
    final p = pattern;
    final muted = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary);
    final n = p.assignedEmployeeCount;
    final blocked = deactivateBlockedReason(p);
    return Container(
      key: Key('wop-${p.id}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(p.name, style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
              if (p.isDefault) _badge('Default', AppColors.primary, Key('wop-default-${p.id}')),
              if (!p.isActive) _badge('Inactive', AppColors.textSecondary, Key('wop-inactive-${p.id}')),
            ]),
            Text(weeklyOffDaysSummary(p), style: muted),
            Text('$n employee${n != 1 ? 's' : ''}', style: muted),
          ]),
        ),
        if (canEdit)
          IconButton(
            key: Key('wop-edit-${p.id}'),
            tooltip: 'Edit',
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 18),
          ),
        if (canDelete)
          IconButton(
            key: Key('wop-delete-${p.id}'),
            tooltip: blocked ?? 'Deactivate',
            onPressed: blocked != null ? null : onDeactivate,
            color: AppColors.error,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
      ]),
    );
  }
}

/// Web Add/Edit pattern modal: Pattern Name, a Working / Off / Half Day choice
/// per weekday, and "Make this the organization default pattern". Pops with
/// the server's message once saved; a failure keeps every value.
class WeeklyOffPatternFormSheet extends ConsumerStatefulWidget {
  const WeeklyOffPatternFormSheet({super.key, this.pattern});
  final WeeklyOffPattern? pattern;

  @override
  ConsumerState<WeeklyOffPatternFormSheet> createState() => _WeeklyOffPatternFormSheetState();
}

class _WeeklyOffPatternFormSheetState extends ConsumerState<WeeklyOffPatternFormSheet> {
  late final WeeklyOffPatternForm _form =
      widget.pattern == null ? WeeklyOffPatternForm() : WeeklyOffPatternForm.fromPattern(widget.pattern!);
  late final _name = TextEditingController(text: _form.name);
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    _form.name = _name.text;
    if (!_form.canSave) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final service = ref.read(weeklyOffPatternServiceProvider);
    try {
      final message =
          widget.pattern == null ? await service.create(_form) : await service.update(widget.pattern!.id, _form);
      if (mounted) Navigator.of(context).pop(message);
    } on WeeklyOffPatternBusy {
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = weeklyOffPatternError(e, 'Failed to save pattern.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AssignmentSheet(
      key: const Key('wop-form'),
      title: widget.pattern == null ? 'Add Weekly Off Pattern' : 'Edit Pattern',
      saving: _saving,
      content: [
        if (_error != null) AssignmentErrorBox(key: const Key('wop-form-error'), text: _error!),
        TextField(
          key: const Key('wop-name'),
          controller: _name,
          enabled: !_saving,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Pattern Name *',
            hintText: 'e.g. Sunday Off, Weekend Off',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        Text('Day Schedule', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var i = 0; i < 7; i++)
            SizedBox(
              width: 104,
              child: AssignmentPicker(
                key: Key('wop-day-${kWeekdayKeys[i]}'),
                label: kWeekdayShort[i],
                value: _form.days[kWeekdayKeys[i]] ?? 'working',
                options: kDayTypes,
                onChanged: _saving ? null : (v) => setState(() => _form.days[kWeekdayKeys[i]] = v),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        CheckboxListTile(
          key: const Key('wop-default'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
          value: _form.isDefault,
          onChanged: _saving ? null : (v) => setState(() => _form.isDefault = v ?? false),
          title: const Text('Make this the organization default pattern', style: TextStyle(fontSize: 13)),
        ),
      ],
      action: FilledButton(
        key: const Key('wop-save'),
        onPressed: !_saving && _name.text.isNotEmpty ? _save : null,
        child: Text(_saving ? 'Saving…' : 'Save Pattern'),
      ),
    );
  }
}

/// Web "Deactivate Pattern" confirmation. A refusal stays in the dialog;
/// success pops with the server's message.
class DeactivatePatternDialog extends ConsumerStatefulWidget {
  const DeactivatePatternDialog({super.key, required this.pattern});
  final WeeklyOffPattern pattern;

  @override
  ConsumerState<DeactivatePatternDialog> createState() => _DeactivatePatternDialogState();
}

class _DeactivatePatternDialogState extends ConsumerState<DeactivatePatternDialog> {
  bool _deleting = false;
  String? _error;

  Future<void> _deactivate() async {
    if (_deleting) return;
    setState(() {
      _deleting = true;
      _error = null;
    });
    try {
      final message = await ref.read(weeklyOffPatternServiceProvider).deactivate(widget.pattern.id);
      if (mounted) Navigator.of(context).pop(message);
    } on WeeklyOffPatternBusy {
      if (mounted) setState(() => _deleting = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _deleting = false;
          _error = weeklyOffPatternError(e, 'Delete failed.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_deleting,
      child: AlertDialog(
        key: const Key('wop-deactivate'),
        title: Text('Deactivate Pattern', style: TextStyle(color: AppColors.error)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_error != null) AssignmentErrorBox(key: const Key('wop-deactivate-error'), text: _error!),
          Text(
            '"${widget.pattern.name}" will be deactivated. Employees currently assigned this pattern keep it until '
            'reassigned — history is preserved.',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
        ]),
        actions: [
          TextButton(onPressed: _deleting ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            key: const Key('wop-deactivate-confirm'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: _deleting ? null : _deactivate,
            child: Text(_deleting ? 'Deactivating…' : 'Deactivate'),
          ),
        ],
      ),
    );
  }
}

/// Informational only: nothing is blocked and no assignment changes.
class _NoDefaultWarning extends StatelessWidget {
  const _NoDefaultWarning();

  @override
  Widget build(BuildContext context) {
    final c = AppColors.warning;
    return Container(
      key: const Key('wop-no-default-warning'),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withValues(alpha: 0.3)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_outline, size: 16, color: c),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            const TextSpan(children: [
              TextSpan(
                  text: 'No default Weekly Off Pattern is configured.', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(
                  text: ' Employees without an individual assignment may continue using the legacy company '
                      'weekly-off setting. Set a pattern as Default to manage weekly offs here.'),
            ]),
            style: AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textPrimary),
          ),
        ),
      ]),
    );
  }
}

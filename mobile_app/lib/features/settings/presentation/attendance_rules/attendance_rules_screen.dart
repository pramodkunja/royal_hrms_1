import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_loading_widget.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/attendance_settings_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import '../widgets/settings_page_header.dart';

class AttendanceRulesScreen extends ConsumerStatefulWidget {
  const AttendanceRulesScreen({super.key});

  @override
  ConsumerState<AttendanceRulesScreen> createState() => _AttendanceRulesScreenState();
}

class _AttendanceRulesScreenState extends ConsumerState<AttendanceRulesScreen> {
  AttendanceSettingsModel? _edited;
  String? _savingSection;
  bool _savingAll = false;

  void _toast(String msg, bool ok) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  AttendanceSettingsModel _mergeSectionFromServer(
      AttendanceSettingsModel local, AttendanceSettingsModel server, String key) {
    switch (key) {
      case 'working_hours':
        return local.copyWith(workingHours: server.workingHours);
      case 'weekly_off':
        return local.copyWith(weeklyOff: server.weeklyOff);
      case 'punch_rules':
        return local.copyWith(punchRules: server.punchRules);
      case 'overtime_rules':
        return local.copyWith(overtimeRules: server.overtimeRules);
      case 'late_mark_rules':
        return local.copyWith(lateMarkRules: server.lateMarkRules);
      case 'absence_alert':
        return local.copyWith(absenceAlert: server.absenceAlert);
      case 'face_verification':
        return local.copyWith(faceVerification: server.faceVerification);
      default:
        return local;
    }
  }

  Future<void> _saveSection(AttendanceSettingsModel current, String key, Map<String, dynamic> json) async {
    setState(() => _savingSection = key);
    final error = await ref.read(attendanceSettingsProvider.notifier).saveSection(key, json);
    if (!mounted) return;
    final serverModel = ref.read(attendanceSettingsProvider).valueOrNull;
    setState(() {
      _savingSection = null;
      if (error == null && serverModel != null) {
        _edited = _mergeSectionFromServer(current, serverModel, key);
      }
    });
    _toast(error ?? 'Section saved.', error == null);
  }

  Future<void> _saveAll(AttendanceSettingsModel current) async {
    if (!current.weeklyOff.hasAtLeastOneWorkingDay) {
      _toast('At least one day must remain a working day.', false);
      return;
    }
    setState(() => _savingAll = true);
    final error = await ref.read(attendanceSettingsProvider.notifier).saveAll(current);
    if (!mounted) return;
    setState(() {
      _savingAll = false;
      if (error == null) _edited = null;
    });
    _toast(error ?? 'All settings saved.', error == null);
  }

  void _discard() => setState(() => _edited = null);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(attendanceSettingsProvider);
    final permissions = ref.watch(authStateProvider).valueOrNull?.user?.permissions ?? const [];
    final canEdit = permissions.contains('settings.edit');
    final busy = _savingAll || _savingSection != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Attendance Rules'),
      body: async.when(
        loading: () => const AppLoadingWidget(),
        error: (e, _) => _ErrorView(message: e.toString(), onRetry: () => ref.invalidate(attendanceSettingsProvider)),
        data: (serverModel) {
          final current = _edited ?? serverModel;
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SettingsPageHeader(
                        icon: Icons.schedule_outlined,
                        title: 'Attendance Rules',
                        subtitle: 'Shift timings, late marks, overtime and absence alerts',
                      ),
                      const SizedBox(height: 18),
                      _WorkingHoursCard(
                        section: current.workingHours,
                        canEdit: canEdit,
                        saving: _savingSection == 'working_hours',
                        busy: busy,
                        onChanged: (s) => setState(() => _edited = current.copyWith(workingHours: s)),
                        onSave: () => _saveSection(current, 'working_hours', current.workingHours.toJson()),
                      ),
                      const SizedBox(height: 12),
                      _WeeklyOffCard(
                        section: current.weeklyOff,
                        canEdit: canEdit,
                        saving: _savingSection == 'weekly_off',
                        busy: busy,
                        onChanged: (s) => setState(() => _edited = current.copyWith(weeklyOff: s)),
                        onSave: () => _saveSection(current, 'weekly_off', current.weeklyOff.toJson()),
                      ),
                      const SizedBox(height: 12),
                      _PunchRulesCard(
                        section: current.punchRules,
                        canEdit: canEdit,
                        saving: _savingSection == 'punch_rules',
                        busy: busy,
                        onChanged: (s) => setState(() => _edited = current.copyWith(punchRules: s)),
                        onSave: () => _saveSection(current, 'punch_rules', current.punchRules.toJson()),
                      ),
                      const SizedBox(height: 12),
                      _OvertimeRulesCard(
                        section: current.overtimeRules,
                        canEdit: canEdit,
                        saving: _savingSection == 'overtime_rules',
                        busy: busy,
                        onChanged: (s) => setState(() => _edited = current.copyWith(overtimeRules: s)),
                        onSave: () => _saveSection(current, 'overtime_rules', current.overtimeRules.toJson()),
                      ),
                      const SizedBox(height: 12),
                      _LateMarkCard(
                        section: current.lateMarkRules,
                        canEdit: canEdit,
                        saving: _savingSection == 'late_mark_rules',
                        busy: busy,
                        onChanged: (s) => setState(() => _edited = current.copyWith(lateMarkRules: s)),
                        onSave: () => _saveSection(current, 'late_mark_rules', current.lateMarkRules.toJson()),
                      ),
                      const SizedBox(height: 12),
                      _AbsenceAlertCard(
                        section: current.absenceAlert,
                        canEdit: canEdit,
                        saving: _savingSection == 'absence_alert',
                        busy: busy,
                        onChanged: (s) => setState(() => _edited = current.copyWith(absenceAlert: s)),
                        onSave: () => _saveSection(current, 'absence_alert', current.absenceAlert.toJson()),
                      ),
                      const SizedBox(height: 12),
                      _FaceVerificationCard(
                        section: current.faceVerification,
                        canEdit: canEdit,
                        saving: _savingSection == 'face_verification',
                        busy: busy,
                        onChanged: (s) => setState(() => _edited = current.copyWith(faceVerification: s)),
                        onSave: () => _saveSection(current, 'face_verification', current.faceVerification.toJson()),
                      ),
                    ],
                  ),
                ),
              ),
              if (canEdit)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: (busy || _edited == null) ? null : _discard,
                          child: const Text('Discard'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: busy ? null : () => _saveAll(current),
                          icon: _savingAll
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_outlined, size: 18),
                          label: Text(_savingAll ? 'Saving…' : 'Save All'),
                          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

// ── Shared section card chrome ───────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? accentColor;
  final Widget? headerTrailing;
  final bool canEdit;
  final bool saving;
  final bool busy;
  final VoidCallback onSave;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    this.accentColor,
    this.headerTrailing,
    required this.canEdit,
    required this.saving,
    required this.busy,
    required this.onSave,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedAccentColor = accentColor ?? AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(color: resolvedAccentColor.withValues(alpha: 0.04)),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: resolvedAccentColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: resolvedAccentColor, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (headerTrailing != null) headerTrailing!,
                if (canEdit)
                  TextButton(
                    onPressed: busy ? null : onSave,
                    style: TextButton.styleFrom(
                      backgroundColor: resolvedAccentColor.withValues(alpha: 0.10),
                      foregroundColor: resolvedAccentColor,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: saving
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: resolvedAccentColor),
                          )
                        : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: AppColors.border),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

class _LabeledDropdown<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;
  final bool enabled;

  const _LabeledDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          items: options
              .map((o) => DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis)))
              .toList(),
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
        ),
      ],
    );
  }
}

class _LabeledNumberField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const _LabeledNumberField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        TextFormField(
          key: ValueKey('$label-$value'),
          initialValue: '$value',
          enabled: enabled,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
          onChanged: (v) {
            final parsed = int.tryParse(v);
            if (parsed != null) onChanged(parsed.clamp(min, max));
          },
        ),
      ],
    );
  }
}

// ── Working Hours ─────────────────────────────────────────────────────────────

class _WorkingHoursCard extends StatelessWidget {
  final WorkingHoursSectionModel section;
  final bool canEdit;
  final bool saving;
  final bool busy;
  final ValueChanged<WorkingHoursSectionModel> onChanged;
  final VoidCallback onSave;

  const _WorkingHoursCard({
    required this.section,
    required this.canEdit,
    required this.saving,
    required this.busy,
    required this.onChanged,
    required this.onSave,
  });

  Future<void> _pickTime(BuildContext context, bool isStart) async {
    final parts = (isStart ? section.shiftStart : section.shiftEnd).split(':');
    final initial = TimeOfDay(hour: int.tryParse(parts[0]) ?? 9, minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final formatted = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    onChanged(isStart ? section.copyWith(shiftStart: formatted) : section.copyWith(shiftEnd: formatted));
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.schedule_outlined,
      title: 'Working Hours',
      accentColor: AppColors.primary,
      canEdit: canEdit,
      saving: saving,
      busy: busy,
      onSave: onSave,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _TimeField(label: 'Shift Start', value: section.shiftStart, enabled: canEdit, onTap: () => _pickTime(context, true))),
              const SizedBox(width: 10),
              Expanded(child: _TimeField(label: 'Shift End', value: section.shiftEnd, enabled: canEdit, onTap: () => _pickTime(context, false))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _LabeledNumberField(
                  label: 'Grace Period (min)',
                  value: section.gracePeriodMinutes,
                  min: 0,
                  max: 120,
                  enabled: canEdit,
                  onChanged: (v) => onChanged(section.copyWith(gracePeriodMinutes: v)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LabeledNumberField(
                  label: 'Break Duration (min)',
                  value: section.breakDurationMinutes,
                  min: 0,
                  max: 480,
                  enabled: canEdit,
                  onChanged: (v) => onChanged(section.copyWith(breakDurationMinutes: v)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimeField extends StatelessWidget {
  final String label;
  final String value;
  final bool enabled;
  final VoidCallback onTap;

  const _TimeField({required this.label, required this.value, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.access_time, size: 16, color: AppColors.textHint),
                const SizedBox(width: 8),
                Text(value, style: AppTextStyles.body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Weekly Off Days ───────────────────────────────────────────────────────────

class _WeeklyOffCard extends StatelessWidget {
  final WeeklyOffSectionModel section;
  final bool canEdit;
  final bool saving;
  final bool busy;
  final ValueChanged<WeeklyOffSectionModel> onChanged;
  final VoidCallback onSave;

  const _WeeklyOffCard({
    required this.section,
    required this.canEdit,
    required this.saving,
    required this.busy,
    required this.onChanged,
    required this.onSave,
  });

  static const _days = [
    ('monday', 'Mon'), ('tuesday', 'Tue'), ('wednesday', 'Wed'), ('thursday', 'Thu'),
    ('friday', 'Fri'), ('saturday', 'Sat'), ('sunday', 'Sun'),
  ];

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.calendar_view_week_outlined,
      title: 'Weekly Off Days',
      accentColor: const Color(0xFF6B3FA0),
      headerTrailing: const _CriticalBadge(),
      canEdit: canEdit,
      saving: saving,
      busy: busy,
      onSave: onSave,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select off days — excluded from attendance calculations',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _days.map((d) {
              final isOff = section.valueFor(d.$1);
              return GestureDetector(
                onTap: canEdit ? () => onChanged(section.toggled(d.$1)) : null,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isOff ? AppColors.primary : AppColors.backgroundLow,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isOff ? AppColors.primary : AppColors.border),
                  ),
                  child: Text(
                    d.$2,
                    style: AppTextStyles.caption.copyWith(
                      color: isOff ? Colors.white : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _CriticalBadge extends StatelessWidget {
  const _CriticalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.errorContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'Critical',
        style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ── Punch Rules ────────────────────────────────────────────────────────────────

class _PunchRulesCard extends StatelessWidget {
  final PunchRulesSectionModel section;
  final bool canEdit;
  final bool saving;
  final bool busy;
  final ValueChanged<PunchRulesSectionModel> onChanged;
  final VoidCallback onSave;

  const _PunchRulesCard({
    required this.section,
    required this.canEdit,
    required this.saving,
    required this.busy,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.fingerprint,
      title: 'Punch Rules',
      accentColor: AppColors.info,
      canEdit: canEdit,
      saving: saving,
      busy: busy,
      onSave: onSave,
      child: Column(
        children: [
          _LabeledDropdown<String>(
            label: 'Min Hours — Full Day',
            value: section.minHoursFullDay,
            enabled: canEdit,
            options: const [('8.00', '8 hours'), ('7.00', '7 hours'), ('9.00', '9 hours')],
            onChanged: (v) => v != null ? onChanged(section.copyWith(minHoursFullDay: v)) : null,
          ),
          const SizedBox(height: 12),
          _LabeledDropdown<String>(
            label: 'Min Hours — Half Day',
            value: section.minHoursHalfDay,
            enabled: canEdit,
            options: const [('4.00', '4 hours'), ('3.50', '3.5 hours'), ('5.00', '5 hours')],
            onChanged: (v) => v != null ? onChanged(section.copyWith(minHoursHalfDay: v)) : null,
          ),
          const SizedBox(height: 12),
          _LabeledDropdown<int>(
            label: 'Early Exit Grace',
            value: section.earlyExitGraceMinutes,
            enabled: canEdit,
            options: const [(30, '30 minutes'), (15, '15 minutes'), (45, '45 minutes')],
            onChanged: (v) => v != null ? onChanged(section.copyWith(earlyExitGraceMinutes: v)) : null,
          ),
        ],
      ),
    );
  }
}

// ── Overtime Rules ─────────────────────────────────────────────────────────────

class _OvertimeRulesCard extends StatelessWidget {
  final OvertimeRulesSectionModel section;
  final bool canEdit;
  final bool saving;
  final bool busy;
  final ValueChanged<OvertimeRulesSectionModel> onChanged;
  final VoidCallback onSave;

  const _OvertimeRulesCard({
    required this.section,
    required this.canEdit,
    required this.saving,
    required this.busy,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.trending_up,
      title: 'Overtime Rules',
      accentColor: AppColors.success,
      canEdit: canEdit,
      saving: saving,
      busy: busy,
      onSave: onSave,
      child: Column(
        children: [
          _LabeledDropdown<String>(
            label: 'OT Threshold',
            value: section.otThresholdHours,
            enabled: canEdit,
            options: const [('9.00', '9 hours'), ('8.00', '8 hours'), ('10.00', '10 hours')],
            onChanged: (v) => v != null ? onChanged(section.copyWith(otThresholdHours: v)) : null,
          ),
          const SizedBox(height: 12),
          _LabeledDropdown<String>(
            label: 'Multiplier — Regular',
            value: section.otMultiplierRegular,
            enabled: canEdit,
            options: const [('1.50', '1.5×'), ('1.25', '1.25×'), ('2.00', '2.0×')],
            onChanged: (v) => v != null ? onChanged(section.copyWith(otMultiplierRegular: v)) : null,
          ),
          const SizedBox(height: 12),
          _LabeledDropdown<String>(
            label: 'Multiplier — Holiday',
            value: section.otMultiplierHoliday,
            enabled: canEdit,
            options: const [('2.00', '2.0×'), ('1.50', '1.5×'), ('2.50', '2.5×')],
            onChanged: (v) => v != null ? onChanged(section.copyWith(otMultiplierHoliday: v)) : null,
          ),
        ],
      ),
    );
  }
}

// ── Late Mark & LOP ────────────────────────────────────────────────────────────

class _LateMarkCard extends StatelessWidget {
  final LateMarkRulesSectionModel section;
  final bool canEdit;
  final bool saving;
  final bool busy;
  final ValueChanged<LateMarkRulesSectionModel> onChanged;
  final VoidCallback onSave;

  const _LateMarkCard({
    required this.section,
    required this.canEdit,
    required this.saving,
    required this.busy,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.warning_amber_outlined,
      title: 'Late Mark & LOP Rule',
      accentColor: AppColors.error,
      headerTrailing: const _CriticalBadge(),
      canEdit: canEdit,
      saving: saving,
      busy: busy,
      onSave: onSave,
      child: Column(
        children: [
          _LabeledDropdown<int>(
            label: 'Late Marks per LOP',
            value: section.lateMarksPerLop,
            enabled: canEdit,
            options: const [
              (3, '3 late marks = 1 LOP'),
              (2, '2 late marks = 1 LOP'),
              (4, '4 late marks = 1 LOP'),
              (0, 'No LOP (tracking only)'),
            ],
            onChanged: (v) => v != null ? onChanged(section.copyWith(lateMarksPerLop: v)) : null,
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Resets each calendar month', style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
          ),
          const SizedBox(height: 12),
          _LabeledDropdown<String>(
            label: 'LOP Deduction Unit',
            value: section.lopDeductionUnit,
            enabled: canEdit,
            options: const [('full_day', '1 day'), ('half_day', '0.5 day (half)')],
            onChanged: (v) => v != null ? onChanged(section.copyWith(lopDeductionUnit: v)) : null,
          ),
        ],
      ),
    );
  }
}

// ── Absence Alert ──────────────────────────────────────────────────────────────

class _AbsenceAlertCard extends StatelessWidget {
  final AbsenceAlertSectionModel section;
  final bool canEdit;
  final bool saving;
  final bool busy;
  final ValueChanged<AbsenceAlertSectionModel> onChanged;
  final VoidCallback onSave;

  const _AbsenceAlertCard({
    required this.section,
    required this.canEdit,
    required this.saving,
    required this.busy,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.notifications_active_outlined,
      title: 'Absence Alert',
      accentColor: AppColors.warning,
      headerTrailing: Switch(
        value: section.isEnabled,
        onChanged: canEdit ? (v) => onChanged(section.copyWith(isEnabled: v)) : null,
      ),
      canEdit: canEdit,
      saving: saving,
      busy: busy,
      onSave: onSave,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notify HR and the manager when an employee is absent for N+ '
            'consecutive working days without approved leave.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 12),
          _LabeledDropdown<int>(
            label: 'Alert After N Absent Days',
            value: section.alertAfterDays,
            enabled: canEdit && section.isEnabled,
            options: const [(3, '3 days'), (2, '2 days'), (5, '5 days')],
            onChanged: (v) => v != null ? onChanged(section.copyWith(alertAfterDays: v)) : null,
          ),
          const SizedBox(height: 12),
          _LabeledDropdown<String>(
            label: 'Notify',
            value: section.notifyWhom,
            enabled: canEdit && section.isEnabled,
            options: const [
              ('manager_and_hr', 'Manager + HR'),
              ('hr_only', 'HR Only'),
              ('manager_only', 'Manager Only'),
            ],
            onChanged: (v) => v != null ? onChanged(section.copyWith(notifyWhom: v)) : null,
          ),
        ],
      ),
    );
  }
}

// ── Face ID Verification ─────────────────────────────────────────────────────────

class _FaceVerificationCard extends StatelessWidget {
  final FaceVerificationSectionModel section;
  final bool canEdit;
  final bool saving;
  final bool busy;
  final ValueChanged<FaceVerificationSectionModel> onChanged;
  final VoidCallback onSave;

  const _FaceVerificationCard({
    required this.section,
    required this.canEdit,
    required this.saving,
    required this.busy,
    required this.onChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      icon: Icons.face_outlined,
      title: 'Face ID Verification',
      accentColor: AppColors.error,
      headerTrailing: Switch(
        value: section.isMandatory,
        onChanged: canEdit ? (v) => onChanged(section.copyWith(isMandatory: v)) : null,
      ),
      canEdit: canEdit,
      saving: saving,
      busy: busy,
      onSave: onSave,
      child: Text(
        section.isMandatory
            ? 'Face ID registration is mandatory for every employee. Clock-in/out '
                '(web and mobile) is blocked until an employee registers and is '
                'approved, and every punch after that requires a live face match.'
            : 'Face ID verification is off. Employees cannot register a face ID or '
                'be asked to verify — their Profile page shows "Contact admin to use '
                'this feature", and no punch requires a face match.',
        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────────────

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
            Text('Could not load attendance settings', style: AppTextStyles.h4),
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

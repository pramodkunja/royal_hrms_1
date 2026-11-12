import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/network/api_client.dart' show dioProvider;
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../attendance/presentation/providers/attendance_providers.dart'
    show attendanceStatsProvider, employeeAttendanceStatsProvider;
import '../../../../auth/domain/entities/user_entity.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../data/models/late_limit_models.dart';
import '../../providers/settings_providers.dart' show friendlySettingsError;

// Settings → Leave Policy → "Maximum Late Arrivals Per Month" — web
// settings/leave-policy/_components/LateArrivalLimitCard.tsx (top of the
// Leave Policy tab). Company-wide and tracking only: it never adds LOP and
// never touches attendance records or pay. Editing is the server's
// can_edit (settings.edit or leave.approve); the over-limit list is for HR
// (attendance.edit) or Leave Policy admins, and the server scopes it
// (branch / a manager's direct reports).

final lateLimitApiProvider = Provider<LateLimitApi>((ref) => LateLimitApi(ref.watch(dioProvider)));

final lateLimitSettingProvider =
    FutureProvider.autoDispose<LateLimitSetting>((ref) => ref.read(lateLimitApiProvider).fetch());

typedef LateLimitEmployeesQuery = ({String month, bool includeReached});

final lateLimitEmployeesProvider = FutureProvider.autoDispose.family<LateLimitEmployees, LateLimitEmployeesQuery>(
    (ref, q) => ref.read(lateLimitApiProvider).employees(month: q.month, includeReached: q.includeReached));

/// Web usePermission("attendance.edit") (superuser or the permission) — who
/// may see the over-limit list besides Leave Policy admins.
bool canSeeLateLimitEmployees(UserEntity? u) => u != null && (u.isSuperuser || u.hasPermission('attendance.edit'));

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

class LateArrivalLimitCard extends ConsumerStatefulWidget {
  const LateArrivalLimitCard({super.key, this.today});

  /// The month shown first (tests); defaults to now.
  final DateTime? today;

  @override
  ConsumerState<LateArrivalLimitCard> createState() => _LateArrivalLimitCardState();
}

class _LateArrivalLimitCardState extends ConsumerState<LateArrivalLimitCard> {
  bool _enabled = true;
  final _maximum = TextEditingController();
  LateLimitSetting? _loaded;
  bool _saving = false;
  String? _err;
  late DateTime _month;
  bool _includeReached = false;

  @override
  void initState() {
    super.initState();
    final t = widget.today ?? DateTime.now();
    _month = DateTime(t.year, t.month);
  }

  @override
  void dispose() {
    _maximum.dispose();
    super.dispose();
  }

  /// Web useEffect([data]): the form follows each fresh server value.
  void _sync(LateLimitSetting s) {
    if (identical(s, _loaded)) return;
    _loaded = s;
    _enabled = s.enabled;
    _maximum.text = '${s.maximum}';
  }

  String? get _fieldErr => _enabled
      ? lateLimitMaximumError(_maximum.text)
      : (_maximum.text.trim().isNotEmpty ? lateLimitMaximumError(_maximum.text) : null);

  bool get _dirty {
    final s = _loaded;
    return s != null && (s.enabled != _enabled || '${s.maximum}' != _maximum.text.trim());
  }

  LateLimitEmployeesQuery get _query => (month: lateLimitMonthParam(_month), includeReached: _includeReached);

  Future<void> _save() async {
    final s = _loaded;
    final fieldErr = _fieldErr;
    if (fieldErr != null) {
      setState(() => _err = fieldErr);
      return;
    }
    if (s == null || _saving) return;
    setState(() {
      _saving = true;
      _err = null;
    });
    try {
      final text = _maximum.text.trim();
      final msg = await ref
          .read(lateLimitApiProvider)
          .save(enabled: _enabled, maximum: text.isEmpty ? s.maximum : int.parse(text));
      ref.invalidate(lateLimitSettingProvider);
      ref.invalidate(lateLimitEmployeesProvider);
      // The employee's own monthly summary (My Attendance) follows the limit.
      ref.invalidate(attendanceStatsProvider);
      ref.invalidate(employeeAttendanceStatsProvider);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
    } catch (e) {
      if (!mounted) return;
      final m = friendlySettingsError(e);
      setState(() {
        _saving = false;
        _err = m.isEmpty ? 'Could not save.' : m;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // A fresh server value (first load, or after a save) resets the form.
    ref.listen(lateLimitSettingProvider, (_, next) {
      final s = next.valueOrNull;
      if (s != null && !identical(s, _loaded)) setState(() => _sync(s));
    });
    final async = ref.watch(lateLimitSettingProvider);
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    return Container(
      key: const Key('late-limit-card'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Icon(Icons.timer_off_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text('Maximum Late Arrivals Per Month',
                style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
          ),
        ]),
        const SizedBox(height: 10),
        ...async.when(
          loading: () => [
            if (_loaded == null)
              const Padding(
                key: Key('late-limit-loading'),
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Loading…'),
              )
            else
              ..._body(_loaded!, user),
          ],
          error: (e, _) => [
            Text(friendlySettingsError(e),
                key: const Key('late-limit-load-error'),
                style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('late-limit-retry'),
                onPressed: () => ref.invalidate(lateLimitSettingProvider),
                child: const Text('Retry'),
              ),
            ),
          ],
          data: (s) {
            if (_loaded == null) _sync(s); // already loaded when this card appeared
            return _body(s, user);
          },
        ),
      ]),
    );
  }

  List<Widget> _body(LateLimitSetting s, UserEntity? user) {
    final canEdit = s.canEdit;
    final fieldErr = _fieldErr;
    final small = AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary);
    final showEmployees = canSeeLateLimitEmployees(user) || canEdit;
    return [
      Text.rich(
        TextSpan(style: small, children: const [
          TextSpan(
              text: 'Company-wide tracking limit, counted per calendar month and reset on the 1st. '
                  'Late (Excused) days are not counted. '),
          TextSpan(text: 'It does not add LOP', style: TextStyle(fontWeight: FontWeight.w700)),
          TextSpan(text: ' — late-mark deductions stay as set in Settings → Attendance Rules.'),
        ]),
        key: const Key('late-limit-intro'),
      ),
      if (!s.configured)
        Container(
          key: const Key('late-limit-not-configured'),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(8)),
          child: Text(
              'Save Settings → Attendance Rules once before changing this limit. Until then the default applies.',
              style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
        ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('Maximum Late Arrivals Per Month', style: AppTextStyles.bodySmall)),
        Text(_enabled ? 'Enabled' : 'Disabled', style: AppTextStyles.caption),
        Switch(
          key: const Key('late-limit-enabled'),
          value: _enabled,
          onChanged: !canEdit || _saving ? null : (v) => setState(() => _enabled = v),
        ),
      ]),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('Maximum Allowed Late Arrivals', style: AppTextStyles.bodySmall),
        )),
        SizedBox(
          width: 110,
          child: TextField(
            key: const Key('late-limit-maximum'),
            controller: _maximum,
            enabled: canEdit && !_saving && _enabled,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onChanged: (_) => setState(() => _err = null),
          ),
        ),
      ]),
      if (fieldErr != null && canEdit)
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(fieldErr,
                key: const Key('late-limit-field-error'),
                style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 12)),
          ),
        ),
      if (_err != null)
        Container(
          key: const Key('late-limit-error'),
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(10),
          decoration:
              BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8)),
          child: Text(_err!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
        ),
      const SizedBox(height: 10),
      if (canEdit)
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            key: const Key('late-limit-save'),
            onPressed: !_dirty || _saving || fieldErr != null || !s.configured ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        )
      else
        Text('Read only — only Leave Policy administrators can change this.',
            key: const Key('late-limit-read-only'), style: AppTextStyles.caption.copyWith(fontSize: 12)),
      if (showEmployees) ...[
        const SizedBox(height: 12),
        Divider(height: 1, color: AppColors.border),
        const SizedBox(height: 12),
        _employees(s),
      ],
    ];
  }

  Widget _employees(LateLimitSetting s) {
    final async = ref.watch(lateLimitEmployeesProvider(_query));
    final small = AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary);
    return Column(key: const Key('late-limit-employees'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Employees over the limit', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Row(children: [
        IconButton(
          key: const Key('late-limit-prev-month'),
          tooltip: 'Previous month',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
          icon: const Icon(Icons.chevron_left),
        ),
        Text('${_months[_month.month - 1]} ${_month.year}',
            key: const Key('late-limit-month'), style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
        IconButton(
          key: const Key('late-limit-next-month'),
          tooltip: 'Next month',
          visualDensity: VisualDensity.compact,
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
      GestureDetector(
        key: const Key('late-limit-include-reached'),
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _includeReached = !_includeReached),
        child: Row(children: [
          Checkbox(
            value: _includeReached,
            visualDensity: VisualDensity.compact,
            onChanged: (v) => setState(() => _includeReached = v ?? false),
          ),
          Expanded(child: Text('Include “Limit reached”', style: AppTextStyles.bodySmall)),
        ]),
      ),
      async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('Loading…', key: Key('late-limit-employees-loading')),
        ),
        error: (e, _) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(friendlySettingsError(e),
              key: const Key('late-limit-employees-error'),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
          TextButton(
            key: const Key('late-limit-employees-retry'),
            onPressed: () => ref.invalidate(lateLimitEmployeesProvider(_query)),
            child: const Text('Retry'),
          ),
        ]),
        data: (over) {
          if (!over.enabled) {
            return Text('The limit is disabled — nothing is tracked.',
                key: const Key('late-limit-employees-disabled'), style: small);
          }
          if (over.results.isEmpty) {
            return Text(
                'No employees ${_includeReached ? 'at or over' : 'over'} the limit of ${over.maximum} in this month.',
                key: const Key('late-limit-employees-empty'),
                style: small);
          }
          return Column(children: [for (final r in over.results) _employeeRow(r, over.maximum)]);
        },
      ),
    ]);
  }

  Widget _employeeRow(LateLimitEmployee r, int maximum) {
    final color = switch (r.status) {
      'exceeded' => AppColors.error,
      'reached' => AppColors.warning,
      _ => AppColors.success,
    };
    return Container(
      key: Key('late-limit-row-${r.employee}'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: r.name, style: const TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: '  ${r.employeeCode}', style: TextStyle(color: AppColors.textSecondary)),
            ]), style: AppTextStyles.bodySmall),
            Text('${r.branch.isEmpty ? '—' : r.branch} · ${r.department.isEmpty ? '—' : r.department}',
                style: AppTextStyles.caption.copyWith(fontSize: 11)),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${r.lateArrivals} / $maximum',
              key: Key('late-limit-count-${r.employee}'),
              style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Text('${r.statusLabel}${r.overBy > 0 ? ' (+${r.overBy})' : ''}',
                key: Key('late-limit-status-${r.employee}'),
                style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
          ),
        ]),
      ]),
    );
  }
}

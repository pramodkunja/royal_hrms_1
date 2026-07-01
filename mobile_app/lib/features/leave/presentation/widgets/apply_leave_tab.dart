import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../providers/leave_providers.dart';
import 'apply_leave_type_selector.dart';

// ── Duration options ───────────────────────────────────────────────────────────

enum _Duration { fullDay, halfMorning, halfAfternoon }

// ── Static sidebar data (team on leave / history stay as mock) ────────────────

const _kTeamOnLeave = <(String, String, String, String, String)>[
  ('Priya Sharma', 'PS', 'EL', 'Jun 24', 'Jun 28'),
  ('Rahul Singh',  'RS', 'CL', 'Jun 26', 'Jun 26'),
];

const _kLeaveHistory = <(String, String, int, String)>[
  ('Casual Leave', 'May 12', 2, 'approved'),
  ('Sick Leave',   'Apr 3',  1, 'approved'),
  ('Earned Leave', 'Mar 20', 6, 'rejected'),
];

// ── Apply Leave Tab ───────────────────────────────────────────────────────────

class ApplyLeaveTab extends ConsumerStatefulWidget {
  final VoidCallback? onDashboard;
  const ApplyLeaveTab({super.key, this.onDashboard});

  @override
  ConsumerState<ApplyLeaveTab> createState() => _ApplyLeaveTabState();
}

class _ApplyLeaveTabState extends ConsumerState<ApplyLeaveTab> {
  String _selectedType = '';
  _Duration _duration  = _Duration.fullDay;
  DateTime? _fromDate;
  DateTime? _toDate;
  final _reasonCtrl       = TextEditingController();
  final _handoverCtrl     = TextEditingController();
  final _contactCtrl      = TextEditingController();
  final _handoverNoteCtrl = TextEditingController();
  final _formKey          = GlobalKey<FormState>();
  bool _loading   = false;
  bool _submitted = false;
  String? _error;
  String? _submittedTypeName;

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _handoverCtrl.dispose();
    _contactCtrl.dispose();
    _handoverNoteCtrl.dispose();
    super.dispose();
  }

  bool get _isHalfDay => _duration != _Duration.fullDay;

  int _workingDays(DateTime from, DateTime? to) {
    if (_isHalfDay) return 0;
    final end = to ?? from;
    if (end.isBefore(from)) return 0;
    int count = 0;
    DateTime cur = from;
    while (!cur.isAfter(end)) {
      if (cur.weekday != DateTime.saturday &&
          cur.weekday != DateTime.sunday) { count++; }
      cur = cur.add(const Duration(days: 1));
    }
    return count;
  }

  String _toIso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _durationCode() => switch (_duration) {
    _Duration.fullDay       => 'full_day',
    _Duration.halfMorning   => 'half_day_morning',
    _Duration.halfAfternoon => 'half_day_afternoon',
  };

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom
          ? (_fromDate ?? now)
          : (_toDate ?? (_fromDate ?? now)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _fromDate = picked;
        if (_toDate != null && _toDate!.isBefore(picked)) {
          _toDate = picked;
        }
      } else {
        _toDate = picked;
      }
    });
  }

  Future<void> _submit(List<LeaveTypeOption> typeOptions) async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromDate == null) {
      setState(() => _error = 'Please select a start date.');
      return;
    }
    if (!_isHalfDay && _toDate == null) {
      setState(() => _error = 'Please select an end date.');
      return;
    }
    final lt =
        typeOptions.firstWhere((t) => t.key == _selectedType, orElse: () => typeOptions.first);
    final days = _isHalfDay ? 0.5 : _workingDays(_fromDate!, _toDate).toDouble();
    final isLwp = lt.code == 'LWP';
    if (!isLwp && days > lt.balance && days > 0) {
      setState(() => _error =
          'Requested days exceed your ${lt.label} balance (${lt.balance}d).');
      return;
    }

    setState(() { _loading = true; _error = null; });

    final err = await ref.read(leaveRequestsProvider.notifier).applyLeave(
          leaveTypeCode: lt.code,
          fromDate:      _toIso(_fromDate!),
          toDate:        _toIso(_isHalfDay ? _fromDate! : _toDate!),
          reason:        _reasonCtrl.text.trim(),
          duration:      _durationCode(),
        );

    if (!mounted) return;
    setState(() { _loading = false; });

    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() { _submitted = true; _submittedTypeName = lt.label; });
      ref.invalidate(leaveBalancesProvider);
      ref.invalidate(leaveStatsProvider);
    }
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.save_outlined, size: 14, color: Colors.white),
            SizedBox(width: 8),
            Text('Draft saved'),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _reset() {
    setState(() {
      _selectedType = '';
      _duration     = _Duration.fullDay;
      _fromDate     = null;
      _toDate       = null;
      _reasonCtrl.clear();
      _handoverCtrl.clear();
      _contactCtrl.clear();
      _handoverNoteCtrl.clear();
      _error        = null;
      _submitted    = false;
      _submittedTypeName = null;
    });
  }

  // ── Success screen ────────────────────────────────────────────────────────────

  Widget _successView() {
    final days = _isHalfDay
        ? '0.5 working day'
        : '${_workingDays(_fromDate!, _toDate)} working day${_workingDays(_fromDate!, _toDate) != 1 ? "s" : ""}';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline,
                  size: 40, color: AppColors.success),
            ),
            const SizedBox(height: 16),
            Text('Request Submitted!', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Your ${_submittedTypeName ?? ''} request for $days '
              'has been sent for approval.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('APPROVAL CHAIN',
                      style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                          letterSpacing: 0.5)),
                  const SizedBox(height: 10),
                  for (final step in ['You', 'Line Manager', 'HR Manager'])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            child: Text(step[0],
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary)),
                          ),
                          const SizedBox(width: 8),
                          Text(step,
                              style: AppTextStyles.caption.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _reset,
                    child: const Text('Apply Another'),
                  ),
                ),
                if (widget.onDashboard != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: widget.onDashboard,
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary),
                      child: const Text('Dashboard',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Main build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final typesAsync    = ref.watch(leaveTypesProvider);
    final balancesAsync = ref.watch(leaveBalancesProvider);
    final authAsync     = ref.watch(authStateProvider);

    // auto-select first type once data loads
    ref.listen(leaveTypesProvider, (_, next) {
      if (_selectedType.isEmpty &&
          next.hasValue &&
          next.value!.isNotEmpty) {
        setState(() => _selectedType = next.value!.first.code);
      }
    });

    final typeEntities  = typesAsync.valueOrNull ?? [];
    final balances      = balancesAsync.valueOrNull ?? [];
    final typeOptions   = LeaveTypeOption.listFromEntities(typeEntities, balances);

    // ensure _selectedType valid when types reload
    if (_selectedType.isEmpty && typeOptions.isNotEmpty) {
      _selectedType = typeOptions.first.key;
    }

    final user = authAsync.valueOrNull?.user;

    LeaveTypeOption? lt = typeOptions.isEmpty
        ? null
        : typeOptions.firstWhere((t) => t.key == _selectedType,
            orElse: () => typeOptions.first);

    final days = _fromDate != null
        ? (_isHalfDay ? 0.5 : _workingDays(_fromDate!, _toDate).toDouble())
        : 0.0;
    final overLimit = lt != null &&
        lt.code != 'LWP' &&
        lt.code != 'ML' &&
        lt.code != 'PL' &&
        days > lt.balance &&
        days > 0;

    if (_submitted) return _successView();

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Employee banner
            _EmployeeBanner(user: user),
            const SizedBox(height: 14),

            // Leave type selector
            _Card(
              child: typesAsync.isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    )
                  : LeaveTypeSelector(
                      types: typeOptions,
                      selectedKey: _selectedType,
                      onSelect: (k) =>
                          setState(() => _selectedType = k),
                    ),
            ),
            const SizedBox(height: 12),

            // Duration + dates
            _Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel(text: 'Duration'),
                  const SizedBox(height: 8),
                  _DurationToggle(
                    value: _duration,
                    onChanged: (d) => setState(() {
                      _duration = d;
                      if (_isHalfDay) _toDate = null;
                    }),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel(text: 'Start Date', required: true),
                            const SizedBox(height: 6),
                            _DateField(
                                value: _fromDate,
                                hint: 'Select',
                                onTap: () => _pickDate(true)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            FieldLabel(
                                text: 'End Date',
                                required: !_isHalfDay),
                            const SizedBox(height: 6),
                            _DateField(
                              value: _isHalfDay ? _fromDate : _toDate,
                              hint: 'Select',
                              disabled: _isHalfDay,
                              onTap:
                                  _isHalfDay ? null : () => _pickDate(false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (_fromDate != null &&
                      (_isHalfDay || _toDate != null)) ...[
                    const SizedBox(height: 10),
                    _WorkingDaysChip(
                      days: days,
                      balance: lt?.balance.toDouble() ?? 0,
                      isLwp: lt?.code == 'LWP',
                      overLimit: overLimit,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Reason + document
            _Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const FieldLabel(
                      text: 'Reason for Leave', required: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _reasonCtrl,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText:
                          'Briefly describe the reason for your leave…',
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Reason is required.';
                      }
                      if (v.trim().length < 10) {
                        return 'Minimum 10 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const FieldLabel(text: 'Supporting Document'),
                      const SizedBox(width: 4),
                      Text(
                        (lt?.docRequired ?? false)
                            ? '(Required)'
                            : '(Optional)',
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            color: (lt?.docRequired ?? false)
                                ? AppColors.error
                                : AppColors.textHint),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.symmetric(vertical: 18),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: (lt?.docRequired ?? false)
                              ? AppColors.warning.withValues(alpha: 0.5)
                              : AppColors.border,
                          style: BorderStyle.solid,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.backgroundLow,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_upload_outlined,
                              size: 24, color: AppColors.textHint),
                          const SizedBox(height: 4),
                          Text('Tap to upload',
                              style: AppTextStyles.caption),
                          Text('PDF, JPG, PNG · Max 5 MB',
                              style: AppTextStyles.caption
                                  .copyWith(fontSize: 10)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Handover & Contact
            _Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_forward,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Handover & Contact',
                          style: AppTextStyles.label),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel(text: 'Handover To'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _handoverCtrl,
                              decoration: const InputDecoration(
                                hintText: 'Colleague name',
                                prefixIcon: Icon(
                                    Icons.person_outline,
                                    size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel(text: 'Emergency Contact'),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _contactCtrl,
                              decoration: const InputDecoration(
                                hintText: '+91 9876543210',
                                prefixIcon:
                                    Icon(Icons.phone_outlined, size: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const FieldLabel(text: 'Handover Notes'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _handoverNoteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      hintText:
                          'Pending tasks, important context, coverage instructions…',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Sidebar info cards
            _RequestSummarySideCard(
              lt: lt,
              duration: _duration,
              fromDate: _fromDate,
              toDate: _toDate,
              workingDays: _fromDate != null
                  ? (_isHalfDay ? 0.5 : _workingDays(_fromDate!, _toDate).toDouble())
                  : 0,
              isHalfDay: _isHalfDay,
              employeeName: user?.fullName ?? '',
            ),
            const SizedBox(height: 10),
            _LeaveBalanceSideCard(lt: lt, overLimit: overLimit),
            const SizedBox(height: 10),
            const _ApprovalChainSideCard(),
            const SizedBox(height: 10),
            const _TeamOnLeaveSideCard(),
            const SizedBox(height: 10),
            const _MyLeaveHistorySideCard(),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 14, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_error!,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.error)),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                OutlinedButton(
                  onPressed: _loading ? null : _reset,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _loading ? null : _saveDraft,
                  icon: const Icon(Icons.save_outlined, size: 15),
                  label: const Text('Draft',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: (_loading || typeOptions.isEmpty)
                        ? null
                        : () => _submit(typeOptions),
                    icon: _loading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_outlined, size: 16),
                    label: Text(_loading ? 'Submitting…' : 'Submit',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600)),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding:
                          const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Card container ────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }
}

// ── Employee banner ───────────────────────────────────────────────────────────

class _EmployeeBanner extends StatelessWidget {
  final UserEntity? user;
  const _EmployeeBanner({this.user});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();
  }

  @override
  Widget build(BuildContext context) {
    final name       = user?.fullName ?? '';
    final employeeId = user?.employeeId ?? '';
    final initials   = name.isNotEmpty ? _initials(name) : '?';
    final subtitle   = [user?.designation, user?.department]
        .where((v) => v != null && v.isNotEmpty)
        .join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name.isNotEmpty ? name : 'Loading…',
                        style: AppTextStyles.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (employeeId.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(employeeId,
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Duration toggle ───────────────────────────────────────────────────────────

class _DurationToggle extends StatelessWidget {
  final _Duration value;
  final ValueChanged<_Duration> onChanged;
  const _DurationToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const opts = [
      (_Duration.fullDay,       Icons.wb_sunny_outlined,    'Full Day'),
      (_Duration.halfMorning,   Icons.wb_sunny,             'Half · AM'),
      (_Duration.halfAfternoon, Icons.nights_stay_outlined, 'Half · PM'),
    ];
    return Row(
      children: opts.map((opt) {
        final selected = opt.$1 == value;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(opt.$1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.backgroundLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color:
                        selected ? AppColors.primary : AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(opt.$2,
                      size: 14,
                      color: selected
                          ? Colors.white
                          : AppColors.textSecondary),
                  const SizedBox(height: 3),
                  Text(opt.$3,
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── Date field ────────────────────────────────────────────────────────────────

class _DateField extends StatelessWidget {
  final DateTime? value;
  final String hint;
  final bool disabled;
  final VoidCallback? onTap;
  const _DateField(
      {this.value, required this.hint, this.disabled = false, this.onTap});

  static String _format(DateTime d) {
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color:
              disabled ? AppColors.backgroundLow : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 13,
                color: disabled
                    ? AppColors.textHint
                    : AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value != null ? _format(value!) : hint,
                style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: value != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                    fontWeight: value != null
                        ? FontWeight.w600
                        : FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Working days chip ─────────────────────────────────────────────────────────

class _WorkingDaysChip extends StatelessWidget {
  final double days;
  final double balance;
  final bool isLwp;
  final bool overLimit;
  const _WorkingDaysChip(
      {required this.days,
      required this.balance,
      required this.isLwp,
      required this.overLimit});

  @override
  Widget build(BuildContext context) {
    final color = overLimit ? AppColors.error : AppColors.primary;
    final label = days == 0.5
        ? '0.5 working day'
        : '${days.toInt()} working day${days.toInt() == 1 ? "" : "s"}';
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
              overLimit
                  ? Icons.warning_amber_outlined
                  : Icons.calendar_month_outlined,
              size: 14,
              color: color),
          const SizedBox(width: 8),
          Text(label,
              style: AppTextStyles.caption
                  .copyWith(color: color, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (!isLwp)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                overLimit
                    ? 'Exceeds balance'
                    : '${(balance - days).toStringAsFixed(days == 0.5 ? 1 : 0)}d will remain',
                style: AppTextStyles.caption.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Sidebar card wrapper ──────────────────────────────────────────────────────

class _SideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _SideCard(
      {required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 7),
                Text(title,
                    style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        fontSize: 12)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),
          Padding(padding: const EdgeInsets.all(14), child: child),
        ],
      ),
    );
  }
}

// ── Request Summary ───────────────────────────────────────────────────────────

class _RequestSummarySideCard extends StatelessWidget {
  final LeaveTypeOption? lt;
  final _Duration duration;
  final DateTime? fromDate;
  final DateTime? toDate;
  final double workingDays;
  final bool isHalfDay;
  final String employeeName;

  const _RequestSummarySideCard({
    required this.lt,
    required this.duration,
    required this.fromDate,
    required this.toDate,
    required this.workingDays,
    required this.isHalfDay,
    required this.employeeName,
  });

  static String _fmt(DateTime? d) {
    if (d == null) return '—';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  String get _durationLabel => switch (duration) {
    _Duration.fullDay       => 'Full Day',
    _Duration.halfMorning   => 'Half Day (AM)',
    _Duration.halfAfternoon => 'Half Day (PM)',
  };

  String get _daysLabel {
    if (fromDate == null) return '—';
    if (isHalfDay) return '0.5 day';
    return workingDays > 0
        ? '${workingDays.toInt()} day${workingDays.toInt() == 1 ? "" : "s"}'
        : '—';
  }

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (Icons.person_outline,          'Employee',     employeeName.isNotEmpty ? employeeName : '—'),
      (Icons.beach_access_outlined,   'Leave Type',   lt?.label ?? '—'),
      (Icons.wb_sunny_outlined,       'Duration',     _durationLabel),
      (Icons.calendar_today_outlined, 'From',         _fmt(fromDate)),
      (Icons.calendar_today_outlined, 'To',           isHalfDay ? _fmt(fromDate) : _fmt(toDate)),
      (Icons.work_outline,            'Working Days', _daysLabel),
    ];
    return _SideCard(
      icon: Icons.description_outlined,
      title: 'Request Summary',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: rows
            .map((row) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Row(
                    children: [
                      Container(
                        width: 26, height: 26,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Icon(row.$1, size: 12, color: AppColors.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(row.$2,
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 9,
                                    color: AppColors.textHint)),
                            Text(row.$3,
                                style: AppTextStyles.caption.copyWith(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ── Leave Balance ─────────────────────────────────────────────────────────────

class _LeaveBalanceSideCard extends StatelessWidget {
  final LeaveTypeOption? lt;
  final bool overLimit;
  const _LeaveBalanceSideCard({required this.lt, required this.overLimit});

  @override
  Widget build(BuildContext context) {
    if (lt == null) {
      return const _SideCard(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Leave Balance',
        child: SizedBox(
          height: 40,
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }
    final isLwp      = lt!.code == 'LWP';
    final balancePct =
        isLwp ? 1.0 : (lt!.total > 0 ? (lt!.balance / lt!.total).clamp(0.0, 1.0) : 0.0);

    return _SideCard(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Leave Balance',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: lt!.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Text(lt!.code,
                      style: AppTextStyles.caption.copyWith(
                          color: lt!.color,
                          fontWeight: FontWeight.w800,
                          fontSize: 9)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lt!.label,
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Text(
                      isLwp
                          ? 'Unpaid · No limit'
                          : '${lt!.balance} of ${lt!.total} days left',
                      style: AppTextStyles.caption.copyWith(fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!isLwp) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: balancePct,
                minHeight: 6,
                backgroundColor: lt!.color.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(lt!.color),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${lt!.total - lt!.balance} used',
                    style: AppTextStyles.caption.copyWith(
                        fontSize: 10, color: AppColors.textHint)),
                Text('${lt!.balance} remaining',
                    style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: lt!.color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          if (overLimit) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 13, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                        'Requested days exceed your balance.',
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 10, color: AppColors.error)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Approval Chain ────────────────────────────────────────────────────────────

class _ApprovalChainSideCard extends StatelessWidget {
  const _ApprovalChainSideCard();

  @override
  Widget build(BuildContext context) {
    const steps = <(String, String, String, bool)>[
      ('ME', 'You',          'Requestor',    true),
      ('LM', 'Line Manager', 'L1 Approver',  false),
      ('HR', 'HR Manager',   'L2 Approver',  false),
    ];
    return _SideCard(
      icon: Icons.account_tree_outlined,
      title: 'Approval Chain',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(steps.length, (i) {
          final step = steps[i];
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      color: step.$4
                          ? AppColors.primary
                          : AppColors.backgroundLow,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: step.$4
                              ? AppColors.primary
                              : AppColors.border),
                    ),
                    child: Center(
                      child: Text(step.$1,
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: step.$4
                                  ? Colors.white
                                  : AppColors.textSecondary)),
                    ),
                  ),
                  if (i < steps.length - 1)
                    Container(width: 1, height: 20, color: AppColors.border),
                ],
              ),
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.$2,
                        style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text(step.$3,
                        style:
                            AppTextStyles.caption.copyWith(fontSize: 10)),
                  ],
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Team on Leave ─────────────────────────────────────────────────────────────

class _TeamOnLeaveSideCard extends StatelessWidget {
  const _TeamOnLeaveSideCard();

  @override
  Widget build(BuildContext context) {
    const avatarColors = [AppColors.info, AppColors.primary];
    return _SideCard(
      icon: Icons.people_outline,
      title: 'Team on Leave',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(
                '${_kTeamOnLeave.length} teammate${_kTeamOnLeave.length == 1 ? "" : "s"} on leave',
                style: AppTextStyles.caption
                    .copyWith(fontSize: 10, color: AppColors.textHint),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_kTeamOnLeave.length}',
                    style: AppTextStyles.caption.copyWith(
                        color: AppColors.warning,
                        fontWeight: FontWeight.w700,
                        fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...List.generate(_kTeamOnLeave.length, (i) {
            final member = _kTeamOnLeave[i];
            final color  = avatarColors[i % avatarColors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(member.$2,
                          style: AppTextStyles.caption.copyWith(
                              color: color,
                              fontWeight: FontWeight.w800,
                              fontSize: 9)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.$1,
                            style: AppTextStyles.caption.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text('${member.$4} – ${member.$5}',
                            style: AppTextStyles.caption
                                .copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(member.$3,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 9)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── My Leave History ──────────────────────────────────────────────────────────

class _MyLeaveHistorySideCard extends StatelessWidget {
  const _MyLeaveHistorySideCard();

  @override
  Widget build(BuildContext context) {
    return _SideCard(
      icon: Icons.history_outlined,
      title: 'My Leave History',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_kLeaveHistory.length, (i) {
          final record     = _kLeaveHistory[i];
          final isApproved = record.$4 == 'approved';
          final statusColor =
              isApproved ? AppColors.success : AppColors.error;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.$1,
                          style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text('${record.$2}  ·  ${record.$3}d',
                          style:
                              AppTextStyles.caption.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(isApproved ? '✓' : '✗',
                      style: AppTextStyles.caption.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 10)),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

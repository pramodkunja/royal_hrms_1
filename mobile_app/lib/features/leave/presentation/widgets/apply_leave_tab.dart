import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../documents/presentation/widgets/document_file_picker.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/leave_entity.dart';
import '../providers/leave_providers.dart';
import 'apply_leave_type_selector.dart';
import 'leave_type_icons.dart';

// ── Duration options ───────────────────────────────────────────────────────────

enum _Duration { fullDay, halfMorning, halfAfternoon }

// Must match backend LeaveRequestCreateSerializer.validate_document.
const _kMaxDocBytes = 5 * 1024 * 1024;
const _kAllowedDocExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

// ── Policy helpers ────────────────────────────────────────────────────────────
//
// Mirrors backend `_calc_working_days` / `_validate_leave_policy` / the
// balance-check branch in `LeaveRequestCreateView.post`
// (web_frontend_backend/Royal-HRMS/backend/apps/hrms/views/leave.py).

/// Finds the [LeaveTypeEntity] backing a given leave-type code, falling back
/// to a default-policy entity (mirrors `LeaveTypeOption.listFromEntities`'s
/// own synthesized fallback) so callers always get sensible policy defaults
/// even before the backend policy list has loaded.
LeaveTypeEntity _resolveLeaveEntity(
    List<LeaveTypeEntity> entities, String code) {
  for (final e in entities) {
    if (e.code.toLowerCase() == code.toLowerCase()) return e;
  }
  return LeaveTypeEntity(
    id: 0,
    name: '',
    code: code,
    maxDays: 0,
    isPaid: true,
    carryForward: false,
    docRequired: false,
    genderEligibility: 'all',
    isActive: true,
    description: '',
    policy: '',
  );
}

/// Formats a day count trimming a trailing `.0` (e.g. `2` not `2.0`, but
/// `2.5` stays `2.5`) — matches the existing chip/side-card formatting style.
String _fmtDays(double d) =>
    d == d.roundToDouble() ? d.toInt().toString() : d.toStringAsFixed(1);

enum _BalanceMode { lop, negative, blocked }

/// Result of comparing requested days against available balance, per the
/// backend's `convert_to_lop` / `allow_negative_balance` / hard-block
/// three-way branch (`views/leave.py` `post()`, balance-check block).
class _BalanceCheck {
  final _BalanceMode mode;
  final double available;
  final double requested;
  final double excess; // requested - available
  const _BalanceCheck({
    required this.mode,
    required this.available,
    required this.requested,
    required this.excess,
  });
}

/// Mirrors the backend: only runs when `requested > available`; `convert_to_lop`
/// takes priority over `allow_negative_balance` (backend uses an if/elif chain).
_BalanceCheck? _evaluateBalance({
  required bool isLwp,
  required double available,
  required double requested,
  required bool convertToLop,
  required bool allowNegativeBalance,
}) {
  if (isLwp || requested <= 0 || requested <= available) return null;
  final excess = requested - available;
  if (convertToLop) {
    return _BalanceCheck(
        mode: _BalanceMode.lop,
        available: available,
        requested: requested,
        excess: excess);
  }
  if (allowNegativeBalance) {
    return _BalanceCheck(
        mode: _BalanceMode.negative,
        available: available,
        requested: requested,
        excess: excess);
  }
  return _BalanceCheck(
      mode: _BalanceMode.blocked,
      available: available,
      requested: requested,
      excess: excess);
}

/// Duration/half-day-shaped violations — shown near the Duration toggle /
/// working-days chip. Mirrors the first half of backend `_validate_leave_policy`
/// (allow_half_day, minimum/maximum_leave_duration, maximum_consecutive_days),
/// in the same order.
List<String> _durationErrors({
  required LeaveTypeEntity entity,
  required bool isHalfDay,
  required double days,
}) {
  final errors = <String>[];
  if (isHalfDay && !entity.allowHalfDay) {
    errors.add('Half-day leave is not allowed for this leave type.');
  }
  if (entity.minimumLeaveDuration > 0 &&
      days > 0 &&
      days < entity.minimumLeaveDuration) {
    errors.add(
        'Minimum ${_fmtDays(entity.minimumLeaveDuration)}d required for this leave type.');
  }
  if (entity.maximumLeaveDuration > 0 && days > entity.maximumLeaveDuration) {
    errors.add(
        'Maximum ${entity.maximumLeaveDuration}d allowed for this leave type.');
  }
  if (entity.maximumConsecutiveDays > 0 &&
      days > entity.maximumConsecutiveDays) {
    errors.add(
        'Maximum ${entity.maximumConsecutiveDays} consecutive day(s) allowed for this leave type.');
  }
  return errors;
}

/// Date-shaped violations — shown near the Start Date field. Mirrors the
/// second half of backend `_validate_leave_policy` (minimum_notice_period,
/// allow_backdated_leave/maximum_backdated_days, allow_future_leave/
/// maximum_future_days), in the same order.
List<String> _dateErrors({
  required LeaveTypeEntity entity,
  required DateTime start,
}) {
  final errors = <String>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final startDate = DateTime(start.year, start.month, start.day);

  final noticeDays = startDate.difference(today).inDays;
  if (entity.minimumNoticePeriod > 0 &&
      noticeDays < entity.minimumNoticePeriod) {
    errors.add(
        'Requires at least ${entity.minimumNoticePeriod}d advance notice.');
  }
  if (startDate.isBefore(today)) {
    if (!entity.allowBackdatedLeave) {
      errors.add(
          'Backdated leave applications are not allowed for this leave type.');
    } else if (entity.maximumBackdatedDays > 0 &&
        today.difference(startDate).inDays > entity.maximumBackdatedDays) {
      errors.add(
          'Backdated leave is limited to ${entity.maximumBackdatedDays}d in the past.');
    }
  }
  if (startDate.isAfter(today)) {
    if (!entity.allowFutureLeave) {
      errors.add(
          'Future-dated leave applications are not allowed for this leave type.');
    } else if (entity.maximumFutureDays > 0 &&
        startDate.difference(today).inDays > entity.maximumFutureDays) {
      errors.add(
          'Leave can only be applied ${entity.maximumFutureDays}d in advance.');
    }
  }
  return errors;
}

/// Client-side mirror of backend `_validate_leave_policy`, same order of
/// checks (duration-shaped checks first, then date-shaped checks) so
/// violations surface before the server round-trip.
List<String> _preSubmitErrors({
  required LeaveTypeEntity entity,
  required bool isHalfDay,
  required DateTime start,
  required double days,
}) =>
    [
      ..._durationErrors(entity: entity, isHalfDay: isHalfDay, days: days),
      ..._dateErrors(entity: entity, start: start),
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
  _Duration _duration = _Duration.fullDay;
  DateTime? _fromDate;
  DateTime? _toDate;
  final _reasonCtrl = TextEditingController();
  final _handoverCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _handoverNoteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _submitted = false;
  String? _error;
  String? _submittedTypeName;
  PlatformFile? _pickedDoc;
  String? _docError;

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _kAllowedDocExtensions,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    if (file.size > _kMaxDocBytes) {
      setState(() => _docError = 'File exceeds 5 MB.');
      return;
    }
    setState(() {
      _pickedDoc = file;
      _docError = null;
    });
  }

  @override
  void dispose() {
    _reasonCtrl.dispose();
    _handoverCtrl.dispose();
    _contactCtrl.dispose();
    _handoverNoteCtrl.dispose();
    super.dispose();
  }

  bool get _isHalfDay => _duration != _Duration.fullDay;

  // Non-null once a leave type + full date range is selected — used to key
  // the authoritative server-side day-count/LOP preview.
  LeavePreviewParams? _previewParams(LeaveTypeOption? lt) {
    if (lt == null || _fromDate == null) return null;
    final end = _isHalfDay ? _fromDate! : _toDate;
    if (end == null) return null;
    return (
      leaveType: lt.code,
      startDate: _toIso(_fromDate!),
      endDate: _toIso(end),
      duration: _durationCode(),
    );
  }

  // Prefers the server preview (accounts for holidays, which the local
  // `_workingDays` estimate below does not) once it has loaded; falls back to
  // the local estimate while the request is in flight or if it fails, so the
  // form never blocks on this endpoint's availability.
  double _effectiveDays(double localDays, LeavePreviewEntity? preview) =>
      preview?.actualLeaveDays ?? localDays;

  _BalanceCheck? _effectiveBalanceCheck(
      _BalanceCheck? localCheck, LeavePreviewEntity? preview) {
    if (preview == null) return localCheck;
    if (preview.lopDays > 0) {
      return _BalanceCheck(
        mode: _BalanceMode.lop,
        available: preview.availableBalance,
        requested: preview.actualLeaveDays,
        excess: preview.lopDays,
      );
    }
    if (!preview.sufficientBalance) {
      return _BalanceCheck(
        mode: _BalanceMode.blocked,
        available: preview.availableBalance,
        requested: preview.actualLeaveDays,
        excess: (preview.actualLeaveDays - preview.availableBalance)
            .clamp(0, double.infinity),
      );
    }
    return null;
  }

  // Mirrors backend `_calc_working_days`: weekly-off days (Sat/Sun) are
  // excluded from the count UNLESS the leave type's policy has sandwich
  // leave enabled or counts week-offs as leave, in which case every
  // calendar day in the range counts.
  int _workingDays(DateTime from, DateTime? to, LeaveTypeEntity entity) {
    if (_isHalfDay) return 0;
    final end = to ?? from;
    if (end.isBefore(from)) return 0;
    final includeWeekoffs =
        entity.sandwichLeaveEnabled || entity.countWeekoffsAsLeave;
    int count = 0;
    DateTime cur = from;
    while (!cur.isAfter(end)) {
      final isWeekoff =
          cur.weekday == DateTime.saturday || cur.weekday == DateTime.sunday;
      if (includeWeekoffs || !isWeekoff) {
        count++;
      }
      cur = cur.add(const Duration(days: 1));
    }
    return count;
  }

  String _toIso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  // Must match backend DURATION_CHOICES in apps/hrms/models.py exactly.
  String _durationCode() => switch (_duration) {
        _Duration.fullDay => 'full_day',
        _Duration.halfMorning => 'half_morning',
        _Duration.halfAfternoon => 'half_afternoon',
      };

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isFrom ? (_fromDate ?? now) : (_toDate ?? (_fromDate ?? now)),
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: ColorScheme.light(primary: AppColors.primary),
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

  Future<void> _submit(
    List<LeaveTypeOption> typeOptions,
    List<LeaveTypeEntity> typeEntities,
  ) async {
    if (!_formKey.currentState!.validate()) return;
    if (_fromDate == null) {
      setState(() => _error = 'Please select a start date.');
      return;
    }
    if (!_isHalfDay && _toDate == null) {
      setState(() => _error = 'Please select an end date.');
      return;
    }
    final lt = typeOptions.firstWhere((t) => t.key == _selectedType,
        orElse: () => typeOptions.first);
    final entity = _resolveLeaveEntity(typeEntities, lt.code);
    final localDays =
        _isHalfDay ? 0.5 : _workingDays(_fromDate!, _toDate, entity).toDouble();

    // Prefer the server preview (already fetched for display) as the
    // authoritative day count / balance check — it accounts for company
    // holidays, which the local estimate above does not.
    final previewParams = _previewParams(lt);
    final preview = previewParams == null
        ? null
        : ref.read(leavePreviewProvider(previewParams)).valueOrNull;
    final days = _effectiveDays(localDays, preview);

    final preErrors = _preSubmitErrors(
        entity: entity, isHalfDay: _isHalfDay, start: _fromDate!, days: days);
    if (preErrors.isNotEmpty) {
      setState(() => _error = preErrors.first);
      return;
    }

    final isLwp = LeaveTypeColors.isLwp(lt.code);
    final localBalanceCheck = _evaluateBalance(
      isLwp: isLwp,
      available: lt.balance.toDouble(),
      requested: days,
      convertToLop: entity.convertToLop,
      allowNegativeBalance: entity.allowNegativeBalance,
    );
    final balanceCheck = _effectiveBalanceCheck(localBalanceCheck, preview);
    if (balanceCheck?.mode == _BalanceMode.blocked) {
      setState(() => _error =
          'Exceeds balance by ${_fmtDays(balanceCheck!.excess)}d. Only ${_fmtDays(balanceCheck.available)}d available.');
      return;
    }
    if (lt.docRequired && _pickedDoc == null) {
      setState(() =>
          _docError = 'Supporting document is required for this leave type.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    // Backend computes `lop_days` itself from the balance check server-side
    // (see `_calc_working_days`/`post()` in views/leave.py) — no LOP amount
    // is sent here even when `balanceCheck.mode == _BalanceMode.lop`.
    final err = await ref.read(leaveRequestsProvider.notifier).applyLeave(
          leaveTypeCode: lt.code,
          fromDate: _toIso(_fromDate!),
          toDate: _toIso(_isHalfDay ? _fromDate! : _toDate!),
          reason: _reasonCtrl.text.trim(),
          duration: _durationCode(),
          handoverTo: _handoverCtrl.text.trim(),
          contactDuringLeave: _contactCtrl.text.trim(),
          handoverNotes: _handoverNoteCtrl.text.trim(),
          document: _pickedDoc,
        );

    if (!mounted) return;
    setState(() {
      _loading = false;
    });

    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() {
        _submitted = true;
        _submittedTypeName = lt.label;
      });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _reset() {
    setState(() {
      _selectedType = '';
      _duration = _Duration.fullDay;
      _fromDate = null;
      _toDate = null;
      _reasonCtrl.clear();
      _handoverCtrl.clear();
      _contactCtrl.clear();
      _handoverNoteCtrl.clear();
      _error = null;
      _submitted = false;
      _submittedTypeName = null;
      _pickedDoc = null;
      _docError = null;
    });
  }

  // ── Success screen ────────────────────────────────────────────────────────────

  Widget _successView(LeaveTypeEntity entity) {
    final wd = _workingDays(_fromDate!, _toDate, entity);
    final days =
        _isHalfDay ? '0.5 working day' : '$wd working day${wd != 1 ? "s" : ""}';
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline,
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
                                style: TextStyle(
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
                  child: AppButton(
                    label: 'Apply Another',
                    variant: AppButtonVariant.outline,
                    onPressed: _reset,
                  ),
                ),
                if (widget.onDashboard != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'Dashboard',
                      onPressed: widget.onDashboard,
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
    final typesAsync = ref.watch(leaveTypesProvider);
    final balancesAsync = ref.watch(leaveBalancesProvider);
    final authAsync = ref.watch(authStateProvider);

    // auto-select first type once data loads
    ref.listen(leaveTypesProvider, (_, next) {
      if (_selectedType.isEmpty && next.hasValue && next.value!.isNotEmpty) {
        setState(() => _selectedType = next.value!.first.code);
      }
    });

    final typeEntities = typesAsync.valueOrNull ?? [];
    final balances = balancesAsync.valueOrNull ?? [];
    final typeOptions =
        LeaveTypeOption.listFromEntities(typeEntities, balances);

    // ensure _selectedType valid when types reload
    if (_selectedType.isEmpty && typeOptions.isNotEmpty) {
      _selectedType = typeOptions.first.key;
    }

    final user = authAsync.valueOrNull?.user;

    LeaveTypeOption? lt = typeOptions.isEmpty
        ? null
        : typeOptions.firstWhere((t) => t.key == _selectedType,
            orElse: () => typeOptions.first);

    final selectedEntity =
        _resolveLeaveEntity(typeEntities, lt?.code ?? _selectedType);

    final localDays = _fromDate != null
        ? (_isHalfDay
            ? 0.5
            : _workingDays(_fromDate!, _toDate, selectedEntity).toDouble())
        : 0.0;

    // Authoritative server-side breakdown (holiday-aware) — only fetched once
    // a full type + date range is selected; falls back to the local estimate
    // above while loading/on error so the form stays responsive offline.
    final previewParams = _previewParams(lt);
    final previewAsync = previewParams == null
        ? const AsyncValue<LeavePreviewEntity>.loading()
        : ref.watch(leavePreviewProvider(previewParams));
    final preview = previewAsync.valueOrNull;

    final days = _effectiveDays(localDays, preview);

    final localBalanceCheck = lt == null
        ? null
        : _evaluateBalance(
            isLwp: LeaveTypeColors.isLwp(lt.code),
            available: lt.balance.toDouble(),
            requested: days,
            convertToLop: selectedEntity.convertToLop,
            allowNegativeBalance: selectedEntity.allowNegativeBalance,
          );
    final balanceCheck = _effectiveBalanceCheck(localBalanceCheck, preview);
    final blocked = balanceCheck?.mode == _BalanceMode.blocked;

    final hasDateRange = _fromDate != null && (_isHalfDay || _toDate != null);
    final durationErrs = hasDateRange
        ? _durationErrors(
            entity: selectedEntity, isHalfDay: _isHalfDay, days: days)
        : const <String>[];
    final dateErrs = _fromDate != null
        ? _dateErrors(entity: selectedEntity, start: _fromDate!)
        : const <String>[];
    final preErrors = [...durationErrs, ...dateErrs];

    final canSubmit =
        !_loading && typeOptions.isNotEmpty && !blocked && preErrors.isEmpty;

    if (_submitted) return _successView(selectedEntity);

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
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      ),
                    )
                  : LeaveTypeSelector(
                      types: typeOptions,
                      selectedKey: _selectedType,
                      onSelect: (k) => setState(() {
                        _selectedType = k;
                        // If the newly selected leave type disallows half-day
                        // leave, fall back to Full Day (mirrors backend's
                        // `allow_half_day` gate in `_validate_leave_policy`).
                        final newEntity = _resolveLeaveEntity(typeEntities, k);
                        if (!newEntity.allowHalfDay && _isHalfDay) {
                          _duration = _Duration.fullDay;
                        }
                      }),
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
                    allowHalfDay: selectedEntity.allowHalfDay,
                    onChanged: (d) => setState(() {
                      _duration = d;
                      if (_isHalfDay) _toDate = null;
                    }),
                  ),
                  if (!selectedEntity.allowHalfDay) ...[
                    const SizedBox(height: 6),
                    Text('Half-day leave is not available for this leave type.',
                        style: AppTextStyles.caption
                            .copyWith(fontSize: 10, color: AppColors.textHint)),
                  ],
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const FieldLabel(
                                text: 'Start Date', required: true),
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
                            FieldLabel(text: 'End Date', required: !_isHalfDay),
                            const SizedBox(height: 6),
                            _DateField(
                              value: _isHalfDay ? _fromDate : _toDate,
                              hint: 'Select',
                              disabled: _isHalfDay,
                              onTap: _isHalfDay ? null : () => _pickDate(false),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (dateErrs.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _InlineErrors(messages: dateErrs),
                  ],
                  if (_fromDate != null && (_isHalfDay || _toDate != null)) ...[
                    const SizedBox(height: 10),
                    _WorkingDaysChip(
                      days: days,
                      balance: lt?.balance.toDouble() ?? 0,
                      isLwp: lt != null && LeaveTypeColors.isLwp(lt.code),
                      balanceCheck: balanceCheck,
                    ),
                    if (durationErrs.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _InlineErrors(messages: durationErrs),
                    ],
                    if (balanceCheck != null) ...[
                      const SizedBox(height: 10),
                      _BalanceStatusBanner(check: balanceCheck),
                    ],
                    if (preview != null &&
                        (preview.companyHolidayCount > 0 ||
                            preview.weekOffCount > 0 ||
                            preview.warning.isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      _PreviewBreakdownNote(preview: preview),
                    ],
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
                  const FieldLabel(text: 'Reason for Leave', required: true),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _reasonCtrl,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(
                      hintText: 'Briefly describe the reason for your leave…',
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
                  DocumentFilePicker(
                    picked: _pickedDoc,
                    error: _docError,
                    onPick: _pickDocument,
                    hintText: 'PDF, JPG, PNG · Max 5 MB',
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
                      Icon(Icons.arrow_forward,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text('Handover & Contact', style: AppTextStyles.label),
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
                                prefixIcon:
                                    Icon(Icons.person_outline, size: 16),
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
              workingDays: days,
              isHalfDay: _isHalfDay,
              employeeName: user?.fullName ?? '',
            ),
            const SizedBox(height: 10),
            _LeaveBalanceSideCard(lt: lt, balanceCheck: balanceCheck),
            const SizedBox(height: 10),
            const _ApprovalChainSideCard(),
            const SizedBox(height: 10),
            const _MyLeaveRequestsSideCard(),

            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline,
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
                    side: BorderSide(color: AppColors.border),
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
                    side: BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppButton(
                    label: 'Submit',
                    onPressed: canSubmit
                        ? () => _submit(typeOptions, typeEntities)
                        : null,
                    isLoading: _loading,
                    leadingIcon: Icons.send_outlined,
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
    final name = user?.fullName ?? '';
    final employeeId = user?.employeeId ?? '';
    final initials = name.isNotEmpty ? _initials(name) : '?';
    final subtitle = [user?.designation, user?.department]
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
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
  final bool allowHalfDay;
  const _DurationToggle({
    required this.value,
    required this.onChanged,
    this.allowHalfDay = true,
  });

  @override
  Widget build(BuildContext context) {
    // When the selected leave type's policy disallows half-day leave
    // (`allow_half_day == false`), only Full Day is shown — matches backend
    // `_validate_leave_policy`'s half-day gate.
    final opts = [
      (_Duration.fullDay, Icons.wb_sunny_outlined, 'Full Day'),
      if (allowHalfDay) (_Duration.halfMorning, Icons.wb_sunny, 'Half · AM'),
      if (allowHalfDay)
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
                color: selected ? AppColors.primary : AppColors.backgroundLow,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: selected ? AppColors.primary : AppColors.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(opt.$2,
                      size: 14,
                      color: selected ? Colors.white : AppColors.textSecondary),
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
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
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
          color: disabled ? AppColors.backgroundLow : AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 13,
                color: disabled ? AppColors.textHint : AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value != null ? _format(value!) : hint,
                style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: value != null
                        ? AppColors.textPrimary
                        : AppColors.textHint,
                    fontWeight:
                        value != null ? FontWeight.w600 : FontWeight.w400),
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
  final _BalanceCheck? balanceCheck;
  const _WorkingDaysChip(
      {required this.days,
      required this.balance,
      required this.isLwp,
      this.balanceCheck});

  @override
  Widget build(BuildContext context) {
    final mode = balanceCheck?.mode;
    // Hard block reads as an error; LOP/negative-overdraft are allowed to
    // submit, so they read as a (less alarming) warning — same three-way
    // split used by the balance panel below.
    final color = mode == _BalanceMode.blocked
        ? AppColors.error
        : (mode == _BalanceMode.lop || mode == _BalanceMode.negative)
            ? AppColors.warning
            : AppColors.primary;
    final label = days == 0.5
        ? '0.5 working day'
        : '${days.toInt()} working day${days.toInt() == 1 ? "" : "s"}';
    final badgeText = switch (mode) {
      _BalanceMode.blocked => 'Exceeds balance',
      _BalanceMode.lop => '${_fmtDays(balanceCheck!.excess)}d → LOP',
      _BalanceMode.negative => 'Negative ${_fmtDays(balanceCheck!.excess)}d',
      null => '${_fmtDays(balance - days)}d will remain',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(
              mode != null
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
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                badgeText,
                style: AppTextStyles.caption.copyWith(
                    color: color, fontSize: 10, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Inline validation errors ─────────────────────────────────────────────────
//
// Compact list of pre-submit validation messages, placed near the relevant
// field(s). Reuses the same error-colored icon+text row style as the
// app-level error banner further down this file.

class _InlineErrors extends StatelessWidget {
  final List<String> messages;
  const _InlineErrors({required this.messages});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: messages
          .map((m) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.error_outline,
                        size: 12, color: AppColors.error),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(m,
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 10, color: AppColors.error)),
                    ),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

// ── Preview breakdown note (holidays/week-offs excluded, policy warning) ────
//
// Surfaces the server preview's holiday/week-off exclusions and any policy
// warning (e.g. max-consecutive-days-with-LOP) so the day count shown in the
// chip above isn't a mystery — mirrors the breakdown panel the web preview
// endpoint was built to drive.

class _PreviewBreakdownNote extends StatelessWidget {
  final LeavePreviewEntity preview;
  const _PreviewBreakdownNote({required this.preview});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (preview.companyHolidayCount > 0)
        '${preview.companyHolidayCount} holiday${preview.companyHolidayCount == 1 ? "" : "s"}',
      if (preview.weekOffCount > 0)
        '${preview.weekOffCount} week-off${preview.weekOffCount == 1 ? "" : "s"}',
    ];
    final excludedNote = parts.isEmpty
        ? null
        : (preview.sandwichLeaveEnabled
            ? '${parts.join(" + ")} included (sandwich leave policy).'
            : '${parts.join(" + ")} excluded from the day count.');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (excludedNote != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 13, color: AppColors.info),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(excludedNote,
                      style: AppTextStyles.caption
                          .copyWith(fontSize: 10.5, color: AppColors.info)),
                ),
              ],
            ),
          if (preview.warning.isNotEmpty) ...[
            if (excludedNote != null) const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_outlined,
                    size: 13, color: AppColors.warning),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(preview.warning,
                      style: AppTextStyles.caption.copyWith(
                          fontSize: 10.5, color: AppColors.warning)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Balance status banner (LOP / negative-balance / blocked) ────────────────
//
// Reuses the existing warning/error Container styling (padding 10, radius 8,
// alpha-bordered) already used by the app-level error banner and the
// leave-balance side card's over-limit box — only the three-way content
// differs, per backend `convert_to_lop`/`allow_negative_balance`/hard-block.

class _BalanceStatusBanner extends StatelessWidget {
  final _BalanceCheck check;
  const _BalanceStatusBanner({required this.check});

  @override
  Widget build(BuildContext context) {
    final color = check.mode == _BalanceMode.blocked
        ? AppColors.error
        : AppColors.warning;

    if (check.mode == _BalanceMode.lop) {
      final used = check.available;
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_outlined, size: 14, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Part of this request will be Leave Without Pay (LOP).',
                    style: AppTextStyles.caption
                        .copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _StatChip(
                    label: 'Available',
                    value: _fmtDays(check.available),
                    color: color),
                const SizedBox(width: 6),
                _StatChip(
                    label: 'Requested',
                    value: _fmtDays(check.requested),
                    color: color),
                const SizedBox(width: 6),
                _StatChip(label: 'Used', value: _fmtDays(used), color: color),
                const SizedBox(width: 6),
                _StatChip(
                    label: 'LOP', value: _fmtDays(check.excess), color: color),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'The shortfall of ${_fmtDays(check.excess)}d beyond your available balance '
              'will be treated as Leave Without Pay.',
              style: AppTextStyles.caption.copyWith(fontSize: 10, color: color),
            ),
          ],
        ),
      );
    }

    final message = switch (check.mode) {
      _BalanceMode.negative =>
        'You will have a negative balance of ${_fmtDays(check.excess)}d after this request.',
      _BalanceMode.blocked =>
        'Exceeds balance by ${_fmtDays(check.excess)}d. Only ${_fmtDays(check.available)}d available.',
      _BalanceMode.lop => '', // handled above
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
              check.mode == _BalanceMode.blocked
                  ? Icons.error_outline
                  : Icons.info_outline,
              size: 13,
              color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(message,
                style: AppTextStyles.caption
                    .copyWith(fontSize: 10.5, color: color)),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                style: AppTextStyles.caption.copyWith(
                    fontSize: 11, fontWeight: FontWeight.w800, color: color)),
            Text(label,
                style:
                    AppTextStyles.caption.copyWith(fontSize: 8, color: color)),
          ],
        ),
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
          Divider(height: 1, color: AppColors.border),
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
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  String get _durationLabel => switch (duration) {
        _Duration.fullDay => 'Full Day',
        _Duration.halfMorning => 'Half Day (AM)',
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
      (
        Icons.person_outline,
        'Employee',
        employeeName.isNotEmpty ? employeeName : '—'
      ),
      (Icons.beach_access_outlined, 'Leave Type', lt?.label ?? '—'),
      (Icons.wb_sunny_outlined, 'Duration', _durationLabel),
      (Icons.calendar_today_outlined, 'From', _fmt(fromDate)),
      (
        Icons.calendar_today_outlined,
        'To',
        isHalfDay ? _fmt(fromDate) : _fmt(toDate)
      ),
      (Icons.work_outline, 'Working Days', _daysLabel),
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
                        width: 26,
                        height: 26,
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
                                    fontSize: 9, color: AppColors.textHint)),
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
  final _BalanceCheck? balanceCheck;
  const _LeaveBalanceSideCard({required this.lt, this.balanceCheck});

  @override
  Widget build(BuildContext context) {
    if (lt == null) {
      return _SideCard(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Leave Balance',
        child: SizedBox(
          height: 40,
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }
    final isLwp = LeaveTypeColors.isLwp(lt!.code);
    final balancePct = isLwp
        ? 1.0
        : (lt!.total > 0 ? (lt!.balance / lt!.total).clamp(0.0, 1.0) : 0.0);

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
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: lt!.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Center(
                  child: Icon(leaveTypeIconForCode(lt!.code),
                      size: 16, color: lt!.color),
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
                    style: AppTextStyles.caption
                        .copyWith(fontSize: 10, color: AppColors.textHint)),
                Text('${lt!.balance} remaining',
                    style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: lt!.color,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ],
          if (balanceCheck != null) ...[
            const SizedBox(height: 8),
            Builder(builder: (context) {
              final check = balanceCheck!;
              final color = check.mode == _BalanceMode.blocked
                  ? AppColors.error
                  : AppColors.warning;
              final message = switch (check.mode) {
                _BalanceMode.blocked =>
                  'Exceeds balance by ${_fmtDays(check.excess)}d.',
                _BalanceMode.lop =>
                  '${_fmtDays(check.excess)}d will convert to LOP.',
                _BalanceMode.negative =>
                  'Will go negative by ${_fmtDays(check.excess)}d.',
              };
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                        check.mode == _BalanceMode.blocked
                            ? Icons.error_outline
                            : Icons.warning_amber_outlined,
                        size: 13,
                        color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(message,
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 10, color: color)),
                    ),
                  ],
                ),
              );
            }),
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
      ('ME', 'You', 'Requestor', true),
      ('LM', 'Line Manager', 'L1 Approver', false),
      ('HR', 'HR Manager', 'L2 Approver', false),
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
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color:
                          step.$4 ? AppColors.primary : AppColors.backgroundLow,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color:
                              step.$4 ? AppColors.primary : AppColors.border),
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
                        style: AppTextStyles.caption.copyWith(fontSize: 10)),
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

// ── My Leave Requests (real data — mirrors web's "My Leave Requests" table) ───

class _MyLeaveRequestsSideCard extends ConsumerWidget {
  const _MyLeaveRequestsSideCard();

  static Color _statusColor(String s) => switch (s) {
        'approved' => AppColors.success,
        'rejected' => AppColors.error,
        'cancelled' => AppColors.textSecondary,
        _ => AppColors.warning,
      };

  static String _fmtIso(String iso) {
    if (iso.isEmpty) return '—';
    try {
      final d = DateTime.parse(iso);
      const m = [
        '',
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${d.day} ${m[d.month]}';
    } catch (_) {
      return iso;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(leaveRequestsProvider);
    final requests = requestsAsync.valueOrNull ?? [];

    if (requestsAsync.isLoading) {
      return _SideCard(
        icon: Icons.history_outlined,
        title: 'My Leave Requests',
        child: SizedBox(
          height: 40,
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        ),
      );
    }

    if (requests.isEmpty) {
      return _SideCard(
        icon: Icons.history_outlined,
        title: 'My Leave Requests',
        child: Text('No leave requests yet.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
      );
    }

    return _SideCard(
      icon: Icons.history_outlined,
      title: 'My Leave Requests',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: requests.take(5).map((r) {
          final sc = _statusColor(r.status);
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: sc, shape: BoxShape.circle),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.leaveType,
                          style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${_fmtIso(r.from)} – ${_fmtIso(r.to)}  ·  ${r.days}d'
                        '${r.l1ApproverName.isNotEmpty ? "  ·  ${r.l1ApproverName}" : ""}',
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(r.status,
                      style: AppTextStyles.caption.copyWith(
                          color: sc, fontWeight: FontWeight.w700, fontSize: 9)),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../branches/presentation/providers/branch_providers.dart';
import '../../../../leave/domain/entities/leave_entity.dart';
import '../../../../leave/presentation/widgets/leave_type_icons.dart';
import '../../../data/models/leave_policy_model.dart';
import '../../providers/settings_providers.dart';

// Matches web's EligibilitySection.tsx: "No employment-type concept exists
// anywhere in this system yet (checked accounts.models — no field, no
// choices). Kept as a static placeholder list matching the exact values the
// backend's PUT example uses..." — applicable_employment_types has no
// backing model/API, so both web and this screen hardcode the same options.
const List<String> _employmentTypeOptions = [
  'Full-time',
  'Part-time',
  'Contract',
  'Intern',
  'Consultant',
];

/// The "Leave Policy" tab — a full-page rule editor for ONE leave type at a
/// time, selected via the dropdown at the top. Mirrors web's
/// `LeavePoliciesTab.tsx` exactly: this tab never touches annual_days,
/// can_carry_forward/max_carry_forward_days, policy_note or is_active as a
/// primary surface — wait, carry-forward IS also editable here (its own
/// section, same as web's `CarryForwardSettingsSection`) since the two real
/// carry-forward fields are legitimately saved from both tabs on web; the
/// other four (annual_days/note/active) stay exclusively on the "Leave
/// Types" tab.
class LeavePolicyRulesTab extends ConsumerStatefulWidget {
  const LeavePolicyRulesTab({super.key});

  @override
  ConsumerState<LeavePolicyRulesTab> createState() =>
      _LeavePolicyRulesTabState();
}

class _LeavePolicyRulesTabState extends ConsumerState<LeavePolicyRulesTab> {
  String? _selectedType;

  // ── Carry Forward (real fields only — see file doc comment) ──
  late bool _canCarryForward;
  late final TextEditingController _carryFwdLimitCtrl;

  // ── Leave Application Rules ──
  late final TextEditingController _minDurationCtrl;
  late final TextEditingController _maxDurationCtrl;
  late final TextEditingController _maxConsecutiveCtrl;
  late final TextEditingController _minNoticeCtrl;
  late bool _allowHalfDay;
  late bool _allowBackdatedLeave;
  late final TextEditingController _maxBackdatedCtrl;
  late bool _allowFutureLeave;
  late final TextEditingController _maxFutureCtrl;

  // ── Holiday & Week-off Rules ──
  late bool _sandwichLeaveEnabled;
  late bool _countHolidaysAsLeave;
  late bool _countWeekoffsAsLeave;

  // ── Eligibility Rules ──
  late List<String> _applicableBranches;
  late List<String> _applicableDepartments;
  late List<String> _applicableDesignations;
  late List<String> _applicableEmploymentTypes;
  late String _applicableGender;
  late final TextEditingController _minServicePeriodCtrl;

  // ── Documentation Rules ──
  late bool _attachmentRequired;
  late bool _medicalCertificateRequired;
  late final TextEditingController _certAfterDaysCtrl;

  // ── Leave Restrictions ──
  late bool _allowNegativeBalance;
  late bool _convertToLop;
  late bool _allowLeaveCancellation;
  late final TextEditingController _cancelUntilCtrl;

  // ── Additional Rules ──
  late bool _allowProbationLeave;
  late bool _allowNoticePeriodLeave;
  late bool _allowLeaveExtension;
  late bool _allowLeaveCombination;

  bool _saving = false;
  bool _initialized = false;
  String? _carryFwdLimitError;
  String? _maxDurationError;
  String? _certAfterDaysError;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _carryFwdLimitCtrl = TextEditingController(text: '0');
    _minDurationCtrl = TextEditingController(text: '0.5');
    _maxDurationCtrl = TextEditingController(text: '0');
    _maxConsecutiveCtrl = TextEditingController(text: '0');
    _minNoticeCtrl = TextEditingController(text: '0');
    _maxBackdatedCtrl = TextEditingController(text: '0');
    _maxFutureCtrl = TextEditingController(text: '0');
    _minServicePeriodCtrl = TextEditingController(text: '0');
    _certAfterDaysCtrl = TextEditingController(text: '3');
    _cancelUntilCtrl = TextEditingController(text: '0');
    _canCarryForward = false;
    _allowHalfDay = true;
    _allowBackdatedLeave = false;
    _allowFutureLeave = true;
    _sandwichLeaveEnabled = false;
    _countHolidaysAsLeave = false;
    _countWeekoffsAsLeave = false;
    _applicableBranches = [];
    _applicableDepartments = [];
    _applicableDesignations = [];
    _applicableEmploymentTypes = [];
    _applicableGender = 'all';
    _attachmentRequired = false;
    _medicalCertificateRequired = false;
    _allowNegativeBalance = false;
    _convertToLop = false;
    _allowLeaveCancellation = true;
    _allowProbationLeave = false;
    _allowNoticePeriodLeave = false;
    _allowLeaveExtension = false;
    _allowLeaveCombination = false;
  }

  @override
  void dispose() {
    _carryFwdLimitCtrl.dispose();
    _minDurationCtrl.dispose();
    _maxDurationCtrl.dispose();
    _maxConsecutiveCtrl.dispose();
    _minNoticeCtrl.dispose();
    _maxBackdatedCtrl.dispose();
    _maxFutureCtrl.dispose();
    _minServicePeriodCtrl.dispose();
    _certAfterDaysCtrl.dispose();
    _cancelUntilCtrl.dispose();
    super.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _loadFrom(LeavePolicyModel p) {
    final form = LeavePolicyFormData.fromModel(p);
    _canCarryForward = form.canCarryForward;
    _carryFwdLimitCtrl.text =
        form.canCarryForward ? '${form.maxCarryForwardDays}' : '0';
    _minDurationCtrl.text = _fmt(form.minimumLeaveDuration);
    _maxDurationCtrl.text = '${form.maximumLeaveDuration}';
    _maxConsecutiveCtrl.text = '${form.maximumConsecutiveDays}';
    _minNoticeCtrl.text = '${form.minimumNoticePeriod}';
    _allowHalfDay = form.allowHalfDay;
    _allowBackdatedLeave = form.allowBackdatedLeave;
    _maxBackdatedCtrl.text = '${form.maximumBackdatedDays}';
    _allowFutureLeave = form.allowFutureLeave;
    _maxFutureCtrl.text = '${form.maximumFutureDays}';
    _sandwichLeaveEnabled = form.sandwichLeaveEnabled;
    _countHolidaysAsLeave = form.countHolidaysAsLeave;
    _countWeekoffsAsLeave = form.countWeekoffsAsLeave;
    _applicableBranches = List.of(form.applicableBranches);
    _applicableDepartments = List.of(form.applicableDepartments);
    _applicableDesignations = List.of(form.applicableDesignations);
    _applicableEmploymentTypes = List.of(form.applicableEmploymentTypes);
    _applicableGender = form.applicableGender;
    _minServicePeriodCtrl.text = '${form.minimumServicePeriod}';
    _attachmentRequired = form.attachmentRequired;
    _medicalCertificateRequired = form.medicalCertificateRequired;
    _certAfterDaysCtrl.text = '${form.medicalCertificateAfterDays}';
    _allowNegativeBalance = form.allowNegativeBalance;
    _convertToLop = form.convertToLop;
    _allowLeaveCancellation = form.allowLeaveCancellation;
    _cancelUntilCtrl.text = '${form.cancellationAllowedUntil}';
    _allowProbationLeave = form.allowProbationLeave;
    _allowNoticePeriodLeave = form.allowNoticePeriodLeave;
    _allowLeaveExtension = form.allowLeaveExtension;
    _allowLeaveCombination = form.allowLeaveCombination;
    _carryFwdLimitError = null;
    _maxDurationError = null;
    _certAfterDaysError = null;
    _saveError = null;
  }

  void _selectType(String type, List<LeavePolicyModel> policies) {
    final policy = policies.where((p) => p.leaveType == type).firstOrNull;
    if (policy == null) return;
    setState(() {
      _selectedType = type;
      _loadFrom(policy);
    });
  }

  void _discard(List<LeavePolicyModel> policies) {
    final policy =
        policies.where((p) => p.leaveType == _selectedType).firstOrNull;
    if (policy == null) return;
    setState(() => _loadFrom(policy));
  }

  Future<void> _save(LeavePolicyModel current) async {
    final base = LeavePolicyFormData.fromModel(current);
    base.canCarryForward = _canCarryForward;
    base.maxCarryForwardDays = int.tryParse(_carryFwdLimitCtrl.text) ?? 0;
    base.minimumLeaveDuration = double.tryParse(_minDurationCtrl.text) ?? 0.5;
    base.maximumLeaveDuration = int.tryParse(_maxDurationCtrl.text) ?? 0;
    base.maximumConsecutiveDays = int.tryParse(_maxConsecutiveCtrl.text) ?? 0;
    base.minimumNoticePeriod = int.tryParse(_minNoticeCtrl.text) ?? 0;
    base.allowHalfDay = _allowHalfDay;
    base.allowBackdatedLeave = _allowBackdatedLeave;
    base.maximumBackdatedDays = int.tryParse(_maxBackdatedCtrl.text) ?? 0;
    base.allowFutureLeave = _allowFutureLeave;
    base.maximumFutureDays = int.tryParse(_maxFutureCtrl.text) ?? 0;
    base.sandwichLeaveEnabled = _sandwichLeaveEnabled;
    base.countHolidaysAsLeave = _countHolidaysAsLeave;
    base.countWeekoffsAsLeave = _countWeekoffsAsLeave;
    base.applicableBranches = _applicableBranches;
    base.applicableDepartments = _applicableDepartments;
    base.applicableDesignations = _applicableDesignations;
    base.applicableEmploymentTypes = _applicableEmploymentTypes;
    base.applicableGender = _applicableGender;
    base.minimumServicePeriod = int.tryParse(_minServicePeriodCtrl.text) ?? 0;
    base.attachmentRequired = _attachmentRequired;
    base.medicalCertificateRequired = _medicalCertificateRequired;
    base.medicalCertificateAfterDays =
        int.tryParse(_certAfterDaysCtrl.text) ?? 0;
    base.allowNegativeBalance = _allowNegativeBalance;
    base.convertToLop = _convertToLop;
    base.allowLeaveCancellation = _allowLeaveCancellation;
    base.cancellationAllowedUntil = int.tryParse(_cancelUntilCtrl.text) ?? 0;
    base.allowProbationLeave = _allowProbationLeave;
    base.allowNoticePeriodLeave = _allowNoticePeriodLeave;
    base.allowLeaveExtension = _allowLeaveExtension;
    base.allowLeaveCombination = _allowLeaveCombination;

    final errors = base.validate();
    if (errors.isNotEmpty) {
      setState(() {
        _carryFwdLimitError = errors['maxCarryForwardDays'];
        _maxDurationError = errors['maximumLeaveDuration'];
        _certAfterDaysError = errors['medicalCertificateAfterDays'];
      });
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    final result = await ref
        .read(leavePoliciesProvider.notifier)
        .updatePolicy(current.leaveType, base);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Leave policy updated.'),
        backgroundColor: AppColors.success,
      ));
    } else {
      setState(() => _saveError = result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final policiesAsync = ref.watch(leavePoliciesProvider);
    return policiesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(friendlySettingsError(e),
              style: AppTextStyles.bodySecondary),
        ),
      ),
      data: (policies) {
        if (policies.isEmpty) {
          return Center(
            child: Text('No leave policies found',
                style: AppTextStyles.bodySecondary),
          );
        }
        if (!_initialized ||
            !policies.any((p) => p.leaveType == _selectedType)) {
          _selectedType = policies.first.leaveType;
          _loadFrom(policies.first);
          _initialized = true;
        }
        final current =
            policies.firstWhere((p) => p.leaveType == _selectedType);

        final typeColor =
            Color(LeaveTypeColors.colorValueForCode(current.leaveType));
        final typeIcon = leaveTypeIconForCode(current.leaveType);

        return Column(
          children: [
            Expanded(
                child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              children: [
                // ── Page heading — matches the "Leave Types" tab's subtitle pattern ──
                Text(
                  'Configure application, eligibility, documentation and restriction '
                  'rules for each leave type',
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 14),

                // ── Leave type selector card ──
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border:
                        Border.all(color: typeColor.withValues(alpha: 0.25)),
                    boxShadow: [
                      BoxShadow(
                          color: typeColor.withValues(alpha: 0.10),
                          blurRadius: 10,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(typeIcon, size: 20, color: typeColor),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Editing rules for',
                                    style: AppTextStyles.caption.copyWith(
                                        fontSize: 10,
                                        color: AppColors.textHint,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.4)),
                                const SizedBox(height: 1),
                                Text(current.leaveTypeDisplay,
                                    style: AppTextStyles.h4.copyWith(
                                        fontSize: 16, color: typeColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'These rules apply only to this leave type — switch below to configure another.',
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedType,
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        elevation: 3,
                        borderRadius: BorderRadius.circular(12),
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary),
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textPrimary),
                        decoration: _dec('Switch Leave Type').copyWith(
                          prefixIcon: Padding(
                            padding: const EdgeInsets.only(left: 4, right: 8),
                            child: Icon(Icons.swap_horiz_rounded,
                                size: 18, color: typeColor),
                          ),
                        ),
                        // The closed field always shows plain, high-contrast text —
                        // the colour dot + checkmark styling below is only for the
                        // open menu, where it tells leave types apart at a glance.
                        selectedItemBuilder: (context) => policies
                            .map((p) => Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    p.leaveTypeDisplay,
                                    style: AppTextStyles.body.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ))
                            .toList(),
                        items: policies.map((p) {
                          final itemColor = Color(
                              LeaveTypeColors.colorValueForCode(p.leaveType));
                          final isSelected = p.leaveType == _selectedType;
                          return DropdownMenuItem(
                            value: p.leaveType,
                            child: Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                      color: itemColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    p.leaveTypeDisplay,
                                    style: AppTextStyles.body.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isSelected)
                                  Icon(Icons.check_rounded,
                                      size: 16, color: AppColors.primary),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) _selectType(v, policies);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_saveError != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_saveError!,
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.error, fontSize: 12)),
                  ),
                  const SizedBox(height: 14),
                ],

                _RuleSection(
                  icon: Icons.event_available_outlined,
                  title: 'Leave Application Rules',
                  color: AppColors.primary,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _numField(
                            controller: _minDurationCtrl,
                            label: 'Min Duration (days)',
                            decimal: true,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _numField(
                            controller: _maxDurationCtrl,
                            label: 'Max Duration (0=∞)',
                            error: _maxDurationError,
                            onChanged: () =>
                                setState(() => _maxDurationError = null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _numField(
                      controller: _maxConsecutiveCtrl,
                      label: 'Max Consecutive Days (0 = unlimited)',
                    ),
                    const SizedBox(height: 12),
                    _numField(
                      controller: _minNoticeCtrl,
                      label: 'Minimum Notice Period (days)',
                    ),
                    const SizedBox(height: 8),
                    _switchTile('Allow Half Day', null, _allowHalfDay,
                        (v) => setState(() => _allowHalfDay = v)),
                    _switchTile(
                        'Allow Backdated Leave',
                        'Employees can apply for past dates',
                        _allowBackdatedLeave,
                        (v) => setState(() => _allowBackdatedLeave = v)),
                    if (_allowBackdatedLeave) ...[
                      const SizedBox(height: 8),
                      _numField(
                        controller: _maxBackdatedCtrl,
                        label: 'Maximum Backdated Days',
                      ),
                    ],
                    _switchTile(
                        'Allow Future Leave',
                        'Employees can apply in advance',
                        _allowFutureLeave,
                        (v) => setState(() => _allowFutureLeave = v)),
                    if (_allowFutureLeave) ...[
                      const SizedBox(height: 8),
                      _numField(
                        controller: _maxFutureCtrl,
                        label: 'Maximum Future Days',
                      ),
                    ],
                  ],
                ),

                _RuleSection(
                  icon: Icons.holiday_village_outlined,
                  title: 'Holiday & Week-off Rules',
                  color: AppColors.warning,
                  children: [
                    _switchTile(
                        'Sandwich Leave',
                        'Holidays/week-offs between two leave days also count as leave',
                        _sandwichLeaveEnabled,
                        (v) => setState(() => _sandwichLeaveEnabled = v)),
                    _switchTile(
                        'Count Holidays as Leave',
                        'Public holidays within the leave range consume balance',
                        _countHolidaysAsLeave,
                        (v) => setState(() => _countHolidaysAsLeave = v)),
                    _switchTile(
                        'Count Week-offs as Leave',
                        'Weekly off days within the leave range consume balance',
                        _countWeekoffsAsLeave,
                        (v) => setState(() => _countWeekoffsAsLeave = v)),
                  ],
                ),

                _RuleSection(
                  icon: Icons.groups_outlined,
                  title: 'Eligibility Rules',
                  color: AppColors.info,
                  children: [
                    Consumer(builder: (context, ref, _) {
                      final async = ref.watch(branchListProvider);
                      return async.when(
                        data: (branches) => _ChipMultiSelect(
                          label: 'Applicable Branches',
                          options: branches.map((b) => b.branchName).toList(),
                          selected: _applicableBranches,
                          onChanged: (v) =>
                              setState(() => _applicableBranches = v),
                        ),
                        loading: () =>
                            const _ChipsLoading(label: 'Applicable Branches'),
                        error: (_, __) =>
                            const _ChipsError(label: 'Applicable Branches'),
                      );
                    }),
                    const SizedBox(height: 14),
                    Consumer(builder: (context, ref, _) {
                      final async = ref.watch(departmentsProvider);
                      return async.when(
                        data: (depts) => _ChipMultiSelect(
                          label: 'Applicable Departments',
                          options: depts.map((d) => d.name).toList(),
                          selected: _applicableDepartments,
                          onChanged: (v) =>
                              setState(() => _applicableDepartments = v),
                        ),
                        loading: () => const _ChipsLoading(
                            label: 'Applicable Departments'),
                        error: (_, __) =>
                            const _ChipsError(label: 'Applicable Departments'),
                      );
                    }),
                    const SizedBox(height: 14),
                    Consumer(builder: (context, ref, _) {
                      final async = ref.watch(designationsProvider);
                      return async.when(
                        data: (desigs) => _ChipMultiSelect(
                          label: 'Applicable Designations',
                          options: desigs.map((d) => d.name).toList(),
                          selected: _applicableDesignations,
                          onChanged: (v) =>
                              setState(() => _applicableDesignations = v),
                        ),
                        loading: () => const _ChipsLoading(
                            label: 'Applicable Designations'),
                        error: (_, __) =>
                            const _ChipsError(label: 'Applicable Designations'),
                      );
                    }),
                    const SizedBox(height: 14),
                    _ChipMultiSelect(
                      label: 'Applicable Employment Types',
                      options: _employmentTypeOptions,
                      selected: _applicableEmploymentTypes,
                      onChanged: (v) =>
                          setState(() => _applicableEmploymentTypes = v),
                    ),
                    const SizedBox(height: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Applicable Gender',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _applicableGender,
                          isExpanded: true,
                          decoration: _dec('Gender'),
                          items: const [
                            DropdownMenuItem(value: 'all', child: Text('All')),
                            DropdownMenuItem(
                                value: 'male', child: Text('Male')),
                            DropdownMenuItem(
                                value: 'female', child: Text('Female')),
                          ],
                          onChanged: (v) =>
                              setState(() => _applicableGender = v ?? 'all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _numField(
                      controller: _minServicePeriodCtrl,
                      label: 'Minimum Service Period (months)',
                    ),
                  ],
                ),

                _RuleSection(
                  icon: Icons.description_outlined,
                  title: 'Documentation Rules',
                  color: AppColors.secondary,
                  children: [
                    _switchTile(
                        'Attachment Required',
                        'Employees must upload a supporting document',
                        _attachmentRequired,
                        (v) => setState(() => _attachmentRequired = v)),
                    _switchTile(
                        'Medical Certificate Required',
                        null,
                        _medicalCertificateRequired,
                        (v) => setState(() {
                              _medicalCertificateRequired = v;
                              _certAfterDaysError = null;
                            })),
                    if (_medicalCertificateRequired) ...[
                      const SizedBox(height: 8),
                      _numField(
                        controller: _certAfterDaysCtrl,
                        label: 'Certificate Required After (days) *',
                        error: _certAfterDaysError,
                        onChanged: () =>
                            setState(() => _certAfterDaysError = null),
                      ),
                    ],
                  ],
                ),

                _RuleSection(
                  icon: Icons.block_outlined,
                  title: 'Leave Restrictions',
                  color: AppColors.error,
                  children: [
                    _switchTile(
                        'Allow Negative Balance',
                        'Employees may apply beyond their available balance',
                        _allowNegativeBalance,
                        (v) => setState(() => _allowNegativeBalance = v)),
                    _switchTile(
                        'Convert to Loss of Pay',
                        'Excess days beyond balance are treated as LOP',
                        _convertToLop,
                        (v) => setState(() => _convertToLop = v)),
                    _switchTile(
                        'Allow Leave Cancellation',
                        null,
                        _allowLeaveCancellation,
                        (v) => setState(() => _allowLeaveCancellation = v)),
                    if (_allowLeaveCancellation) ...[
                      const SizedBox(height: 8),
                      _numField(
                        controller: _cancelUntilCtrl,
                        label: 'Cancellation Allowed Until (days before start)',
                      ),
                    ],
                  ],
                ),

                _RuleSection(
                  icon: Icons.tune_outlined,
                  title: 'Additional Rules',
                  color: AppColors.success,
                  children: [
                    _switchTile(
                        'Allow During Probation',
                        null,
                        _allowProbationLeave,
                        (v) => setState(() => _allowProbationLeave = v)),
                    _switchTile(
                        'Allow During Notice Period',
                        null,
                        _allowNoticePeriodLeave,
                        (v) => setState(() => _allowNoticePeriodLeave = v)),
                    _switchTile(
                        'Allow Leave Extension',
                        null,
                        _allowLeaveExtension,
                        (v) => setState(() => _allowLeaveExtension = v)),
                    _switchTile(
                        'Allow Combining with Other Leave Types',
                        null,
                        _allowLeaveCombination,
                        (v) => setState(() => _allowLeaveCombination = v)),
                  ],
                ),

                // Carry Forward — the only fields from web's
                // CarryForwardSettingsSection that are real (see file doc
                // comment): the 3 phantom fields (type/mode/expiry) don't exist
                // on the backend and are deliberately omitted.
                _RuleSection(
                  icon: Icons.repeat_rounded,
                  title: 'Carry Forward',
                  color: typeColor,
                  children: [
                    _switchTile(
                        'Allow Carry Forward',
                        'Unused days roll over to next year',
                        _canCarryForward,
                        (v) => setState(() {
                              _canCarryForward = v;
                              if (!v) _carryFwdLimitCtrl.text = '0';
                            })),
                    if (_canCarryForward) ...[
                      const SizedBox(height: 8),
                      _numField(
                        controller: _carryFwdLimitCtrl,
                        label: 'Max Carry Forward Days',
                        error: _carryFwdLimitError,
                        onChanged: () =>
                            setState(() => _carryFwdLimitError = null),
                      ),
                    ],
                  ],
                ),
              ],
            )),
            _PolicyFooter(
              saving: _saving,
              onDiscard: () => _discard(policies),
              onSave: () => _save(current),
            ),
          ],
        );
      },
    );
  }

  InputDecoration _dec(String label, [String? error]) => InputDecoration(
        labelText: label,
        errorText: error,
        labelStyle: AppTextStyles.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );

  Widget _numField({
    required TextEditingController controller,
    required String label,
    bool decimal = false,
    String? error,
    VoidCallback? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: AppTextStyles.body,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        decimal
            ? FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}$'))
            : FilteringTextInputFormatter.digitsOnly,
      ],
      onChanged: onChanged != null ? (_) => onChanged() : null,
      decoration: _dec(label, error),
    );
  }

  Widget _switchTile(String title, String? subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style: AppTextStyles.body
              .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle,
              style: AppTextStyles.caption
                  .copyWith(fontSize: 11, color: AppColors.textHint))
          : null,
      value: value,
      activeTrackColor: AppColors.success,
      onChanged: onChanged,
    );
  }
}

// ── Pinned footer — matches the app's established form-footer pattern (e.g.
// AddEmployeeSheet's _Footer): a top border separates it from the scrollable
// content above, Discard is a subdued OutlinedButton, Save is the prominent
// FilledButton at 2x width. ────────────────────────────────────────────────

class _PolicyFooter extends StatelessWidget {
  final bool saving;
  final VoidCallback onDiscard;
  final VoidCallback onSave;
  const _PolicyFooter(
      {required this.saving, required this.onDiscard, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Discard — a solid tonal fill (not just a faint outline) so it
            // reads as a clear, tappable button against the white footer
            // instead of nearly disappearing into it.
            Expanded(
              child: OutlinedButton.icon(
                onPressed: saving ? null : onDiscard,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.backgroundMid,
                  foregroundColor: AppColors.textPrimary,
                  disabledForegroundColor: AppColors.textHint,
                  side: BorderSide(color: AppColors.borderStrong, width: 1.2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle:
                      AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                ),
                icon: Icon(Icons.restore_outlined,
                    size: 18, color: AppColors.textPrimary),
                label: const Text('Discard'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor:
                      AppColors.primary.withValues(alpha: 0.4),
                  elevation: 1,
                  shadowColor: AppColors.primary.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle:
                      AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                ),
                icon: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save_outlined,
                        size: 18, color: Colors.white),
                label: Text(saving ? 'Saving…' : 'Save Policy',
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Collapsible rule section ──────────────────────────────────────────────────

class _RuleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<Widget> children;
  const _RuleSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 17, color: color),
          ),
          title: Text(title,
              style: AppTextStyles.label
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
          children: [
            Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children),
          ],
        ),
      ),
    );
  }
}

// ── Chip-based multi-select ────────────────────────────────────────────────────

class _ChipMultiSelect extends StatelessWidget {
  final String label;
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const _ChipMultiSelect({
    required this.label,
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        if (options.isEmpty)
          Text('None available',
              style: AppTextStyles.caption.copyWith(color: AppColors.textHint))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((o) {
              final isSel = selected.contains(o);
              return FilterChip(
                label: Text(o,
                    style: AppTextStyles.caption.copyWith(fontSize: 11)),
                selected: isSel,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
                selectedColor: AppColors.primary.withValues(alpha: 0.15),
                checkmarkColor: AppColors.primary,
                backgroundColor: AppColors.backgroundLow,
                side: BorderSide(
                    color: isSel ? AppColors.primary : AppColors.border),
                onSelected: (v) {
                  final next = List<String>.of(selected);
                  if (v) {
                    if (!next.contains(o)) next.add(o);
                  } else {
                    next.remove(o);
                  }
                  onChanged(next);
                },
              );
            }).toList(),
          ),
        const SizedBox(height: 2),
        Text('Leave empty to apply to everyone.',
            style: AppTextStyles.caption
                .copyWith(fontSize: 10, color: AppColors.textHint)),
      ],
    );
  }
}

class _ChipsLoading extends StatelessWidget {
  final String label;
  const _ChipsLoading({required this.label});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      );
}

class _ChipsError extends StatelessWidget {
  final String label;
  const _ChipsError({required this.label});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Could not load options.',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.error, fontSize: 11)),
        ],
      );
}

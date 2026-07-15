import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../branches/presentation/providers/branch_providers.dart';
import '../../../../leave/domain/entities/leave_entity.dart';
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

// Edit-only sheet for one of the real, backend-persisted leave types (built-in
// or custom — both are edited via LeavePoliciesNotifier.updatePolicy, a real
// PUT /api/leave/policy/<leave_type>/). Creating a brand new custom type is
// handled by the separate, simpler AddLeaveTypeDialog — see that file.
class LeavePolicyFormSheet extends StatefulWidget {
  final LeavePolicyModel policy;
  final WidgetRef ref;

  const LeavePolicyFormSheet({super.key, required this.policy, required this.ref});

  @override
  State<LeavePolicyFormSheet> createState() => _LeavePolicyFormSheetState();
}

class _LeavePolicyFormSheetState extends State<LeavePolicyFormSheet> {
  // ── Type & Credit ──
  late final TextEditingController _annualDaysCtrl;
  late final TextEditingController _carryFwdLimitCtrl;
  late final TextEditingController _noteCtrl;
  late bool _canCarryForward;
  late bool _isActive;

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
  String? _annualDaysError;
  String? _carryFwdLimitError;
  String? _maxDurationError;
  String? _certAfterDaysError;

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void initState() {
    super.initState();
    final p = widget.policy;
    final form = LeavePolicyFormData.fromModel(p);

    _annualDaysCtrl = TextEditingController(text: _fmt(form.annualDays));
    _carryFwdLimitCtrl =
        TextEditingController(text: '${form.maxCarryForwardDays}');
    _noteCtrl = TextEditingController(text: form.policyNote);
    _canCarryForward = form.canCarryForward;
    _isActive = form.isActive;

    _minDurationCtrl =
        TextEditingController(text: _fmt(form.minimumLeaveDuration));
    _maxDurationCtrl = TextEditingController(text: '${form.maximumLeaveDuration}');
    _maxConsecutiveCtrl =
        TextEditingController(text: '${form.maximumConsecutiveDays}');
    _minNoticeCtrl = TextEditingController(text: '${form.minimumNoticePeriod}');
    _allowHalfDay = form.allowHalfDay;
    _allowBackdatedLeave = form.allowBackdatedLeave;
    _maxBackdatedCtrl = TextEditingController(text: '${form.maximumBackdatedDays}');
    _allowFutureLeave = form.allowFutureLeave;
    _maxFutureCtrl = TextEditingController(text: '${form.maximumFutureDays}');

    _sandwichLeaveEnabled = form.sandwichLeaveEnabled;
    _countHolidaysAsLeave = form.countHolidaysAsLeave;
    _countWeekoffsAsLeave = form.countWeekoffsAsLeave;

    _applicableBranches = List.of(form.applicableBranches);
    _applicableDepartments = List.of(form.applicableDepartments);
    _applicableDesignations = List.of(form.applicableDesignations);
    _applicableEmploymentTypes = List.of(form.applicableEmploymentTypes);
    _applicableGender = form.applicableGender;
    _minServicePeriodCtrl =
        TextEditingController(text: '${form.minimumServicePeriod}');

    _attachmentRequired = form.attachmentRequired;
    _medicalCertificateRequired = form.medicalCertificateRequired;
    _certAfterDaysCtrl =
        TextEditingController(text: '${form.medicalCertificateAfterDays}');

    _allowNegativeBalance = form.allowNegativeBalance;
    _convertToLop = form.convertToLop;
    _allowLeaveCancellation = form.allowLeaveCancellation;
    _cancelUntilCtrl = TextEditingController(text: '${form.cancellationAllowedUntil}');

    _allowProbationLeave = form.allowProbationLeave;
    _allowNoticePeriodLeave = form.allowNoticePeriodLeave;
    _allowLeaveExtension = form.allowLeaveExtension;
    _allowLeaveCombination = form.allowLeaveCombination;
  }

  @override
  void dispose() {
    _annualDaysCtrl.dispose();
    _carryFwdLimitCtrl.dispose();
    _noteCtrl.dispose();
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

  @override
  Widget build(BuildContext context) {
    final color = Color(LeaveTypeColors.colorValueForCode(widget.policy.leaveType));
    final title = 'Edit: ${widget.policy.leaveTypeDisplay}';
    return ConstrainedBox(
      // Caps the dialog so the header always stays put and the form body
      // below scrolls within whatever room is left — without this bound,
      // Flexible below has nothing to size against and the content overflows
      // past the dialog instead of scrolling.
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DlgHeader(
              color: color,
              title: title,
              subtitle: 'Update leave rules, eligibility and documentation policy',
              onClose: () => Navigator.pop(context),
            ),
            Flexible(
              child: Container(
                color: AppColors.background,
                padding: EdgeInsets.fromLTRB(
                    20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Type & Credit ──
                      TextFormField(
                        controller: _annualDaysCtrl,
                        style: AppTextStyles.body,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d{0,1}$'))
                        ],
                        onChanged: (_) =>
                            setState(() => _annualDaysError = null),
                        decoration: _dec('Annual Days *', _annualDaysError),
                      ),
                      const SizedBox(height: 14),
                      _ToggleRow(
                        icon: Icons.repeat_rounded,
                        label: 'Allow Carry Forward',
                        subtitleOn: 'Unused days roll over to next year',
                        subtitleOff: 'Unused days expire at year end',
                        value: _canCarryForward,
                        onChanged: (v) => setState(() => _canCarryForward = v),
                      ),
                      if (_canCarryForward) ...[
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _carryFwdLimitCtrl,
                          style: AppTextStyles.body,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (_) =>
                              setState(() => _carryFwdLimitError = null),
                          decoration: _dec(
                              'Max Carry Forward Days *', _carryFwdLimitError),
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _noteCtrl,
                        style: AppTextStyles.body,
                        maxLines: 3,
                        maxLength: 300,
                        decoration: _dec('Policy Note'),
                      ),
                      const SizedBox(height: 6),
                      _ToggleRow(
                        icon: Icons.check_circle_outline,
                        label: 'Active',
                        subtitleOn:
                            'Employees can select and apply for this leave',
                        subtitleOff: 'Hidden from Apply Leave and dashboards',
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                      ),
                      const SizedBox(height: 16),

                      // ── Leave Application Rules ──
                      _RuleSection(
                        icon: Icons.event_available_outlined,
                        title: 'Leave Application Rules',
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
                                  onChanged: () => setState(
                                      () => _maxDurationError = null),
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
                              (v) =>
                                  setState(() => _allowBackdatedLeave = v)),
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

                      // ── Holiday & Week-off Rules ──
                      _RuleSection(
                        icon: Icons.holiday_village_outlined,
                        title: 'Holiday & Week-off Rules',
                        children: [
                          _switchTile(
                              'Sandwich Leave',
                              'Holidays/week-offs between two leave days also count as leave',
                              _sandwichLeaveEnabled,
                              (v) =>
                                  setState(() => _sandwichLeaveEnabled = v)),
                          _switchTile(
                              'Count Holidays as Leave',
                              'Public holidays within the leave range consume balance',
                              _countHolidaysAsLeave,
                              (v) =>
                                  setState(() => _countHolidaysAsLeave = v)),
                          _switchTile(
                              'Count Week-offs as Leave',
                              'Weekly off days within the leave range consume balance',
                              _countWeekoffsAsLeave,
                              (v) =>
                                  setState(() => _countWeekoffsAsLeave = v)),
                        ],
                      ),

                      // ── Eligibility Rules ──
                      _RuleSection(
                        icon: Icons.groups_outlined,
                        title: 'Eligibility Rules',
                        children: [
                          Consumer(builder: (context, ref, _) {
                            final async = ref.watch(branchListProvider);
                            return async.when(
                              data: (branches) => _ChipMultiSelect(
                                label: 'Applicable Branches',
                                options:
                                    branches.map((b) => b.branchName).toList(),
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
                                onChanged: (v) => setState(
                                    () => _applicableDepartments = v),
                              ),
                              loading: () => const _ChipsLoading(
                                  label: 'Applicable Departments'),
                              error: (_, __) => const _ChipsError(
                                  label: 'Applicable Departments'),
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
                                onChanged: (v) => setState(
                                    () => _applicableDesignations = v),
                              ),
                              loading: () => const _ChipsLoading(
                                  label: 'Applicable Designations'),
                              error: (_, __) => const _ChipsError(
                                  label: 'Applicable Designations'),
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
                                  DropdownMenuItem(
                                      value: 'all', child: Text('All')),
                                  DropdownMenuItem(
                                      value: 'male', child: Text('Male')),
                                  DropdownMenuItem(
                                      value: 'female', child: Text('Female')),
                                ],
                                onChanged: (v) => setState(
                                    () => _applicableGender = v ?? 'all'),
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

                      // ── Documentation Rules ──
                      _RuleSection(
                        icon: Icons.description_outlined,
                        title: 'Documentation Rules',
                        children: [
                          _switchTile(
                              'Attachment Required',
                              'Employees must upload a supporting document',
                              _attachmentRequired,
                              (v) =>
                                  setState(() => _attachmentRequired = v)),
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

                      // ── Leave Restrictions ──
                      _RuleSection(
                        icon: Icons.block_outlined,
                        title: 'Leave Restrictions',
                        children: [
                          _switchTile(
                              'Allow Negative Balance',
                              'Employees may apply beyond their available balance',
                              _allowNegativeBalance,
                              (v) =>
                                  setState(() => _allowNegativeBalance = v)),
                          _switchTile(
                              'Convert to Loss of Pay',
                              'Excess days beyond balance are treated as LOP',
                              _convertToLop,
                              (v) => setState(() => _convertToLop = v)),
                          _switchTile(
                              'Allow Leave Cancellation',
                              null,
                              _allowLeaveCancellation,
                              (v) => setState(
                                  () => _allowLeaveCancellation = v)),
                          if (_allowLeaveCancellation) ...[
                            const SizedBox(height: 8),
                            _numField(
                              controller: _cancelUntilCtrl,
                              label: 'Cancellation Allowed Until (days before start)',
                            ),
                          ],
                        ],
                      ),

                      // ── Additional Rules ──
                      _RuleSection(
                        icon: Icons.tune_outlined,
                        title: 'Additional Rules',
                        children: [
                          _switchTile(
                              'Allow During Probation',
                              null,
                              _allowProbationLeave,
                              (v) =>
                                  setState(() => _allowProbationLeave = v)),
                          _switchTile(
                              'Allow During Notice Period',
                              null,
                              _allowNoticePeriodLeave,
                              (v) => setState(
                                  () => _allowNoticePeriodLeave = v)),
                          _switchTile(
                              'Allow Leave Extension',
                              null,
                              _allowLeaveExtension,
                              (v) =>
                                  setState(() => _allowLeaveExtension = v)),
                          _switchTile(
                              'Allow Combining with Other Leave Types',
                              null,
                              _allowLeaveCombination,
                              (v) => setState(
                                  () => _allowLeaveCombination = v)),
                        ],
                      ),

                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2))
                            : Text('Save Changes',
                                style: AppTextStyles.label
                                    .copyWith(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

  Widget _switchTile(
      String title, String? subtitle, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title,
          style:
              AppTextStyles.body.copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
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

  Future<void> _submit() async {
    final form = LeavePolicyFormData(
      annualDays: double.tryParse(_annualDaysCtrl.text) ?? -1,
      canCarryForward: _canCarryForward,
      maxCarryForwardDays: int.tryParse(_carryFwdLimitCtrl.text) ?? 0,
      policyNote: _noteCtrl.text.trim(),
      isActive: _isActive,
      minimumLeaveDuration: double.tryParse(_minDurationCtrl.text) ?? 0.5,
      maximumLeaveDuration: int.tryParse(_maxDurationCtrl.text) ?? 0,
      maximumConsecutiveDays: int.tryParse(_maxConsecutiveCtrl.text) ?? 0,
      minimumNoticePeriod: int.tryParse(_minNoticeCtrl.text) ?? 0,
      allowHalfDay: _allowHalfDay,
      allowBackdatedLeave: _allowBackdatedLeave,
      maximumBackdatedDays: int.tryParse(_maxBackdatedCtrl.text) ?? 0,
      allowFutureLeave: _allowFutureLeave,
      maximumFutureDays: int.tryParse(_maxFutureCtrl.text) ?? 0,
      sandwichLeaveEnabled: _sandwichLeaveEnabled,
      countHolidaysAsLeave: _countHolidaysAsLeave,
      countWeekoffsAsLeave: _countWeekoffsAsLeave,
      applicableBranches: _applicableBranches,
      applicableDepartments: _applicableDepartments,
      applicableDesignations: _applicableDesignations,
      applicableEmploymentTypes: _applicableEmploymentTypes,
      applicableGender: _applicableGender,
      minimumServicePeriod: int.tryParse(_minServicePeriodCtrl.text) ?? 0,
      attachmentRequired: _attachmentRequired,
      medicalCertificateRequired: _medicalCertificateRequired,
      medicalCertificateAfterDays: int.tryParse(_certAfterDaysCtrl.text) ?? 0,
      allowNegativeBalance: _allowNegativeBalance,
      convertToLop: _convertToLop,
      allowLeaveCancellation: _allowLeaveCancellation,
      cancellationAllowedUntil: int.tryParse(_cancelUntilCtrl.text) ?? 0,
      allowProbationLeave: _allowProbationLeave,
      allowNoticePeriodLeave: _allowNoticePeriodLeave,
      allowLeaveExtension: _allowLeaveExtension,
      allowLeaveCombination: _allowLeaveCombination,
    );
    final errors = form.validate();
    if (errors.isNotEmpty) {
      setState(() {
        _annualDaysError = errors['annualDays'];
        _carryFwdLimitError = errors['maxCarryForwardDays'];
        _maxDurationError = errors['maximumLeaveDuration'];
        _certAfterDaysError = errors['medicalCertificateAfterDays'];
      });
      return;
    }

    setState(() => _saving = true);
    final notifier = widget.ref.read(leavePoliciesProvider.notifier);
    final result = await notifier.updatePolicy(widget.policy.leaveType, form);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result),
        backgroundColor: AppColors.error,
      ));
    }
  }
}

// ── Collapsible rule section ──────────────────────────────────────────────────

class _RuleSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;
  const _RuleSection({required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Icon(icon, size: 18, color: AppColors.primary),
          title: Text(title,
              style: AppTextStyles.label
                  .copyWith(fontWeight: FontWeight.w700, fontSize: 13)),
          children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
                label: Text(o, style: AppTextStyles.caption.copyWith(fontSize: 11)),
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
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 11)),
        ],
      );
}

// ── Toggle row (generalised version of Departments' _StatusToggle) ────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitleOn;
  final String subtitleOff;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitleOn,
    required this.subtitleOff,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: value
            ? AppColors.success.withValues(alpha: 0.07)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? AppColors.success.withValues(alpha: 0.40)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            value ? Icons.check_circle_rounded : icon,
            color: value ? AppColors.success : AppColors.textHint,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.label
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  value ? subtitleOn : subtitleOff,
                  style: AppTextStyles.caption.copyWith(
                    color: value ? AppColors.success : AppColors.textHint,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.success,
          ),
        ],
      ),
    );
  }
}

// ── Dialog header ─────────────────────────────────────────────────────────────

class _DlgHeader extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onClose;
  const _DlgHeader(
      {required this.color,
      required this.title,
      required this.subtitle,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.beach_access_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            onPressed: onClose,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

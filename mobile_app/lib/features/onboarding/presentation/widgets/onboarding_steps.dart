part of '../screens/onboarding_screen.dart';

// ─── Step metadata ─────────────────────────────────────────────────────────

const List<Map<String, dynamic>> kStepMeta = [
  {'label': 'Personal', 'icon': Icons.person_outline},
  {'label': 'Education', 'icon': Icons.school_outlined},
  {'label': 'Bank', 'icon': Icons.account_balance_outlined},
  {'label': 'Emergency', 'icon': Icons.contact_emergency_outlined},
  {'label': 'Documents', 'icon': Icons.folder_copy_outlined},
];

const List<String> kStepTitles = [
  'Personal',
  'Education & Experience',
  'Bank Details',
  'Emergency Contact',
  'Documents',
];

// ─── Shared input decorator ────────────────────────────────────────────────

InputDecoration _fieldDec(String label, {String? hint, IconData? icon}) =>
    InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: AppTextStyles.label.copyWith(color: AppColors.textSecondary),
      floatingLabelStyle: AppTextStyles.label.copyWith(
          color: AppColors.primary, fontWeight: FontWeight.w600),
      prefixIcon: icon != null
          ? Icon(icon, size: 18, color: AppColors.textSecondary)
          : null,
      filled: true,
      fillColor: AppColors.backgroundLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primary, width: 1.8)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.error, width: 1.8)),
      errorStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
    );

Widget _fieldRow(Widget left, Widget right) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 14),
        Expanded(child: right),
      ],
    );

class _DropdownInput extends StatelessWidget {
  const _DropdownInput({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<Map<String, String>> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: _fieldDec(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.any((m) => m['value'] == value) ? value : null,
          isDense: true,
          isExpanded: true,
          hint: const Text('Select', style: TextStyle(fontSize: 14)),
          items: items
              .map((m) =>
                  DropdownMenuItem(value: m['value'], child: Text(m['label']!)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Shared "card section" — icon badge + title + fields ──────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, size: 20, color: accent),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Text(title, style: AppTextStyles.h4)),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 54),
                          child: Text(
                            subtitle!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      for (var i = 0; i < children.length; i++) ...[
                        children[i],
                        if (i != children.length - 1)
                          const SizedBox(height: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact tinted note for a single important callout inside a card (e.g.
/// the bank-details accuracy warning) — themed via AppColors so it reads
/// correctly in dark mode too, unlike a one-off hardcoded amber container.
class _InlineNote extends StatelessWidget {
  const _InlineNote(this.text, {this.icon = Icons.info_outline});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared buttons — one cohesive look for every step's footer actions ────

/// Gradient-filled primary CTA (Save & Continue / Submit) shared by every
/// step footer, so the wizard's main action always reads the same way.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: enabled
            ? LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])
            : null,
        color: enabled ? null : AppColors.border,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 17, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(label,
                            style: AppTextStyles.button
                                .copyWith(color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary action (Previous / Save Draft) sharing the same
/// radius and typography rhythm as [_PrimaryButton].
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        backgroundColor: AppColors.backgroundLow,
        side: BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.textSecondary))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.labelLarge,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Step 0 — Personal Information ────────────────────────────────────────

class _PersonalStep extends StatefulWidget {
  const _PersonalStep({
    required this.initial,
    required this.onSave,
    required this.onPrevious,
  });

  final OnboardingPersonalEntity initial;
  final Future<String?> Function(Map<String, dynamic>) onSave;
  final VoidCallback? onPrevious;

  @override
  State<_PersonalStep> createState() => _PersonalStepState();
}

class _PersonalStepState extends State<_PersonalStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _dob;
  late final TextEditingController _fatherName;
  late final TextEditingController _currentAddress;
  late final TextEditingController _permanentAddress;
  String? _gender;
  String? _bloodGroup;
  String? _maritalStatus;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _dob = TextEditingController(text: p.dateOfBirth ?? '');
    _fatherName = TextEditingController(text: p.fatherName ?? '');
    _currentAddress = TextEditingController(text: p.currentAddress ?? '');
    _permanentAddress = TextEditingController(text: p.permanentAddress ?? '');
    _gender = p.gender;
    _bloodGroup = p.bloodGroup;
    _maritalStatus = p.maritalStatus;
  }

  @override
  void dispose() {
    _dob.dispose();
    _fatherName.dispose();
    _currentAddress.dispose();
    _permanentAddress.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await widget.onSave({
      'date_of_birth': _dob.text.trim(),
      'gender': _gender,
      'marital_status': _maritalStatus,
      'father_name': _fatherName.text.trim(),
      'blood_group': _bloodGroup,
      'current_address': _currentAddress.text.trim(),
      'permanent_address': _permanentAddress.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepFormWrapper(
      formKey: _formKey,
      saving: _saving,
      onSave: _handleSave,
      onPrevious: widget.onPrevious,
      children: [
        _SectionCard(
          icon: Icons.badge_outlined,
          title: 'Personal Details',
          children: [
            _fieldRow(
              TextFormField(
                controller: _dob,
                decoration: _fieldDec('Date of Birth',
                    hint: 'dd-mm-yyyy', icon: Icons.calendar_today_outlined),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    _dob.text =
                        '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                  }
                },
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              _DropdownInput(
                label: 'Gender',
                value: _gender,
                items: const [
                  {'value': 'male', 'label': 'Male'},
                  {'value': 'female', 'label': 'Female'},
                  {'value': 'other', 'label': 'Other / Prefer not to say'},
                ],
                onChanged: (v) => setState(() => _gender = v),
              ),
            ),
            _fieldRow(
              _DropdownInput(
                label: 'Marital Status',
                value: _maritalStatus,
                items: const [
                  {'value': 'single', 'label': 'Single'},
                  {'value': 'married', 'label': 'Married'},
                  {'value': 'divorced', 'label': 'Divorced'},
                  {'value': 'widowed', 'label': 'Widowed'},
                ],
                onChanged: (v) => setState(() => _maritalStatus = v),
              ),
              _DropdownInput(
                label: 'Blood Group',
                value: _bloodGroup,
                items: const [
                  {'value': 'A+', 'label': 'A+'},
                  {'value': 'A-', 'label': 'A-'},
                  {'value': 'B+', 'label': 'B+'},
                  {'value': 'B-', 'label': 'B-'},
                  {'value': 'O+', 'label': 'O+'},
                  {'value': 'O-', 'label': 'O-'},
                  {'value': 'AB+', 'label': 'AB+'},
                  {'value': 'AB-', 'label': 'AB-'},
                ],
                onChanged: (v) => setState(() => _bloodGroup = v),
              ),
            ),
            TextFormField(
              controller: _fatherName,
              decoration: _fieldDec("Father's Name",
                  hint: "Father's full name",
                  icon: Icons.family_restroom_outlined),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
          ],
        ),
        _SectionCard(
          icon: Icons.home_outlined,
          title: 'Address',
          iconColor: AppColors.secondary,
          children: [
            TextFormField(
              controller: _currentAddress,
              decoration: _fieldDec('Current Address',
                  hint: 'House / Flat no., Street, City, State, PIN',
                  icon: Icons.location_on_outlined),
              maxLines: 3,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _permanentAddress,
              decoration: _fieldDec(
                'Permanent Address (if different)',
                hint: 'Leave blank if same as current',
                icon: Icons.location_city_outlined,
              ),
              maxLines: 3,
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Step 1 — Education & Experience ──────────────────────────────────────

class _EducationStep extends StatefulWidget {
  const _EducationStep({
    required this.initial,
    required this.onSave,
    required this.onPrevious,
  });

  final OnboardingEducationEntity initial;
  final Future<String?> Function(Map<String, dynamic>) onSave;
  final VoidCallback? onPrevious;

  @override
  State<_EducationStep> createState() => _EducationStepState();
}

class _EducationStepState extends State<_EducationStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _qualification;
  late final TextEditingController _institution;
  late final TextEditingController _year;
  late final TextEditingController _specialization;
  late final TextEditingController _totalExp;
  late final TextEditingController _prevEmployer;
  late final TextEditingController _prevDesignation;
  late final TextEditingController _leavingReason;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _qualification = TextEditingController(text: e.highestQualification ?? '');
    _institution = TextEditingController(text: e.institution ?? '');
    _year = TextEditingController(text: e.yearOfPassing ?? '');
    _specialization = TextEditingController(text: e.specialization ?? '');
    _totalExp = TextEditingController(text: e.totalExperienceYears ?? '');
    _prevEmployer = TextEditingController(text: e.previousEmployer ?? '');
    _prevDesignation = TextEditingController(text: e.previousDesignation ?? '');
    _leavingReason = TextEditingController(text: e.leavingReason ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _qualification,
      _institution,
      _year,
      _specialization,
      _totalExp,
      _prevEmployer,
      _prevDesignation,
      _leavingReason,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await widget.onSave({
      'highest_qualification': _qualification.text.trim(),
      'institution': _institution.text.trim(),
      'year_of_passing':
          _year.text.trim().isNotEmpty ? int.tryParse(_year.text.trim()) : null,
      'specialization': _specialization.text.trim(),
      'total_experience_years': _totalExp.text.trim().isNotEmpty
          ? double.tryParse(_totalExp.text.trim())
          : null,
      'previous_employer': _prevEmployer.text.trim(),
      'previous_designation': _prevDesignation.text.trim(),
      'leaving_reason': _leavingReason.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepFormWrapper(
      formKey: _formKey,
      saving: _saving,
      onSave: _handleSave,
      onPrevious: widget.onPrevious,
      children: [
        _SectionCard(
          icon: Icons.school_outlined,
          title: 'Education',
          children: [
            _fieldRow(
              TextFormField(
                controller: _qualification,
                decoration: _fieldDec('Highest Qualification',
                    hint: 'e.g. B.Tech, MBA',
                    icon: Icons.workspace_premium_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _specialization,
                decoration:
                    _fieldDec('Specialization', hint: 'e.g. Computer Science'),
              ),
            ),
            _fieldRow(
              TextFormField(
                controller: _institution,
                decoration: _fieldDec('Institution / University',
                    hint: 'College or university name',
                    icon: Icons.account_balance_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _year,
                decoration: _fieldDec('Year of Passing', hint: 'e.g. 2020'),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
          ],
        ),
        _SectionCard(
          icon: Icons.work_outline,
          title: 'Work Experience',
          subtitle: 'Optional — leave blank if this is your first job.',
          iconColor: AppColors.secondary,
          children: [
            _fieldRow(
              TextFormField(
                controller: _totalExp,
                decoration: _fieldDec('Total Experience (years)',
                    hint: 'e.g. 3.5', icon: Icons.timeline_outlined),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              TextFormField(
                controller: _prevEmployer,
                decoration: _fieldDec('Previous Employer',
                    hint: 'Company name (if any)'),
              ),
            ),
            TextFormField(
              controller: _prevDesignation,
              decoration:
                  _fieldDec('Previous Designation', hint: 'Job title (if any)'),
            ),
            TextFormField(
              controller: _leavingReason,
              decoration: _fieldDec('Reason for Leaving', hint: 'Optional'),
              maxLines: 3,
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Step 2 — Bank Details ─────────────────────────────────────────────────

class _BankStep extends StatefulWidget {
  const _BankStep({
    required this.initial,
    required this.onSave,
    required this.onPrevious,
  });

  final OnboardingBankEntity initial;
  final Future<String?> Function(Map<String, dynamic>) onSave;
  final VoidCallback? onPrevious;

  @override
  State<_BankStep> createState() => _BankStepState();
}

class _BankStepState extends State<_BankStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _accountHolderName;
  late final TextEditingController _accountNumber;
  late final TextEditingController _ifsc;
  late final TextEditingController _bankName;
  late final TextEditingController _bankBranchName;
  String? _accountType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    _accountHolderName = TextEditingController(text: b.accountHolderName ?? '');
    _accountNumber = TextEditingController(text: b.accountNumber ?? '');
    _ifsc = TextEditingController(text: b.ifscCode ?? '');
    _bankName = TextEditingController(text: b.bankName ?? '');
    _bankBranchName = TextEditingController(text: b.bankBranchName ?? '');
    _accountType = b.accountType;
  }

  @override
  void dispose() {
    _accountHolderName.dispose();
    _accountNumber.dispose();
    _ifsc.dispose();
    _bankName.dispose();
    _bankBranchName.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await widget.onSave({
      'account_holder_name': _accountHolderName.text.trim(),
      'account_type': _accountType,
      'account_number': _accountNumber.text.trim(),
      'ifsc_code': _ifsc.text.trim().toUpperCase(),
      'bank_name': _bankName.text.trim(),
      'bank_branch_name': _bankBranchName.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepFormWrapper(
      formKey: _formKey,
      saving: _saving,
      onSave: _handleSave,
      onPrevious: widget.onPrevious,
      children: [
        _SectionCard(
          icon: Icons.account_balance_outlined,
          title: 'Bank Account Details',
          children: [
            const _InlineNote(
              'Bank details are used for payroll. Ensure all information matches your passbook exactly.',
              icon: Icons.warning_amber_rounded,
            ),
            _fieldRow(
              TextFormField(
                controller: _accountHolderName,
                decoration: _fieldDec('Account Holder Name',
                    hint: 'As printed on passbook', icon: Icons.person_outline),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              _DropdownInput(
                label: 'Account Type',
                value: _accountType,
                items: const [
                  {'value': 'savings', 'label': 'Savings'},
                  {'value': 'current', 'label': 'Current'},
                ],
                onChanged: (v) => setState(() => _accountType = v),
              ),
            ),
            _fieldRow(
              TextFormField(
                controller: _accountNumber,
                decoration: _fieldDec('Account Number',
                    hint: 'Bank account number',
                    icon: Icons.credit_card_outlined),
                keyboardType: TextInputType.number,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _ifsc,
                decoration: _fieldDec('IFSC Code', hint: 'e.g. SBIN0001234'),
                textCapitalization: TextCapitalization.characters,
                maxLength: 11,
                buildCounter: (_,
                        {required currentLength,
                        required isFocused,
                        maxLength}) =>
                    null,
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            _fieldRow(
              TextFormField(
                controller: _bankName,
                decoration: _fieldDec('Bank Name',
                    hint: 'e.g. State Bank of India',
                    icon: Icons.account_balance_outlined),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _bankBranchName,
                decoration:
                    _fieldDec('Branch Name', hint: 'Branch city / locality'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Step 3 — Emergency Contact ───────────────────────────────────────────

class _EmergencyStep extends StatefulWidget {
  const _EmergencyStep({
    required this.initial,
    required this.onSave,
    required this.onPrevious,
  });

  final OnboardingEmergencyEntity initial;
  final Future<String?> Function(Map<String, dynamic>) onSave;
  final VoidCallback? onPrevious;

  @override
  State<_EmergencyStep> createState() => _EmergencyStepState();
}

class _EmergencyStepState extends State<_EmergencyStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _relationship;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _name = TextEditingController(text: e.emergencyName ?? '');
    _relationship = TextEditingController(text: e.emergencyRelationship ?? '');
    _phone = TextEditingController(text: e.emergencyPhone ?? '');
    _email = TextEditingController(text: e.emergencyEmail ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _relationship.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await widget.onSave({
      'emergency_name': _name.text.trim(),
      'emergency_relationship': _relationship.text.trim(),
      'emergency_phone': _phone.text.trim(),
      'emergency_email': _email.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepFormWrapper(
      formKey: _formKey,
      saving: _saving,
      onSave: _handleSave,
      onPrevious: widget.onPrevious,
      children: [
        _SectionCard(
          icon: Icons.contact_emergency_outlined,
          title: 'Emergency Contact',
          subtitle:
              'This person will be contacted in case of an emergency at the workplace.',
          children: [
            _fieldRow(
              TextFormField(
                controller: _name,
                decoration: _fieldDec('Contact Name',
                    hint: 'Full name', icon: Icons.person_outline),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _relationship,
                decoration: _fieldDec('Relationship',
                    hint: 'e.g. Spouse, Parent, Sibling'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
            ),
            _fieldRow(
              TextFormField(
                controller: _phone,
                decoration: _fieldDec('Phone Number',
                    hint: 'Mobile number', icon: Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                validator: (v) =>
                    FormValidators.lenientPhone(v, required: true),
              ),
              TextFormField(
                controller: _email,
                decoration: _fieldDec('Email (optional)',
                    hint: 'email@example.com', icon: Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? null
                    : FormValidators.email(v),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Step 4 — Documents ───────────────────────────────────────────────────

const List<Map<String, String>> kDocTypes = [
  {'value': 'pan_card', 'label': 'PAN Card'},
  {'value': 'aadhaar_card', 'label': 'Aadhaar Card'},
  {'value': 'degree_certificate', 'label': 'Degree Certificate'},
  {'value': 'experience_letter', 'label': 'Experience Letter'},
];

class _DocumentsStep extends StatefulWidget {
  const _DocumentsStep({
    required this.documents,
    required this.onUpload,
    required this.onDelete,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onPrevious,
  });

  final List<OnboardingDocEntity> documents;
  final Future<String?> Function(String docType, PlatformFile file) onUpload;
  final Future<String?> Function(int id) onDelete;
  final Future<void> Function() onSaveDraft;
  final Future<void> Function() onSubmit;
  final VoidCallback? onPrevious;

  @override
  State<_DocumentsStep> createState() => _DocumentsStepState();
}

class _DocumentsStepState extends State<_DocumentsStep> {
  bool _submitting = false;
  bool _savingDraft = false;
  final _uploading = <String>{};

  Future<void> _pickAndUpload(String docType) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('File must be under 5 MB.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }
    setState(() => _uploading.add(docType));
    final err = await widget.onUpload(docType, file);
    if (!mounted) return;
    setState(() => _uploading.remove(docType));
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err), backgroundColor: AppColors.error),
      );
    }
  }

  Future<void> _handleSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit for Approval?'),
        content: const Text(
          'Once submitted, your profile will be reviewed by HR. You cannot make changes after submission.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _submitting = true);
    await widget.onSubmit();
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _handleSaveDraft() async {
    setState(() => _savingDraft = true);
    await widget.onSaveDraft();
    if (mounted) setState(() => _savingDraft = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.infoContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(Icons.info_outline, color: AppColors.info, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Upload clear scans or photos. Accepted: PDF, JPG, PNG · Max 5 MB each.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                ...kDocTypes.map((doc) {
                  final uploaded = widget.documents
                      .where((d) => d.docType == doc['value'])
                      .toList();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DocTypeCard(
                      docType: doc['value']!,
                      label: doc['label']!,
                      uploaded: uploaded,
                      isUploading: _uploading.contains(doc['value']),
                      onUpload: () => _pickAndUpload(doc['value']!),
                      onDelete: widget.onDelete,
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        _StickyFooter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: _PrimaryButton(
                  label: 'Submit for Approval',
                  loading: _submitting,
                  onPressed: _handleSubmit,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.onPrevious != null) ...[
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Previous',
                        icon: Icons.arrow_back,
                        onPressed: widget.onPrevious,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _SecondaryButton(
                      label: 'Save Draft',
                      loading: _savingDraft,
                      onPressed: _handleSaveDraft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocTypeCard extends StatelessWidget {
  const _DocTypeCard({
    required this.docType,
    required this.label,
    required this.uploaded,
    required this.isUploading,
    required this.onUpload,
    required this.onDelete,
  });

  final String docType;
  final String label;
  final List<OnboardingDocEntity> uploaded;
  final bool isUploading;
  final VoidCallback onUpload;
  final Future<String?> Function(int id) onDelete;

  @override
  Widget build(BuildContext context) {
    final hasUpload = uploaded.isNotEmpty;
    final accent = hasUpload ? AppColors.success : AppColors.textHint;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: hasUpload
              ? AppColors.successContainer.withValues(alpha: 0.35)
              : AppColors.backgroundLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUpload
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent.withValues(alpha: 0.6)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: hasUpload
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: hasUpload
                              ? null
                              : Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          hasUpload
                              ? Icons.check_circle_rounded
                              : Icons.upload_file_outlined,
                          color: hasUpload
                              ? AppColors.success
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: AppTextStyles.label
                                    .copyWith(fontWeight: FontWeight.w600)),
                            if (hasUpload)
                              ...uploaded.map((doc) =>
                                  _UploadedChip(doc: doc, onDelete: onDelete))
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('Not uploaded yet',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.textHint)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      isUploading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary))
                          : TextButton(
                              onPressed: onUpload,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.1),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(hasUpload ? 'Add another' : 'Upload',
                                  style: AppTextStyles.labelSmall
                                      .copyWith(fontWeight: FontWeight.w700)),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadedChip extends StatelessWidget {
  const _UploadedChip({required this.doc, required this.onDelete});

  final OnboardingDocEntity doc;
  final Future<String?> Function(int id) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 14, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              doc.fileName.isNotEmpty ? doc.fileName : 'Uploaded',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () async {
              final err = await onDelete(doc.id);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(2),
              child:
                  Icon(Icons.close, size: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared step form wrapper ──────────────────────────────────────────────

/// Bottom action bar pinned outside the scrollable step content, so
/// Previous/Save & Continue (or Save Draft/Submit) always stay reachable
/// without scrolling, and read as a distinct footer rather than trailing
/// off the end of a form.
class _StickyFooter extends StatelessWidget {
  const _StickyFooter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _StepFormWrapper extends StatelessWidget {
  const _StepFormWrapper({
    required this.formKey,
    required this.saving,
    required this.onSave,
    required this.onPrevious,
    required this.children,
  });

  final GlobalKey<FormState> formKey;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback? onPrevious;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i != children.length - 1) const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          _StickyFooter(
            child: Row(
              children: [
                if (onPrevious != null) ...[
                  _SecondaryButton(
                    label: 'Previous',
                    icon: Icons.arrow_back,
                    onPressed: onPrevious,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _PrimaryButton(
                    label: 'Save & Continue',
                    icon: Icons.arrow_forward,
                    loading: saving,
                    onPressed: onSave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

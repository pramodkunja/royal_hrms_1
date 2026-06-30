part of '../screens/onboarding_screen.dart';

// ─── Step metadata ─────────────────────────────────────────────────────────

const List<Map<String, dynamic>> kStepMeta = [
  {'label': 'Personal',  'icon': Icons.person_outline},
  {'label': 'Education', 'icon': Icons.school_outlined},
  {'label': 'Bank',      'icon': Icons.account_balance_outlined},
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

InputDecoration _fieldDec(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
    );

Widget _fieldRow(Widget left, Widget right) => Row(
      children: [
        Expanded(child: left),
        const SizedBox(width: 12),
        Expanded(child: right),
      ],
    );

Widget _sectionLabel(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
          color: AppColors.textSecondary,
        ),
      ),
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
              .map((m) => DropdownMenuItem(
                  value: m['value'], child: Text(m['label']!)))
              .toList(),
          onChanged: onChanged,
        ),
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
    _permanentAddress =
        TextEditingController(text: p.permanentAddress ?? '');
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
        _fieldRow(
          TextFormField(
            controller: _dob,
            decoration: _fieldDec('Date of Birth', hint: 'dd-mm-yyyy'),
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
        const SizedBox(height: 16),
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
        const SizedBox(height: 16),
        _fieldRow(
          TextFormField(
            controller: _fatherName,
            decoration:
                _fieldDec("Father's Name", hint: "Father's full name"),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
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
        const SizedBox(height: 16),
        TextFormField(
          controller: _currentAddress,
          decoration: _fieldDec('Current Address',
              hint: 'House / Flat no., Street, City, State, PIN'),
          maxLines: 3,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _permanentAddress,
          decoration: _fieldDec(
            'Permanent Address (if different)',
            hint: 'Leave blank if same as current',
          ),
          maxLines: 3,
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
    _qualification =
        TextEditingController(text: e.highestQualification ?? '');
    _institution = TextEditingController(text: e.institution ?? '');
    _year = TextEditingController(text: e.yearOfPassing ?? '');
    _specialization =
        TextEditingController(text: e.specialization ?? '');
    _totalExp =
        TextEditingController(text: e.totalExperienceYears ?? '');
    _prevEmployer =
        TextEditingController(text: e.previousEmployer ?? '');
    _prevDesignation =
        TextEditingController(text: e.previousDesignation ?? '');
    _leavingReason =
        TextEditingController(text: e.leavingReason ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _qualification, _institution, _year, _specialization,
      _totalExp, _prevEmployer, _prevDesignation, _leavingReason,
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
      'year_of_passing': _year.text.trim().isNotEmpty
          ? int.tryParse(_year.text.trim())
          : null,
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
        _sectionLabel('EDUCATION'),
        _fieldRow(
          TextFormField(
            controller: _qualification,
            decoration: _fieldDec('Highest Qualification',
                hint: 'e.g. B.Tech, MBA'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _specialization,
            decoration:
                _fieldDec('Specialization', hint: 'e.g. Computer Science'),
          ),
        ),
        const SizedBox(height: 12),
        _fieldRow(
          TextFormField(
            controller: _institution,
            decoration: _fieldDec('Institution / University',
                hint: 'College or university name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _year,
            decoration:
                _fieldDec('Year of Passing', hint: 'e.g. 2020'),
            keyboardType: TextInputType.number,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        const SizedBox(height: 24),
        _sectionLabel('WORK EXPERIENCE'),
        _fieldRow(
          TextFormField(
            controller: _totalExp,
            decoration: _fieldDec('Total Experience (years)',
                hint: 'e.g. 3.5'),
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
          ),
          TextFormField(
            controller: _prevEmployer,
            decoration: _fieldDec('Previous Employer',
                hint: 'Company name (if any)'),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _prevDesignation,
          decoration: _fieldDec('Previous Designation',
              hint: 'Job title (if any)'),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _leavingReason,
          decoration: _fieldDec('Reason for Leaving', hint: 'Optional'),
          maxLines: 3,
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
    _accountHolderName =
        TextEditingController(text: b.accountHolderName ?? '');
    _accountNumber =
        TextEditingController(text: b.accountNumber ?? '');
    _ifsc = TextEditingController(text: b.ifscCode ?? '');
    _bankName = TextEditingController(text: b.bankName ?? '');
    _bankBranchName =
        TextEditingController(text: b.bankBranchName ?? '');
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
        // Warning banner
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 16, color: Color(0xFFD97706)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bank details are used for payroll. Ensure all information matches your passbook exactly.',
                  style: AppTextStyles.caption
                      .copyWith(color: const Color(0xFFD97706)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _fieldRow(
          TextFormField(
            controller: _accountHolderName,
            decoration: _fieldDec('Account Holder Name',
                hint: 'As printed on passbook'),
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
        const SizedBox(height: 12),
        _fieldRow(
          TextFormField(
            controller: _accountNumber,
            decoration: _fieldDec('Account Number',
                hint: 'Bank account number'),
            keyboardType: TextInputType.number,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _ifsc,
            decoration:
                _fieldDec('IFSC Code', hint: 'e.g. SBIN0001234'),
            textCapitalization: TextCapitalization.characters,
            maxLength: 11,
            buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
                null,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
        ),
        const SizedBox(height: 12),
        _fieldRow(
          TextFormField(
            controller: _bankName,
            decoration: _fieldDec('Bank Name',
                hint: 'e.g. State Bank of India'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _bankBranchName,
            decoration: _fieldDec('Branch Name',
                hint: 'Branch city / locality'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
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
    _relationship =
        TextEditingController(text: e.emergencyRelationship ?? '');
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
        Text(
          'This person will be contacted in case of an emergency at the workplace.',
          style:
              AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        _fieldRow(
          TextFormField(
            controller: _name,
            decoration:
                _fieldDec('Contact Name', hint: 'Full name'),
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
        const SizedBox(height: 12),
        _fieldRow(
          TextFormField(
            controller: _phone,
            decoration: _fieldDec('Phone Number', hint: 'Mobile number'),
            keyboardType: TextInputType.phone,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          TextFormField(
            controller: _email,
            decoration: _fieldDec('Email (optional)',
                hint: 'email@example.com'),
            keyboardType: TextInputType.emailAddress,
          ),
        ),
      ],
    );
  }
}

// ─── Step 4 — Documents ───────────────────────────────────────────────────

const List<Map<String, String>> kDocTypes = [
  {'value': 'pan_card',          'label': 'PAN Card'},
  {'value': 'aadhaar_card',      'label': 'Aadhaar Card'},
  {'value': 'degree_certificate','label': 'Degree Certificate'},
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
  final Future<String?> Function(String docType) onUpload;
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload clear scans or photos. Accepted: PDF, JPG, PNG · Max 5 MB each.',
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          ...kDocTypes.map((doc) {
            final uploaded = widget.documents
                .where((d) => d.docType == doc['value'])
                .toList();
            return _DocTypeCard(
              docType: doc['value']!,
              label: doc['label']!,
              uploaded: uploaded,
              onUpload: () => widget.onUpload(doc['value']!),
              onDelete: widget.onDelete,
            );
          }),
          const SizedBox(height: 32),
          // Navigation row
          Row(
            children: [
              if (widget.onPrevious != null)
                OutlinedButton.icon(
                  onPressed: widget.onPrevious,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Previous'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              const Spacer(),
              OutlinedButton(
                onPressed: _savingDraft ? null : _handleSaveDraft,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  side: const BorderSide(color: AppColors.border),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: _savingDraft
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textSecondary))
                    : const Text('Save Draft'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _submitting ? null : _handleSubmit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Submit for Approval'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _DocTypeCard extends StatelessWidget {
  const _DocTypeCard({
    required this.docType,
    required this.label,
    required this.uploaded,
    required this.onUpload,
    required this.onDelete,
  });

  final String docType;
  final String label;
  final List<OnboardingDocEntity> uploaded;
  final VoidCallback onUpload;
  final Future<String?> Function(int id) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined,
              color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: AppTextStyles.label
                        .copyWith(fontWeight: FontWeight.w600)),
                if (uploaded.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  ...uploaded.map((doc) => _UploadedChip(
                      doc: doc, onDelete: onDelete)),
                ],
              ],
            ),
          ),
          TextButton(
            onPressed: onUpload,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Upload'),
          ),
        ],
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
    return Row(
      children: [
        const Icon(Icons.check_circle_rounded,
            color: Color(0xFF22C55E), size: 14),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            doc.fileName.isNotEmpty ? doc.fileName : 'Uploaded',
            style: AppTextStyles.caption
                .copyWith(color: const Color(0xFF22C55E)),
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
          child: const Icon(Icons.close,
              size: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

// ─── Shared step form wrapper ──────────────────────────────────────────────

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
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...children,
            const SizedBox(height: 32),
            Row(
              children: [
                if (onPrevious != null)
                  OutlinedButton.icon(
                    onPressed: onPrevious,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text('Previous'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side: const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: saving ? null : onSave,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Save & Continue'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

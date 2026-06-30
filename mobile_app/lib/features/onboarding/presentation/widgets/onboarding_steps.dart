part of '../screens/onboarding_screen.dart';

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

class _DropdownInput extends StatelessWidget {
  const _DropdownInput({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: _fieldDec(label),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isDense: true,
          isExpanded: true,
          hint: const Text('Select', style: TextStyle(fontSize: 14)),
          items: items
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ─── Step 0 — Personal Information ────────────────────────────────────────

class _PersonalStep extends StatefulWidget {
  const _PersonalStep({required this.initial, required this.onSave});

  final OnboardingPersonalEntity initial;
  final Future<String?> Function(Map<String, dynamic>) onSave;

  @override
  State<_PersonalStep> createState() => _PersonalStepState();
}

class _PersonalStepState extends State<_PersonalStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _dob;
  late final TextEditingController _nationality;
  late final TextEditingController _fatherName;
  late final TextEditingController _phone;
  late final TextEditingController _addr1;
  late final TextEditingController _addr2;
  late final TextEditingController _city;
  late final TextEditingController _stateCtrl;
  late final TextEditingController _pincode;
  late final TextEditingController _country;
  String? _gender;
  String? _bloodGroup;
  String? _maritalStatus;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;
    _firstName = TextEditingController(text: p.firstName ?? '');
    _lastName = TextEditingController(text: p.lastName ?? '');
    _dob = TextEditingController(text: p.dateOfBirth ?? '');
    _nationality = TextEditingController(text: p.nationality ?? '');
    _fatherName = TextEditingController(text: p.fatherName ?? '');
    _phone = TextEditingController(text: p.phone ?? '');
    _addr1 = TextEditingController(text: p.addressLine1 ?? '');
    _addr2 = TextEditingController(text: p.addressLine2 ?? '');
    _city = TextEditingController(text: p.city ?? '');
    _stateCtrl = TextEditingController(text: p.state ?? '');
    _pincode = TextEditingController(text: p.pincode ?? '');
    _country = TextEditingController(text: p.country ?? 'India');
    _gender = p.gender;
    _bloodGroup = p.bloodGroup;
    _maritalStatus = p.maritalStatus;
  }

  @override
  void dispose() {
    for (final c in [
      _firstName, _lastName, _dob, _nationality, _fatherName,
      _phone, _addr1, _addr2, _city, _stateCtrl, _pincode, _country,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await widget.onSave({
      'first_name': _firstName.text.trim(),
      'last_name': _lastName.text.trim(),
      'date_of_birth': _dob.text.trim(),
      'gender': _gender,
      'nationality': _nationality.text.trim(),
      'blood_group': _bloodGroup,
      'marital_status': _maritalStatus,
      'father_name': _fatherName.text.trim(),
      'phone': _phone.text.trim(),
      'address_line1': _addr1.text.trim(),
      'address_line2': _addr2.text.trim(),
      'city': _city.text.trim(),
      'state': _stateCtrl.text.trim(),
      'pincode': _pincode.text.trim(),
      'country': _country.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepFormWrapper(
      formKey: _formKey,
      saving: _saving,
      onSave: _handleSave,
      children: [
        _fieldRow(
          TextFormField(
              controller: _firstName,
              decoration: _fieldDec('First Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          TextFormField(
              controller: _lastName,
              decoration: _fieldDec('Last Name'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _dob,
          decoration: _fieldDec('Date of Birth', hint: 'YYYY-MM-DD'),
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
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
        ),
        const SizedBox(height: 16),
        _fieldRow(
          _DropdownInput(
            label: 'Gender',
            value: _gender,
            items: const ['Male', 'Female', 'Other'],
            onChanged: (v) => setState(() => _gender = v),
          ),
          _DropdownInput(
            label: 'Blood Group',
            value: _bloodGroup,
            items: const ['A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'AB+', 'AB-'],
            onChanged: (v) => setState(() => _bloodGroup = v),
          ),
        ),
        const SizedBox(height: 16),
        _fieldRow(
          TextFormField(
              controller: _nationality,
              decoration: _fieldDec('Nationality')),
          _DropdownInput(
            label: 'Marital Status',
            value: _maritalStatus,
            items: const ['Single', 'Married', 'Divorced', 'Widowed'],
            onChanged: (v) => setState(() => _maritalStatus = v),
          ),
        ),
        const SizedBox(height: 16),
        _fieldRow(
          TextFormField(
              controller: _fatherName,
              decoration: _fieldDec("Father's Name")),
          TextFormField(
              controller: _phone,
              decoration: _fieldDec('Phone Number'),
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        ),
        const SizedBox(height: 24),
        Text('Address', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextFormField(
            controller: _addr1,
            decoration: _fieldDec('Address Line 1')),
        const SizedBox(height: 12),
        TextFormField(
            controller: _addr2,
            decoration: _fieldDec('Address Line 2 (Optional)')),
        const SizedBox(height: 12),
        _fieldRow(
          TextFormField(controller: _city, decoration: _fieldDec('City')),
          TextFormField(controller: _stateCtrl, decoration: _fieldDec('State')),
        ),
        const SizedBox(height: 12),
        _fieldRow(
          TextFormField(
              controller: _pincode,
              decoration: _fieldDec('Pincode'),
              keyboardType: TextInputType.number),
          TextFormField(controller: _country, decoration: _fieldDec('Country')),
        ),
      ],
    );
  }
}

// ─── Step 1 — Education ────────────────────────────────────────────────────

class _EducationStep extends StatefulWidget {
  const _EducationStep({required this.initial, required this.onSave});

  final OnboardingEducationEntity initial;
  final Future<String?> Function(Map<String, dynamic>) onSave;

  @override
  State<_EducationStep> createState() => _EducationStepState();
}

class _EducationStepState extends State<_EducationStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _institution;
  late final TextEditingController _specialization;
  late final TextEditingController _year;
  late final TextEditingController _grade;
  String? _qualification;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _institution = TextEditingController(text: e.institution ?? '');
    _specialization = TextEditingController(text: e.specialization ?? '');
    _year = TextEditingController(text: e.yearOfPassing ?? '');
    _grade = TextEditingController(text: e.grade ?? '');
    _qualification = e.qualification;
  }

  @override
  void dispose() {
    for (final c in [_institution, _specialization, _year, _grade]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await widget.onSave({
      'qualification': _qualification,
      'institution': _institution.text.trim(),
      'specialization': _specialization.text.trim(),
      'year_of_passing': _year.text.trim(),
      'grade': _grade.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepFormWrapper(
      formKey: _formKey,
      saving: _saving,
      onSave: _handleSave,
      children: [
        _DropdownInput(
          label: 'Highest Qualification',
          value: _qualification,
          items: const [
            '10th', '12th', 'Diploma', 'Bachelor\'s', 'Master\'s', 'PhD', 'Other'
          ],
          onChanged: (v) => setState(() => _qualification = v),
        ),
        const SizedBox(height: 16),
        TextFormField(
            controller: _institution,
            decoration: _fieldDec('Institution / University'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        const SizedBox(height: 16),
        TextFormField(
            controller: _specialization,
            decoration: _fieldDec('Specialization / Field of Study')),
        const SizedBox(height: 16),
        _fieldRow(
          TextFormField(
              controller: _year,
              decoration: _fieldDec('Year of Passing'),
              keyboardType: TextInputType.number),
          TextFormField(
              controller: _grade,
              decoration: _fieldDec('Grade / Percentage')),
        ),
      ],
    );
  }
}

// ─── Step 2 — Bank Details ─────────────────────────────────────────────────

class _BankStep extends StatefulWidget {
  const _BankStep({required this.initial, required this.onSave});

  final OnboardingBankEntity initial;
  final Future<String?> Function(Map<String, dynamic>) onSave;

  @override
  State<_BankStep> createState() => _BankStepState();
}

class _BankStepState extends State<_BankStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _bankName;
  late final TextEditingController _accountNumber;
  late final TextEditingController _ifsc;
  late final TextEditingController _branchName;
  String? _accountType;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final b = widget.initial;
    _bankName = TextEditingController(text: b.bankName ?? '');
    _accountNumber = TextEditingController(text: b.accountNumber ?? '');
    _ifsc = TextEditingController(text: b.ifscCode ?? '');
    _branchName = TextEditingController(text: b.branchName ?? '');
    _accountType = b.accountType;
  }

  @override
  void dispose() {
    for (final c in [_bankName, _accountNumber, _ifsc, _branchName]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await widget.onSave({
      'bank_name': _bankName.text.trim(),
      'account_number': _accountNumber.text.trim(),
      'ifsc_code': _ifsc.text.trim(),
      'branch_name': _branchName.text.trim(),
      'account_type': _accountType,
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepFormWrapper(
      formKey: _formKey,
      saving: _saving,
      onSave: _handleSave,
      children: [
        TextFormField(
            controller: _bankName,
            decoration: _fieldDec('Bank Name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        const SizedBox(height: 16),
        TextFormField(
            controller: _accountNumber,
            decoration: _fieldDec('Account Number'),
            keyboardType: TextInputType.number,
            obscureText: true,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        const SizedBox(height: 16),
        _fieldRow(
          TextFormField(
              controller: _ifsc,
              decoration: _fieldDec('IFSC Code'),
              textCapitalization: TextCapitalization.characters,
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
          _DropdownInput(
            label: 'Account Type',
            value: _accountType,
            items: const ['Savings', 'Current'],
            onChanged: (v) => setState(() => _accountType = v),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
            controller: _branchName,
            decoration: _fieldDec('Branch Name')),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFED7AA)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 16, color: Color(0xFFEA580C)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bank details are used for salary processing. Ensure all details are accurate.',
                  style: AppTextStyles.caption.copyWith(color: const Color(0xFFEA580C)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Step 3 — Emergency Contact ───────────────────────────────────────────

class _EmergencyStep extends StatefulWidget {
  const _EmergencyStep({required this.initial, required this.onSave});

  final OnboardingEmergencyEntity initial;
  final Future<String?> Function(Map<String, dynamic>) onSave;

  @override
  State<_EmergencyStep> createState() => _EmergencyStepState();
}

class _EmergencyStepState extends State<_EmergencyStep> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contactName;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  String? _relationship;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.initial;
    _contactName = TextEditingController(text: e.contactName ?? '');
    _phone = TextEditingController(text: e.phone ?? '');
    _email = TextEditingController(text: e.email ?? '');
    _address = TextEditingController(text: e.address ?? '');
    _relationship = e.relationship;
  }

  @override
  void dispose() {
    for (final c in [_contactName, _phone, _email, _address]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final err = await widget.onSave({
      'contact_name': _contactName.text.trim(),
      'relationship': _relationship,
      'phone': _phone.text.trim(),
      'email': _email.text.trim(),
      'address': _address.text.trim(),
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(err), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _StepFormWrapper(
      formKey: _formKey,
      saving: _saving,
      onSave: _handleSave,
      children: [
        TextFormField(
            controller: _contactName,
            decoration: _fieldDec('Contact Name'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        const SizedBox(height: 16),
        _DropdownInput(
          label: 'Relationship',
          value: _relationship,
          items: const [
            'Spouse', 'Parent', 'Sibling', 'Child', 'Friend', 'Other'
          ],
          onChanged: (v) => setState(() => _relationship = v),
        ),
        const SizedBox(height: 16),
        TextFormField(
            controller: _phone,
            decoration: _fieldDec('Phone Number'),
            keyboardType: TextInputType.phone,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null),
        const SizedBox(height: 16),
        TextFormField(
            controller: _email,
            decoration: _fieldDec('Email Address'),
            keyboardType: TextInputType.emailAddress),
        const SizedBox(height: 16),
        TextFormField(
            controller: _address,
            decoration: _fieldDec('Address'),
            maxLines: 3),
      ],
    );
  }
}

// ─── Step 4 — Documents ───────────────────────────────────────────────────

const List<Map<String, String>> kDocTypes = [
  {'value': 'aadhaar', 'label': 'Aadhaar Card'},
  {'value': 'pan', 'label': 'PAN Card'},
  {'value': 'photo', 'label': 'Passport Photo'},
  {'value': 'resume', 'label': 'Resume / CV'},
  {'value': 'certificate', 'label': 'Education Certificate'},
  {'value': 'other', 'label': 'Other Document'},
];

class _DocumentsStep extends StatefulWidget {
  const _DocumentsStep({
    required this.documents,
    required this.onUpload,
    required this.onDelete,
    required this.onSubmit,
  });

  final List<OnboardingDocEntity> documents;
  final Future<String?> Function(String docType) onUpload;
  final Future<String?> Function(int id) onDelete;
  final Future<void> Function() onSubmit;

  @override
  State<_DocumentsStep> createState() => _DocumentsStepState();
}

class _DocumentsStepState extends State<_DocumentsStep> {
  bool _submitting = false;

  Future<void> _handleSubmit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit Profile?'),
        content: const Text(
          'Once submitted, your profile will be reviewed by HR. You cannot edit it after submission.',
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

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Upload required documents to complete your profile.',
            style:
                AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),
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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _handleSubmit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_submitting ? 'Submitting...' : 'Submit Profile'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.description_outlined,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                  child: Text(label,
                      style: AppTextStyles.label
                          .copyWith(fontWeight: FontWeight.w600))),
              TextButton.icon(
                onPressed: onUpload,
                icon: const Icon(Icons.upload_rounded, size: 16),
                label: const Text('Upload'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          if (uploaded.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...uploaded.map(
              (doc) => _UploadedDocRow(doc: doc, onDelete: onDelete),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadedDocRow extends StatelessWidget {
  const _UploadedDocRow({required this.doc, required this.onDelete});

  final OnboardingDocEntity doc;
  final Future<String?> Function(int id) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: Color(0xFF22C55E), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              doc.fileName.isNotEmpty ? doc.fileName : 'Uploaded',
              style: AppTextStyles.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () async {
              final err = await onDelete(doc.id);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err)));
              }
            },
            child: const Icon(Icons.close, size: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Shared step form wrapper ──────────────────────────────────────────────

class _StepFormWrapper extends StatelessWidget {
  const _StepFormWrapper({
    required this.formKey,
    required this.saving,
    required this.onSave,
    required this.children,
  });

  final GlobalKey<FormState> formKey;
  final bool saving;
  final VoidCallback onSave;
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
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Save & Continue',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

part of 'add_candidate_sheet.dart';

InputDecoration _inputDec(String? hint) => InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.error)),
    );

class _AddCandidateFormContent extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController emailCtrl;
  final TextEditingController posCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController notesCtrl;
  final int? selectedBranch;
  final List<Map<String, dynamic>> branches;
  final bool branchLocked;
  final String mode;
  final DateTime? interviewDate;
  final DateTime? originalInterviewDate;
  final bool isEdit;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final ValueChanged<int?> onBranchChanged;
  final ValueChanged<String?> onModeChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final ScrollController scrollCtrl;

  const _AddCandidateFormContent({
    required this.formKey,
    required this.nameCtrl,
    required this.emailCtrl,
    required this.posCtrl,
    required this.phoneCtrl,
    required this.notesCtrl,
    required this.selectedBranch,
    required this.branches,
    this.branchLocked = false,
    required this.mode,
    required this.interviewDate,
    this.originalInterviewDate,
    this.isEdit = false,
    required this.loading,
    required this.onSubmit,
    required this.onCancel,
    required this.onBranchChanged,
    required this.onModeChanged,
    required this.onDateChanged,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          _row(
            _field('Full Name *', nameCtrl,
                hint: 'e.g. Anjali Sharma',
                validator: FormValidators.candidateName,
                sanitize: FormValidators.sanitizeCandidateName),
            _field('Email Address *', emailCtrl,
                hint: 'anjali@gmail.com',
                keyboardType: TextInputType.emailAddress,
                required: true,
                enabled: !isEdit,
                validator: FormValidators.email),
          ),
          const SizedBox(height: 14),
          _row(
            _field('Position Applied *', posCtrl,
                hint: 'e.g. Backend Engineer',
                validator: FormValidators.candidatePosition,
                sanitize: FormValidators.sanitizeCandidatePosition),
            _field('Phone', phoneCtrl,
                hint: '+91 98765 43210',
                keyboardType: TextInputType.phone,
                validator: FormValidators.candidatePhone,
                sanitize: FormValidators.sanitizeCandidatePhone),
          ),
          const SizedBox(height: 14),
          _branchDropdown(context),
          const SizedBox(height: 14),
          _row(_datePicker(context), _modePicker()),
          const SizedBox(height: 14),
          _notesField(),
          const SizedBox(height: 20),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _row(Widget left, Widget right) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 12),
          Expanded(child: right),
        ],
      );

  static TextStyle get _labelStyle => AppTextStyles.labelSmall
      .copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600);

  Widget _field(String label, TextEditingController ctrl,
      {String? hint,
      TextInputType? keyboardType,
      bool required = false,
      bool enabled = true,
      String? Function(String?)? validator,
      String Function(String)? sanitize}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: _labelStyle),
      const SizedBox(height: 6),
      TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        enabled: enabled,
        style: AppTextStyles.bodySmall,
        validator: validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null),
        onChanged: sanitize == null
            ? null
            : (v) {
                final cleaned = sanitize(v);
                if (cleaned != v) {
                  ctrl.value = ctrl.value.copyWith(
                    text: cleaned,
                    selection: TextSelection.collapsed(offset: cleaned.length),
                  );
                }
              },
        decoration: _inputDec(hint),
      ),
    ]);
  }

  Widget _branchDropdown(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Branch *', style: _labelStyle),
        if (branchLocked) ...[
          const SizedBox(width: 6),
          Icon(Icons.lock_outline, size: 12, color: AppColors.textHint),
        ],
      ]),
      const SizedBox(height: 6),
      IgnorePointer(
        ignoring: branchLocked,
        child: Opacity(
          opacity: branchLocked ? 0.6 : 1,
          child: _DropdownField<int>(
            value: selectedBranch,
            hint: '— Select branch —',
            items: branches
                .map((b) => DropdownMenuItem<int>(
                      value: b['id'] as int,
                      child: Text(b['name'] as String,
                          style: AppTextStyles.bodySmall),
                    ))
                .toList(),
            onChanged: onBranchChanged,
          ),
        ),
      ),
    ]);
  }

  Widget _datePicker(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Interview Date', style: _labelStyle),
      const SizedBox(height: 6),
      GestureDetector(
        onTap: () async {
          final today = DateTime.now();
          final todayDateOnly = DateTime(today.year, today.month, today.day);
          // Edit: the picker's floor stays at the existing interview date (if
          // it's already in the past) so re-saving an already-past interview
          // doesn't force the user through an impossible "pick a future date"
          // step — only *changing* to a new past date is blocked (validated
          // on submit via FormValidators.interviewDate).
          final floor = isEdit && originalInterviewDate != null && originalInterviewDate!.isBefore(todayDateOnly)
              ? originalInterviewDate!
              : todayDateOnly;
          final picked = await showDatePicker(
            context: context,
            initialDate: interviewDate ?? todayDateOnly,
            firstDate: floor,
            lastDate: DateTime(2030),
          );
          if (picked != null) onDateChanged(picked);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(8),
            color: AppColors.surface,
          ),
          child: Row(children: [
            Icon(Icons.calendar_today_outlined,
                size: 14, color: AppColors.textHint),
            const SizedBox(width: 8),
            Text(
              interviewDate == null
                  ? 'dd/mm/yyyy'
                  : '${interviewDate!.day}/${interviewDate!.month}/${interviewDate!.year}',
              style: AppTextStyles.bodySmall.copyWith(
                  color: interviewDate == null
                      ? AppColors.textHint
                      : AppColors.textPrimary),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _modePicker() {
    const modes = {
      'in_person': 'In-Person',
      'phone': 'Phone',
      'video_call': 'Video Call',
    };
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Interview Mode', style: _labelStyle),
      const SizedBox(height: 6),
      _DropdownField<String>(
        value: mode,
        items: modes.entries
            .map((e) => DropdownMenuItem(
                  value: e.key,
                  child: Text(e.value, style: AppTextStyles.bodySmall),
                ))
            .toList(),
        onChanged: onModeChanged,
      ),
    ]);
  }

  Widget _notesField() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Notes', style: _labelStyle),
      const SizedBox(height: 6),
      TextFormField(
        controller: notesCtrl,
        maxLines: 3,
        style: AppTextStyles.bodySmall,
        decoration: _inputDec('Any notes about this candidate...'),
      ),
    ]);
  }

  Widget _buildActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onCancel,
            child: const Text('Cancel'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: loading ? null : onSubmit,
            icon: loading
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check, size: 16),
            label: Text(isEdit ? 'Save Changes' : 'Add to List'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

// Avoids the deprecated `value` on DropdownButtonFormField.
class _DropdownField<T> extends StatelessWidget {
  final T? value;
  final String? hint;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  const _DropdownField({
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButton<T>(
        value: value,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        hint: hint != null
            ? Text(hint!,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textHint))
            : null,
        items: items,
        onChanged: onChanged,
      ),
    );
  }
}

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../documents/presentation/widgets/document_file_picker.dart';
import '../../domain/entities/separation_entity.dart';
import '../providers/separation_providers.dart';
import 'employee_picker_field.dart';

// Must match backend SeparationRequestCreateSerializer.validate_document.
const _kMaxDocBytes = 5 * 1024 * 1024;
const _kAllowedDocExtensions = ['pdf', 'jpg', 'jpeg', 'png'];

/// Opens the create/edit Separation request form. Pass [existing] to edit an
/// already-filed (still-pending) request in place — mirrors web's
/// SeparationFormModal. Returns true if a request was created/updated.
Future<bool?> showSeparationFormSheet(
  BuildContext context, {
  SeparationRequestEntity? existing,
  bool canPickEmployee = false,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => SeparationFormSheet(
      existing: existing,
      canPickEmployee: canPickEmployee,
    ),
  );
}

class SeparationFormSheet extends ConsumerStatefulWidget {
  final SeparationRequestEntity? existing;
  final bool canPickEmployee;
  const SeparationFormSheet({
    super.key,
    this.existing,
    this.canPickEmployee = false,
  });

  @override
  ConsumerState<SeparationFormSheet> createState() =>
      _SeparationFormSheetState();
}

class _SeparationFormSheetState extends ConsumerState<SeparationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _noticeCtrl = TextEditingController(text: '30');
  final _commentsCtrl = TextEditingController();

  String? _separationType;
  String? _reason;
  DateTime? _requestDate;
  DateTime? _lastWorkingDay;
  EmployeePickerOption? _employee;
  PlatformFile? _pickedDoc;
  String? _docError;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _separationType = e.separationType;
      _reason = e.reason;
      _requestDate = DateTime.tryParse(e.requestDate);
      _lastWorkingDay = DateTime.tryParse(e.proposedLastWorkingDay);
      _noticeCtrl.text = e.noticePeriodDays.toString();
      _commentsCtrl.text = e.comments;
    } else {
      _requestDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _noticeCtrl.dispose();
    _commentsCtrl.dispose();
    super.dispose();
  }

  String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool isLastWorkingDay}) async {
    final initial = isLastWorkingDay
        ? (_lastWorkingDay ?? _requestDate ?? DateTime.now())
        : (_requestDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isLastWorkingDay) {
        _lastWorkingDay = picked;
      } else {
        _requestDate = picked;
      }
    });
  }

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_separationType == null) {
      setState(() => _error = 'Please select a separation type.');
      return;
    }
    if (_reason == null) {
      setState(() => _error = 'Please select a reason.');
      return;
    }
    if (_requestDate == null) {
      setState(() => _error = 'Request date is required.');
      return;
    }
    if (_lastWorkingDay == null) {
      setState(() => _error = 'Proposed last working day is required.');
      return;
    }
    if (_lastWorkingDay!.isBefore(_requestDate!)) {
      setState(() =>
          _error = 'Last working day cannot be earlier than the request date.');
      return;
    }
    final notice = int.tryParse(_noticeCtrl.text.trim());
    if (notice == null || notice < 0) {
      setState(() => _error = 'Enter a valid number of days.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final actions = ref.read(separationActionsProvider);
    final err = _isEdit
        ? await actions.updateRequest(
            id: widget.existing!.id,
            separationType: _separationType!,
            reason: _reason!,
            requestDate: _iso(_requestDate!),
            proposedLastWorkingDay: _iso(_lastWorkingDay!),
            noticePeriodDays: notice,
            comments: _commentsCtrl.text.trim(),
            document: _pickedDoc,
          )
        : await actions.createRequest(
            separationType: _separationType!,
            reason: _reason!,
            requestDate: _iso(_requestDate!),
            proposedLastWorkingDay: _iso(_lastWorkingDay!),
            noticePeriodDays: notice,
            comments: _commentsCtrl.text.trim(),
            employeeId: _employee?.code,
            document: _pickedDoc,
          );

    if (!mounted) return;
    setState(() => _loading = false);
    if (err == null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _error = err);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typesAsync = ref.watch(separationTypesProvider);
    final reasonsAsync = ref.watch(separationReasonsProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.92),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.logout_outlined,
                          size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _isEdit ? 'Edit Separation Request' : 'Request Separation',
                        style: AppTextStyles.h4.copyWith(fontSize: 15),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.border),

              // Body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_error != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(_error!,
                                style: AppTextStyles.caption
                                    .copyWith(color: AppColors.error)),
                          ),
                          const SizedBox(height: 12),
                        ],

                        if (widget.canPickEmployee && !_isEdit) ...[
                          Text('Employee',
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.textSecondary)),
                          const SizedBox(height: 6),
                          EmployeePickerField(
                            value: _employee,
                            onChanged: (e) => setState(() => _employee = e),
                          ),
                          const SizedBox(height: 14),
                        ],

                        Text('Separation Type *',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        typesAsync.when(
                          data: (types) => DropdownButtonFormField<String>(
                            initialValue: _separationType,
                            items: types
                                .map((t) => DropdownMenuItem(
                                    value: t.value, child: Text(t.label)))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _separationType = v),
                            decoration: const InputDecoration(
                                hintText: 'Select separation type'),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => Text('Could not load types.',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.error)),
                        ),
                        const SizedBox(height: 14),

                        Text('Reason *',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        reasonsAsync.when(
                          data: (reasons) => DropdownButtonFormField<String>(
                            initialValue: _reason,
                            items: reasons
                                .map((r) => DropdownMenuItem(
                                    value: r.value, child: Text(r.label)))
                                .toList(),
                            onChanged: (v) => setState(() => _reason = v),
                            decoration:
                                const InputDecoration(hintText: 'Select reason'),
                          ),
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => Text('Could not load reasons.',
                              style: AppTextStyles.caption
                                  .copyWith(color: AppColors.error)),
                        ),
                        const SizedBox(height: 14),

                        Text('Request Date *',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        _DateField(
                          value: _requestDate,
                          onTap: () => _pickDate(isLastWorkingDay: false),
                        ),
                        const SizedBox(height: 14),

                        Text('Proposed Last Working Day *',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        _DateField(
                          value: _lastWorkingDay,
                          onTap: () => _pickDate(isLastWorkingDay: true),
                        ),
                        if (_requestDate != null && _lastWorkingDay != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${_lastWorkingDay!.difference(_requestDate!).inDays} days from request date',
                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                            ),
                          ),
                        const SizedBox(height: 14),

                        AppTextField(
                          label: 'Notice Period (days) *',
                          controller: _noticeCtrl,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 14),

                        AppTextField(
                          label: 'Comments',
                          hint: 'Optional notes for the record…',
                          controller: _commentsCtrl,
                          keyboardType: TextInputType.multiline,
                          maxLines: 3,
                          textInputAction: TextInputAction.newline,
                        ),
                        const SizedBox(height: 14),

                        Text('Supporting Document',
                            style: AppTextStyles.label
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        DocumentFilePicker(
                          picked: _pickedDoc,
                          error: _docError,
                          onPick: _pickDocument,
                          hintText: 'PDF, JPG, or PNG — up to 5 MB',
                        ),
                        if (_isEdit && widget.existing?.documentUrl != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'A document is already attached. Choosing a new file replaces it.',
                              style: AppTextStyles.caption.copyWith(fontSize: 11),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: SafeArea(
                  top: false,
                  child: AppButton(
                    label: _isEdit ? 'Save Changes' : 'Submit Request',
                    isLoading: _loading,
                    onPressed: _submit,
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

class _DateField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  const _DateField({required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(
              value == null
                  ? 'Select date'
                  : '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}',
              style: AppTextStyles.body.copyWith(
                color:
                    value == null ? AppColors.textHint : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

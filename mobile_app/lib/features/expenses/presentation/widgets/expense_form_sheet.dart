import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// ── Category options ──────────────────────────────────────────────────────────

class _CategoryOpt {
  final String  value;
  final String  label;
  final IconData icon;
  const _CategoryOpt(this.value, this.label, this.icon);
}

const _kCategories = [
  _CategoryOpt('travel',    'Travel',    Icons.flight_takeoff_outlined),
  _CategoryOpt('meals',     'Meals',     Icons.restaurant_outlined),
  _CategoryOpt('equipment', 'Equipment', Icons.computer_outlined),
  _CategoryOpt('other',     'Other',     Icons.more_horiz_outlined),
];

// ── Attached file ─────────────────────────────────────────────────────────────

class _PickedFile {
  final String name;
  final int    size;
  final String path;
  const _PickedFile({required this.name, required this.size, required this.path});
}

// ── Callback typedef ──────────────────────────────────────────────────────────

typedef SubmitCallback = Future<String?> Function({
  required String title,
  required String amount,
  required String category,
  required String expenseDate,
  required String description,
  required List<MultipartFile> receipts,
});

// ── Form sheet ────────────────────────────────────────────────────────────────

class ExpenseFormSheet extends StatefulWidget {
  final SubmitCallback onSubmit;
  const ExpenseFormSheet({super.key, required this.onSubmit});

  @override
  State<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<ExpenseFormSheet> {
  final _titleCtrl  = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descCtrl   = TextEditingController();

  String?            _category;
  DateTime?          _expenseDate;
  List<_PickedFile>  _pickedFiles = [];
  bool               _submitting  = false;
  String?            _submitError;
  Map<String, String?> _errors    = {};

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Date picker ─────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _expenseDate ?? now,
      firstDate:   now.subtract(const Duration(days: 365)),
      lastDate:    now,
      builder:     (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _expenseDate = picked;
        _errors = {..._errors, 'date': null};
      });
    }
  }

  // ── File picker ─────────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    const maxBytes = 5 * 1024 * 1024;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple:     true,
      type:              FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null) return;
    final sizeErrors = <String>[];
    final valid      = <_PickedFile>[];
    for (final pf in result.files) {
      if (pf.path == null) continue;
      if (pf.size > maxBytes) {
        sizeErrors.add('"${pf.name}" exceeds 5 MB.');
        continue;
      }
      valid.add(_PickedFile(name: pf.name, size: pf.size, path: pf.path!));
    }
    setState(() {
      _pickedFiles = [..._pickedFiles, ...valid];
      _errors = {
        ..._errors,
        'receipt': sizeErrors.isNotEmpty ? sizeErrors.join(' ') : null,
      };
    });
  }

  void _removeFile(int index) {
    setState(() => _pickedFiles = [
      ..._pickedFiles.sublist(0, index),
      ..._pickedFiles.sublist(index + 1),
    ]);
  }

  // ── Validation ──────────────────────────────────────────────────────────────

  bool _validate() {
    final errs = <String, String?>{};
    if (_titleCtrl.text.trim().isEmpty) {
      errs['title'] = 'Expense title is required.';
    }
    if (_amountCtrl.text.isEmpty) {
      errs['amount'] = 'Amount is required.';
    } else if ((double.tryParse(_amountCtrl.text) ?? 0) <= 0) {
      errs['amount'] = 'Amount must be greater than zero.';
    }
    if (_category == null)    errs['category'] = 'Please select a category.';
    if (_expenseDate == null) errs['date']     = 'Date is required.';
    if (_pickedFiles.isEmpty) errs['receipt']  = 'At least one receipt is required.';
    setState(() => _errors = errs);
    return errs.values.every((v) => v == null);
  }

  // ── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() { _submitting = true; _submitError = null; });

    final d       = _expenseDate!;
    final dateStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

    final multipartFiles = <MultipartFile>[];
    for (final pf in _pickedFiles) {
      multipartFiles.add(await MultipartFile.fromFile(pf.path, filename: pf.name));
    }

    final err = await widget.onSubmit(
      title:       _titleCtrl.text,
      amount:      _amountCtrl.text,
      category:    _category!,
      expenseDate: dateStr,
      description: _descCtrl.text,
      receipts:    multipartFiles,
    );

    if (!mounted) return;
    if (err != null) {
      setState(() { _submitting = false; _submitError = err; });
    } else {
      Navigator.of(context).pop(true);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _fmtDate(DateTime d) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${months[d.month]} ${d.year}';
  }

  String _fmtSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Submit New Expense',
                    style: AppTextStyles.h4.copyWith(fontSize: 16)),
                const Spacer(),
                IconButton(
                  icon:            const Icon(Icons.close, size: 20),
                  onPressed:       () => Navigator.of(context).pop(),
                  visualDensity:   VisualDensity.compact,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // Scrollable body
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                mainAxisSize:       MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_submitError != null) ...[
                    _ErrorBanner(message: _submitError!),
                    const SizedBox(height: 12),
                  ],

                  // Title
                  const _FieldLabel(text: 'Expense Title', required: true),
                  const SizedBox(height: 6),
                  TextField(
                    controller:         _titleCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (_) =>
                        setState(() => _errors = {..._errors, 'title': null}),
                    decoration: _inputDecor(
                      hint:     'e.g. Client visit to Mumbai',
                      hasError: _errors['title'] != null,
                    ),
                  ),
                  if (_errors['title'] != null) _ErrMsg(_errors['title']!),
                  const SizedBox(height: 14),

                  // Amount + Category row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildAmountField()),
                      const SizedBox(width: 10),
                      Expanded(child: _buildCategoryField()),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Date
                  const _FieldLabel(text: 'Date', required: true),
                  const SizedBox(height: 6),
                  _buildDateField(),
                  if (_errors['date'] != null) _ErrMsg(_errors['date']!),
                  const SizedBox(height: 14),

                  // Description
                  const _FieldLabel(text: 'Description'),
                  const SizedBox(height: 6),
                  TextField(
                    controller:         _descCtrl,
                    maxLines:           3,
                    maxLength:          500,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:         _inputDecor(
                      hint:    'Optional notes about this expense…',
                      hasError: false,
                      counter: true,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Receipts
                  Row(
                    children: [
                      const _FieldLabel(text: 'Receipts', required: true),
                      const SizedBox(width: 6),
                      Text('(at least one required)',
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 10, color: AppColors.textHint)),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Attached file list
                  if (_pickedFiles.isNotEmpty) ...[
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(_pickedFiles.length, (i) {
                        final pf = _pickedFiles[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color:        AppColors.backgroundLow,
                            borderRadius: BorderRadius.circular(8),
                            border:       Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.insert_drive_file_outlined,
                                  size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(pf.name,
                                    style: AppTextStyles.caption.copyWith(
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              const SizedBox(width: 8),
                              Text(_fmtSize(pf.size),
                                  style: AppTextStyles.caption.copyWith(
                                      fontSize: 10, color: AppColors.textHint)),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _removeFile(i),
                                child: const Icon(Icons.close,
                                    size: 14, color: AppColors.error),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Upload zone
                  GestureDetector(
                    onTap: _pickFiles,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width:    double.infinity,
                      padding:  const EdgeInsets.symmetric(vertical: 22),
                      decoration: BoxDecoration(
                        color: _errors['receipt'] != null
                            ? AppColors.error.withValues(alpha: 0.04)
                            : AppColors.backgroundLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _errors['receipt'] != null
                              ? AppColors.error
                              : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_upload_outlined,
                            size:  28,
                            color: _errors['receipt'] != null
                                ? AppColors.error
                                : AppColors.textHint,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _pickedFiles.isNotEmpty
                                ? 'Add more receipts'
                                : 'Tap to upload receipts',
                            style: AppTextStyles.caption.copyWith(
                              fontSize:   12,
                              fontWeight: FontWeight.w600,
                              color:      _errors['receipt'] != null
                                  ? AppColors.error
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text('PDF, JPG, PNG · Max 5 MB each',
                              style: AppTextStyles.caption.copyWith(
                                  fontSize: 10, color: AppColors.textHint)),
                        ],
                      ),
                    ),
                  ),
                  if (_errors['receipt'] != null) ...[
                    const SizedBox(height: 4),
                    _ErrMsg(_errors['receipt']!),
                  ],
                  const SizedBox(height: 14),

                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:        AppColors.info.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:       Border.all(
                          color: AppColors.info.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            size: 14, color: AppColors.info),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Your expense will be sent for approval. '
                            'Approved expenses are reimbursed in the next payroll cycle.',
                            style: AppTextStyles.caption.copyWith(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: const BoxDecoration(
              color:  AppColors.surface,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textSecondary,
                      side:    const BorderSide(color: AppColors.border),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_outlined, size: 16),
                    label: Text(
                      _submitting ? 'Submitting…' : 'Submit Expense',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Field builders ────────────────────────────────────────────────────────

  Widget _buildAmountField() {
    return Column(
      mainAxisSize:       MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'Amount (₹)', required: true),
        const SizedBox(height: 6),
        TextField(
          controller:      _amountCtrl,
          keyboardType:    const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          onChanged: (_) =>
              setState(() => _errors = {..._errors, 'amount': null}),
          decoration: _inputDecor(
            hint:     '0.00',
            hasError: _errors['amount'] != null,
          ),
        ),
        if (_errors['amount'] != null) _ErrMsg(_errors['amount']!),
      ],
    );
  }

  Widget _buildCategoryField() {
    final selected = _category != null
        ? _kCategories.firstWhere((c) => c.value == _category)
        : null;
    return Column(
      mainAxisSize:       MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(text: 'Category', required: true),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: _showCategoryPicker,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: _errors['category'] != null
                  ? AppColors.error.withValues(alpha: 0.05)
                  : AppColors.backgroundLow,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _errors['category'] != null
                    ? AppColors.error
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selected?.label ?? 'Select…',
                    style: AppTextStyles.caption.copyWith(
                      fontSize:   13,
                      color:      selected != null
                          ? AppColors.textPrimary
                          : AppColors.textHint,
                      fontWeight: selected != null
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                const Icon(Icons.expand_more,
                    size: 16, color: AppColors.textHint),
              ],
            ),
          ),
        ),
        if (_errors['category'] != null) _ErrMsg(_errors['category']!),
      ],
    );
  }

  Widget _buildDateField() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: _errors['date'] != null
              ? AppColors.error.withValues(alpha: 0.05)
              : AppColors.backgroundLow,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: _errors['date'] != null ? AppColors.error : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size:  14,
              color: _expenseDate != null ? AppColors.primary : AppColors.textHint,
            ),
            const SizedBox(width: 8),
            Text(
              _expenseDate != null ? _fmtDate(_expenseDate!) : 'Select date',
              style: AppTextStyles.caption.copyWith(
                fontSize:   13,
                color:      _expenseDate != null
                    ? AppColors.textPrimary
                    : AppColors.textHint,
                fontWeight: _expenseDate != null
                    ? FontWeight.w600
                    : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category picker sheet ─────────────────────────────────────────────────

  void _showCategoryPicker() {
    showModalBottomSheet<void>(
      context:         context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
                color: AppColors.border, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('Select Category', style: AppTextStyles.label),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.border),
          ...List.generate(_kCategories.length, (i) {
            final opt        = _kCategories[i];
            final isSelected = _category == opt.value;
            return InkWell(
              onTap: () {
                setState(() {
                  _category = opt.value;
                  _errors   = {..._errors, 'category': null};
                });
                Navigator.of(context).pop();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.10)
                            : AppColors.backgroundLow,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(opt.icon,
                          size:  17,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(opt.label,
                          style: AppTextStyles.caption.copyWith(
                            fontSize:   13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color:      isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          )),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          size: 18, color: AppColors.primary),
                  ],
                ),
              ),
            );
          }),
          Builder(
            builder: (ctx) => SizedBox(
              height: MediaQuery.of(ctx).padding.bottom + 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

InputDecoration _inputDecor({
  required String hint,
  required bool   hasError,
  bool            counter = false,
}) {
  return InputDecoration(
    hintText:    hint,
    counterText: counter ? null : '',
    filled:      true,
    fillColor:   hasError
        ? AppColors.error.withValues(alpha: 0.05)
        : AppColors.backgroundLow,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:   BorderSide(color: hasError ? AppColors.error : AppColors.border),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:   BorderSide(color: hasError ? AppColors.error : AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide:   BorderSide(
          color: hasError ? AppColors.error : AppColors.primary, width: 1.5),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool   required;
  const _FieldLabel({required this.text, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: AppTextStyles.caption.copyWith(
                color:         AppColors.textSecondary,
                fontWeight:    FontWeight.w700,
                fontSize:      11,
                letterSpacing: 0.3)),
        if (required)
          const Text(' *',
              style: TextStyle(
                  color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _ErrMsg extends StatelessWidget {
  final String text;
  const _ErrMsg(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 12, color: AppColors.error),
          const SizedBox(width: 4),
          Expanded(
            child: Text(text,
                style: AppTextStyles.caption.copyWith(
                    fontSize: 10, color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppColors.error.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

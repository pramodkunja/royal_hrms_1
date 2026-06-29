import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/announcement_model.dart';
import '../providers/announcement_providers.dart';

class PostAnnouncementSheet extends ConsumerStatefulWidget {
  final AnnouncementModel? editing;
  final WidgetRef ref;

  const PostAnnouncementSheet({super.key, this.editing, required this.ref});

  @override
  ConsumerState<PostAnnouncementSheet> createState() =>
      _PostAnnouncementSheetState();
}

class _PostAnnouncementSheetState
    extends ConsumerState<PostAnnouncementSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late AnnouncementFormData _form;
  Map<String, String> _errors = {};
  bool _saving = false;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _form = widget.editing != null
        ? AnnouncementFormData.fromModel(widget.editing!)
        : AnnouncementFormData();
    _titleCtrl = TextEditingController(text: _form.title);
    _bodyCtrl  = TextEditingController(text: _form.body);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SheetHeader(
            isEdit: _isEdit,
            onClose: () => Navigator.pop(context),
          ),
          Container(
            color: AppColors.background,
            padding: EdgeInsets.fromLTRB(
                20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _field(
                    controller: _titleCtrl,
                    label: 'Title *',
                    error: _errors['title'],
                    onChanged: (_) => setState(() => _errors.remove('title')),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    controller: _bodyCtrl,
                    label: 'Body *',
                    error: _errors['body'],
                    maxLines: 4,
                    onChanged: (_) => setState(() => _errors.remove('body')),
                  ),
                  const SizedBox(height: 12),
                  _CategoryDropdown(
                    value: _form.category,
                    onChanged: (v) => setState(() => _form.category = v),
                  ),
                  const SizedBox(height: 12),
                  _VisibilityDropdown(
                    value: _form.visibility,
                    onChanged: (v) => setState(() {
                      _form.visibility        = v;
                      _form.targetDepartment  = null;
                      _form.targetBranch      = null;
                      _errors.remove('department');
                      _errors.remove('branch');
                    }),
                  ),
                  if (_form.visibility == 'department') ...[
                    const SizedBox(height: 12),
                    _DepartmentDropdown(
                      value: _form.targetDepartment,
                      error: _errors['department'],
                      onChanged: (v) => setState(() {
                        _form.targetDepartment = v;
                        _errors.remove('department');
                      }),
                    ),
                  ],
                  if (_form.visibility == 'branch') ...[
                    const SizedBox(height: 12),
                    _BranchDropdown(
                      value: _form.targetBranch,
                      error: _errors['branch'],
                      onChanged: (v) => setState(() {
                        _form.targetBranch = v;
                        _errors.remove('branch');
                      }),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _ToggleRow(
                    icon: Icons.push_pin_outlined,
                    label: 'Pin this announcement',
                    value: _form.isPinned,
                    onChanged: (v) => setState(() => _form.isPinned = v),
                  ),
                  const SizedBox(height: 8),
                  _ToggleRow(
                    icon: Icons.email_outlined,
                    label: 'Send email notification',
                    value: _form.sendEmail,
                    onChanged: (v) => setState(() => _form.sendEmail = v),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      backgroundColor: AppColors.primary,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.55),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            _isEdit ? 'Save Changes' : 'Post Announcement',
                            style: AppTextStyles.label
                                .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? error,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      style: AppTextStyles.body,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        labelStyle: AppTextStyles.caption,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Future<void> _submit() async {
    _form
      ..title = _titleCtrl.text
      ..body  = _bodyCtrl.text;

    final errs = _form.validate();
    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }

    setState(() => _saving = true);
    final notifier = widget.ref.read(announcementsProvider.notifier);
    final error = _isEdit
        ? await notifier.edit(widget.editing!.id, _form)
        : await notifier.create(_form);

    if (!mounted) return;
    setState(() => _saving = false);

    if (error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }
}

// ── Sheet header ──────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onClose;
  const _SheetHeader({required this.isEdit, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.campaign_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Announcement' : 'Post Announcement',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Company-wide news, policy updates, and celebrations',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
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

// ── Inline dropdowns ──────────────────────────────────────────────────────────

InputDecoration _dropDec(String label, [String? error]) => InputDecoration(
      labelText: label,
      errorText: error,
      labelStyle: AppTextStyles.caption,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );

class _CategoryDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CategoryDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      DropdownMenuItem(value: 'general',     child: Text('General')),
      DropdownMenuItem(value: 'policy',      child: Text('Policy')),
      DropdownMenuItem(value: 'event',       child: Text('Event')),
      DropdownMenuItem(value: 'celebration', child: Text('Celebration')),
    ];
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: (v) { if (v != null) onChanged(v); },
      decoration: _dropDec('Category'),
    );
  }
}

class _VisibilityDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _VisibilityDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    const items = [
      DropdownMenuItem(value: 'all',        child: Text('All Employees')),
      DropdownMenuItem(value: 'department', child: Text('Specific Department')),
      DropdownMenuItem(value: 'branch',     child: Text('Specific Branch')),
    ];
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: (v) { if (v != null) onChanged(v); },
      decoration: _dropDec('Visibility'),
    );
  }
}

class _DepartmentDropdown extends ConsumerWidget {
  final int? value;
  final String? error;
  final ValueChanged<int?> onChanged;
  const _DepartmentDropdown({this.value, this.error, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(announcementDepartmentsProvider);
    return deptsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (depts) => DropdownButtonFormField<int>(
        initialValue: value,
        items: depts.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))).toList(),
        onChanged: onChanged,
        decoration: _dropDec('Target Department *', error),
      ),
    );
  }
}

class _BranchDropdown extends ConsumerWidget {
  final int? value;
  final String? error;
  final ValueChanged<int?> onChanged;
  const _BranchDropdown({this.value, this.error, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(announcementBranchesProvider);
    return branchesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (branches) => DropdownButtonFormField<int>(
        initialValue: value,
        items: branches.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name))).toList(),
        onChanged: onChanged,
        decoration: _dropDec('Target Branch *', error),
      ),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow({required this.icon, required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: value ? AppColors.primary.withValues(alpha: 0.05) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value ? AppColors.primary.withValues(alpha: 0.30) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: value ? AppColors.primary : AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: AppTextStyles.label.copyWith(
              color: value ? AppColors.textPrimary : AppColors.textSecondary,
            )),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

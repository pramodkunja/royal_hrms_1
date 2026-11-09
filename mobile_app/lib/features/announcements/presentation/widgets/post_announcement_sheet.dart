import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/announcement_model.dart';
import '../announcement_permissions.dart';
import '../providers/announcement_providers.dart';

class PostAnnouncementSheet extends ConsumerStatefulWidget {
  final AnnouncementModel? editing;
  final WidgetRef ref;

  const PostAnnouncementSheet({super.key, this.editing, required this.ref});

  @override
  ConsumerState<PostAnnouncementSheet> createState() =>
      _PostAnnouncementSheetState();
}

class _PostAnnouncementSheetState extends ConsumerState<PostAnnouncementSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late AnnouncementFormData _form;
  Map<String, String> _errors = {};
  bool _saving = false;
  // Server / scope error from the last save, shown in the form (web saveErr);
  // every field keeps its value for a retry.
  String? _saveError;

  // Web form: the audience is "All Employees" or "By Department", plus a
  // Branch field — chosen by org-wide posters (null = All Branches), locked to
  // the poster's own branch for everyone else.
  late bool _byDepartment;
  int? _branchChoice;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    // Web openCreate: a new post starts with "Send email" on (send_email =
    // canPost); openEdit keeps the announcement's saved value.
    _form = widget.editing != null
        ? AnnouncementFormData.fromModel(widget.editing!)
        : AnnouncementFormData(
            sendEmail: canPostAnnouncements(ref.read(authStateProvider).valueOrNull?.user));
    _byDepartment = _form.visibility == 'department';
    // Web openEdit: an org-wide editor keeps the post's branch (if it was a
    // branch post); a branch-scoped one is always re-locked to their branch.
    _branchChoice = _form.visibility == 'branch' ? _form.targetBranch : null;
    _titleCtrl = TextEditingController(text: _form.title);
    _bodyCtrl = TextEditingController(text: _form.body);
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
            // Web disables Cancel while saving.
            onClose: _saving ? null : () => Navigator.pop(context),
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
                    _buildAudience(),
                    const SizedBox(height: 14),
                    _ToggleRow(
                      icon: Icons.push_pin_outlined,
                      label: 'Pin this announcement',
                      value: _form.isPinned,
                      onChanged: (v) => setState(() => _form.isPinned = v),
                    ),
                    const SizedBox(height: 8),
                    _ToggleRow(
                      key: const Key('announcement-send-email'),
                      icon: Icons.email_outlined,
                      label: 'Send email notification',
                      value: _form.sendEmail,
                      onChanged: (v) => setState(() => _form.sendEmail = v),
                    ),
                    if (_saveError != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        key: const Key('announcement-save-error'),
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(_saveError!,
                            style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                      ),
                    ],
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
                              style: AppTextStyles.label.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudience() {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final orgWide = isOrgWideAnnouncer(user);
    final branchesAsync = ref.watch(announcementBranchesProvider);
    final branches = branchesAsync.valueOrNull ?? const <BranchSimple>[];
    final ownId = announcementOwnBranchId(user, branches);
    final existing = widget.editing;
    // A branch-scoped editor of a post aimed elsewhere (company-wide or
    // another branch): saving limits it to their branch — say so up front.
    final narrowed = !orgWide &&
        existing != null &&
        existing.visibility != 'department' &&
        !_byDepartment &&
        !(existing.visibility == 'branch' && existing.targetBranch == ownId);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (orgWide)
        branchesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, __) => Text('Could not load branches.',
              style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          data: (list) => DropdownButtonFormField<int?>(
            key: const Key('announcement-branch'),
            initialValue: list.any((b) => b.id == _branchChoice) ? _branchChoice : null,
            isExpanded: true,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All Branches')),
              for (final b in list) DropdownMenuItem<int?>(value: b.id, child: Text(b.name)),
            ],
            onChanged: _byDepartment ? null : (v) => setState(() => _branchChoice = v),
            decoration: _dropDec('Branch *'),
          ),
        )
      else
        InputDecorator(
          key: const Key('announcement-branch-locked'),
          decoration: _dropDec('Branch'),
          child: Row(children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.textHint),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                branchesAsync.isLoading
                    ? 'Loading…'
                    : (ownId == null ? 'Not assigned' : branches.firstWhere((b) => b.id == ownId).name),
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ]),
        ),
      if (_byDepartment) ...[
        const SizedBox(height: 4),
        Text('Not used for "By Department" — that reaches the department across all branches.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
      ],
      if (narrowed) ...[
        const SizedBox(height: 4),
        Text('Saving will limit this announcement to your branch.',
            key: const Key('announcement-scope-note'),
            style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
      ],
      const SizedBox(height: 12),
      _VisibilityDropdown(
        value: _byDepartment ? 'department' : 'all',
        onChanged: (v) => setState(() {
          _byDepartment = v == 'department';
          if (!_byDepartment) _form.targetDepartment = null;
          _errors.remove('department');
        }),
      ),
      if (_byDepartment) ...[
        const SizedBox(height: 12),
        _DepartmentDropdown(
          branchFilter: orgWide ? null : user?.branch,
          value: _form.targetDepartment,
          error: _errors['department'],
          onChanged: (v) => setState(() {
            _form.targetDepartment = v;
            _errors.remove('department');
          }),
        ),
      ],
    ]);
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
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    _form
      ..title = _titleCtrl.text
      ..body = _bodyCtrl.text;

    // Web handleSave: department → department; else the branch (chosen, or
    // the poster's own) → branch; no branch → company-wide (org-wide only).
    final user = ref.read(authStateProvider).valueOrNull?.user;
    final orgWide = isOrgWideAnnouncer(user);
    final ownId = announcementOwnBranchId(user, ref.read(announcementBranchesProvider).valueOrNull ?? const []);
    applyAnnouncementAudience(_form, byDepartment: _byDepartment, branchId: orgWide ? _branchChoice : ownId);

    final errs = _form.validate();
    if (errs.isNotEmpty) {
      setState(() => _errors = errs);
      return;
    }
    // Never turn a branch-scoped post into a company-wide one.
    final scope = announcementScopeError(_form, user, ownBranchId: ownId);
    if (scope != null) {
      setState(() => _saveError = scope);
      return;
    }

    setState(() {
      _saving = true;
      _saveError = null;
    });
    final notifier = widget.ref.read(announcementsProvider.notifier);
    final error = _isEdit
        ? await notifier.edit(widget.editing!.id, _form)
        : await notifier.create(_form);

    if (!mounted) return;
    setState(() => _saving = false);

    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() => _saveError = error);
    }
  }
}

// ── Sheet header ──────────────────────────────────────────────────────────────

class _SheetHeader extends StatelessWidget {
  final bool isEdit;
  final VoidCallback? onClose;
  const _SheetHeader({required this.isEdit, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
      decoration: BoxDecoration(
        color: AppColors.primary,
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
            child: const Icon(Icons.campaign_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Edit Announcement' : 'Post Announcement',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
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
            key: const Key('announcement-close'),
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
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
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
      DropdownMenuItem(value: 'general', child: Text('General')),
      DropdownMenuItem(value: 'policy', child: Text('Policy')),
      DropdownMenuItem(value: 'event', child: Text('Event')),
      DropdownMenuItem(value: 'celebration', child: Text('Celebration')),
    ];
    return DropdownButtonFormField<String>(
      initialValue: value,
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
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
    // Web VISIBILITY_OPTIONS; branch targeting comes from the Branch field.
    const items = [
      DropdownMenuItem(value: 'all', child: Text('All Employees')),
      DropdownMenuItem(value: 'department', child: Text('By Department')),
    ];
    return DropdownButtonFormField<String>(
      key: const Key('announcement-visibility'),
      initialValue: value,
      items: items,
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
      decoration: _dropDec('Visibility'),
    );
  }
}

class _DepartmentDropdown extends ConsumerWidget {
  final String? branchFilter;
  final int? value;
  final String? error;
  final ValueChanged<int?> onChanged;
  const _DepartmentDropdown({this.branchFilter, this.value, this.error, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deptsAsync = ref.watch(announcementDepartmentsProvider(branchFilter));
    return deptsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (_, __) => const SizedBox.shrink(),
      data: (depts) => DropdownButtonFormField<int>(
        key: const Key('announcement-department'),
        initialValue: depts.any((d) => d.id == value) ? value : null,
        isExpanded: true,
        items: depts
            .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name)))
            .toList(),
        onChanged: onChanged,
        decoration: _dropDec('Target Department *', error),
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
  const _ToggleRow(
      {super.key,
      required this.icon,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: value
            ? AppColors.primary.withValues(alpha: 0.05)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: value
              ? AppColors.primary.withValues(alpha: 0.30)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18, color: value ? AppColors.primary : AppColors.textHint),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: AppTextStyles.label.copyWith(
                  color:
                      value ? AppColors.textPrimary : AppColors.textSecondary,
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

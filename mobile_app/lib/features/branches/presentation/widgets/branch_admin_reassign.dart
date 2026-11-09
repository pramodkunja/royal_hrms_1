import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/branch_model.dart' show BranchAdminCandidate;
import '../../domain/entities/branch_entity.dart';
import '../providers/branch_providers.dart';

/// Web View-branch "Branch Admin" block: the current admin (name + email from
/// the server) or "No Branch Admin assigned", and "Change Branch Admin" /
/// "Assign Branch Admin" for users allowed to reassign. There is no "remove":
/// the server only supports replacing the admin.
class BranchAdminSection extends ConsumerWidget {
  const BranchAdminSection({super.key, required this.branch, this.closeOnSuccess = true});
  final BranchEntity branch;

  /// True in the details sheet (web closes the View modal after a
  /// reassignment); false in the Edit Branch form, which web keeps open and
  /// shows the new admin from the reloaded list.
  final bool closeOnSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canReassign = canReassignBranchAdmin(ref.watch(authStateProvider).valueOrNull?.user);
    final b = branch;
    return Container(
      key: const Key('branch-admin-section'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Branch Admin',
            style: AppTextStyles.labelSmall
                .copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, letterSpacing: 0.4)),
        const SizedBox(height: 8),
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(
            child: b.hasHr
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.hrName!, key: const Key('branch-admin-name'), style: AppTextStyles.label),
                    if ((b.hrEmail ?? '').isNotEmpty)
                      Text(b.hrEmail!,
                          key: const Key('branch-admin-email'), style: AppTextStyles.caption.copyWith(fontSize: 12)),
                  ])
                : Text('No Branch Admin assigned',
                    key: const Key('branch-admin-none'), style: AppTextStyles.bodySecondary.copyWith(fontSize: 13)),
          ),
          if (canReassign)
            OutlinedButton.icon(
              key: const Key('branch-admin-reassign'),
              onPressed: () async {
                final done = await showReassignBranchAdminSheet(context, b);
                // Web closes the View modal after a successful reassignment.
                if (closeOnSuccess && done == true && context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.swap_horiz, size: 16),
              label: Text(b.hasHr ? 'Change Branch Admin' : 'Assign Branch Admin'),
            ),
        ]),
      ]),
    );
  }
}

/// Returns true when the admin was reassigned (the caller closes the details).
Future<bool?> showReassignBranchAdminSheet(BuildContext context, BranchEntity branch) => showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      builder: (_) => ReassignBranchAdminSheet(branch: branch),
    );

/// Web reassign modal: pick an eligible employee, then an explicit confirm.
class ReassignBranchAdminSheet extends ConsumerStatefulWidget {
  const ReassignBranchAdminSheet({super.key, required this.branch});
  final BranchEntity branch;

  @override
  ConsumerState<ReassignBranchAdminSheet> createState() => _ReassignBranchAdminSheetState();
}

class _ReassignBranchAdminSheetState extends ConsumerState<ReassignBranchAdminSheet> {
  final _search = TextEditingController();
  String? _selectedCode;
  bool _confirming = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _reassign(BranchAdminCandidate newAdmin) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref.read(branchListProvider.notifier).reassignAdmin(widget.branch.id, newAdmin.code);
    if (!mounted) return;
    if (result == null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(SnackBar(
        content: Text('Branch Admin for ${widget.branch.branchName} was reassigned successfully.'),
        backgroundColor: AppColors.success,
      ));
    } else {
      setState(() {
        _saving = false;
        _error = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.branch;
    final async = ref.watch(branchAdminCandidatesProvider(b.hrEmail));
    final candidates = async.valueOrNull ?? const <BranchAdminCandidate>[];
    final selected = candidates.where((c) => c.code == _selectedCode).firstOrNull;

    Widget body;
    if (_confirming && selected != null) {
      const bold = TextStyle(fontWeight: FontWeight.w700);
      body = Text.rich(
        key: const Key('reassign-confirm-text'),
        TextSpan(
          children: b.hasHr
              ? [
                  const TextSpan(text: 'This will remove Branch Admin access from '),
                  TextSpan(text: b.hrName, style: bold),
                  const TextSpan(
                      text: ' (their attendance, leave, payroll, and other historical records will not be affected) '
                          'and assign it to '),
                  TextSpan(text: selected.fullName, style: bold),
                  const TextSpan(text: ' for '),
                  TextSpan(text: b.branchName, style: bold),
                  const TextSpan(text: '.'),
                ]
              : [
                  const TextSpan(text: 'This will assign '),
                  TextSpan(text: selected.fullName, style: bold),
                  const TextSpan(text: ' as Branch Admin for '),
                  TextSpan(text: b.branchName, style: bold),
                  const TextSpan(text: '.'),
                ],
        ),
        style: AppTextStyles.body.copyWith(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
      );
    } else if (async.isLoading && !async.hasValue) {
      body = const Padding(
        key: Key('reassign-loading'),
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else {
      // Web: a failed load just leaves the list empty.
      final shown = candidates.where((c) => c.matches(_search.text)).toList();
      body = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          key: const Key('reassign-search'),
          controller: _search,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
              hintText: 'Search by name, email, or employee ID…',
              prefixIcon: Icon(Icons.search, size: 18),
              isDense: true),
        ),
        const SizedBox(height: 8),
        if (candidates.isEmpty)
          Text(
              'No eligible employees found. An employee must be active and have completed onboarding to become '
              'Branch Admin.',
              key: const Key('reassign-empty'),
              style: AppTextStyles.caption.copyWith(fontSize: 12))
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
            child: RadioGroup<String>(
              groupValue: _selectedCode,
              onChanged: (v) => setState(() => _selectedCode = v),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final c in shown)
                    RadioListTile<String>(
                      key: Key('reassign-option-${c.code}'),
                      dense: true,
                      value: c.code,
                      title: Text(c.label, style: AppTextStyles.body.copyWith(fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),
      ]);
    }

    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SafeArea(
          child: Padding(
            key: const Key('reassign-sheet'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(_confirming ? 'Confirm Reassignment' : 'Change Branch Admin — ${b.branchName}',
                  style: AppTextStyles.h4, maxLines: 2, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Container(
                  key: const Key('reassign-error'),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.errorContainer, borderRadius: BorderRadius.circular(8)),
                  child: Text(_error!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
                ),
                const SizedBox(height: 10),
              ],
              Flexible(child: SingleChildScrollView(child: body)),
              const SizedBox(height: 12),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                if (_confirming) ...[
                  TextButton(
                    key: const Key('reassign-back'),
                    onPressed: _saving ? null : () => setState(() => _confirming = false),
                    child: const Text('Back'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('reassign-confirm'),
                    onPressed: _saving || selected == null ? null : () => _reassign(selected),
                    child: Text(_saving ? 'Reassigning…' : 'Yes, Reassign'),
                  ),
                ] else ...[
                  TextButton(
                    key: const Key('reassign-cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: const Key('reassign-continue'),
                    onPressed: selected == null ? null : () => setState(() => _confirming = true),
                    child: const Text('Continue'),
                  ),
                ],
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

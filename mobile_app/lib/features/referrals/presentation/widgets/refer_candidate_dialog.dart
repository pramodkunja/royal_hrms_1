import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/validators/form_validators.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../branches/presentation/widgets/branch_dlg_header.dart';
import '../providers/referral_providers.dart';

// Matches web's RELATIONSHIP_OPTIONS exactly (frontend/app/dashboard/referrals/page.tsx).
const _kRelationshipOptions = [
  'Friend / Acquaintance',
  'Former Colleague',
  'Professional Contact',
  'Family Member',
  'Ex-Employee at Previous Company',
  'Other',
];

/// Shows the "Refer Someone" form as a centered dialog (matches the app's
/// existing dialog-form convention, e.g. BranchFormDialog). Returns true if
/// a referral was submitted successfully.
Future<bool?> showReferCandidateDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (_) => const Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ReferCandidateDialog(),
    ),
  );
}

class ReferCandidateDialog extends ConsumerStatefulWidget {
  const ReferCandidateDialog({super.key});

  @override
  ConsumerState<ReferCandidateDialog> createState() => _ReferCandidateDialogState();
}

class _ReferCandidateDialogState extends ConsumerState<ReferCandidateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _positionCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _relationship;
  // Picker choice (branch id), when canPickReferralBranch.
  int? _branchId;
  bool _branchPrefilled = false;
  bool _saving = false;
  String? _submitError;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _positionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    final required = FormValidators.required(v, fieldName: 'Candidate name');
    if (required != null) return required;
    if (v!.trim().length > 200) return 'Candidate name must be 200 characters or fewer.';
    return null;
  }

  String? _validateEmail(String? v) {
    final email = FormValidators.email(v);
    if (email != null) return email;
    if (v!.trim().length > 254) return 'Email address must be 254 characters or fewer.';
    return null;
  }

  // Backend's ReferralSubmitSerializer extends CandidateCreateSerializer
  // without overriding validate_phone, so it enforces the same strict
  // digits-only rule as Add/Edit Candidate — not the lenient one this used
  // to check client-side (which let 7-9 digit or dash/space-formatted
  // numbers through only to be rejected by the API).
  String? _validatePhone(String? v) => FormValidators.candidatePhone(v);

  String? _validatePosition(String? v) {
    final required = FormValidators.required(v, fieldName: 'Position applied for');
    if (required != null) return required;
    if (v!.trim().length > 200) return 'Position must be 200 characters or fewer.';
    return null;
  }

  String? _validateNotes(String? v) {
    if (v == null || v.trim().isEmpty) return null; // optional
    if (v.trim().length > 2000) return 'Notes must be 2000 characters or fewer.';
    return null;
  }

  String? _validateRelationship(String? v) {
    if (v == null || v.isEmpty) return 'Please select your relationship with the candidate.';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _submitError = null;
    });

    // Web sends the picked branch id (admins) or nothing usable; the
    // backend's ReferralSubmitSerializer doesn't take branch at all, so the
    // value is informational either way. Only a picker user sends one.
    final user = ref.read(authStateProvider).valueOrNull?.user;
    final branchId = canPickReferralBranch(user) ? _branchId : null;

    final notesParts = [
      if (_relationship != null) 'Relationship: $_relationship',
      _notesCtrl.text.trim(),
    ].where((s) => s.isNotEmpty);

    final error = await ref.read(myReferralsProvider.notifier).submit(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          positionApplied: _positionCtrl.text.trim(),
          branchId: branchId,
          notes: notesParts.join('\n'),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    if (error != null) {
      setState(() => _submitError = error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final userBranch = user?.branch;
    final branchLabel = (userBranch == null || userBranch.isEmpty) ? 'Not assigned' : userBranch;
    // Branch list requested only for picker users (never a doomed 403).
    final canPick = canPickReferralBranch(user);
    final branchesAsync = canPick ? ref.watch(referralBranchOptionsProvider) : null;
    final branches = branchesAsync?.valueOrNull ?? const [];
    // Start on the user's own branch when it is in the list (web pre-fills
    // the user's branch too).
    if (canPick && !_branchPrefilled && branchesAsync?.hasValue == true) {
      _branchPrefilled = true;
      final own = (userBranch ?? '').toLowerCase();
      _branchId = branches.where((b) => b.branchName.toLowerCase() == own).map((b) => b.id).firstOrNull;
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BranchDlgHeader(
              icon: Icons.person_add_alt_1_outlined,
              title: 'Refer Someone',
              subtitle: 'Share a great candidate and earn a referral bonus',
              onClose: () => Navigator.of(context).pop(false),
            ),
            Flexible(
              child: Container(
                color: AppColors.background,
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CANDIDATE INFORMATION',
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textHint,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          label: 'Full Name *',
                          hint: 'e.g. Rahul Sharma',
                          controller: _nameCtrl,
                          validator: _validateName,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Email Address *',
                          hint: 'candidate@email.com',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          validator: _validateEmail,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Phone Number',
                          hint: '+91 9876543210',
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          validator: _validatePhone,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Position Applied For *',
                          hint: 'e.g. Senior Developer',
                          controller: _positionCtrl,
                          validator: _validatePosition,
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 14),
                        Text(canPick ? 'Branch *' : 'Branch',
                            style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        if (canPick)
                          // Re-created once the list arrives so the pre-filled
                          // branch shows (initialValue is read only once).
                          KeyedSubtree(
                            key: ValueKey('branch-options-${branchesAsync!.hasValue}-${branches.length}'),
                            child: DropdownButtonFormField<int>(
                            key: const Key('referral-branch-picker'),
                            initialValue: branches.any((b) => b.id == _branchId) ? _branchId : null,
                            isExpanded: true,
                            hint: Text(
                              branchesAsync.isLoading
                                  ? 'Loading branches…'
                                  : branchesAsync.hasError
                                      ? friendlyReferralError(branchesAsync.error!)
                                      : branches.isEmpty
                                          ? 'No active branches'
                                          : 'Select branch…',
                              overflow: TextOverflow.ellipsis,
                            ),
                            items: [
                              for (final b in branches)
                                DropdownMenuItem(
                                  value: b.id,
                                  child: Text(b.branchName, overflow: TextOverflow.ellipsis),
                                ),
                            ],
                            onChanged: _saving ? null : (v) => setState(() => _branchId = v),
                            // Required, as web's <select required>.
                            validator: (v) => v == null ? 'Please select a branch.' : null,
                          ))
                        else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          decoration: BoxDecoration(
                            color: AppColors.backgroundLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.business_outlined, size: 18, color: AppColors.textHint),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  branchLabel,
                                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text('Your Relationship *', style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _relationship,
                          isExpanded: true,
                          decoration: const InputDecoration(hintText: 'Select relationship'),
                          items: _kRelationshipOptions
                              .map((r) => DropdownMenuItem(
                                    value: r,
                                    child: Text(r, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _relationship = v),
                          validator: _validateRelationship,
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          label: 'Why would they be a great fit?',
                          hint: "Share their experience, skills, and why you're recommending them…",
                          controller: _notesCtrl,
                          validator: _validateNotes,
                          maxLines: 3,
                          textInputAction: TextInputAction.done,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.infoContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'By submitting this referral you confirm the candidate has '
                            'consented to share their information and has not applied in '
                            'the last 12 months.',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                        if (_submitError != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _submitError!,
                              style: AppTextStyles.caption.copyWith(color: AppColors.error),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        AppButton(
                          label: _saving ? 'Submitting…' : 'Submit Referral',
                          isLoading: _saving,
                          leadingIcon: Icons.send_outlined,
                          onPressed: _saving ? null : _submit,
                        ),
                        const SizedBox(height: 10),
                        AppButton(
                          label: 'Cancel',
                          variant: AppButtonVariant.ghost,
                          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

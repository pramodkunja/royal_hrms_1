import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../employees/domain/employee_profile_sections.dart'
    show EmployeeProfileSection, isPersonalFieldVisible, isProfileFieldVisible;
import '../../../separation/presentation/notice_period.dart' show formatNoticePeriod;
import '../../../settings/data/models/onboarding_field_config_model.dart';
import '../../../../shared/formatters/en_in_format.dart';
import '../../data/models/my_profile_model.dart';
import '../../domain/entities/my_profile_entity.dart';
import 'profile_widgets.dart';

/// Settings → Onboarding Fields visibility by step (null while loading — web
/// shows every field until the config says otherwise).
typedef ProfileFieldConfig = Map<int, List<OnboardingFieldConfigModel>>?;

String _s(String? v) => (v == null || v.isEmpty) ? '—' : v;

/// Web `fmtDate` (en-IN, "5 Nov 2026"); a value that can't be parsed shows
/// as stored, an empty one as "—".
String formatProfileDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  final dt = DateTime.tryParse(raw);
  return dt == null ? raw : formatEnInDate(dt);
}

/// Bank account number as web shows it: only the last 4 digits.
String maskedAccountNumber(String number) =>
    number.isEmpty ? '—' : '••••${number.substring(number.length > 4 ? number.length - 4 : 0)}';

/// Lays [children] out two per row (stacking on narrow screens / large text),
/// so a hidden field closes the gap instead of leaving a hole.
class ProfileFieldGrid extends StatelessWidget {
  final List<Widget> children;
  const ProfileFieldGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final pair = i + 1 < children.length
          ? ProfileTwoUp(left: children[i], right: children[i + 1])
          : ProfileTwoUp(left: children[i], right: const SizedBox.shrink());
      rows.add(Padding(padding: EdgeInsets.only(bottom: i + 2 < children.length ? 14 : 0), child: pair));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }
}

// ── Personal information ─────────────────────────────────────────────────────────

class ProfilePersonalSection extends StatelessWidget {
  final MyProfileModel profile;
  final TextEditingController phoneCtrl;
  final ProfileFieldConfig config;

  const ProfilePersonalSection({super.key, required this.profile, required this.phoneCtrl, this.config});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    bool vis(String k) => isPersonalFieldVisible(k, config);
    final readOnly = <Widget>[
      if (vis('date_of_birth'))
        ProfileDisplayField(label: 'Date of Birth', value: formatProfileDate(p.detail.dateOfBirth), padBottom: false),
      if (vis('gender')) ProfileDisplayField(label: 'Gender', value: _s(p.detail.gender), padBottom: false),
      if (vis('marital_status'))
        ProfileDisplayField(label: 'Marital Status', value: _s(p.detail.maritalStatus), padBottom: false),
      if (vis('blood_group'))
        ProfileDisplayField(label: 'Blood Group', value: _s(p.detail.bloodGroup), padBottom: false),
      if (vis('father_name'))
        ProfileDisplayField(label: "Father's Name", value: _s(p.detail.fatherName), padBottom: false),
    ];
    return ProfileSectionCard(
      icon: Icons.manage_accounts_outlined,
      title: 'Personal Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileFieldGrid(children: [
            ProfileDisplayField(label: 'Full Name', value: _s(p.fullName), padBottom: false),
            ProfileDisplayField(label: 'Email', value: _s(p.email), padBottom: false),
          ]),
          const SizedBox(height: 14),
          ProfileField(
            label: 'Phone',
            controller: phoneCtrl,
            keyboardType: TextInputType.phone,
            hint: '+91 98765 43210',
          ),
          if (readOnly.isNotEmpty) ...[const SizedBox(height: 14), ProfileFieldGrid(children: readOnly)],
        ],
      ),
    );
  }
}

// ── Work information (read-only) ──────────────────────────────────────────────

class ProfileWorkSection extends StatelessWidget {
  final MyProfileModel profile;
  const ProfileWorkSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final p = profile;
    return ProfileSectionCard(
      icon: Icons.work_outline,
      title: 'Work Information',
      child: ProfileFieldGrid(children: [
        ProfileDisplayField(label: 'Employee ID', value: _s(p.employeeId), padBottom: false),
        ProfileDisplayField(
            label: 'Role', value: _s(p.roleDisplay.isNotEmpty ? p.roleDisplay : p.roleName), padBottom: false),
        ProfileDisplayField(label: 'Department', value: _s(p.department), padBottom: false),
        ProfileDisplayField(label: 'Designation', value: _s(p.designation), padBottom: false),
        ProfileDisplayField(label: 'Branch', value: _s(p.branch), padBottom: false),
        ProfileDisplayField(
            label: 'Date of Joining', value: formatProfileDate(p.dateOfJoining ?? p.dateJoined), padBottom: false),
        // Web: assigned people (name only, "Not assigned" when none) and the
        // notice period, read-only.
        ProfileDisplayField(label: 'Reporting Manager', value: assignedName(p.reportingManager), padBottom: false),
        ProfileDisplayField(label: 'Reporting Approver', value: assignedName(p.reportingApprover), padBottom: false),
        ProfileDisplayField(label: 'HR', value: assignedName(p.hr), padBottom: false),
        ProfileDisplayField(label: 'Notice Period', value: formatNoticePeriod(p.noticePeriodDays), padBottom: false),
        _StatusBadge(label: 'Onboarding Status', status: p.onboardingStatus),
        _StatusBadge(label: 'Assessment Status', status: p.assessmentStatus),
      ]),
    );
  }
}

// Onboarding/assessment status pill — web's colored badge (green when
// 'complete', amber otherwise), a state indicator rather than a text value.
class _StatusBadge extends StatelessWidget {
  final String label;
  final String status;
  const _StatusBadge({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final isComplete = status == 'complete';
    final color = status.isEmpty ? AppColors.textHint : (isComplete ? AppColors.success : AppColors.warning);
    final text = status.isEmpty ? '—' : '${status[0].toUpperCase()}${status.substring(1)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 11),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w700, fontSize: 11),
          ),
        ),
      ],
    );
  }
}

// ── Address ───────────────────────────────────────────────────────────────────

class ProfileAddressSection extends StatelessWidget {
  final TextEditingController currentAddressCtrl;
  final TextEditingController permanentAddressCtrl;
  final ProfileFieldConfig config;

  const ProfileAddressSection({
    super.key,
    required this.currentAddressCtrl,
    required this.permanentAddressCtrl,
    this.config,
  });

  /// Whether any address field is shown (web renders the card regardless; an
  /// empty card is noise on a phone, so the screen skips it).
  static bool anyVisible(ProfileFieldConfig config) =>
      isPersonalFieldVisible('current_address', config) || isPersonalFieldVisible('permanent_address', config);

  @override
  Widget build(BuildContext context) {
    final fields = <Widget>[
      if (isPersonalFieldVisible('current_address', config))
        ProfileField(
          label: 'Current Address',
          controller: currentAddressCtrl,
          hint: 'Current residential address',
          maxLines: 3,
        ),
      if (isPersonalFieldVisible('permanent_address', config))
        ProfileField(
          label: 'Permanent Address',
          controller: permanentAddressCtrl,
          hint: 'Permanent / home town address',
          maxLines: 3,
        ),
    ];
    return ProfileSectionCard(
      icon: Icons.location_on_outlined,
      title: 'Address',
      child: Column(
        children: [
          for (var i = 0; i < fields.length; i++) ...[if (i > 0) const SizedBox(height: 14), fields[i]],
        ],
      ),
    );
  }
}

// ── Education & Experience (read-only) ────────────────────────────────────────

class ProfileEducationSection extends StatelessWidget {
  final MyProfileModel profile;
  final ProfileFieldConfig config;
  const ProfileEducationSection({super.key, required this.profile, this.config});

  @override
  Widget build(BuildContext context) {
    final d = profile.detail;
    bool vis(String k) => isProfileFieldVisible(EmployeeProfileSection.education, k, config);
    Widget f(String label, String value) => ProfileDisplayField(label: label, value: value, padBottom: false);
    // Web order and labels (ProfileClient.tsx "Education & Experience").
    return ProfileSectionCard(
      icon: Icons.school_outlined,
      title: 'Education & Experience',
      child: ProfileFieldGrid(children: [
        if (vis('highest_qualification')) f('Qualification', _s(d.highestQualification)),
        if (vis('institution')) f('Institution', _s(d.institution)),
        if (vis('year_of_passing')) f('Year of Passing', _s(d.yearOfPassing?.toString())),
        if (vis('specialization')) f('Specialization', _s(d.specialization)),
        if (vis('total_experience_years')) f('Experience (yrs)', _s(d.totalExperienceYears)),
        if (vis('previous_employer')) f('Previous Employer', _s(d.previousEmployer)),
        if (vis('previous_designation')) f('Previous Role', _s(d.previousDesignation)),
        if (vis('leaving_reason')) f('Leaving Reason', _s(d.leavingReason)),
      ]),
    );
  }

  static bool anyVisible(ProfileFieldConfig config) => const [
        'highest_qualification', 'institution', 'year_of_passing', 'specialization', //
        'total_experience_years', 'previous_employer', 'previous_designation', 'leaving_reason',
      ].any((k) => isProfileFieldVisible(EmployeeProfileSection.education, k, config));
}

// ── Bank details (read-only, contact HR to update) ────────────────────────────

class ProfileBankSection extends StatelessWidget {
  final MyProfileModel profile;
  final ProfileFieldConfig config;
  const ProfileBankSection({super.key, required this.profile, this.config});

  @override
  Widget build(BuildContext context) {
    final d = profile.detail;
    bool vis(String k) => isProfileFieldVisible(EmployeeProfileSection.bank, k, config);
    Widget f(String label, String value) => ProfileDisplayField(label: label, value: value, padBottom: false);
    return ProfileSectionCard(
      icon: Icons.account_balance_outlined,
      title: 'Bank Details',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Contact HR to update',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ProfileFieldGrid(children: [
            if (vis('bank_name')) f('Bank Name', _s(d.bankName)),
            if (vis('account_type')) f('Account Type', _s(d.accountType)),
            if (vis('account_holder_name')) f('Account Holder', _s(d.accountHolderName)),
            // Web: only the last 4 digits are ever shown.
            if (vis('account_number')) f('Account Number', maskedAccountNumber(d.accountNumber)),
            if (vis('ifsc_code')) f('IFSC Code', _s(d.ifscCode)),
            if (vis('bank_branch_name')) f('Bank Branch', _s(d.bankBranchName)),
          ]),
        ],
      ),
    );
  }
}

// ── Emergency contact ──────────────────────────────────────────────────────────

class ProfileEmergencySection extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController relationshipCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController emailCtrl;
  final ProfileFieldConfig config;

  const ProfileEmergencySection({
    super.key,
    required this.nameCtrl,
    required this.relationshipCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
    this.config,
  });

  @override
  Widget build(BuildContext context) {
    bool vis(String k) => isProfileFieldVisible(EmployeeProfileSection.emergency, k, config);
    return ProfileSectionCard(
      icon: Icons.local_phone_outlined,
      title: 'Emergency Contact',
      child: ProfileFieldGrid(children: [
        if (vis('emergency_name')) ProfileField(label: 'Name', controller: nameCtrl, hint: 'Contact name'),
        if (vis('emergency_relationship'))
          ProfileField(label: 'Relationship', controller: relationshipCtrl, hint: 'e.g. Spouse, Parent'),
        if (vis('emergency_phone'))
          ProfileField(
              label: 'Phone', controller: phoneCtrl, keyboardType: TextInputType.phone, hint: '+91 98765 43210'),
        if (vis('emergency_email'))
          ProfileField(
              label: 'Email',
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              hint: 'email@example.com'),
      ]),
    );
  }
}

// ── Change password ────────────────────────────────────────────────────────────

class ProfileChangePasswordSection extends StatelessWidget {
  final TextEditingController currentCtrl;
  final TextEditingController newCtrl;
  final TextEditingController confirmCtrl;
  final bool loading;
  final VoidCallback onSubmit;

  const ProfileChangePasswordSection({
    super.key,
    required this.currentCtrl,
    required this.newCtrl,
    required this.confirmCtrl,
    required this.loading,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      icon: Icons.lock_outline,
      title: 'Change Password',
      child: Column(
        children: [
          ProfileField(
            label: 'Current password',
            controller: currentCtrl,
            obscureText: true,
            hint: 'Current password',
          ),
          const SizedBox(height: 14),
          ProfileField(label: 'New password', controller: newCtrl, obscureText: true, hint: 'New password'),
          const SizedBox(height: 14),
          ProfileField(
            label: 'Confirm new password',
            controller: confirmCtrl,
            obscureText: true,
            hint: 'Confirm new password',
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: loading ? null : onSubmit,
              icon: loading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.lock_outline, size: 16),
              label: Text(loading ? 'Updating…' : 'Update password'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(46),
                textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Documents: see profile_documents_section.dart (ProfileDocumentsSection).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/my_profile_model.dart';
import '../providers/profile_providers.dart';
import 'profile_widgets.dart';

String _s(String? v) => (v == null || v.isEmpty) ? '—' : v;

String _fmtDate(String? raw) {
  if (raw == null || raw.isEmpty) return '—';
  try {
    final dt = DateTime.parse(raw);
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  } catch (_) {
    return raw;
  }
}

String _fmtFileSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// ── Personal information ─────────────────────────────────────────────────────────

class ProfilePersonalSection extends StatefulWidget {
  final MyProfileModel profile;
  final TextEditingController phoneCtrl;

  const ProfilePersonalSection({
    super.key,
    required this.profile,
    required this.phoneCtrl,
  });

  @override
  State<ProfilePersonalSection> createState() => _ProfilePersonalSectionState();
}

class _ProfilePersonalSectionState extends State<ProfilePersonalSection> {
  bool _showMore = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return ProfileSectionCard(
      icon: Icons.manage_accounts_outlined,
      title: 'Personal Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name row
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: p.avatarColor,
                child: Text(
                  p.initials,
                  style: AppTextStyles.h3.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_s(p.fullName),
                        style: AppTextStyles.label
                            .copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(
                      p.roleDisplay.isNotEmpty ? p.roleDisplay : p.roleName,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ProfileFieldRow(
            left: ProfileField(
              label: 'Phone',
              controller: widget.phoneCtrl,
              keyboardType: TextInputType.phone,
              hint: 'e.g. +91 98765 43210',
            ),
            right: ProfileDisplayField(label: 'Email', value: _s(p.email)),
          ),
          const SizedBox(height: 12),
          ProfileDisplayFieldRow(
            label1: 'Employee ID', value1: _s(p.employeeId),
            label2: 'Role', value2: _s(p.roleDisplay.isNotEmpty ? p.roleDisplay : p.roleName),
          ),
          ProfileDisplayFieldRow(
            label1: 'Department', value1: _s(p.department),
            label2: 'Designation', value2: _s(p.designation),
          ),
          ProfileDisplayFieldRow(
            label1: 'Branch', value1: _s(p.branch),
            label2: 'Date of Joining', value2: _fmtDate(p.dateOfJoining),
            padBottom: false,
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _showMore = !_showMore),
              icon: Icon(
                _showMore ? Icons.expand_less : Icons.expand_more,
                size: 16,
              ),
              label: Text(_showMore ? 'Show less' : 'Show more details'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          if (_showMore) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            ProfileDisplayFieldRow(
              label1: 'Gender', value1: _s(p.detail.gender),
              label2: 'Marital Status', value2: _s(p.detail.maritalStatus),
            ),
            ProfileDisplayFieldRow(
              label1: "Father's Name", value1: _s(p.detail.fatherName),
              label2: 'Blood Group', value2: _s(p.detail.bloodGroup),
              padBottom: false,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Address ───────────────────────────────────────────────────────────────────

class ProfileAddressSection extends StatelessWidget {
  final TextEditingController currentAddressCtrl;
  final TextEditingController permanentAddressCtrl;

  const ProfileAddressSection({
    super.key,
    required this.currentAddressCtrl,
    required this.permanentAddressCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      icon: Icons.location_on_outlined,
      title: 'Address',
      child: Column(
        children: [
          ProfileField(
            label: 'Current Address',
            controller: currentAddressCtrl,
            hint: 'e.g. 42, 3rd Cross, HSR Layout, Bengaluru',
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          ProfileField(
            label: 'Permanent Address',
            controller: permanentAddressCtrl,
            hint: 'e.g. 42, 3rd Cross, HSR Layout, Bengaluru',
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}

// ── Education & Experience (read-only) ────────────────────────────────────────

class ProfileEducationSection extends StatelessWidget {
  final MyProfileModel profile;
  const ProfileEducationSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final d = profile.detail;
    return ProfileSectionCard(
      icon: Icons.school_outlined,
      title: 'Education & Experience',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileDisplayFieldRow(
            label1: 'Highest Qualification', value1: _s(d.highestQualification),
            label2: 'Specialization', value2: _s(d.specialization),
          ),
          ProfileDisplayField(label: 'Institution / University', value: _s(d.institution)),
          ProfileDisplayFieldRow(
            label1: 'Year of Passing', value1: _s(d.yearOfPassing?.toString()),
            label2: 'Total Experience (yrs)', value2: _s(d.totalExperienceYears),
          ),
          ProfileDisplayFieldRow(
            label1: 'Previous Employer', value1: _s(d.previousEmployer),
            label2: 'Previous Designation', value2: _s(d.previousDesignation),
          ),
          ProfileDisplayField(
            label: 'Reason for Leaving',
            value: _s(d.leavingReason),
            maxLines: 3,
            padBottom: false,
          ),
        ],
      ),
    );
  }
}

// ── Bank details (read-only, contact HR to update) ────────────────────────────

class ProfileBankSection extends StatelessWidget {
  final MyProfileModel profile;
  const ProfileBankSection({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final d = profile.detail;
    return ProfileSectionCard(
      icon: Icons.account_balance_outlined,
      title: 'Bank Details',
      trailing: Icon(Icons.lock_outline, size: 14, color: AppColors.textHint),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProfileDisplayFieldRow(
            label1: 'Account Holder Name', value1: _s(d.accountHolderName),
            label2: 'Account Type', value2: _s(d.accountType),
          ),
          ProfileDisplayFieldRow(
            label1: 'Account Number', value1: _s(d.accountNumber),
            label2: 'IFSC Code', value2: _s(d.ifscCode),
          ),
          ProfileDisplayFieldRow(
            label1: 'Bank Name', value1: _s(d.bankName),
            label2: 'Bank Branch', value2: _s(d.bankBranchName),
            padBottom: false,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.backgroundLow,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Contact HR to update your bank details.',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
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

  const ProfileEmergencySection({
    super.key,
    required this.nameCtrl,
    required this.relationshipCtrl,
    required this.phoneCtrl,
    required this.emailCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      icon: Icons.local_phone_outlined,
      title: 'Emergency Contact',
      child: Column(
        children: [
          ProfileFieldRow(
            left: ProfileField(label: 'Contact Name', controller: nameCtrl),
            right: ProfileField(label: 'Relationship', controller: relationshipCtrl),
          ),
          const SizedBox(height: 12),
          ProfileFieldRow(
            left: ProfileField(
                label: 'Phone Number', controller: phoneCtrl, keyboardType: TextInputType.phone),
            right: ProfileField(
                label: 'Email', controller: emailCtrl, keyboardType: TextInputType.emailAddress),
          ),
        ],
      ),
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
            label: 'Current Password',
            controller: currentCtrl,
            obscureText: true,
            hint: '••••••••',
          ),
          const SizedBox(height: 12),
          ProfileFieldRow(
            left: ProfileField(
                label: 'New Password', controller: newCtrl, obscureText: true, hint: '••••••••'),
            right: ProfileField(
                label: 'Confirm Password',
                controller: confirmCtrl,
                obscureText: true,
                hint: '••••••••'),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: loading ? null : onSubmit,
              icon: loading
                  ? const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_outline, size: 13),
              label: Text(loading ? 'Updating…' : 'Update Password'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                textStyle:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Documents (read-only list) ─────────────────────────────────────────────────

class ProfileDocumentsSection extends ConsumerWidget {
  const ProfileDocumentsSection({super.key});

  Future<void> _openDocument(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docsAsync = ref.watch(myDocumentsProvider);
    return ProfileSectionCard(
      icon: Icons.folder_outlined,
      title: 'Documents',
      child: docsAsync.when(
        data: (docs) {
          if (docs.isEmpty) {
            return Text(
              'No documents uploaded yet.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
            );
          }
          return Column(
            children: [
              for (var i = 0; i < docs.length; i++) ...[
                if (i > 0) Divider(height: 1, color: AppColors.border),
                ProfileDocumentItem(
                  name: docs[i].documentTypeDisplay.isNotEmpty
                      ? docs[i].documentTypeDisplay
                      : docs[i].documentType,
                  subtitle: [
                    if (docs[i].uploadedAt.isNotEmpty) _fmtDate(docs[i].uploadedAt),
                    if (docs[i].fileSize > 0) _fmtFileSize(docs[i].fileSize),
                  ].join(' · '),
                  onView: docs[i].fileUrl.isEmpty
                      ? null
                      : () => _openDocument(docs[i].fileUrl),
                ),
              ],
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Text(
          friendlyProfileError(e),
          style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
        ),
      ),
    );
  }
}

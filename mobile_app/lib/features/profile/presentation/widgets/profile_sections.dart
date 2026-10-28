import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/my_profile_model.dart';
import '../providers/profile_providers.dart';
import 'profile_widgets.dart';

// Mirrors backend's User.PROFILE_PHOTO_MIN_SIZE/MAX_SIZE (accounts/models.py)
// so an out-of-range file is caught here instead of round-tripping to the
// API for a 422.
const int _kPhotoMinBytes = 100 * 1024;
const int _kPhotoMaxBytes = 200 * 1024;

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

class ProfilePersonalSection extends ConsumerStatefulWidget {
  final MyProfileModel profile;
  final TextEditingController phoneCtrl;

  const ProfilePersonalSection({
    super.key,
    required this.profile,
    required this.phoneCtrl,
  });

  @override
  ConsumerState<ProfilePersonalSection> createState() => _ProfilePersonalSectionState();
}

class _ProfilePersonalSectionState extends ConsumerState<ProfilePersonalSection> {
  bool _showMore = false;
  bool _uploadingPhoto = false;

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: isError ? AppColors.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final file = File(picked.path);
    final ext = picked.path.split('.').last.toLowerCase();
    if (ext != 'jpg' && ext != 'jpeg' && ext != 'png') {
      _showSnack('Only JPG and PNG files are allowed.', isError: true);
      return;
    }
    final size = await file.length();
    if (size < _kPhotoMinBytes) {
      _showSnack(
        'Image is too small (${(size / 1024).toStringAsFixed(0)} KB). Minimum size is 100 KB.',
        isError: true,
      );
      return;
    }
    if (size > _kPhotoMaxBytes) {
      _showSnack(
        'Image is too large (${(size / 1024).toStringAsFixed(0)} KB). Maximum size is 200 KB.',
        isError: true,
      );
      return;
    }

    setState(() => _uploadingPhoto = true);
    final error = await ref.read(myProfileProvider.notifier).uploadPhoto(file);
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    _showSnack(error ?? 'Profile photo updated.', isError: error != null);
  }

  Future<void> _removePhoto() async {
    setState(() => _uploadingPhoto = true);
    final error = await ref.read(myProfileProvider.notifier).removePhoto();
    if (!mounted) return;
    setState(() => _uploadingPhoto = false);
    _showSnack(error ?? 'Profile photo removed.', isError: error != null);
  }

  Future<void> _showPhotoOptions() async {
    final hasPhoto = (widget.profile.photoUrl ?? '').isNotEmpty;
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAndUploadPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickAndUploadPhoto(ImageSource.gallery);
              },
            ),
            if (hasPhoto)
              ListTile(
                leading: Icon(Icons.delete_outline, color: AppColors.error),
                title: Text('Remove Photo', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

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
              GestureDetector(
                onTap: _uploadingPhoto ? null : _showPhotoOptions,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: p.avatarColor,
                      backgroundImage: (p.photoUrl ?? '').isNotEmpty
                          ? NetworkImage(p.photoUrl!)
                          : null,
                      child: (p.photoUrl ?? '').isEmpty
                          ? Text(
                              p.initials,
                              style: AppTextStyles.h3.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            )
                          : null,
                    ),
                    if (_uploadingPhoto)
                      Positioned.fill(
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.black.withValues(alpha: 0.4),
                          child: const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(Colors.white),
                            ),
                          ),
                        ),
                      )
                    else
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.surface, width: 2),
                          ),
                          child: const Icon(Icons.camera_alt, size: 11, color: Colors.white),
                        ),
                      ),
                  ],
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
          ),
          _StatusBadgeRow(
            label1: 'Onboarding Status', status1: p.onboardingStatus,
            label2: 'Assessment Status', status2: p.assessmentStatus,
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
                textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),
          if (_showMore) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 14),
            ProfileDisplayFieldRow(
              label1: 'Date of Birth', value1: _fmtDate(p.detail.dateOfBirth),
              label2: 'Gender', value2: _s(p.detail.gender),
            ),
            ProfileDisplayFieldRow(
              label1: 'Marital Status', value1: _s(p.detail.maritalStatus),
              label2: 'Blood Group', value2: _s(p.detail.bloodGroup),
            ),
            ProfileDisplayField(
              label: "Father's Name", value: _s(p.detail.fatherName),
              padBottom: false,
            ),
          ],
        ],
      ),
    );
  }
}

// Onboarding/assessment status pill row — matches web's colored badge
// treatment (green when 'complete', amber otherwise) rather than a plain
// bordered display field, since these are state indicators, not text values.
class _StatusBadgeRow extends StatelessWidget {
  final String label1;
  final String status1;
  final String label2;
  final String status2;

  const _StatusBadgeRow({
    required this.label1,
    required this.status1,
    required this.label2,
    required this.status2,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _StatusBadge(label: label1, status: status1)),
          const SizedBox(width: 12),
          Expanded(child: _StatusBadge(label: label2, status: status2)),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final String status;
  const _StatusBadge({required this.label, required this.status});

  @override
  Widget build(BuildContext context) {
    final isComplete = status == 'complete';
    final color = status.isEmpty
        ? AppColors.textHint
        : (isComplete ? AppColors.success : AppColors.warning);
    final text = status.isEmpty
        ? '—'
        : '${status[0].toUpperCase()}${status.substring(1)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                    AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
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

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/formatters/en_in_format.dart';
import '../../data/models/my_profile_model.dart';
import '../providers/profile_providers.dart';

// Web ProfilePhotoModal / useProfilePhotoUpload: JPG/PNG only, 100–200 KB
// (backend User.PROFILE_PHOTO_MIN_SIZE / MAX_SIZE), checked here so a bad
// file never round-trips to the API.
const int kProfilePhotoMinBytes = 100 * 1024;
const int kProfilePhotoMaxBytes = 200 * 1024;

/// Web's validation message for [bytes] outside the allowed range, else null.
String? profilePhotoSizeError(int bytes) => (bytes < kProfilePhotoMinBytes || bytes > kProfilePhotoMaxBytes)
    ? 'Image must be between 100 KB and 200 KB (selected file is ${(bytes / 1024).round()} KB).'
    : null;

/// Web's validation message for a file name that isn't JPG/JPEG/PNG, else null.
String? profilePhotoTypeError(String path) {
  final ext = path.split('.').last.toLowerCase();
  return (ext == 'jpg' || ext == 'jpeg' || ext == 'png') ? null : 'Only JPG, JPEG, and PNG files are allowed.';
}

/// Picks the photo file (tests override this; the app uses image_picker).
final profilePhotoPickerProvider = Provider<Future<File?> Function(ImageSource source)>((ref) => (source) async {
      final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
      return picked == null ? null : File(picked.path);
    });

String _joined(String? iso) {
  final dt = iso == null ? null : DateTime.tryParse(iso);
  return dt == null ? '' : formatEnInDate(dt);
}

/// Self-service identity header: photo (with change/remove), name, role line,
/// employee ID, branch, joining date and the assigned people. Mirrors web's
/// "Avatar + name banner" (ProfileClient.tsx).
class ProfileHeaderCard extends ConsumerStatefulWidget {
  const ProfileHeaderCard({super.key, required this.profile});

  final MyProfileModel profile;

  @override
  ConsumerState<ProfileHeaderCard> createState() => _ProfileHeaderCardState();
}

class _ProfileHeaderCardState extends ConsumerState<ProfileHeaderCard> {
  bool _busy = false;

  void _snack(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : null,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final file = await ref.read(profilePhotoPickerProvider)(source);
    if (file == null) return;
    final typeError = profilePhotoTypeError(file.path);
    if (typeError != null) return _snack(typeError, error: true);
    final sizeError = profilePhotoSizeError(await file.length());
    if (sizeError != null) return _snack(sizeError, error: true);

    setState(() => _busy = true);
    final error = await ref.read(myProfileProvider.notifier).uploadPhoto(file);
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(error ?? 'Profile photo updated.', error: error != null);
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    final error = await ref.read(myProfileProvider.notifier).removePhoto();
    if (!mounted) return;
    setState(() => _busy = false);
    _snack(error ?? 'Profile photo removed.', error: error != null);
  }

  Future<void> _options() async {
    final hasPhoto = (widget.profile.photoUrl ?? '').isNotEmpty;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (sheet) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(
                title: Text('Profile photo', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text('JPG, JPEG, or PNG, between 100 KB and 200 KB.'),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Capture Photo'),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _pickAndUpload(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Upload from Device'),
                onTap: () {
                  Navigator.of(sheet).pop();
                  _pickAndUpload(ImageSource.gallery);
                },
              ),
              if (hasPhoto)
                ListTile(
                  leading: Icon(Icons.delete_outline, color: AppColors.error),
                  title: Text('Remove Current Photo', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.of(sheet).pop();
                    _remove();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(MyProfileModel p) {
    final hasPhoto = (p.photoUrl ?? '').isNotEmpty;
    return Semantics(
      button: true,
      label: 'Change profile photo',
      child: GestureDetector(
        key: const ValueKey('profile-photo-button'),
        onTap: _busy ? null : _options,
        child: SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: p.avatarColor,
                foregroundImage: hasPhoto ? NetworkImage(p.photoUrl!) : null,
                onForegroundImageError: hasPhoto ? (_, __) {} : null,
                child: Text(
                  p.initials,
                  style: AppTextStyles.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              if (_busy)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), shape: BoxShape.circle),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                )
              else
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.surface, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
          ),
        ],
      );

  Widget _person(IconData icon, Color color, String label, String name) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$label: ', style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
                TextSpan(
                  text: name,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
                ),
              ]),
            ),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final roleLine = p.designation.isNotEmpty && p.department.isNotEmpty
        ? '${p.designation} · ${p.department}'
        : (p.roleDisplay.isNotEmpty ? p.roleDisplay : p.roleName);
    final joined = _joined(p.dateOfJoining ?? p.dateJoined);
    final people = <Widget>[
      if ((p.reportingManager?.name ?? '').isNotEmpty)
        _person(Icons.how_to_reg_outlined, AppColors.primary, 'Reporting Manager', p.reportingManager!.name!),
      if ((p.reportingApprover?.name ?? '').isNotEmpty)
        _person(Icons.how_to_reg_outlined, AppColors.primary, 'Reporting Approver', p.reportingApprover!.name!),
      if ((p.hr?.name ?? '').isNotEmpty)
        _person(Icons.support_agent_outlined, const Color(0xFF7C3AED), 'Assigned HR', p.hr!.name!),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _avatar(p),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.fullName.isEmpty ? '—' : p.fullName,
                      style: AppTextStyles.h4.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (roleLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(roleLine, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (p.employeeId.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              p.employeeId,
                              style:
                                  AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                            ),
                          ),
                        if (p.branch.isNotEmpty) _meta(Icons.business_outlined, p.branch),
                        if (joined.isNotEmpty) _meta(Icons.calendar_today_outlined, 'Joined $joined'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (people.isNotEmpty) ...[
            const SizedBox(height: 12),
            Divider(height: 1, color: AppColors.border),
            const SizedBox(height: 10),
            for (var i = 0; i < people.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              people[i],
            ],
          ],
        ],
      ),
    );
  }
}

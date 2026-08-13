import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/face_registration_entity.dart';

/// Small pill badge for a FaceRegistrationStatus — shared by the Profile
/// self-service card, the HR admin screen, and anywhere else that needs to
/// show "Approved / Pending / Rejected / Not registered" at a glance.
class FaceStatusBadge extends StatelessWidget {
  final FaceRegistrationStatus? status;
  const FaceStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      FaceRegistrationStatus.approved => ('Approved', AppColors.success, Icons.check_circle),
      FaceRegistrationStatus.pending => ('Pending', AppColors.warning, Icons.hourglass_top),
      FaceRegistrationStatus.rejected => ('Rejected', AppColors.error, Icons.cancel),
      null => ('Not registered', AppColors.textHint, Icons.face_retouching_off_outlined),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.labelSmall.copyWith(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Circular initials avatar for an employee name — used wherever the face
/// registration UI lists or highlights a specific person.
class FaceInitialsAvatar extends StatelessWidget {
  final String name;
  final double size;
  const FaceInitialsAvatar({super.key, required this.name, this.size = 40});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: AppTextStyles.label.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: size * 0.36),
      ),
    );
  }
}

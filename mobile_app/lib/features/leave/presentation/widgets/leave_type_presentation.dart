import 'package:flutter/material.dart';

import '../../../settings/data/models/leave_policy_model.dart';
import '../../domain/entities/leave_entity.dart';
import 'leave_type_icons.dart';

// Label / icon / colour for a leave type, resolved exactly as the web does
// (frontend/app/dashboard/leave/_data.ts buildLeaveTypesList + configForPolicy,
// used by the Employee Profile LeaveTab via labelOf / leaveTypeMap):
//
//  - the 6 built-in types (casual, earned, sick, lwp, maternity, paternity):
//    their fixed built-in label, icon and colour (LeaveTypeColors /
//    leaveTypeIconForCode — the existing mobile copies of web's
//    LEAVE_TYPE_CONFIG; nothing new is hardcoded here);
//  - an ACTIVE custom Leave Policy: the policy's own label
//    (GET /leave/policy/ → leave_type_display, i.e. the label configured in
//    Leave Policy) with web's neutral custom styling;
//  - anything else (no policy, an inactive custom policy, or the policy list
//    not loaded / failed): the balance's own leave_type_display, same neutral
//    styling.
//
// The backend has no icon or colour setting for leave types (LeavePolicy has
// no such field), so web gives every custom type the same
// CUSTOM_LEAVE_TYPE_DEFAULTS — and so does this.

/// Web CUSTOM_LEAVE_TYPE_DEFAULTS: color "#6b7280", bg rgba(107,114,128,0.1),
/// icon "ti-calendar-star" (closest Material icon below).
const kCustomLeaveTypeColor = Color(0xFF6B7280);
const kCustomLeaveTypeIcon = Icons.edit_calendar_outlined;

class LeaveTypePresentation {
  const LeaveTypePresentation({required this.label, required this.icon, required this.color, required this.builtin});
  final String label;
  final IconData icon;
  final Color color;

  /// One of web's 6 built-in types.
  final bool builtin;

  /// Web `bg` — the icon chip background.
  Color get background => color.withValues(alpha: 0.1);
}

bool isBuiltinLeaveType(String code) => LeaveTypeColors.allCodes.contains(code);

LeaveTypePresentation resolveLeaveTypePresentation({
  required String code,
  required String balanceDisplay,
  List<LeavePolicyModel>? policies,
}) {
  if (isBuiltinLeaveType(code)) {
    return LeaveTypePresentation(
      label: LeaveTypeColors.labelForCode(code),
      icon: leaveTypeIconForCode(code),
      color: Color(LeaveTypeColors.colorValueForCode(code)),
      builtin: true,
    );
  }
  final policy = policies?.where((p) => p.isActive && p.leaveType == code).firstOrNull;
  final policyLabel = policy == null ? '' : (policy.leaveTypeDisplay.isNotEmpty ? policy.leaveTypeDisplay : code);
  return LeaveTypePresentation(
    label: policyLabel.isNotEmpty ? policyLabel : (balanceDisplay.isNotEmpty ? balanceDisplay : code),
    icon: kCustomLeaveTypeIcon,
    color: kCustomLeaveTypeColor,
    builtin: false,
  );
}

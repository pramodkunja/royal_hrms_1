import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// One tap submits the phrase exactly like a typed command (onPick), so it
// goes through the real /voice/parse/ pipeline — not a shortcut, not a
// different code path. Mirrors web's QuickActionChips.tsx: same 5 phrases
// (copied verbatim from backend/apps/voice_commands/registry/intents_en.yaml,
// guaranteeing a tap always matches), same bilingual English/Hindi labels
// (VC-2) shown together rather than behind a language toggle. As on web,
// nobody has confirmed these specific Hindi labels against a native speaker
// yet — flagged for the same review web's own copy still needs.
class QuickAction {
  final String label;
  final String labelHi;
  final String phrase;
  final IconData icon;

  const QuickAction({required this.label, required this.labelHi, required this.phrase, required this.icon});
}

const List<QuickAction> kQuickActions = [
  QuickAction(label: 'Clock In', labelHi: 'क्लॉक-इन', phrase: 'clock in', icon: Icons.login),
  QuickAction(label: 'Clock Out', labelHi: 'क्लॉक-आउट', phrase: 'clock out', icon: Icons.logout),
  QuickAction(
    label: 'Leave Balance',
    labelHi: 'छुट्टी का शेष',
    phrase: 'check my leave balance',
    icon: Icons.event_available_outlined,
  ),
  QuickAction(
    label: 'Apply for Leave',
    labelHi: 'छुट्टी के लिए आवेदन करें',
    phrase: 'apply for leave',
    icon: Icons.event_note_outlined,
  ),
  QuickAction(
    label: 'My Attendance',
    labelHi: 'मेरी उपस्थिति',
    phrase: 'show my attendance summary',
    icon: Icons.fact_check_outlined,
  ),
];

/// A tap wraps rather than scrolls (web's flex-wrap, adapted for this
/// panel's ~290px width — narrower than a desktop panel, so wrap keeps every
/// chip readable instead of forcing a horizontal scroll a thumb has to
/// discover). Shown once, in the fresh-command "typing" phase only — same
/// placement as web's own greeting-phase-only rendering (VoiceConversationPanel.tsx).
class QuickActionChips extends StatelessWidget {
  final void Function(String phrase) onPick;
  const QuickActionChips({super.key, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: kQuickActions.map((action) {
        return OutlinedButton(
          onPressed: () => onPick(action.phrase),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            side: BorderSide(color: AppColors.border),
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, size: 13, color: AppColors.primary),
              const SizedBox(width: 6),
              // Stacked, not side-by-side — same reasoning as web's own chip
              // layout: at this compact width, "Clock In / क्लॉक-इन" side by
              // side would either wrap onto its own line anyway or force one
              // language smaller to fit, which is exactly what stacking avoids.
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(action.label, style: AppTextStyles.labelSmall.copyWith(fontSize: 11.5)),
                  Text(
                    action.labelHi,
                    style: AppTextStyles.labelSmall.copyWith(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

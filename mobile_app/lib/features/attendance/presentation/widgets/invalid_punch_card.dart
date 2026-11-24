import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../approvals/presentation/widgets/approvals_ui.dart';
import '../../domain/entities/attendance_entity.dart';
import 'ot_record_card.dart' show formatAttendanceDate;

// HR Attendance -> Invalid Punches. The list API (services_hr_audit._build_row)
// returns only: id, device_id, raw_time, biometric_id, issue, issue_type,
// suggested_match, branch. There is no employee, punch type, status or
// resolution state in it, so none is shown, and nothing here says a punch was
// fixed: a punch that is listed is one the server still reports as invalid.

/// Server issue types (no-match / duplicate / future) -> the label and colour.
/// Web ISSUE_BADGE: no-match and future are red, duplicate amber, others neutral.
({String label, ApprovalsTone tone, IconData icon}) invalidPunchKind(String issueType) => switch (issueType) {
      'no-match' => (label: 'Sequence mismatch', tone: ApprovalsTone.error, icon: Icons.error_outline),
      'duplicate' => (label: 'Duplicate punch', tone: ApprovalsTone.warning, icon: Icons.warning_amber_rounded),
      'future' => (label: 'Future time', tone: ApprovalsTone.error, icon: Icons.update),
      _ => (label: 'Invalid punch', tone: ApprovalsTone.neutral, icon: Icons.help_outline),
    };

/// `2026-11-23 09:02:11` -> (`23 Nov 2026`, `09:02:11`); unparseable text is returned whole.
({String date, String? time}) splitRawPunchTime(String raw) {
  final m = RegExp(r'^(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2}(?::\d{2})?)').firstMatch(raw.trim());
  if (m == null) return (date: raw.isEmpty ? '—' : raw, time: null);
  return (date: formatAttendanceDate(m.group(1)!), time: m.group(2));
}

bool _blank(String v) => v.trim().isEmpty || v.trim() == '—';

class InvalidPunchCard extends StatelessWidget {
  const InvalidPunchCard({
    super.key,
    required this.punch,
    required this.canEdit,
    required this.busy,
    required this.onAssign,
    required this.onConvert,
    required this.onDiscard,
  });

  final InvalidPunchEntity punch;
  final bool canEdit;
  final bool busy;
  final VoidCallback onAssign;
  final VoidCallback onConvert;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final p = punch;
    final kind = invalidPunchKind(p.issueType);
    final tone = approvalsToneColor(kind.tone);
    final when = splitRawPunchTime(p.rawTime);
    final sameId = p.biometricId == p.deviceId;
    final facts = <(String, String, IconData)>[
      (
        sameId ? 'Device / Card ID' : 'Device ID',
        _blank(p.deviceId) ? 'Not provided' : p.deviceId,
        Icons.devices_outlined
      ),
      if (!sameId) ('Card / Bio ID', _blank(p.biometricId) ? 'Not provided' : p.biometricId, Icons.badge_outlined),
      ('Suggested Fix', _blank(p.suggestedMatch) ? 'None suggested' : p.suggestedMatch, Icons.lightbulb_outline),
      ('Branch', _blank(p.branch) ? 'Not provided' : p.branch, Icons.apartment_outlined),
    ];
    return Semantics(
      container: true,
      label: 'Invalid punch, ${kind.label}, ${p.issue}, ${when.date} ${when.time ?? ''}',
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(children: [
          // Colour rail: the kind of problem, always paired with the text badge.
          Positioned(left: 0, top: 0, bottom: 0, width: 4, child: ColoredBox(color: tone)),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  ApprovalsIconBox(kind.icon, color: tone, size: 38),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        ApprovalsBadge('Invalid · ${kind.label}', kind.tone, icon: Icons.report_gmailerrorred_outlined),
                      ]),
                      const SizedBox(height: 6),
                      Text(p.issue.isEmpty ? 'Invalid punch' : p.issue,
                          key: const Key('invalid-punch-reason'),
                          style: AppTextStyles.body
                              .copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.schedule, size: 16, color: AppColors.textSecondary)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(when.time == null ? when.date : '${when.date} · ${when.time}',
                        key: const Key('invalid-punch-time'),
                        style: AppTextStyles.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 10),
                _Facts(facts: facts),
                if (canEdit) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: AppColors.border.withValues(alpha: 0.7)),
                  const SizedBox(height: 10),
                  busy
                      ? const SizedBox(
                          height: 44,
                          child: Center(
                            child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        )
                      : _Actions(onAssign: onAssign, onConvert: onConvert, onDiscard: onDiscard),
                ] else
                  const SizedBox.shrink(key: Key('invalid-punch-no-actions')),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.facts});
  final List<(String, String, IconData)> facts;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
        final twoCols = c.maxWidth >= 340 && scale <= 1.3;
        const gap = 14.0;
        final w = twoCols ? (c.maxWidth - gap) / 2 : c.maxWidth;
        return Wrap(spacing: gap, runSpacing: 10, children: [
          for (final f in facts)
            SizedBox(
              width: w,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 1), child: Icon(f.$3, size: 14, color: AppColors.textHint)),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(f.$1, style: AppTextStyles.caption.copyWith(color: AppColors.textHint)),
                    Text(f.$2,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textPrimary, fontWeight: FontWeight.w500, height: 1.35)),
                  ]),
                ),
              ]),
            ),
        ]);
      });
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onAssign, required this.onConvert, required this.onDiscard});
  final VoidCallback onAssign;
  final VoidCallback onConvert;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
        final row = c.maxWidth >= 300 && scale <= 1.3;
        final assign = OutlinedButton.icon(
          key: const Key('invalid-punch-assign'),
          onPressed: onAssign,
          icon: const Icon(Icons.person_add_alt_1_outlined, size: 16),
          label: const Text('Assign'),
          style: _style(AppColors.textPrimary, AppColors.border),
        );
        final convert = OutlinedButton.icon(
          key: const Key('invalid-punch-convert'),
          onPressed: onConvert,
          icon: const Icon(Icons.swap_horiz, size: 16),
          label: const Text('Convert'),
          style: _style(AppColors.primary, AppColors.primary.withValues(alpha: 0.45)),
        );
        final discard = OutlinedButton.icon(
          key: const Key('invalid-punch-discard'),
          onPressed: onDiscard,
          icon: const Icon(Icons.delete_outline, size: 16),
          label: const Text('Discard'),
          style: _style(AppColors.error, AppColors.error.withValues(alpha: 0.45)),
        );
        if (row) {
          return Row(children: [
            Expanded(child: assign),
            const SizedBox(width: 8),
            Expanded(child: convert),
            const SizedBox(width: 8),
            Expanded(child: discard),
          ]);
        }
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          assign,
          const SizedBox(height: 8),
          convert,
          const SizedBox(height: 8),
          discard,
        ]);
      });

  ButtonStyle _style(Color fg, Color side) => OutlinedButton.styleFrom(
        foregroundColor: fg,
        side: BorderSide(color: side),
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
      );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../assessments/data/models/assessment_model.dart';

// Onboarding approval extras — web's OnboardingDrawer.tsx (production):
// UAN, Name as per Aadhaar and PAN, prefilled from the profile, editable,
// optional; plus an optional assessment for applicants with a linked
// candidate. Sent with POST /onboarding/approvals/<id>/ (OnboardingApprovalView),
// which also validates the PAN format and refuses a PAN already registered.

/// Web PAN_RE (and backend PAN_RE after upper-casing).
final _panPattern = RegExp(r'^[A-Za-z]{5}[0-9]{4}[A-Za-z]$');

/// Web: "UAN must be exactly 12 digits, or leave it blank." The input only
/// accepts digits, as web's does.
String? validateUan(String value) {
  final v = value.trim();
  if (v.isEmpty) return null;
  if (!RegExp(r'^\d{12}$').hasMatch(v)) return 'UAN must be exactly 12 digits, or leave it blank.';
  return null;
}

/// Web: "Enter a valid PAN (e.g. ABCDE1234F), or leave it blank."
String? validatePan(String value) {
  final v = value.trim();
  if (v.isEmpty) return null;
  if (!_panPattern.hasMatch(v)) return 'Enter a valid PAN (e.g. ABCDE1234F), or leave it blank.';
  return null;
}

/// Read-only display of an identifier: only the last 4 characters.
String? maskIdentifier(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return null;
  if (v.length <= 4) return '••••';
  return '••••${v.substring(v.length - 4)}';
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// Web PAN live hint: shown while a non-empty PAN isn't valid yet.
const kPanFormatHint = '5 letters, 4 digits, 1 letter — e.g. ABCDE1234F';

/// Web UAN live counter: "<n>/12 digits" while a non-empty UAN isn't 12 long.
String? uanDigitsCounter(String value) =>
    value.isNotEmpty && value.length != 12 ? '${value.length}/12 digits' : null;

/// Web PAN live hint, or null.
String? panFormatHint(String value) => value.isNotEmpty && !_panPattern.hasMatch(value) ? kPanFormatHint : null;

/// The three optional identity inputs in the Approve form — web
/// OnboardingDrawer.tsx "EPF Details": a bordered box with the heading and
/// note, UAN Number + Name as per Aadhar (side by side on wide screens) and
/// PAN Number below. Each label sits above its input, so the placeholder is
/// visible before the field is focused. While typing, an incomplete UAN shows
/// "<n>/12 digits" and an invalid PAN the format hint (web's warn text);
/// Confirm reports problems in the Assign Role banner (see validateUan /
/// validatePan). Nothing here is required.
class ApprovalIdentityInputs extends StatelessWidget {
  const ApprovalIdentityInputs({
    super.key,
    required this.uanCtrl,
    required this.aadharNameCtrl,
    required this.panCtrl,
    required this.enabled,
    this.onChanged,
  });

  final TextEditingController uanCtrl;
  final TextEditingController aadharNameCtrl;
  final TextEditingController panCtrl;
  final bool enabled;
  final VoidCallback? onChanged;

  static InputDecoration _dec(String placeholder) => InputDecoration(
        hintText: placeholder,
        counterText: '',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );

  Widget _field(String label, Widget input, {Widget? below}) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          input,
          if (below != null) below,
        ],
      );

  Widget _liveHint(Key key, TextEditingController ctrl, String? Function(String) hint) =>
      ValueListenableBuilder<TextEditingValue>(
        valueListenable: ctrl,
        builder: (_, v, __) {
          final text = hint(v.text);
          if (text == null) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(text, key: key, style: AppTextStyles.caption.copyWith(color: AppColors.warning)),
          );
        },
      );

  @override
  Widget build(BuildContext context) {
    final uan = _field(
      'UAN Number',
      TextField(
        key: const Key('approval-uan'),
        controller: uanCtrl,
        enabled: enabled,
        keyboardType: TextInputType.number,
        maxLength: 12,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => onChanged?.call(),
        decoration: _dec('12-digit UAN'),
      ),
      below: _liveHint(const Key('approval-uan-counter'), uanCtrl, uanDigitsCounter),
    );
    final aadhar = _field(
      'Name as per Aadhar',
      TextField(
        key: const Key('approval-aadhar-name'),
        controller: aadharNameCtrl,
        enabled: enabled,
        textCapitalization: TextCapitalization.words,
        onChanged: (_) => onChanged?.call(),
        decoration: _dec('Exactly as on Aadhar card'),
      ),
    );
    final pan = _field(
      'PAN Number',
      TextField(
        key: const Key('approval-pan'),
        controller: panCtrl,
        enabled: enabled,
        maxLength: 10,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [_UpperCase()],
        onChanged: (_) => onChanged?.call(),
        decoration: _dec('e.g. ABCDE1234F'),
      ),
      below: _liveHint(const Key('approval-pan-hint'), panCtrl, panFormatHint),
    );
    return Container(
      key: const Key('approval-epf-details'),
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: 'EPF DETAILS ',
                style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.textSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.5),
              ),
              TextSpan(
                text: '(optional — can be filled later from employee profile)',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ]),
            key: const Key('approval-epf-heading'),
          ),
          const SizedBox(height: 8),
          // Web: a two-column grid (UAN | Aadhar name), PAN across both.
          // Phones are too narrow for two inputs side by side, so stack there.
          LayoutBuilder(
            builder: (_, c) => c.maxWidth >= 520
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Expanded(child: uan),
                    const SizedBox(width: 8),
                    Expanded(child: aadhar),
                  ])
                : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    uan,
                    const SizedBox(height: 8),
                    aadhar,
                  ]),
          ),
          const SizedBox(height: 8),
          pan,
        ],
      ),
    );
  }
}

/// Optional assessment to assign with the approval (web: the assessment step,
/// offered when the applicant came through recruitment). Never blocks the
/// approval: loading, an empty list and a failed load all allow "None".
class ApprovalAssessmentPicker extends StatelessWidget {
  const ApprovalAssessmentPicker({
    super.key,
    required this.loading,
    required this.failed,
    required this.assessments,
    required this.selectedId,
    required this.enabled,
    required this.onChanged,
  });

  final bool loading;
  final bool failed;
  final List<AssessmentModel> assessments;
  final String? selectedId; // null = none
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final Widget body;
    if (loading) {
      body = const SizedBox(
          key: Key('approval-assessments-loading'),
          height: 44,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    } else if (failed) {
      body = Text('Could not load assessments. You can approve without assigning one.',
          key: const Key('approval-assessments-failed'),
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary));
    } else if (assessments.isEmpty) {
      body = Text('No assessments available to assign.',
          key: const Key('approval-assessments-empty'),
          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary));
    } else {
      body = DropdownButtonFormField<String?>(
        key: const Key('approval-assessment'),
        initialValue: assessments.any((a) => a.id == selectedId) ? selectedId : null,
        isExpanded: true,
        decoration: InputDecoration(
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('No assessment')),
          for (final a in assessments)
            DropdownMenuItem<String?>(value: a.id, child: Text(a.title, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: enabled ? onChanged : null,
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 12),
      Text('Assign assessment (optional)', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
      const SizedBox(height: 6),
      body,
    ]);
  }
}

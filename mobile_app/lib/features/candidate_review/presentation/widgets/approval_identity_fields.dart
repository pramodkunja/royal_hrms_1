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

/// The three optional identity inputs in the Approve form.
class ApprovalIdentityInputs extends StatelessWidget {
  const ApprovalIdentityInputs({
    super.key,
    required this.uanCtrl,
    required this.aadharNameCtrl,
    required this.panCtrl,
    required this.enabled,
    this.uanError,
    this.panError,
    required this.onChanged,
  });

  final TextEditingController uanCtrl;
  final TextEditingController aadharNameCtrl;
  final TextEditingController panCtrl;
  final bool enabled;
  final String? uanError;
  final String? panError;
  final VoidCallback onChanged;

  InputDecoration _dec(String label, {String? hint, String? error}) => InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: error,
        errorMaxLines: 2,
        counterText: '',
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      );

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Text('Statutory details (optional)',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          TextField(
            key: const Key('approval-uan'),
            controller: uanCtrl,
            enabled: enabled,
            keyboardType: TextInputType.number,
            maxLength: 12,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChanged(),
            decoration: _dec('UAN', hint: '12-digit UAN', error: uanError),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('approval-aadhar-name'),
            controller: aadharNameCtrl,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => onChanged(),
            decoration: _dec('Name as per Aadhaar'),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('approval-pan'),
            controller: panCtrl,
            enabled: enabled,
            maxLength: 10,
            textCapitalization: TextCapitalization.characters,
            inputFormatters: [_UpperCase()],
            onChanged: (_) => onChanged(),
            decoration: _dec('PAN', hint: 'e.g. ABCDE1234F', error: panError),
          ),
        ],
      );
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

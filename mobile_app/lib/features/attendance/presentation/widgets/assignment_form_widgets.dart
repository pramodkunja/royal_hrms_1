import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/shift_assignment_models.dart' show isoDate;

// Form pieces shared by the HR Attendance assignment tabs (Shift Assignment,
// Weekly Off Assignment): bottom sheet, labelled dropdown, Effective From date
// field and inline error.

/// Bottom sheet for the assignment forms.
///
/// A modal bottom sheet is drawn by the Navigator, outside any Scaffold, so
/// nothing in it adds the system-bar inset: the action row used to sit under
/// the Android gesture / three-button navigation bar. The footer is therefore
/// wrapped in a [SafeArea] (real `MediaQuery.padding.bottom`, whatever the
/// device) and the keyboard (`viewInsets.bottom`) is added on top of it. The
/// title and fields scroll; the Cancel / action row is pinned below them so it
/// is never scrolled out of reach.
class AssignmentSheet extends StatelessWidget {
  const AssignmentSheet(
      {super.key, required this.title, required this.saving, required this.content, required this.action});
  final String title;
  final bool saving;
  final List<Widget> content;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final stacked = media.textScaler.scale(10) / 10 > 1.3 || media.size.width < 360;
    final cancel = TextButton(
      style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
      onPressed: saving ? null : () => Navigator.of(context).pop(),
      child: const Text('Cancel'),
    );
    return PopScope(
      canPop: !saving,
      child: Padding(
        // Keyboard: lift the whole sheet. (The engine already reports the
        // bottom safe padding net of the keyboard, so the two never double up.)
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height - media.padding.top - 24),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(title, style: AppTextStyles.h4.copyWith(fontSize: 16)),
                  const SizedBox(height: 12),
                  ...content,
                ]),
              ),
            ),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: stacked
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [action, const SizedBox(height: 4), cancel])
                      : Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          cancel,
                          const SizedBox(width: 8),
                          Flexible(child: action),
                        ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class AssignmentPicker extends StatelessWidget {
  const AssignmentPicker(
      {super.key, required this.label, required this.value, required this.options, required this.onChanged});
  final String label;
  final String value;
  final List<(String, String)> options;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final values = options.map((o) => o.$1).toSet();
    return DropdownButtonFormField<String>(
      key: ValueKey('$label|$value|${options.length}'),
      initialValue: values.contains(value) ? value : options.first.$1,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        border: const OutlineInputBorder(),
      ),
      items: [
        for (final o in options) DropdownMenuItem(value: o.$1, child: Text(o.$2, overflow: TextOverflow.ellipsis)),
      ],
      onChanged: onChanged == null ? null : (v) => onChanged!(v ?? ''),
    );
  }
}

class AssignmentDateField extends StatelessWidget {
  const AssignmentDateField({super.key, required this.value, required this.enabled, required this.onChanged});
  final DateTime value;
  final bool enabled;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: !enabled
          ? null
          : () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
                helpText: 'Effective From',
              );
              if (picked != null) onChanged(picked);
            },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Effective From',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
          border: OutlineInputBorder(),
        ),
        child: Text(isoDate(value)),
      ),
    );
  }
}

class AssignmentErrorBox extends StatelessWidget {
  const AssignmentErrorBox({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.error_outline, size: 16, color: AppColors.error),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, color: AppColors.error))),
        ]),
      );
}

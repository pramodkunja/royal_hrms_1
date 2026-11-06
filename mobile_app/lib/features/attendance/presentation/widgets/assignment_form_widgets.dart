import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/shift_assignment_models.dart' show isoDate;

// Form pieces shared by the HR Attendance assignment tabs (Shift Assignment,
// Weekly Off Assignment): bottom sheet, labelled dropdown, Effective From date
// field and inline error.

class AssignmentSheet extends StatelessWidget {
  const AssignmentSheet(
      {super.key, required this.title, required this.saving, required this.content, required this.action});
  final String title;
  final bool saving;
  final List<Widget> content;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !saving,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: AppTextStyles.h4.copyWith(fontSize: 16)),
            const SizedBox(height: 12),
            ...content,
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: saving ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
              const SizedBox(width: 8),
              action,
            ]),
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
      decoration: InputDecoration(labelText: label, isDense: true, border: const OutlineInputBorder()),
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
        decoration: const InputDecoration(labelText: 'Effective From', isDense: true, border: OutlineInputBorder()),
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

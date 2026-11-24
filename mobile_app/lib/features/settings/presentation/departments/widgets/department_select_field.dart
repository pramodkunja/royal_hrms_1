import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/departments_model.dart';

/// Department chooser for the Designation form.
///
/// A plain `DropdownButtonFormField` lays the selected value out at its natural
/// width, so a long department name overflowed the field (no `isExpanded`) and the
/// full name could not be read. This field shows the whole name (it wraps) and opens
/// a searchable, scrollable sheet instead, which also stays inside the visible area
/// with the keyboard open. It handles loading, empty and failed loads itself.
class DepartmentSelectField extends StatelessWidget {
  const DepartmentSelectField({
    super.key,
    required this.departments,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.onRetry,
  });

  /// The departments request: data, loading or error.
  final AsyncValue<List<DepartmentModel>> departments;
  final int? value;
  final ValueChanged<int> onChanged;
  final String? errorText;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return departments.when(
      // Show the loader on a retry/refresh too, not the stale result.
      skipLoadingOnRefresh: false,
      loading: () => const _Notice(
        key: Key('desig-dept-loading'),
        icon: null,
        message: 'Loading departments…',
      ),
      error: (e, _) => _Notice(
        key: const Key('desig-dept-error'),
        icon: Icons.error_outline,
        message: 'Could not load departments.',
        isError: true,
        actionKey: const Key('desig-dept-retry'),
        actionLabel: 'Retry',
        onAction: onRetry,
      ),
      data: (list) {
        if (list.isEmpty) {
          return const _Notice(
            key: Key('desig-dept-empty'),
            icon: Icons.info_outline,
            message: 'No departments available. Add a department first.',
          );
        }
        DepartmentModel? selected;
        for (final d in list) {
          if (d.id == value) selected = d;
        }
        return InkWell(
          key: const Key('desig-dept-field'),
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final id = await showModalBottomSheet<int>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: AppColors.surface,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
              builder: (_) => _DepartmentSheet(departments: list, selectedId: value),
            );
            if (id != null) onChanged(id);
          },
          child: InputDecorator(
            isEmpty: selected == null,
            decoration: InputDecoration(
              labelText: 'Department *',
              errorText: errorText,
              errorMaxLines: 3,
              labelStyle: AppTextStyles.caption,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: AppColors.border),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
            ),
            child: selected == null
                ? const SizedBox(height: 22)
                : Text(selected.name, key: const Key('desig-dept-value'), style: AppTextStyles.body),
          ),
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    super.key,
    required this.icon,
    required this.message,
    this.isError = false,
    this.actionKey,
    this.actionLabel,
    this.onAction,
  });
  final IconData? icon;
  final String message;
  final bool isError;
  final Key? actionKey;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isError ? AppColors.error.withValues(alpha: 0.5) : AppColors.border),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 10,
        runSpacing: 6,
        children: [
          if (icon != null)
            Icon(icon, size: 18, color: color)
          else
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 0),
            child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: color)),
          ),
          if (onAction != null)
            TextButton(
              key: actionKey,
              onPressed: onAction,
              style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
              child: Text(actionLabel ?? ''),
            ),
        ],
      ),
    );
  }
}

class _DepartmentSheet extends StatefulWidget {
  const _DepartmentSheet({required this.departments, required this.selectedId});
  final List<DepartmentModel> departments;
  final int? selectedId;

  @override
  State<_DepartmentSheet> createState() => _DepartmentSheetState();
}

class _DepartmentSheetState extends State<_DepartmentSheet> {
  final _search = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final shown = widget.departments.where((d) => d.name.toLowerCase().contains(_q.trim().toLowerCase())).toList();
    return AnimatedPadding(
      duration: const Duration(milliseconds: 100),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: ConstrainedBox(
        // Never taller than the space above the keyboard.
        constraints: BoxConstraints(maxHeight: (media.size.height - media.viewInsets.bottom) * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
              child: Row(children: [
                Expanded(child: Text('Select Department', style: AppTextStyles.h4)),
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                key: const Key('dept-select-search'),
                controller: _search,
                style: AppTextStyles.body,
                onChanged: (v) => setState(() => _q = v),
                decoration: InputDecoration(
                  hintText: 'Search departments…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            Flexible(
              child: shown.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No departments match your search.',
                          key: const Key('dept-select-no-match'), style: AppTextStyles.bodySecondary),
                    )
                  : ListView.builder(
                      key: const Key('dept-select-list'),
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: shown.length,
                      itemBuilder: (_, i) {
                        final d = shown[i];
                        final selected = d.id == widget.selectedId;
                        return InkWell(
                          key: Key('dept-option-${d.id}'),
                          onTap: () => Navigator.pop(context, d.id),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 52),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(children: [
                                Expanded(
                                  child: Text(
                                    d.name,
                                    style: AppTextStyles.body.copyWith(
                                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                      color: d.isActive ? null : AppColors.textHint,
                                    ),
                                  ),
                                ),
                                if (!d.isActive)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Text('Inactive', style: AppTextStyles.caption),
                                  ),
                                if (selected)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(Icons.check_circle, size: 20, color: AppColors.primary),
                                  ),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

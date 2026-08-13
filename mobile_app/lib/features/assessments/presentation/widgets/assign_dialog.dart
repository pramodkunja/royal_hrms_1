import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import '../providers/assessments_providers.dart';

// Matches backend AssignAssessmentView's default template_name fallback.
const _kDefaultTemplateName = 'assessment_assigned';

// Ported from web's Assign modal (frontend/app/dashboard/assessments/page.tsx):
// notification template picker, search, select-all, multi-select employee
// checklist, then a sequential per-employee assign loop with aggregated
// success/failure reporting — same shape as web's doAssign().
class AssignDialog extends StatefulWidget {
  final AssessmentModel assessment;
  final WidgetRef ref;

  const AssignDialog({super.key, required this.assessment, required this.ref});

  @override
  State<AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<AssignDialog> {
  bool _loading = true;
  String? _loadError;
  List<AssignableEmployeeModel> _employees = const [];
  List<EmailTemplateOptionModel> _templateOptions = const [];

  final _searchCtrl = TextEditingController();
  String _search = '';
  String _templateName = _kDefaultTemplateName;
  final Set<String> _selectedIds = {};

  bool _assigning = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final employees = await widget.ref.read(assignableEmployeesProvider.future);
      final templates = await widget.ref.read(assignEmailTemplateOptionsProvider.future);
      if (!mounted) return;
      setState(() {
        _employees = employees;
        _templateOptions = templates;
        // Keep the default selected if it exists among the loaded options;
        // otherwise fall back to the first real option so the dropdown never
        // holds a value absent from its own item list.
        if (templates.isNotEmpty && !templates.any((t) => t.name == _templateName)) {
          _templateName = templates.first.name;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load employees.';
        _loading = false;
      });
    }
  }

  List<AssignableEmployeeModel> get _filtered {
    if (_search.isEmpty) return _employees;
    final q = _search.toLowerCase();
    return _employees
        .where((e) =>
            e.fullName.toLowerCase().contains(q) ||
            e.email.toLowerCase().contains(q) ||
            e.employeeId.toLowerCase().contains(q))
        .toList();
  }

  void _toggle(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final filtered = _filtered;
    setState(() {
      if (filtered.isNotEmpty && _selectedIds.length == filtered.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(filtered.map((e) => e.id));
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) {
      setState(() {
        _error = 'Select at least one employee.';
        _successMessage = null;
      });
      return;
    }
    setState(() {
      _assigning = true;
      _error = null;
      _successMessage = null;
    });

    var ok = 0;
    final errors = <String>[];
    for (final id in _selectedIds.toList()) {
      final result = await assignCandidateToAssessment(
        widget.ref,
        candidateId: id,
        assessmentId: widget.assessment.id,
        templateName: _templateName,
      );
      if (result == null) {
        ok++;
      } else {
        errors.add(result);
      }
    }

    if (!mounted) return;
    if (ok > 0) {
      unawaited(widget.ref.read(assessmentsProvider.notifier).refreshOne(widget.assessment.id));
    }
    setState(() {
      _assigning = false;
      if (errors.isEmpty) {
        _successMessage = 'Assigned to $ok employee${ok == 1 ? '' : 's'} successfully!';
        _selectedIds.clear();
      } else {
        _error = '$ok succeeded, ${errors.length} failed: ${errors.first}';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final allSelected = filtered.isNotEmpty && _selectedIds.length == filtered.length;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Assign Assessment',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(widget.assessment.title,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_successMessage != null) ...[
                      _Banner(message: _successMessage!, isError: false),
                      const SizedBox(height: 12),
                    ],
                    if (_error != null) ...[
                      _Banner(message: _error!, isError: true),
                      const SizedBox(height: 12),
                    ],

                    // Notification email template
                    Text('Notification Email Template',
                        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _templateName,
                      isExpanded: true,
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                      items: _templateOptions.isEmpty
                          ? const [
                              DropdownMenuItem(
                                value: _kDefaultTemplateName,
                                child: Text('Assessment Assigned (default)', overflow: TextOverflow.ellipsis),
                              ),
                            ]
                          : _templateOptions
                              .map((t) => DropdownMenuItem(
                                    value: t.name,
                                    child: Text(t.displayName, overflow: TextOverflow.ellipsis),
                                  ))
                              .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _templateName = v);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Search
                    TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v),
                      style: AppTextStyles.body,
                      decoration: InputDecoration(
                        hintText: 'Search by name, email or ID…',
                        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textHint),
                        prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textHint),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        isDense: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Select all / count
                    Row(
                      children: [
                        TextButton(
                          onPressed: filtered.isEmpty ? null : _toggleSelectAll,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(
                            allSelected ? 'Deselect All' : 'Select All',
                            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            '${_selectedIds.length} selected · ${filtered.length} shown',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Employee checklist
                    Container(
                      constraints: const BoxConstraints(maxHeight: 260),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _loading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : _loadError != null
                              ? Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Text(_loadError!,
                                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                                      textAlign: TextAlign.center),
                                )
                              : filtered.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Text(
                                        _employees.isEmpty ? 'No employees found.' : 'No employees match.',
                                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: filtered.length,
                                      separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.border),
                                      itemBuilder: (_, i) => _EmployeeRow(
                                        employee: filtered[i],
                                        checked: _selectedIds.contains(filtered[i].id),
                                        onTap: () => _toggle(filtered[i].id),
                                      ),
                                    ),
                    ),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                            child: const Text('Close'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: (_assigning || _selectedIds.isEmpty) ? null : _submit,
                            icon: _assigning
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.person_add_alt_1_outlined, size: 18),
                            label: Text(
                              _assigning
                                  ? 'Assigning…'
                                  : _selectedIds.isEmpty
                                      ? 'Assign'
                                      : 'Assign (${_selectedIds.length})',
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Employee row ──────────────────────────────────────────────────────────────

class _EmployeeRow extends StatelessWidget {
  final AssignableEmployeeModel employee;
  final bool checked;
  final VoidCallback onTap;

  const _EmployeeRow({required this.employee, required this.checked, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (employee.employeeId.isNotEmpty) employee.employeeId,
      employee.email,
      if (employee.department.isNotEmpty) employee.department,
    ];
    return Material(
      color: checked ? AppColors.primary.withValues(alpha: 0.07) : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: (_) => onTap(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      employee.fullName,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitleParts.join(' · '),
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────

class _Banner extends StatelessWidget {
  final String message;
  final bool isError;
  const _Banner({required this.message, required this.isError});

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.error : AppColors.success;
    final bg = isError ? AppColors.errorContainer : AppColors.successContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(isError ? Icons.warning_amber_rounded : Icons.check_circle_outline, size: 14, color: color),
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: AppTextStyles.bodySmall.copyWith(color: color))),
        ],
      ),
    );
  }
}

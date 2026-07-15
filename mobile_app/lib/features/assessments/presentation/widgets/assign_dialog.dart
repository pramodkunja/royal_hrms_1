import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/assessment_model.dart';
import '../providers/assessments_providers.dart';

class AssignDialog extends StatefulWidget {
  final AssessmentModel assessment;
  final WidgetRef ref;

  const AssignDialog({super.key, required this.assessment, required this.ref});

  @override
  State<AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends State<AssignDialog> {
  bool _loadingCandidates = true;
  String? _loadError;
  List<ReviewCandidateModel> _candidates = const [];

  int? _selectedCandidateId;
  bool _assigning = false;
  String? _error;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _loadCandidates();
  }

  Future<void> _loadCandidates() async {
    setState(() {
      _loadingCandidates = true;
      _loadError = null;
    });
    try {
      final candidates =
          await widget.ref.read(assessmentsDataSourceProvider).fetchReviewCandidates();
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _loadingCandidates = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Could not load candidates.';
        _loadingCandidates = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_selectedCandidateId == null) {
      setState(() {
        _error = 'Select a candidate.';
        _successMessage = null;
      });
      return;
    }
    setState(() {
      _assigning = true;
      _error = null;
      _successMessage = null;
    });
    final result = await assignCandidateToAssessment(
      widget.ref,
      candidateId: _selectedCandidateId!,
      assessmentId: widget.assessment.id,
    );
    if (!mounted) return;
    if (result == null) {
      unawaited(widget.ref.read(assessmentsProvider.notifier).refreshOne(widget.assessment.id));
      setState(() {
        _assigning = false;
        _selectedCandidateId = null;
        _successMessage = 'Assessment assigned successfully!';
      });
    } else {
      setState(() {
        _assigning = false;
        _error = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                    Text('Candidate *',
                        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    if (_loadingCandidates)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (_loadError != null)
                      Text(_loadError!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.error))
                    else
                      DropdownButtonFormField<int>(
                        initialValue: _selectedCandidateId,
                        isExpanded: true,
                        hint: Text('— Select candidate —',
                            style: AppTextStyles.body.copyWith(color: AppColors.textHint)),
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: _candidates
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text('${c.name} · ${c.email}', overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() {
                          _selectedCandidateId = v;
                          _error = null;
                        }),
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
                          child: FilledButton.icon(
                            onPressed: (_assigning || _loadingCandidates) ? null : _submit,
                            icon: _assigning
                                ? const SizedBox(
                                    width: 16, height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.person_add_alt_1_outlined, size: 18),
                            label: Text(_assigning ? 'Assigning…' : 'Assign'),
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

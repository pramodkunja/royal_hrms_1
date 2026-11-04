import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../domain/entities/wfh_daily_report_entity.dart';
import '../providers/wfh_report_providers.dart';
import '../wfh_report_strings.dart';

/// Reviewer controls for one pending report: Full Day / Half Day / Not
/// accepted, remarks (required for Not accepted), Save review. Shown only for
/// reports the server marks `can_review`.
class WfhReportReviewPanel extends ConsumerStatefulWidget {
  final WfhDailyReportEntity report;
  const WfhReportReviewPanel({super.key, required this.report});

  @override
  ConsumerState<WfhReportReviewPanel> createState() => _WfhReportReviewPanelState();
}

class _WfhReportReviewPanelState extends ConsumerState<WfhReportReviewPanel> {
  final _remarks = TextEditingController();
  WfhReportReviewStatus? _outcome;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return; // ignore repeat taps while saving
    final problem = wfhReviewError(_outcome, _remarks.text);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await reviewWfhReport(
      ref,
      id: widget.report.id,
      outcome: _outcome!,
      remarks: _remarks.text.trim(),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(WfhReportStrings.chooseOutcome, style: AppTextStyles.label),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final (value, label) in kWfhReviewOutcomes)
                ChoiceChip(
                  label: Text(label),
                  selected: _outcome == value,
                  onSelected: _busy ? null : (_) => setState(() => _outcome = value),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  labelStyle: AppTextStyles.labelSmall,
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            key: Key('wfh-review-remarks-${widget.report.id}'),
            controller: _remarks,
            enabled: !_busy,
            maxLines: 2,
            decoration: const InputDecoration(hintText: WfhReportStrings.remarks),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(_error!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            ),
          const SizedBox(height: 8),
          AppButton(
            label: WfhReportStrings.saveReview,
            onPressed: _busy ? null : _save,
            isLoading: _busy,
          ),
        ],
      ),
    );
  }
}

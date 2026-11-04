import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/wfh_report_providers.dart';
import '../wfh_report_strings.dart';
import 'wfh_report_section.dart';

/// "Today's Work Report": date (today or earlier — the backend refuses future
/// dates), work completed (required), pending work and updates. Submitting the
/// same day again updates that report while it is still pending review.
class WfhReportForm extends ConsumerStatefulWidget {
  /// Injectable clock for tests; defaults to the device's local time.
  final DateTime Function() now;

  const WfhReportForm({super.key, this.now = DateTime.now});

  @override
  ConsumerState<WfhReportForm> createState() => _WfhReportFormState();
}

class _WfhReportFormState extends ConsumerState<WfhReportForm> {
  final _completed = TextEditingController();
  final _pending = TextEditingController();
  final _updates = TextEditingController();
  late DateTime _date = _today();
  bool _busy = false;
  ({bool ok, String text})? _message;

  DateTime _today() {
    final n = widget.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _completed.dispose();
    _pending.dispose();
    _updates.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(today) ? today : _date,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_busy) return; // a second tap while a request is in flight is ignored
    final problem = wfhReportFormError(
      completed: _completed.text,
      pending: _pending.text,
      updates: _updates.text,
    );
    if (problem != null) {
      setState(() => _message = (ok: false, text: problem));
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    final result = await submitWfhReport(
      ref,
      date: wfhReportIsoDate(_date),
      completedWork: _completed.text,
      pendingWork: _pending.text,
      updates: _updates.text,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = (ok: result.ok, text: result.message);
      if (result.ok) {
        _completed.clear();
        _pending.clear();
        _updates.clear();
      }
    });
  }

  Widget _field(String label, TextEditingController c, int lines, {bool required = false}) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(required ? '$label *' : label, style: AppTextStyles.label),
            const SizedBox(height: 6),
            TextField(
              controller: c,
              enabled: !_busy,
              minLines: lines,
              maxLines: lines + 3,
              maxLength: kWfhReportMaxLength,
              decoration: const InputDecoration(counterText: ''),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final msg = _message;
    return WfhReportSection(
      title: WfhReportStrings.formTitle,
      icon: Icons.assignment_outlined,
      children: [
        Text(WfhReportStrings.formHint, style: AppTextStyles.bodySecondary.copyWith(fontSize: 12.5)),
        const SizedBox(height: 12),
        Text(WfhReportStrings.date, style: AppTextStyles.label),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          key: const Key('wfh-report-date'),
          onPressed: _busy ? null : _pickDate,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(wfhReportIsoDate(_date), style: AppTextStyles.body),
        ),
        _field(WfhReportStrings.completed, _completed, 3, required: true),
        _field(WfhReportStrings.pending, _pending, 2),
        _field(WfhReportStrings.updates, _updates, 2),
        if (msg != null) ...[
          const SizedBox(height: 12),
          WfhReportNotice(text: msg.text, ok: msg.ok),
        ],
        const SizedBox(height: 16),
        AppButton(
          label: WfhReportStrings.submit,
          onPressed: _busy ? null : _submit,
          isLoading: _busy,
          leadingIcon: Icons.send_outlined,
        ),
      ],
    );
  }
}

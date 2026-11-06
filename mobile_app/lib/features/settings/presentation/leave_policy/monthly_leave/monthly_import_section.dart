import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../data/models/monthly_leave_models.dart';
import 'monthly_leave_providers.dart';
import 'monthly_leave_widgets.dart';

/// Web MonthlyImportSection: month/year, sample files, a .csv/.xlsx (≤ 5 MB)
/// previewed with dry_run (nothing saved), then "Confirm import (N)".
class MonthlyImportSection extends ConsumerStatefulWidget {
  const MonthlyImportSection({super.key});

  @override
  ConsumerState<MonthlyImportSection> createState() => _MonthlyImportSectionState();
}

class _MonthlyImportSectionState extends ConsumerState<MonthlyImportSection> {
  late final DateTime _today = ref.read(monthlyLeaveClockProvider)();
  late int _month = _today.month;
  late int _year = _today.year;
  PickedFile? _file;
  MonthlyPlan? _preview;
  MonthlyApplyResult? _result;
  String? _busy; // 'preview' | 'import'
  String? _sampleBusy; // 'csv' | 'xlsx'
  String? _error;

  void _reset() => setState(() {
        _file = null;
        _preview = null;
        _result = null;
        _error = null;
      });

  Future<void> _pick() async {
    final f = await ref.read(monthlyImportFilePickerProvider)();
    if (!mounted || f == null) return;
    setState(() {
      _preview = null;
      _result = null;
      _error = null;
      final name = f.name.toLowerCase();
      if (!name.endsWith('.csv') && !name.endsWith('.xlsx')) {
        _error = 'Upload a .csv or .xlsx file.';
      } else if (f.size > kMonthlyImportMaxBytes) {
        _error = 'File must not exceed 5 MB.';
      } else {
        _file = f;
      }
    });
  }

  Future<void> _sample(String format) async {
    if (_sampleBusy != null) return;
    setState(() => _sampleBusy = format);
    try {
      final bytes = await ref.read(monthlyLeaveServiceProvider).sample(format);
      await ref.read(monthlySampleSaverProvider)('monthly_leave_credit_sample.$format', Uint8List.fromList(bytes));
    } on MonthlyLeaveBusy {
      // already downloading
    } catch (e) {
      if (mounted) setState(() => _error = monthlyLeaveError(e, 'Failed to download the sample.'));
    } finally {
      if (mounted) setState(() => _sampleBusy = null);
    }
  }

  Future<void> _send({required bool dryRun}) async {
    final file = _file;
    if (file == null || _busy != null) return;
    setState(() {
      _busy = dryRun ? 'preview' : 'import';
      _error = null;
    });
    final service = ref.read(monthlyLeaveServiceProvider);
    try {
      if (dryRun) {
        final p = await service.importPreview(file, _year, _month);
        if (mounted) {
          setState(() {
            _preview = p;
            _result = null;
          });
        }
      } else {
        final r = await service.importApply(file, _year, _month);
        if (mounted) {
          setState(() {
            _result = r;
            _preview = null;
          });
        }
      }
    } on MonthlyLeaveBusy {
      // the same import is already running
    } catch (e) {
      if (mounted) {
        setState(() => _error = monthlyLeaveError(
            e, dryRun ? 'Could not preview the file.' : 'Import failed. Nothing was changed for rows that failed.'));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preview = _preview, result = _result;
    final muted = AppTextStyles.bodySmall.copyWith(fontSize: 12.5, color: AppColors.textSecondary);
    return Column(
      key: const Key('monthly-import'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Set each employee's leave credit for one month. Columns: Employee Code, Leave Type, Monthly Leave "
          "Credit. Re-importing the same file changes nothing; a different value replaces the month's credit, "
          'and 0 removes it.',
          style: muted,
        ),
        const SizedBox(height: 12),
        MonthYearFields(
          keyPrefix: 'import-',
          month: _month,
          year: _year,
          years: creditYears(_today),
          disabled: _busy != null || preview != null,
          onMonth: (m) => setState(() {
            _month = m;
            _preview = null;
            _result = null;
          }),
          onYear: (y) => setState(() {
            _year = y;
            _preview = null;
            _result = null;
          }),
        ),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          for (final f in const ['csv', 'xlsx'])
            OutlinedButton.icon(
              key: Key('import-sample-$f'),
              onPressed: _sampleBusy != null ? null : () => _sample(f),
              icon: const Icon(Icons.download_outlined, size: 16),
              label: Text(_sampleBusy == f ? 'Downloading…' : (f == 'csv' ? 'Sample CSV' : 'Sample Excel')),
            ),
          OutlinedButton.icon(
            key: const Key('import-choose-file'),
            onPressed: _busy != null ? null : _pick,
            icon: const Icon(Icons.upload_file_outlined, size: 16),
            label: Text(_file != null ? 'Choose another file' : 'Choose CSV / Excel file'),
          ),
          if (_file != null) Text(_file!.name, key: const Key('import-file-name'), style: AppTextStyles.bodySmall),
        ]),
        if (_error != null) ...[
          const SizedBox(height: 10),
          MonthlyAlert(key: const Key('import-error'), kind: MonthlyAlertKind.error, text: _error!),
        ],
        const SizedBox(height: 12),
        if (preview == null && result == null)
          FilledButton.icon(
            key: const Key('import-preview'),
            onPressed: _file == null || _busy != null ? null : () => _send(dryRun: true),
            icon: _busy == 'preview' ? monthlySpinner() : const Icon(Icons.visibility_outlined, size: 16),
            label: Text(_busy == 'preview' ? 'Checking…' : 'Preview'),
          ),
        if (preview != null) ...[
          MonthlyAlert(
            key: const Key('import-preview-summary'),
            kind: preview.count('error') > 0 ? MonthlyAlertKind.warn : MonthlyAlertKind.info,
            text: 'Preview for ${kMonthNames[(preview.month - 1).clamp(0, 11)]} ${preview.year} (nothing saved yet): '
                '${preview.count('new')} new, ${preview.count('update')} update, ${preview.count('unchanged')} '
                'unchanged, ${preview.count('duplicate')} duplicate, ${preview.count('error')} error. Only new and '
                'update rows will be applied.',
          ),
          const SizedBox(height: 8),
          AnnualWarning(types: annualWarningTypes(preview.rows, preview.annualEntitlements)),
          const SizedBox(height: 8),
          MonthlyRowsList(rows: preview.rows),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            TextButton(onPressed: _busy != null ? null : _reset, child: const Text('Cancel')),
            const SizedBox(width: 8),
            FilledButton.icon(
              key: const Key('import-confirm'),
              onPressed: _busy != null || preview.applicable == 0 ? null : () => _send(dryRun: false),
              icon: _busy == 'import' ? monthlySpinner() : const Icon(Icons.check, size: 16),
              label: Text(_busy == 'import' ? 'Importing…' : 'Confirm import (${preview.applicable})'),
            ),
          ]),
        ],
        if (result != null) ...[
          MonthlyAlert(
            key: const Key('import-result'),
            kind: result.failed > 0 ? MonthlyAlertKind.warn : MonthlyAlertKind.success,
            text: 'Import for ${kMonthNames[(result.month - 1).clamp(0, 11)]} ${result.year} finished: '
                '${result.created} added, ${result.updated} updated, ${result.skipped} skipped, ${result.failed} '
                'failed (of ${result.total} rows). Failed rows changed nothing.',
          ),
          const SizedBox(height: 8),
          MonthlyRowsList(rows: result.rows),
          TextButton(key: const Key('import-another'), onPressed: _reset, child: const Text('Import another file')),
        ],
      ],
    );
  }
}

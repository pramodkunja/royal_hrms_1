import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/notice_period_models.dart';
import '../leave_policy/monthly_leave/monthly_leave_providers.dart' show PickedFile;
import 'notice_period_providers.dart';

Future<void> showNoticeImportDialog(BuildContext context) => showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const NoticeImportDialog(),
    );

/// Web NoticePeriodImportModal: sample files, a .csv/.xlsx (≤ 5 MB) previewed
/// with dry_run (nothing saved), an explicit "Yes, update N employee(s)"
/// confirmation, then the per-row result. The server checks every row again
/// on the confirm request.
class NoticeImportDialog extends ConsumerStatefulWidget {
  const NoticeImportDialog({super.key});

  @override
  ConsumerState<NoticeImportDialog> createState() => _NoticeImportDialogState();
}

class _NoticeImportDialogState extends ConsumerState<NoticeImportDialog> {
  PickedFile? _file;
  NoticeImportResult? _preview;
  bool _confirming = false;
  NoticeImportResult? _result;
  String? _busy; // 'preview' | 'save'
  String? _sampleBusy; // 'csv' | 'xlsx'
  String? _error;

  void _reset() => setState(() {
        _file = null;
        _preview = null;
        _confirming = false;
        _result = null;
        _error = null;
      });

  Future<void> _pick() async {
    if (_busy != null) return;
    final f = await ref.read(noticeImportFilePickerProvider)();
    if (!mounted) return;
    setState(() {
      _preview = null;
      _confirming = false;
      _result = null;
      _error = null;
      if (f == null) return;
      final problem = checkNoticeImportFile(f);
      if (problem != null) {
        _error = problem;
        _file = null;
      } else {
        _file = f;
      }
    });
  }

  Future<void> _sample(String format) async {
    if (_sampleBusy != null) return;
    setState(() => _sampleBusy = format);
    try {
      final bytes = await ref.read(noticePeriodServiceProvider).sample(format);
      await ref.read(noticeSampleSaverProvider)('notice_period_import_sample.$format', Uint8List.fromList(bytes));
    } on NoticePeriodBusy {
      // another request is running
    } catch (e) {
      if (mounted) setState(() => _error = noticePeriodError(e, 'Failed to download the sample.'));
    } finally {
      if (mounted) setState(() => _sampleBusy = null);
    }
  }

  Future<void> _send({required bool dryRun}) async {
    final file = _file;
    if (file == null || _busy != null) return;
    setState(() {
      _busy = dryRun ? 'preview' : 'save';
      _error = null;
    });
    final service = ref.read(noticePeriodServiceProvider);
    try {
      if (dryRun) {
        final r = await service.preview(file);
        if (mounted) setState(() => _preview = r);
      } else {
        final r = await service.apply(file);
        if (mounted) {
          setState(() {
            _result = r;
            _preview = null;
            _confirming = false;
          });
        }
      }
    } on NoticePeriodBusy {
      // another request is running
    } catch (e) {
      if (mounted) {
        setState(() {
          _confirming = false;
          _error = noticePeriodError(e, dryRun ? 'Could not check the file.' : 'Import failed.');
        });
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _busy != null;
    final preview = _preview;
    final result = _result;
    final toUpdate = preview?.summary.update ?? 0;

    return PopScope(
      canPop: !busy,
      child: Dialog.fullscreen(
        key: const Key('notice-import-dialog'),
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: const Text('Import Notice Periods'),
            leading: IconButton(
              key: const Key('notice-import-close'),
              icon: const Icon(Icons.close),
              onPressed: busy ? null : () => Navigator.of(context).pop(),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (preview == null && result == null) ...[
                Text(
                  'Upload a CSV or Excel (.xlsx) file with columns Employee ID and Notice Period (days) — up to '
                  '1000 rows, 5 MB. Notice period is a whole number of days from 0 to 365. A blank notice period '
                  'leaves that employee unchanged. Nothing is saved until you confirm.',
                  style: AppTextStyles.bodySecondary.copyWith(fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (final f in const ['csv', 'xlsx'])
                      OutlinedButton.icon(
                        key: Key('notice-sample-$f'),
                        onPressed: _sampleBusy != null ? null : () => _sample(f),
                        icon: const Icon(Icons.download_outlined, size: 16),
                        label: Text(_sampleBusy == f
                            ? 'Downloading…'
                            : (f == 'csv' ? 'Download Sample CSV' : 'Download Sample Excel')),
                      ),
                    OutlinedButton.icon(
                      key: const Key('notice-import-pick'),
                      onPressed: busy ? null : _pick,
                      icon: const Icon(Icons.upload_outlined, size: 16),
                      label: Text(_file == null ? 'Choose CSV / Excel file' : 'Choose another file'),
                    ),
                  ],
                ),
                if (_file case final f?) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(f.name, key: const Key('notice-import-file'))),
                  ]),
                ],
              ],
              if (_error case final e?) ...[
                const SizedBox(height: 12),
                _Alert(key: const Key('notice-import-error'), color: AppColors.error, text: e),
              ],
              if (preview != null) ...[
                const SizedBox(height: 4),
                _Alert(
                  key: const Key('notice-import-preview-summary'),
                  color: preview.summary.error > 0 ? AppColors.warning : AppColors.info,
                  text: 'Preview (nothing saved yet): ${preview.summary.update} to update, '
                      '${preview.summary.noChange} no change, ${preview.summary.skipped} skipped, '
                      '${preview.summary.error} with errors. Only “Will update” rows are saved.',
                ),
                if (_confirming) ...[
                  const SizedBox(height: 8),
                  _Alert(
                    key: const Key('notice-import-confirm-text'),
                    color: AppColors.warning,
                    text: 'Update the notice period of $toUpdate employee(s)? Every row is checked again before '
                        'saving; anything that changed since this preview is reported instead of saved.',
                  ),
                ],
                const SizedBox(height: 10),
                _Rows(rows: preview.rows),
              ],
              if (result != null) ...[
                _Alert(
                  key: const Key('notice-import-result-summary'),
                  color: result.summary.error > 0 ? AppColors.warning : AppColors.success,
                  text: 'Finished: ${result.summary.updated ?? 0} updated, ${result.summary.noChange} no change, '
                      '${result.summary.skipped} skipped, ${result.summary.error} with errors '
                      '(of ${result.summary.total} rows).',
                ),
                const SizedBox(height: 10),
                _Rows(rows: result.rows),
              ],
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: _footer(busy, preview, result, toUpdate),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _footer(bool busy, NoticeImportResult? preview, NoticeImportResult? result, int toUpdate) {
    Widget ghost(String key, String label, VoidCallback? onTap) =>
        TextButton(key: Key(key), onPressed: onTap, child: Text(label));
    Widget filled(String key, String label, VoidCallback? onTap) => Flexible(
          child: FilledButton(key: Key(key), onPressed: onTap, child: Text(label, textAlign: TextAlign.center)),
        );
    if (result != null) {
      return [
        ghost('notice-import-another', 'Import another file', _reset),
        const SizedBox(width: 8),
        filled('notice-import-done', 'Done', () => Navigator.of(context).pop()),
      ];
    }
    if (preview != null && _confirming) {
      return [
        ghost('notice-import-back', 'Back', busy ? null : () => setState(() => _confirming = false)),
        const SizedBox(width: 8),
        filled('notice-import-confirm', _busy == 'save' ? 'Saving…' : 'Yes, update $toUpdate employee(s)',
            busy ? null : () => _send(dryRun: false)),
      ];
    }
    if (preview != null) {
      return [
        ghost('notice-import-cancel', 'Cancel', busy ? null : _reset),
        const SizedBox(width: 8),
        filled('notice-import-update', 'Update $toUpdate employee(s)…',
            busy || toUpdate == 0 ? null : () => setState(() => _confirming = true)),
      ];
    }
    return [
      ghost('notice-import-cancel', 'Cancel', busy ? null : () => Navigator.of(context).pop()),
      const SizedBox(width: 8),
      filled('notice-import-preview', _busy == 'preview' ? 'Checking…' : 'Preview',
          _file == null || busy ? null : () => _send(dryRun: true)),
    ];
  }
}

class _Alert extends StatelessWidget {
  const _Alert({super.key, required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(text, style: AppTextStyles.caption.copyWith(color: AppColors.textPrimary, fontSize: 12)),
      );
}

/// Web Rows: Row, Employee, Notice Period, Status, Details — as cards.
class _Rows extends StatelessWidget {
  const _Rows({required this.rows});
  final List<NoticeImportRow> rows;

  static Color _color(String status) => switch (status) {
        'update' || 'updated' => AppColors.success,
        'skipped' => AppColors.warning,
        'error' => AppColors.error,
        _ => AppColors.textSecondary,
      };

  @override
  Widget build(BuildContext context) => Column(
        children: [
          for (final r in rows)
            Container(
              key: Key('notice-import-row-${r.row}'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Row ${r.row}', style: AppTextStyles.caption.copyWith(fontSize: 11)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r.employeeText,
                            style: AppTextStyles.label.copyWith(fontSize: 13), overflow: TextOverflow.ellipsis),
                      ),
                      Text(r.statusLabel,
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 11, fontWeight: FontWeight.w700, color: _color(r.status))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(r.changeText, style: AppTextStyles.body.copyWith(fontSize: 12)),
                  if (r.details.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(r.details, style: AppTextStyles.caption.copyWith(fontSize: 11)),
                  ],
                ],
              ),
            ),
        ],
      );
}

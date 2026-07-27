import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/leave_import_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';

enum _Phase { upload, preview, result }

const _kRequiredCols = ['Employee ID', 'Leave Type', 'Financial Year'];
const _kBalanceCols = ['Opening Balance', 'Leave Allocated', 'Leave Availed', 'Carry Forward Days'];
const _kHistoryCols = ['From Date', 'To Date', 'Total Days'];

// One-time historical migration tool — mirrors web's
// OpeningBalanceImportModal.tsx (upload → validate/preview → import phases),
// ported to a full-screen flow instead of a modal to fit mobile scroll depth.
class LeaveBalanceImportScreen extends ConsumerStatefulWidget {
  const LeaveBalanceImportScreen({super.key});

  @override
  ConsumerState<LeaveBalanceImportScreen> createState() => _LeaveBalanceImportScreenState();
}

class _LeaveBalanceImportScreenState extends ConsumerState<LeaveBalanceImportScreen> {
  _Phase _phase = _Phase.upload;
  PlatformFile? _picked;
  String? _pickError;
  bool _validating = false;
  bool _importing = false;
  String? _sampleDownloading;
  String? _apiError;
  LeaveImportValidateResult? _preview;
  LeaveImportResult? _result;

  static const _maxBytes = 5 * 1024 * 1024;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Import Leave Balances & History'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              switch (_phase) {
                _Phase.upload => _buildUploadPhase(),
                _Phase.preview => _buildPreviewPhase(),
                _Phase.result => _buildResultPhase(),
              },
            ],
          ),
        ),
      ),
    );
  }

  // ── Phase: upload ────────────────────────────────────────────────────────

  Widget _buildUploadPhase() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoCard(
          onDownloadSample: _downloadSample,
          downloading: _sampleDownloading,
        ),
        const SizedBox(height: 16),
        _FilePickerCard(picked: _picked, error: _pickError, onPick: _pickFile),
        if (_apiError != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: _apiError!),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: (_picked == null || _validating) ? null : _validate,
            icon: _validating
                ? const SizedBox(
                    width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.search, size: 18),
            label: Text(_validating ? 'Validating…' : 'Validate File',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _downloadSample(String format) async {
    setState(() => _sampleDownloading = format);
    try {
      final bytes = await ref
          .read(settingsDataSourceProvider)
          .downloadLeaveBalanceImportSample(format);
      final path = await FilePicker.platform.saveFile(
        fileName: 'leave_opening_balance_sample.$format',
        bytes: Uint8List.fromList(bytes),
        type: FileType.custom,
        allowedExtensions: [format],
      );
      if (!mounted) return;
      if (path != null) {
        _toast('Sample downloaded.', true);
      }
    } catch (e) {
      if (!mounted) return;
      _toast(friendlySettingsError(e), false);
    } finally {
      if (mounted) setState(() => _sampleDownloading = null);
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > _maxBytes) {
      setState(() { _pickError = 'File is too large. Maximum allowed size is 5 MB.'; _picked = null; });
      return;
    }
    setState(() {
      _picked = file;
      _pickError = null;
      _apiError = null;
      _preview = null;
      _result = null;
    });
  }

  Future<void> _validate() async {
    final file = _picked;
    if (file == null || file.bytes == null) return;
    setState(() { _validating = true; _apiError = null; });
    try {
      final preview = await ref
          .read(settingsDataSourceProvider)
          .validateLeaveBalanceImport(file.bytes!, file.name);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _phase = _Phase.preview;
        _validating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _validating = false; _apiError = friendlySettingsError(e); });
    }
  }

  // ── Phase: preview ───────────────────────────────────────────────────────

  Widget _buildPreviewPhase() {
    final preview = _preview!;
    final hasErrors = preview.errorRows > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: (hasErrors ? AppColors.warning : AppColors.success).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: (hasErrors ? AppColors.warning : AppColors.success).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(hasErrors ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      size: 18, color: hasErrors ? AppColors.warning : AppColors.success),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${preview.validRows} of ${preview.totalRows} rows ready to import',
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              if (hasErrors) ...[
                const SizedBox(height: 4),
                Text('${preview.errorRows} rows have errors and will be skipped',
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary)),
              ],
              const SizedBox(height: 6),
              Text(
                '${preview.balanceRows} balance row${preview.balanceRows == 1 ? '' : 's'} · '
                '${preview.historyRows} history row${preview.historyRows == 1 ? '' : 's'}',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (_apiError != null) ...[
          _ErrorBanner(message: _apiError!),
          const SizedBox(height: 12),
        ],
        ...preview.preview.map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PreviewRowCard(row: row),
            )),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _importing ? null : () => setState(() {
                  _phase = _Phase.upload;
                  _preview = null;
                  _apiError = null;
                }),
                icon: const Icon(Icons.arrow_back, size: 16),
                label: const Text('Change File'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: (preview.validRows == 0 || _importing) ? null : _import,
                icon: _importing
                    ? const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.file_upload_outlined, size: 18),
                label: Text(
                  _importing ? 'Importing…' : 'Import ${preview.validRows} row${preview.validRows == 1 ? '' : 's'}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _import() async {
    final file = _picked;
    if (file == null || file.bytes == null) return;
    setState(() { _importing = true; _apiError = null; });
    try {
      final result = await ref
          .read(settingsDataSourceProvider)
          .importLeaveBalanceFile(file.bytes!, file.name);
      if (!mounted) return;
      setState(() { _result = result; _phase = _Phase.result; _importing = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _importing = false; _apiError = friendlySettingsError(e); });
    }
  }

  // ── Phase: result ────────────────────────────────────────────────────────

  Widget _buildResultPhase() {
    final result = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatChip(label: 'Total', value: result.totalRecords, color: AppColors.textSecondary),
            _StatChip(label: 'Balances', value: result.balancesCreated, color: AppColors.success),
            _StatChip(label: 'History', value: result.historyImported, color: AppColors.success),
            _StatChip(label: 'Skipped', value: result.skipped, color: AppColors.warning),
            _StatChip(label: 'Failed', value: result.failed, color: AppColors.error),
          ],
        ),
        if (result.errors.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            'Errors (${result.errors.length}${result.errors.length >= 100 ? '+' : ''})',
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.error),
          ),
          const SizedBox(height: 8),
          ...result.errors.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ErrorRowCard(error: e),
              )),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => setState(() {
              _phase = _Phase.upload;
              _picked = null;
              _preview = null;
              _result = null;
              _apiError = null;
            }),
            child: const Text('Import Another File'),
          ),
        ),
      ],
    );
  }

  void _toast(String msg, bool ok) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Info card ───────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final ValueChanged<String> onDownloadSample;
  final String? downloading;
  const _InfoCard({required this.onDownloadSample, this.downloading});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text('One-Time Historical Migration',
                    style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Use this to onboard existing employees or migrate from another HRMS. '
            'Each row is either a Balance row (annual totals) or a History row '
            '(individual leave dates). Leave the unused columns blank for each row type.',
            style: AppTextStyles.caption.copyWith(fontSize: 11.5, height: 1.5),
          ),
          const SizedBox(height: 10),
          Text('Required on all rows', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: _kRequiredCols.map((c) => _ColChip(c, color: AppColors.primary)).toList()),
          const SizedBox(height: 8),
          Text('Balance columns', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: _kBalanceCols.map((c) => _ColChip(c, color: AppColors.textSecondary)).toList()),
          const SizedBox(height: 8),
          Text('History columns', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: _kHistoryCols.map((c) => _ColChip(c, color: AppColors.textSecondary)).toList()),
          const SizedBox(height: 10),
          Text('Accepted: .csv, .xlsx (max 5 MB). Duplicate balances and overlapping dates are skipped.',
              style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.textHint)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: downloading != null ? null : () => onDownloadSample('csv'),
                icon: downloading == 'csv'
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined, size: 14),
                label: Text(downloading == 'csv' ? 'Downloading…' : 'Sample CSV', style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: downloading != null ? null : () => onDownloadSample('xlsx'),
                icon: downloading == 'xlsx'
                    ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_outlined, size: 14),
                label: Text(downloading == 'xlsx' ? 'Downloading…' : 'Sample XLSX', style: const TextStyle(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: Size.zero,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColChip extends StatelessWidget {
  final String label;
  final Color color;
  const _ColChip(this.label, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── File picker card ─────────────────────────────────────────────────────────

class _FilePickerCard extends StatelessWidget {
  final PlatformFile? picked;
  final String? error;
  final VoidCallback onPick;
  const _FilePickerCard({required this.picked, required this.error, required this.onPick});

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: error != null ? AppColors.error : (picked != null ? AppColors.primary : AppColors.border),
            width: picked != null ? 1.5 : 1,
          ),
        ),
        child: picked == null
            ? Column(
                children: [
                  Icon(Icons.cloud_upload_outlined, size: 36,
                      color: error != null ? AppColors.error : AppColors.textHint),
                  const SizedBox(height: 8),
                  Text('Tap to select CSV or XLSX file',
                      style: AppTextStyles.label.copyWith(
                          color: error != null ? AppColors.error : AppColors.textSecondary)),
                  if (error != null) ...[
                    const SizedBox(height: 2),
                    Text(error!, style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 10),
                        textAlign: TextAlign.center),
                  ],
                ],
              )
            : Row(
                children: [
                  Icon(Icons.insert_drive_file_outlined, size: 28, color: AppColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(picked!.name, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(_formatSize(picked!.size), style: AppTextStyles.caption.copyWith(fontSize: 10)),
                      ],
                    ),
                  ),
                  Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                ],
              ),
      ),
    );
  }
}

// ── Preview row card ──────────────────────────────────────────────────────────

class _PreviewRowCard extends StatelessWidget {
  final LeaveImportPreviewRow row;
  const _PreviewRowCard({required this.row});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: row.valid ? AppColors.border : AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (row.isHistory ? AppColors.primary : AppColors.secondary).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(row.rowType,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                        color: row.isHistory ? AppColors.primary : AppColors.secondary)),
              ),
              const SizedBox(width: 6),
              Text('Row ${row.row}', style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.textHint)),
              const Spacer(),
              if (row.valid)
                Icon(Icons.check_circle, size: 15, color: AppColors.success)
              else
                Icon(Icons.error_outline, size: 15, color: AppColors.error),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${row.employeeId.isEmpty ? '—' : row.employeeId} · ${row.leaveType.isEmpty ? '—' : row.leaveType}',
            style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 11.5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            row.isHistory
                ? '${row.fromDate ?? '—'} → ${row.toDate ?? '—'}${row.days != null ? ' · ${row.days} day(s)' : ''}'
                : row.financialYear.isEmpty ? '—' : row.financialYear,
            style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.textHint),
          ),
          if (!row.valid && row.error != null) ...[
            const SizedBox(height: 4),
            Text(row.error!, style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.error)),
          ],
        ],
      ),
    );
  }
}

// ── Result widgets ────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 84),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 10, color: color)),
        ],
      ),
    );
  }
}

class _ErrorRowCard extends StatelessWidget {
  final LeaveImportRowError error;
  const _ErrorRowCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('Row ${error.row}',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.error)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${error.employeeId.isEmpty ? '—' : error.employeeId} · ${error.leaveType.isEmpty ? '—' : error.leaveType}',
                    style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w600, fontSize: 11)),
                Text(error.reason, style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 14, color: AppColors.error),
          const SizedBox(width: 6),
          Expanded(child: Text(message, style: AppTextStyles.caption.copyWith(color: AppColors.error))),
        ],
      ),
    );
  }
}

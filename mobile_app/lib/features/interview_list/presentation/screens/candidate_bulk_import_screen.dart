import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../shared/models/bulk_import_result.dart';
import '../../../../shared/widgets/bulk_import_result_view.dart';
import '../providers/interview_providers.dart';

const _kMaxImportBytes = 5 * 1024 * 1024;

class CandidateBulkImportScreen extends ConsumerStatefulWidget {
  const CandidateBulkImportScreen({super.key});

  @override
  ConsumerState<CandidateBulkImportScreen> createState() => _CandidateBulkImportScreenState();
}

class _CandidateBulkImportScreenState extends ConsumerState<CandidateBulkImportScreen> {
  PlatformFile? _picked;
  String? _pickError;
  bool _uploading = false;
  BulkImportResult? _result;
  String? _uploadError;

  // Web CandidateBulkImportModal: "Sample CSV" / "Sample XLSX" — both
  // disabled while either downloads; a failure is shown under them.
  String? _sampleDownloading;
  String? _sampleError;

  bool get _allowed => canOpenCandidateBulkImport(ref.read(authStateProvider).valueOrNull?.user);

  Future<void> _downloadSample(String format) async {
    if (_sampleDownloading != null || !_allowed) return;
    setState(() {
      _sampleDownloading = format;
      _sampleError = null;
    });
    try {
      final bytes = await ref.read(interviewDataSourceProvider).fetchBulkImportSample(format);
      final path = await ref.read(candidateSampleSaverProvider)(
          'candidate_import_sample.$format', Uint8List.fromList(bytes));
      if (!mounted) return;
      if (path != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Sample downloaded.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (!mounted) return;
      final msg = _friendly(e);
      setState(() => _sampleError = msg.isEmpty ? 'Failed to download sample file.' : msg);
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
    if (file.size > _kMaxImportBytes) {
      // Web validateFile wording.
      setState(() { _pickError = 'File is too large. Maximum allowed size is 5 MB.'; _picked = null; });
      return;
    }
    setState(() {
      _picked = file;
      _pickError = null;
      _result = null;
      _uploadError = null;
    });
  }

  Future<void> _upload() async {
    final file = _picked;
    if (file == null || file.bytes == null || !_allowed) return;
    setState(() { _uploading = true; _uploadError = null; });
    try {
      final result = await ref.read(interviewDataSourceProvider).bulkImport(
            bytes: file.bytes!,
            filename: file.name,
          );
      if (!mounted) return;
      setState(() { _result = result; _uploading = false; });
      if (result.created > 0) {
        await ref.read(candidateListProvider.notifier).refresh();
        await ref.read(candidateStatsProvider.notifier).refresh();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() { _uploading = false; _uploadError = _friendly(e); });
    }
  }

  void _reset() {
    setState(() {
      _picked = null;
      _pickError = null;
      _result = null;
      _uploadError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Reached without web's canCreate (e.g. a link, or settings.edit alone,
    // which the router lets through): nothing to pick, download or import.
    if (!canOpenCandidateBulkImport(ref.watch(authStateProvider).valueOrNull?.user)) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Bulk Import Candidates')),
        body: Center(
          key: const Key('candidate-import-denied'),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline, size: 40, color: AppColors.textHint),
              const SizedBox(height: 12),
              Text(kCandidateImportDenied,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.label.copyWith(color: AppColors.textSecondary)),
            ]),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Bulk Import Candidates')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoCard(
                samples: Row(children: [
                  for (final format in const ['csv', 'xlsx']) ...[
                    OutlinedButton.icon(
                      key: Key('candidate-sample-$format'),
                      onPressed: _sampleDownloading != null ? null : () => _downloadSample(format),
                      icon: _sampleDownloading == format
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.download_outlined, size: 16),
                      label: Text(_sampleDownloading == format ? 'Downloading…' : 'Sample ${format.toUpperCase()}'),
                    ),
                    const SizedBox(width: 10),
                  ],
                ]),
                sampleError: _sampleError,
              ),
              const SizedBox(height: 16),
              _FilePickerCard(picked: _picked, error: _pickError, onPick: _pickFile),
              const SizedBox(height: 16),
              if (_uploadError != null) ...[
                _ErrorBanner(message: _uploadError!),
                const SizedBox(height: 12),
              ],
              Row(
                children: [
                  if (_result != null || _picked != null) ...[
                    OutlinedButton(
                      onPressed: _uploading ? null : _reset,
                      child: const Text('Reset'),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: (_picked == null || _uploading) ? null : _upload,
                      icon: _uploading
                          ? const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file_outlined, size: 18),
                      label: Text(_uploading ? 'Importing…' : 'Import',
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                    ),
                  ),
                ],
              ),
              if (_result != null) ...[
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.cardShadow,
                  ),
                  child: BulkImportResultView(result: _result!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Web CandidateBulkImportModal "File Requirements": accepted formats and
/// size, required columns (as chips), optional columns (plain), then the
/// Sample CSV / Sample XLSX buttons and their error — same words, same order.
class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.samples, required this.sampleError});

  final Widget samples;
  final String? sampleError;

  static const requiredCols = ['Name', 'Email', 'Position', 'Branch'];
  static const optionalCols = 'Phone, Interview Date, Interview Mode, Notes';

  @override
  Widget build(BuildContext context) {
    final body = AppTextStyles.caption.copyWith(fontSize: 12, color: AppColors.textSecondary, height: 1.6);
    Widget bullet(Widget child) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('•  ', style: body), Expanded(child: child)],
        );
    return Container(
      key: const Key('candidate-import-requirements'),
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
              const SizedBox(width: 6),
              Text('File Requirements',
                  style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 6),
          bullet(Text.rich(
            key: const Key('candidate-import-formats'),
            TextSpan(style: body, children: const [
              TextSpan(text: 'Accepted formats: '),
              TextSpan(text: '.csv', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ', '),
              TextSpan(text: '.xlsx', style: TextStyle(fontWeight: FontWeight.w700)),
              TextSpan(text: ' (max 5 MB)'),
            ]),
          )),
          bullet(Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              Text('Required columns:', style: body),
              for (final c in requiredCols) _ColChip(c, required: true),
            ],
          )),
          bullet(Text('Optional columns: $optionalCols', key: const Key('candidate-import-optional'), style: body)),
          const SizedBox(height: 10),
          samples,
          if (sampleError != null)
            Padding(
              key: const Key('candidate-sample-error'),
              padding: const EdgeInsets.only(top: 8),
              child: Text(sampleError!, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
            ),
        ],
      ),
    );
  }
}

class _ColChip extends StatelessWidget {
  final String label;
  final bool required;
  const _ColChip(this.label, {required this.required});

  @override
  Widget build(BuildContext context) {
    final color = required ? AppColors.primary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

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
                    Text(error!, style: AppTextStyles.caption.copyWith(color: AppColors.error, fontSize: 10)),
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

String _friendly(Object e) {
  if (e is DioException) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return 'Cannot reach server. Check your connection.';
    }
    return parseDioException(e).message;
  }
  return e.toString().replaceAll('Exception:', '').trim();
}

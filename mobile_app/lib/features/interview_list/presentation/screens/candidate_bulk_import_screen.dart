import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.size > _kMaxImportBytes) {
      setState(() { _pickError = 'File exceeds 5 MB.'; _picked = null; });
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
    if (file == null || file.bytes == null) return;
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Bulk Import Candidates')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _InfoCard(
                requiredCols: ['name', 'email', 'position_applied', 'branch_name'],
                optionalCols: ['phone', 'interview_date', 'interview_mode', 'notes'],
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

class _InfoCard extends StatelessWidget {
  final List<String> requiredCols;
  final List<String> optionalCols;
  const _InfoCard({required this.requiredCols, required this.optionalCols});

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
              Text('CSV / XLSX format', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 10),
          Text('Required columns', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: requiredCols.map((c) => _ColChip(c, required: true)).toList()),
          const SizedBox(height: 10),
          Text('Optional columns', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Wrap(spacing: 6, runSpacing: 6, children: optionalCols.map((c) => _ColChip(c, required: false)).toList()),
          const SizedBox(height: 10),
          Text('branch_name must match an existing branch exactly (name or code) — branches are never auto-created. '
              'Max 1000 rows, 5 MB. Existing emails/phones are skipped, not failed.',
              style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.textHint)),
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

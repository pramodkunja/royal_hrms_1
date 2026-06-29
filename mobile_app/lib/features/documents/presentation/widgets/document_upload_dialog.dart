import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../providers/document_providers.dart';
import 'document_file_picker.dart';

class DocumentUploadDialog extends ConsumerStatefulWidget {
  const DocumentUploadDialog({super.key});

  @override
  ConsumerState<DocumentUploadDialog> createState() =>
      _DocumentUploadDialogState();
}

class _DocumentUploadDialogState
    extends ConsumerState<DocumentUploadDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  PlatformFile? _pickedFile;
  String _category = 'policy';
  bool _uploading = false;
  String? _titleError;
  String? _fileError;

  static const _categories = [
    ('policy', 'Policy'),
    ('form', 'Form'),
    ('template', 'Template'),
    ('other', 'Other'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
            decoration: const BoxDecoration(color: AppColors.primary),
            child: Row(
              children: [
                const Icon(Icons.upload_file_outlined,
                    color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Upload Document',
                          style: AppTextStyles.label
                              .copyWith(color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                      Text(
                        'PDF, Word, Excel, PPT, images, TXT, CSV — up to 25 MB',
                        style: AppTextStyles.caption
                            .copyWith(color: Colors.white70, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),
          ),
          // ── Form body ─────────────────────────────────────────────────────
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  16, 14, 16,
                  MediaQuery.viewInsetsOf(context).bottom + 20,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DocumentFilePicker(
                      picked: _pickedFile,
                      error: _fileError,
                      onPick: _pickFile,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _titleCtrl,
                      style: AppTextStyles.body,
                      onChanged: (_) => setState(() => _titleError = null),
                      decoration: _dec('Document Name *', _titleError),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _descCtrl,
                      style: AppTextStyles.body,
                      maxLines: 3,
                      decoration: _dec('Description (Optional)'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      style: AppTextStyles.body,
                      decoration: _dec('Category'),
                      items: _categories
                          .map((c) => DropdownMenuItem(
                              value: c.$1, child: Text(c.$2)))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _category = val);
                      },
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed:
                                _uploading ? null : () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton(
                            onPressed: _uploading ? null : _submit,
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(46),
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: _uploading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2),
                                  )
                                : Text('Upload Document',
                                    style: AppTextStyles.labelSmall
                                        .copyWith(color: Colors.white)),
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

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: [
        'pdf', 'doc', 'docx', 'xls', 'xlsx',
        'ppt', 'pptx', 'jpg', 'jpeg', 'png', 'txt', 'csv',
      ],
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() {
        _pickedFile = result.files.first;
        _fileError = null;
      });
    }
  }

  bool _validate() {
    setState(() {
      _fileError = _pickedFile == null ? 'Please select a file' : null;
      _titleError = _titleCtrl.text.trim().isEmpty
          ? 'Document name is required'
          : null;
    });
    return _pickedFile != null && _titleCtrl.text.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final file = _pickedFile!;
    if (file.path == null) {
      setState(() => _fileError = 'Could not read file path');
      return;
    }
    setState(() => _uploading = true);
    final error = await ref.read(documentListProvider.notifier).upload(
          filePath: file.path!,
          fileName: file.name,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          category: _category,
        );
    if (!mounted) return;
    setState(() => _uploading = false);
    if (error == null) {
      Navigator.pop(context);
      ref.read(documentStatsProvider.notifier).refresh();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  InputDecoration _dec(String label, [String? error]) => InputDecoration(
        labelText: label,
        errorText: error,
        labelStyle: AppTextStyles.caption,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}


import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../settings/data/models/onboarding_field_config_model.dart';
import '../../data/models/onboarding_config_models.dart';

/// Opens the system file chooser (PDF/JPG/PNG, with bytes). A provider so
/// tests can supply a file without the platform dialog.
final onboardingFilePickerProvider = Provider<Future<PlatformFile?> Function()>((ref) => () async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: kOnboardingUploadExtensions,
        withData: true,
      );
      return (result == null || result.files.isEmpty) ? null : result.files.first;
    });

String _size(int bytes) =>
    bytes >= 1024 * 1024 ? '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB' : '${(bytes / 1024).ceil()} KB';

/// A custom "file" field (web: CustomFieldFileUpload). Files upload straight
/// away to /onboarding/custom-file-fields/ under the field's field_key; a
/// single-file field replaces its previous file on the server.
class OnboardingCustomFileField extends ConsumerStatefulWidget {
  final OnboardingFieldConfigModel config;
  final List<CustomFileValue> files;

  /// Upload / delete; each returns an error message or null.
  final Future<String?> Function(String fieldKey, String fileName, List<int> bytes) onUpload;
  final Future<String?> Function(int id) onDelete;

  /// Builds an uploaded file's row around its Remove button (e.g. to add an
  /// in-app View on the employee profile). Null → the plain name row, as in
  /// the onboarding wizard.
  final Widget Function(CustomFileValue file, Widget removeButton)? fileRowBuilder;

  /// Shown when a required field has no file at save time.
  final String? errorText;

  const OnboardingCustomFileField({
    super.key,
    required this.config,
    required this.files,
    required this.onUpload,
    required this.onDelete,
    this.fileRowBuilder,
    this.errorText,
  });

  @override
  ConsumerState<OnboardingCustomFileField> createState() => _OnboardingCustomFileFieldState();
}

class _OnboardingCustomFileFieldState extends ConsumerState<OnboardingCustomFileField> {
  bool _busy = false;
  bool _deleting = false;
  String? _error;

  Future<void> _pick() async {
    if (_busy) return; // one upload at a time
    final file = await ref.read(onboardingFilePickerProvider)();
    if (!mounted || file == null) return;
    final bytes = file.bytes;
    final problem = bytes == null ? 'Could not read the file.' : onboardingUploadError(file.name, bytes.length);
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await widget.onUpload(widget.config.fieldKey, file.name, bytes!);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = err;
    });
  }

  Future<void> _remove(int id) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _deleting = true;
    });
    final err = await widget.onDelete(id);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _deleting = false;
      _error = err;
    });
  }

  Widget _fileRow(CustomFileValue f) {
    final remove = IconButton(
      key: Key('custom-file-remove-${f.id}'),
      tooltip: 'Remove',
      icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error),
      onPressed: _busy ? null : () => _remove(f.id),
    );
    final builder = widget.fileRowBuilder;
    if (builder != null) return builder(f, remove);
    return Row(children: [
      Icon(Icons.insert_drive_file_outlined, size: 18, color: AppColors.success),
      const SizedBox(width: 8),
      Expanded(
        child: Text('${f.fileName} · ${_size(f.fileSize)}', style: AppTextStyles.bodySmall, overflow: TextOverflow.ellipsis),
      ),
      remove,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.config;
    final files = widget.files;
    final error = _error ?? widget.errorText;
    final action = files.isEmpty ? 'Upload' : (c.allowMultiple ? 'Add another' : 'Replace');
    return Container(
      key: Key('onboarding-file-${c.fieldKey}'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: error != null ? AppColors.error : AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(c.required ? '${c.label} *' : c.label, style: AppTextStyles.label),
        const SizedBox(height: 2),
        Text('PDF, JPG or PNG · up to 5 MB', style: AppTextStyles.caption),
        for (final f in files)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _fileRow(f),
          ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(error, style: AppTextStyles.caption.copyWith(color: AppColors.error)),
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _busy ? null : _pick,
          icon: _busy
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.upload_file, size: 18),
          label: Text(_busy ? (_deleting ? 'Removing…' : 'Uploading…') : action),
        ),
      ]),
    );
  }
}

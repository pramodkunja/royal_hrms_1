import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/location/location_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../documents/presentation/widgets/document_file_picker.dart';
import '../../domain/entities/wfh_entity.dart';
import '../../domain/entities/wfh_medical_proof.dart';
import '../providers/wfh_providers.dart';
import 'wfh_saved_location_picker.dart';

String _toIso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String _fmtDate(DateTime d) {
  const m = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec'
  ];
  return '${d.day} ${m[d.month]} ${d.year}';
}

/// Opens the system file chooser for a medical proof (PDF/JPG/PNG). A
/// provider so tests can supply a file without the platform dialog.
final wfhProofPickerProvider = Provider<Future<PlatformFile?> Function()>((ref) => () async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: kWfhProofExtensions,
      );
      return (result == null || result.files.isEmpty) ? null : result.files.first;
    });

class RequestWfhTab extends ConsumerStatefulWidget {
  final VoidCallback? onSubmitted;
  const RequestWfhTab({super.key, this.onSubmitted});

  @override
  ConsumerState<RequestWfhTab> createState() => _RequestWfhTabState();
}

class _RequestWfhTabState extends ConsumerState<RequestWfhTab> {
  DateTime? _startDate;
  DateTime? _endDate;
  final _locationLabelCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  final _saveLabelCtrl = TextEditingController();

  double? _latitude;
  double? _longitude;
  String? _selectedSavedLocationId;
  bool _capturingLocation = false;
  String? _locationError;
  bool _showSaveLocation = false;

  bool _loading = false;
  String? _error;
  bool _submitted = false;

  // WFH for medical reasons — needs a proof (web RequestWfhForm.tsx).
  bool _isMedical = false;
  PlatformFile? _proofFile;
  String? _proofError;

  WfhMedicalProof? get _proof => _proofFile?.path == null
      ? null
      : WfhMedicalProof(path: _proofFile!.path!, filename: _proofFile!.name, sizeBytes: _proofFile!.size);

  Future<void> _pickProof() async {
    final file = await ref.read(wfhProofPickerProvider)();
    if (!mounted || file == null || file.path == null) return;
    final candidate = WfhMedicalProof(path: file.path!, filename: file.name, sizeBytes: file.size);
    final problem = wfhMedicalProofError(isMedical: true, proof: candidate);
    setState(() {
      _proofFile = problem == null ? file : null;
      _proofError = problem;
    });
  }

  @override
  void dispose() {
    _locationLabelCtrl.dispose();
    _reasonCtrl.dispose();
    _saveLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          isStart ? (_startDate ?? now) : (_endDate ?? (_startDate ?? now)),
      // No past-date/max-future-date restriction — the backend imposes
      // none, so the picker only needs a wide practical range.
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx)
            .copyWith(colorScheme: ColorScheme.light(primary: AppColors.primary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _captureLocation() async {
    setState(() {
      _capturingLocation = true;
      _locationError = null;
    });
    final position = await ref.read(locationServiceProvider).getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _capturingLocation = false;
      if (position == null) {
        _locationError =
            "Couldn't get your location. Enable location services and grant permission, then try again.";
      } else {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _selectedSavedLocationId = null;
        _showSaveLocation = true;
      }
    });
  }

  void _onSavedLocationSelected(WfhSavedLocationEntity loc) {
    setState(() {
      _latitude = loc.latitude;
      _longitude = loc.longitude;
      _selectedSavedLocationId = loc.id;
      _showSaveLocation = false;
      _locationError = null;
    });
  }

  Future<void> _saveCurrentLocation() async {
    final label = _saveLabelCtrl.text.trim();
    if (label.isEmpty || _latitude == null || _longitude == null) return;
    final err = await ref.read(wfhSavedLocationsProvider.notifier).saveLocation(
          label: label,
          latitude: _latitude!,
          longitude: _longitude!,
        );
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _saveLabelCtrl.clear();
      setState(() => _showSaveLocation = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Location saved.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool get _canSubmit =>
      !_loading &&
      _startDate != null &&
      _endDate != null &&
      !_endDate!.isBefore(_startDate!) &&
      _latitude != null &&
      _longitude != null;

  Future<void> _submit() async {
    if (!_canSubmit) return;
    // A medical request needs its proof before anything is sent.
    final proofProblem = wfhMedicalProofError(isMedical: _isMedical, proof: _proof);
    if (proofProblem != null) {
      setState(() => _proofError = proofProblem);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await ref.read(wfhMyRequestsProvider.notifier).createRequest(
          startDate: _toIso(_startDate!),
          endDate: _toIso(_endDate!),
          reason: _reasonCtrl.text.trim(),
          locationLabel: _locationLabelCtrl.text.trim(),
          latitude: _latitude!,
          longitude: _longitude!,
          isMedical: _isMedical,
          medicalProof: _isMedical ? _proof : null,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      setState(() => _submitted = true);
    }
  }

  void _reset() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _locationLabelCtrl.clear();
      _reasonCtrl.clear();
      _saveLabelCtrl.clear();
      _latitude = null;
      _longitude = null;
      _selectedSavedLocationId = null;
      _locationError = null;
      _showSaveLocation = false;
      _error = null;
      _submitted = false;
      _isMedical = false;
      _proofFile = null;
      _proofError = null;
    });
  }

  Widget _successView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_outline,
                  size: 40, color: AppColors.success),
            ),
            const SizedBox(height: 16),
            Text('Request Submitted!', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(
              'Your work-from-home request for ${_fmtDate(_startDate!)} – ${_fmtDate(_endDate!)} '
              'has been sent for approval.',
              style: AppTextStyles.bodySecondary,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'New Request',
                    variant: AppButtonVariant.outline,
                    onPressed: _reset,
                  ),
                ),
                if (widget.onSubmitted != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: AppButton(
                      label: 'My Requests',
                      onPressed: widget.onSubmitted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _successView();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Dates ─────────────────────────────────────────────────────────
          _Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel(text: 'Start Date', required: true),
                          const SizedBox(height: 6),
                          _DateField(
                              value: _startDate,
                              onTap: () => _pickDate(true)),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const _FieldLabel(text: 'End Date', required: true),
                          const SizedBox(height: 6),
                          _DateField(
                              value: _endDate, onTap: () => _pickDate(false)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_startDate != null &&
                    _endDate != null &&
                    _endDate!.isBefore(_startDate!)) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.error_outline, size: 12, color: AppColors.error),
                      const SizedBox(width: 5),
                      Text('End date must be on or after start date.',
                          style: AppTextStyles.caption
                              .copyWith(fontSize: 10, color: AppColors.error)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Location + reason ────────────────────────────────────────────
          _Card(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FieldLabel(text: 'Location Label'),
                const SizedBox(height: 6),
                TextField(
                  controller: _locationLabelCtrl,
                  decoration: const InputDecoration(hintText: 'e.g. Home'),
                ),
                const SizedBox(height: 12),
                const _FieldLabel(text: 'Reason'),
                const SizedBox(height: 6),
                TextField(
                  controller: _reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Optional — add context for your approver',
                  ),
                ),
                const SizedBox(height: 8),
                // Own Material so the tile's ink isn't hidden by the card's
                // decorated background.
                Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    key: const Key('wfh-medical'),
                    value: _isMedical,
                    onChanged: _loading
                        ? null
                        : (v) => setState(() {
                              _isMedical = v ?? false;
                              if (!_isMedical) {
                                _proofFile = null;
                                _proofError = null;
                              }
                            }),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text('WFH for medical reasons', style: AppTextStyles.body),
                  ),
                ),
                if (_isMedical) ...[
                  const _FieldLabel(text: 'Medical proof (report or prescription)', required: true),
                  const SizedBox(height: 6),
                  DocumentFilePicker(
                    picked: _proofFile,
                    error: _proofError,
                    onPick: _loading ? () {} : _pickProof,
                    hintText: 'PDF, JPG, or PNG — up to 5 MB',
                  ),
                ],
                const SizedBox(height: 14),
                const _FieldLabel(text: 'Your Location', required: true),
                const SizedBox(height: 6),
                Text(
                  'This is what your clock-in will be checked against on WFH days.',
                  style: AppTextStyles.caption.copyWith(fontSize: 10.5, color: AppColors.textHint),
                ),
                const SizedBox(height: 8),
                WfhSavedLocationPicker(
                  selectedId: _selectedSavedLocationId,
                  onSelected: _onSavedLocationSelected,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _capturingLocation ? null : _captureLocation,
                    icon: _capturingLocation
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary),
                          )
                        : const Icon(Icons.my_location, size: 15),
                    label: Text(_capturingLocation
                        ? 'Getting location…'
                        : 'Use current location'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                  ),
                ),
                if (_locationError != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.location_off_outlined, size: 14, color: AppColors.error),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(_locationError!,
                              style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_latitude != null && _longitude != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.success, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_showSaveLocation) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _saveLabelCtrl,
                          decoration: const InputDecoration(
                              hintText: 'Save this location as…', isDense: true),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _saveCurrentLocation,
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
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
                  Expanded(
                    child: Text(_error!,
                        style: AppTextStyles.caption.copyWith(color: AppColors.error)),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          AppButton(
            label: 'Submit',
            onPressed: _canSubmit ? _submit : null,
            isLoading: _loading,
            leadingIcon: Icons.send_outlined,
          ),
        ],
      ),
    );
  }
}

// ── Small shared bits ─────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      child: child,
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _FieldLabel({required this.text, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text,
            style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.3)),
        if (required)
          Text(' *',
              style: TextStyle(
                  color: AppColors.error, fontSize: 11, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime? value;
  final VoidCallback onTap;
  const _DateField({this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value != null ? _fmtDate(value!) : 'Select',
                style: AppTextStyles.caption.copyWith(
                    fontSize: 11,
                    color: value != null ? AppColors.textPrimary : AppColors.textHint,
                    fontWeight: value != null ? FontWeight.w600 : FontWeight.w400),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

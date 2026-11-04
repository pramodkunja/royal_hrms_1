part of '../screens/onboarding_screen.dart';

// ─── Step metadata ─────────────────────────────────────────────────────────

const List<Map<String, dynamic>> kStepMeta = [
  {'label': 'Personal', 'icon': Icons.person_outline},
  {'label': 'Education', 'icon': Icons.school_outlined},
  {'label': 'Bank', 'icon': Icons.account_balance_outlined},
  {'label': 'Emergency', 'icon': Icons.contact_emergency_outlined},
  {'label': 'Documents', 'icon': Icons.folder_copy_outlined},
];

const List<String> kStepTitles = [
  'Personal',
  'Education & Experience',
  'Bank Details',
  'Emergency Contact',
  'Documents',
];

// ─── Shared "card section" — icon badge + title + fields ──────────────────

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.primary;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: AppColors.cardShadow,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 5, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 22, 22, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(icon, size: 20, color: accent),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Text(title, style: AppTextStyles.h4)),
                        ],
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.only(left: 54),
                          child: Text(
                            subtitle!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      for (var i = 0; i < children.length; i++) ...[
                        children[i],
                        if (i != children.length - 1)
                          const SizedBox(height: 18),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared buttons — one cohesive look for every step's footer actions ────

/// Gradient-filled primary CTA (Save & Continue / Submit) shared by every
/// step footer, so the wizard's main action always reads the same way.
class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: enabled
            ? LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])
            : null,
        color: enabled ? null : AppColors.border,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onPressed : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            child: Center(
              child: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 17, color: Colors.white),
                          const SizedBox(width: 8),
                        ],
                        Text(label,
                            style: AppTextStyles.button
                                .copyWith(color: Colors.white)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined secondary action (Previous / Save Draft) sharing the same
/// radius and typography rhythm as [_PrimaryButton].
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: loading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        backgroundColor: AppColors.backgroundLow,
        side: BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      child: loading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.textSecondary))
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: AppTextStyles.labelLarge,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ),
              ],
            ),
    );
  }
}

// Steps 0–3 (Personal, Education, Bank, Emergency) are admin-configured —
// see onboarding_configured_step.dart.

// ─── Step 4 — Documents ───────────────────────────────────────────────────

/// The PAN card document type — its upload first saves the PAN number
/// (web: handlePanCardUpload; backend: _save_profile_step step 4).
const kPanCardType = 'pan_card';

/// Backend PAN_RE (accounts/models.py), checked after upper-casing as
/// normalize_and_validate_pan does.
final kPanPattern = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');

/// The backend's/web's messages; null when the PAN can be sent.
String? panNumberError(String value) {
  final v = value.trim().toUpperCase();
  if (v.isEmpty) return 'Enter your PAN number before uploading the PAN card.';
  if (!kPanPattern.hasMatch(v)) return 'Enter a valid PAN (e.g. ABCDE1234F) — 5 letters, 4 digits, 1 letter.';
  return null;
}

/// Shows the server's verdict on Save Draft (PATCH /onboarding/step/4/):
/// it never submits or moves the wizard; it reports whether the required
/// documents are all present.
void _showDraftResult(BuildContext context, ({bool ok, String message}) result) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.message),
      backgroundColor: result.ok ? AppColors.success : AppColors.error,
    ));

/// Labels of visible, required document types with no file uploaded yet
/// (the backend's own submit check, DocumentTypeConfig visible+required).
List<String> missingRequiredDocuments(
        List<DocumentTypeConfigModel> types, List<OnboardingDocEntity> documents) =>
    [
      for (final t in types)
        if (t.visible && t.required && !documents.any((d) => d.docType == t.typeKey)) t.label,
    ];

/// Shared "Submit for Approval?" confirmation — used by whichever step owns
/// the final Submit action (Documents when there's no Face ID step, the
/// Face ID step when there is one — see hasFaceStep).
Future<bool> _confirmSubmitForApproval(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Submit for Approval?'),
      content: const Text(
        'Once submitted, your profile will be reviewed by HR. You cannot make changes after submission.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit')),
      ],
    ),
  );
  return confirmed == true;
}

class _DocumentsStep extends ConsumerStatefulWidget {
  const _DocumentsStep({
    required this.documentTypes,
    required this.documents,
    required this.panNumber,
    required this.onSavePan,
    required this.onUpload,
    required this.onDelete,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onPrevious,
    required this.hasFaceStep,
    required this.onContinueToFaceStep,
  });

  /// Visible document types from the admin configuration, in order.
  final List<DocumentTypeConfigModel> documentTypes;
  final List<OnboardingDocEntity> documents;

  /// The saved PAN number (GET /onboarding/ pan_number), shown when PAN
  /// Card is a configured document type.
  final String panNumber;

  /// Saves the PAN number; returns an error message or null.
  final Future<String?> Function(String pan) onSavePan;
  final Future<String?> Function(String docType, PlatformFile file) onUpload;
  final Future<String?> Function(int id) onDelete;
  final Future<({bool ok, String message})> Function() onSaveDraft;
  final Future<void> Function() onSubmit;
  final VoidCallback? onPrevious;
  // When true, a Face ID step follows this one and owns the real Submit
  // action (mirrors web: Documents is only ever the last step, with its own
  // Submit button, when the org's Face ID toggle is off — see FACE_STEP in
  // app/onboarding/page.tsx). When true, this step's primary action is just
  // "Continue" to the Face ID step instead.
  final bool hasFaceStep;
  final VoidCallback onContinueToFaceStep;

  @override
  ConsumerState<_DocumentsStep> createState() => _DocumentsStepState();
}

class _DocumentsStepState extends ConsumerState<_DocumentsStep> {
  bool _submitting = false;
  bool _savingDraft = false;
  final _uploading = <String>{};
  late final _panCtrl = TextEditingController(text: widget.panNumber);
  String? _panError;

  @override
  void dispose() {
    _panCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAndUpload(String docType) async {
    if (_uploading.contains(docType)) return; // one upload per type at a time
    final isPan = docType == kPanCardType;
    if (isPan) {
      // As on web: the PAN number is checked before the file chooser opens.
      final problem = panNumberError(_panCtrl.text);
      if (problem != null) {
        setState(() => _panError = problem);
        return;
      }
    }
    final file = await ref.read(onboardingFilePickerProvider)();
    if (!mounted || file == null) return;
    final bytes = file.bytes;
    final problem = bytes == null ? 'Could not read the file.' : onboardingUploadError(file.name, bytes.length);
    if (problem != null) {
      _snack(problem);
      return;
    }
    setState(() {
      _uploading.add(docType);
      if (isPan) _panError = null;
    });
    if (isPan) {
      // Save (and server-validate) the PAN first; the card is only sent once
      // the number is accepted. What was typed stays either way.
      final pan = _panCtrl.text.trim().toUpperCase();
      final panErr = await widget.onSavePan(pan);
      if (!mounted) return;
      if (panErr != null) {
        setState(() {
          _uploading.remove(docType);
          _panError = panErr;
        });
        return;
      }
      _panCtrl.text = pan;
    }
    final err = await widget.onUpload(docType, file);
    if (!mounted) return;
    setState(() => _uploading.remove(docType));
    if (err != null) _snack(err);
  }

  Widget _panField() => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
        child: TextField(
          key: const Key('onboarding-pan-number'),
          controller: _panCtrl,
          enabled: !_uploading.contains(kPanCardType),
          maxLength: 10,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [_PanUpperCase()],
          onChanged: (_) {
            if (_panError != null) setState(() => _panError = null);
          },
          decoration: InputDecoration(
            labelText: 'PAN Number *',
            hintText: 'e.g. ABCDE1234F',
            counterText: '',
            errorText: _panError,
            errorMaxLines: 3,
            helperText: _panError == null
                ? 'Checked against every other employee before the upload goes through — enter it first.'
                : null,
            helperMaxLines: 3,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );

  void _snack(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message), backgroundColor: AppColors.error));

  /// Required document types still missing — checked before leaving the
  /// step, so the employee hears it here rather than from a failed submit.
  bool _requiredDocsPresent() {
    final missing = missingRequiredDocuments(widget.documentTypes, widget.documents);
    if (missing.isEmpty) return true;
    _snack('Please upload: ${missing.join(', ')}');
    return false;
  }

  Future<void> _handleSubmit() async {
    if (_submitting || !_requiredDocsPresent()) return;
    if (!await _confirmSubmitForApproval(context)) return;
    if (!mounted) return;
    setState(() => _submitting = true);
    await widget.onSubmit();
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _handleSaveDraft() async {
    if (_savingDraft) return;
    setState(() => _savingDraft = true);
    final result = await widget.onSaveDraft();
    if (!mounted) return;
    setState(() => _savingDraft = false);
    _showDraftResult(context, result);
  }

  void _handleContinue() {
    if (_requiredDocsPresent()) widget.onContinueToFaceStep();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.infoContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.info.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child:
                            Icon(Icons.info_outline, color: AppColors.info, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Upload clear scans or photos. Accepted: PDF, JPG, PNG · Max 5 MB each.',
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.info),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (widget.documentTypes.isEmpty)
                  Text('No documents are required for onboarding.',
                      style: AppTextStyles.bodySecondary),
                ...widget.documentTypes.map((doc) {
                  final uploaded = widget.documents
                      .where((d) => d.docType == doc.typeKey)
                      .toList();
                  final card = Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DocTypeCard(
                      key: Key('onboarding-doc-${doc.typeKey}'),
                      docType: doc.typeKey,
                      label: doc.required ? '${doc.label} *' : doc.label,
                      allowMultiple: doc.allowMultiple,
                      uploaded: uploaded,
                      isUploading: _uploading.contains(doc.typeKey),
                      onUpload: () => _pickAndUpload(doc.typeKey),
                      onDelete: widget.onDelete,
                    ),
                  );
                  if (doc.typeKey != kPanCardType) return card;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [card, _panField()],
                  );
                }),
              ],
            ),
          ),
        ),
        _StickyFooter(
          child: widget.hasFaceStep
              // A Face ID step follows — this is no longer the last step, so
              // it gets the same plain "Previous / Save & Continue" footer as
              // every other non-final step (Personal/Education/Bank/
              // Emergency), not the Submit/Save Draft pair.
              ? Row(
                  children: [
                    if (widget.onPrevious != null) ...[
                      _SecondaryButton(
                        label: 'Previous',
                        icon: Icons.arrow_back,
                        onPressed: widget.onPrevious,
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: _PrimaryButton(
                        label: 'Save & Continue',
                        icon: Icons.arrow_forward,
                        onPressed: _handleContinue,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: _PrimaryButton(
                        label: 'Submit for Approval',
                        loading: _submitting,
                        onPressed: _handleSubmit,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (widget.onPrevious != null) ...[
                          Expanded(
                            child: _SecondaryButton(
                              label: 'Previous',
                              icon: Icons.arrow_back,
                              onPressed: widget.onPrevious,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: _SecondaryButton(
                            label: 'Save Draft',
                            loading: _savingDraft,
                            onPressed: _handleSaveDraft,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _PanUpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

class _DocTypeCard extends StatelessWidget {
  const _DocTypeCard({
    super.key,
    required this.docType,
    required this.label,
    required this.allowMultiple,
    required this.uploaded,
    required this.isUploading,
    required this.onUpload,
    required this.onDelete,
  });

  final String docType;
  final String label;
  final bool allowMultiple;
  final List<OnboardingDocEntity> uploaded;
  final bool isUploading;
  final VoidCallback onUpload;
  final Future<String?> Function(int id) onDelete;

  @override
  Widget build(BuildContext context) {
    final hasUpload = uploaded.isNotEmpty;
    final accent = hasUpload ? AppColors.success : AppColors.textHint;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: hasUpload
              ? AppColors.successContainer.withValues(alpha: 0.35)
              : AppColors.backgroundLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasUpload
                ? AppColors.success.withValues(alpha: 0.4)
                : AppColors.border,
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent.withValues(alpha: 0.6)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 16, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: hasUpload
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: hasUpload
                              ? null
                              : Border.all(color: AppColors.border),
                        ),
                        child: Icon(
                          hasUpload
                              ? Icons.check_circle_rounded
                              : Icons.upload_file_outlined,
                          color: hasUpload
                              ? AppColors.success
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label,
                                style: AppTextStyles.label
                                    .copyWith(fontWeight: FontWeight.w600)),
                            if (hasUpload)
                              ...uploaded.map((doc) =>
                                  _UploadedChip(doc: doc, onDelete: onDelete))
                            else
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text('Not uploaded yet',
                                    style: AppTextStyles.bodySmall
                                        .copyWith(color: AppColors.textHint)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      isUploading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary))
                          : TextButton(
                              onPressed: onUpload,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                backgroundColor:
                                    AppColors.primary.withValues(alpha: 0.1),
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(!hasUpload ? 'Upload' : (allowMultiple ? 'Add another' : 'Replace'),
                                  style: AppTextStyles.labelSmall
                                      .copyWith(fontWeight: FontWeight.w700)),
                            ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadedChip extends StatelessWidget {
  const _UploadedChip({required this.doc, required this.onDelete});

  final OnboardingDocEntity doc;
  final Future<String?> Function(int id) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 14, color: AppColors.success),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              doc.fileName.isNotEmpty ? doc.fileName : 'Uploaded',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.success),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () async {
              final err = await onDelete(doc.id);
              if (err != null && context.mounted) {
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(err)));
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(2),
              child:
                  Icon(Icons.close, size: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Step 5 — Face ID (only inserted when the org's Face ID Verification
// toggle is mandatory — see includeFaceStep in onboarding_screen.dart).
// Always the last step, and owns the real Submit for Approval / Save Draft
// actions in that case (Documents' footer becomes a plain "Continue" when
// this step exists — see _DocumentsStep.hasFaceStep). Reuses the exact same
// self-submit capture flow as ProfileFaceIdSection (same controller, same
// consent text, same endpoint) — first-time registration during onboarding
// and later self-service registration from Profile are the same backend
// call. ────────────────────────────────────────────────────────────────────

class _FaceIdStep extends ConsumerStatefulWidget {
  const _FaceIdStep({
    required this.onSaveDraft,
    required this.onSubmit,
    required this.onPrevious,
  });

  final Future<({bool ok, String message})> Function() onSaveDraft;
  final Future<void> Function() onSubmit;
  final VoidCallback? onPrevious;

  @override
  ConsumerState<_FaceIdStep> createState() => _FaceIdStepState();
}

class _FaceIdStepState extends ConsumerState<_FaceIdStep> {
  bool _submitting = false;
  bool _savingDraft = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(faceRegistrationControllerProvider.notifier).loadStatus());
  }

  Future<void> _openCaptureFlow({required String title, required String subtitle}) async {
    final controller = ref.read(faceRegistrationControllerProvider.notifier);
    controller.startCapture();
    final result = await showFaceCaptureSheet(
      context,
      title: title,
      subtitle: subtitle,
      consentNoticeText: kFaceConsentNoticeEmployee,
    );
    if (!mounted) return;
    if (result?.captured.embedding != null) {
      await controller.submit(result!.captured, consentAcknowledged: result.consentAcknowledged);
      if (mounted &&
          ref.read(faceRegistrationControllerProvider).phase == FaceRegistrationPhase.error) {
        final message = ref.read(faceRegistrationControllerProvider).errorMessage;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? 'Could not save your face ID.'), backgroundColor: AppColors.error),
        );
      }
    } else {
      controller.cancelCapture();
    }
  }

  Future<void> _handleSubmit() async {
    if (!await _confirmSubmitForApproval(context)) return;
    if (!mounted) return;
    setState(() => _submitting = true);
    await widget.onSubmit();
    if (mounted) setState(() => _submitting = false);
  }

  Future<void> _handleSaveDraft() async {
    if (_savingDraft) return;
    setState(() => _savingDraft = true);
    final result = await widget.onSaveDraft();
    if (!mounted) return;
    setState(() => _savingDraft = false);
    _showDraftResult(context, result);
  }

  @override
  Widget build(BuildContext context) {
    final regState = ref.watch(faceRegistrationControllerProvider);
    final busy = regState.phase == FaceRegistrationPhase.capturing ||
        regState.phase == FaceRegistrationPhase.submitting;
    // OnboardingView._submit (backend) gates on FaceRegistrationRequest
    // .exists() with no status filter — pending/approved/rejected all count.
    // Mirrors web's canSubmit = !faceMandatory || Boolean(faceRegistration);
    // this step only ever renders when faceMandatory is already true.
    final canSubmit = regState.registration != null;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionCard(
                  icon: Icons.face_outlined,
                  title: 'Face ID Registration',
                  subtitle: 'Your organisation requires a registered face ID for clock-in/out. '
                      'Register once here — we run a quick liveness check, then send it to HR '
                      'for approval. You won\'t be able to submit your profile until this is done.',
                  children: [_FaceIdStatusRow(regState: regState, busy: busy, onCapture: _openCaptureFlow)],
                ),
              ],
            ),
          ),
        ),
        _StickyFooter(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: _PrimaryButton(
                  label: 'Submit for Approval',
                  loading: _submitting,
                  onPressed: canSubmit ? _handleSubmit : null,
                ),
              ),
              if (!canSubmit) ...[
                const SizedBox(height: 8),
                Text(
                  'Register your Face ID above to enable submission.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  if (widget.onPrevious != null) ...[
                    Expanded(
                      child: _SecondaryButton(
                        label: 'Previous',
                        icon: Icons.arrow_back,
                        onPressed: widget.onPrevious,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: _SecondaryButton(
                      label: 'Save Draft',
                      loading: _savingDraft,
                      onPressed: _handleSaveDraft,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Status card mirroring web's TabFaceId exactly: title text keyed off the
/// registration's status, and an action slot that's hidden (replaced by
/// "Awaiting review") while pending — no re-submit affordance for a request
/// already in HR's queue, same rule as ProfileFaceIdSection.
class _FaceIdStatusRow extends StatelessWidget {
  const _FaceIdStatusRow({required this.regState, required this.busy, required this.onCapture});

  final FaceRegistrationUiState regState;
  final bool busy;
  final Future<void> Function({required String title, required String subtitle}) onCapture;

  @override
  Widget build(BuildContext context) {
    final status = regState.registration?.status;
    final label = switch (status) {
      FaceRegistrationStatus.approved => 'Face ID approved',
      FaceRegistrationStatus.pending => 'Face ID submitted — pending HR approval',
      FaceRegistrationStatus.rejected => 'Face ID rejected — please register again',
      null => 'Face ID not yet registered',
    };
    final registered = status != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: registered ? AppColors.successContainer.withValues(alpha: 0.35) : AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: registered ? AppColors.success.withValues(alpha: 0.4) : AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: registered ? AppColors.success.withValues(alpha: 0.15) : AppColors.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.face_outlined, size: 18, color: registered ? AppColors.success : AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          if (status == FaceRegistrationStatus.pending)
            Text('Awaiting review',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700))
          else
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => onCapture(
                        title: status == null ? 'Register My Face' : 'Update My Face',
                        subtitle: status == null
                            ? 'This registers your Face ID for clock-in verification.'
                            : 'This replaces your current Face ID and needs re-approval.',
                      ),
              child: busy
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(switch (status) {
                      FaceRegistrationStatus.approved => 'Update',
                      FaceRegistrationStatus.rejected => 'Register Again',
                      _ => 'Register Face ID',
                    }),
            ),
        ],
      ),
    );
  }
}

// ─── Shared step form wrapper ──────────────────────────────────────────────

/// Bottom action bar pinned outside the scrollable step content, so
/// Previous/Save & Continue (or Save Draft/Submit) always stay reachable
/// without scrolling, and read as a distinct footer rather than trailing
/// off the end of a form.
class _StickyFooter extends StatelessWidget {
  const _StickyFooter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: AppColors.elevatedShadow,
      ),
      child: SafeArea(top: false, child: child),
    );
  }
}

class _StepFormWrapper extends StatelessWidget {
  const _StepFormWrapper({
    required this.formKey,
    required this.saving,
    required this.onSave,
    required this.onPrevious,
    required this.children,
  });

  final GlobalKey<FormState> formKey;
  final bool saving;
  final VoidCallback onSave;
  final VoidCallback? onPrevious;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    children[i],
                    if (i != children.length - 1) const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ),
          _StickyFooter(
            child: Row(
              children: [
                if (onPrevious != null) ...[
                  _SecondaryButton(
                    label: 'Previous',
                    icon: Icons.arrow_back,
                    onPressed: onPrevious,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: _PrimaryButton(
                    label: 'Save & Continue',
                    icon: Icons.arrow_forward,
                    loading: saving,
                    onPressed: onSave,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

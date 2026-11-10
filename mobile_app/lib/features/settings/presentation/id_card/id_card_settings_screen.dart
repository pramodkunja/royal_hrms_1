import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/access_control.dart' show userHasPermission;
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../employees/presentation/id_card/id_card_faces.dart';
import '../../../employees/presentation/id_card/id_card_spec.dart';
import '../../../profile/data/services/profile_document_viewer.dart';
import '../../../profile/presentation/screens/profile_document_viewer_screen.dart';
import '../../data/models/company_model.dart';
import '../../data/models/id_card_settings_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import 'id_card_settings_providers.dart';

/// Web /dashboard/settings/id-card (app/dashboard/settings/id-card/page.tsx):
/// the reference design PDF, the logo/website taken from Company Info, the
/// card content (authorised signature, its caption, terms & conditions and
/// which personal details are printed) and a sample layout preview.
///
/// Access: the route needs settings.view (GET /settings/id-card/). Changing
/// anything needs settings.edit (web `usePermission("settings.edit")`; the
/// PUT is refused without it) — without it everything is read-only and no
/// Save/Cancel/upload/remove controls are shown.
class IdCardSettingsScreen extends ConsumerStatefulWidget {
  const IdCardSettingsScreen({super.key});

  @override
  ConsumerState<IdCardSettingsScreen> createState() => _IdCardSettingsScreenState();
}

class _IdCardSettingsScreenState extends ConsumerState<IdCardSettingsScreen> {
  IdCardSettingsModel? _settings;
  CompanyModel? _company;
  IdCardSettingsForm _form = const IdCardSettingsForm();
  IdCardPickedFile? _pdfFile;
  bool _removePdf = false;
  IdCardPickedFile? _sigFile;
  bool _removeSig = false;
  bool _saving = false;
  bool _saved = false;
  bool _openingPdf = false;
  String? _apiError;

  final _caption = TextEditingController();
  final _terms = TextEditingController();

  bool get _canEdit => userHasPermission(ref.read(authStateProvider).valueOrNull?.user, 'settings.edit');

  bool get _dirty =>
      _settings != null &&
      (_form != _settings!.toForm() || _pdfFile != null || _removePdf || _sigFile != null || _removeSig);

  @override
  void dispose() {
    _caption.dispose();
    _terms.dispose();
    super.dispose();
  }

  /// Takes the server's settings as the saved state (first load, refresh,
  /// successful save) and resets the form and pending files to them.
  void _adopt(IdCardSettingsModel s) {
    _settings = s;
    _form = s.toForm();
    _caption.text = _form.signatoryLabel;
    _terms.text = _form.terms;
    _pdfFile = null;
    _removePdf = false;
    _sigFile = null;
    _removeSig = false;
  }

  void _update(IdCardSettingsForm f) => setState(() {
        _saved = false;
        _apiError = null;
        _form = f;
      });

  Future<void> _pickPdf() async {
    final f = await ref.read(idCardReferencePdfPickerProvider)();
    if (f == null || !mounted) return;
    final problem = validateIdCardReferencePdf(f);
    setState(() {
      if (problem != null) {
        _apiError = problem;
        return;
      }
      _apiError = null;
      _saved = false;
      _pdfFile = f;
      _removePdf = false;
    });
  }

  Future<void> _pickSignature() async {
    final f = await ref.read(idCardSignaturePickerProvider)();
    if (f == null || !mounted) return;
    final problem = validateIdCardSignature(f);
    setState(() {
      if (problem != null) {
        _apiError = problem;
        return;
      }
      _apiError = null;
      _saved = false;
      _sigFile = f;
      _removeSig = false;
    });
  }

  void _resetChanges() => setState(() {
        if (_settings != null) _adopt(_settings!);
        _apiError = null;
        _saved = false;
      });

  Future<void> _save() async {
    if (_saving || !_dirty || !_canEdit) return;
    setState(() {
      _saving = true;
      _apiError = null;
    });
    try {
      final saved = await ref.read(settingsDataSourceProvider).saveIdCardSettings(
            _form,
            referencePdf: _pdfFile,
            removeReferencePdf: _removePdf,
            signature: _sigFile,
            removeSignature: _removeSig,
          );
      if (!mounted) return;
      setState(() {
        _adopt(saved);
        _saved = true;
      });
    } catch (e) {
      if (mounted) setState(() => _apiError = idCardServerMessage(e) ?? kIdCardSettingsSaveError);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _viewReferencePdf() async {
    if (_openingPdf) return;
    setState(() {
      _openingPdf = true;
      _apiError = null;
    });
    final outcome = await ref.read(idCardReferencePdfViewerProvider).load(0);
    if (!mounted) {
      if (outcome is ProfileDocumentReady) await outcome.release();
      return;
    }
    setState(() => _openingPdf = false);
    switch (outcome) {
      case ProfileDocumentReady():
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) =>
              ProfileDocumentViewerScreen(document: outcome, title: _settings?.referencePdfName ?? 'Reference design'),
        ));
      case DocumentViewFailed(:final message):
        setState(() => _apiError = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = userHasPermission(ref.watch(authStateProvider).valueOrNull?.user, 'settings.edit');
    final async = ref.watch(idCardSettingsPageProvider);
    // Adopt freshly loaded data once (never over the user's unsaved edits).
    ref.listen(idCardSettingsPageProvider, (_, next) {
      final d = next.valueOrNull;
      if (d != null) {
        setState(() {
          _adopt(d.settings);
          _company = d.company;
        });
      }
    });
    if (_settings == null && async.valueOrNull != null) {
      _adopt(async.value!.settings);
      _company = async.value!.company;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: SettingsAppBar(
        title: 'ID Card',
        trailing: canEdit && _settings != null ? _saveButton(compact: true) : null,
      ),
      body: _settings != null
          ? _body(canEdit)
          : async.when(
              data: (_) => const SizedBox.shrink(),
              loading: () => Center(
                key: const Key('idcs-loading'),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 10),
                  Text('Loading settings…', style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
                ]),
              ),
              error: (_, __) => Center(
                key: const Key('idcs-load-error'),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.error_outline, size: 40, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(kIdCardSettingsLoadError, textAlign: TextAlign.center, style: AppTextStyles.body),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      key: const Key('idcs-retry'),
                      onPressed: () => ref.invalidate(idCardSettingsPageProvider),
                      child: const Text('Retry'),
                    ),
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _saveButton({bool compact = false}) {
    final enabled = !_saving && _dirty;
    final child = _saving
        ? Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: compact ? AppColors.primary : Colors.white)),
            const SizedBox(width: 6),
            const Text('Saving…'),
          ])
        : Text(compact ? 'Save' : 'Save Changes');
    return compact
        ? TextButton(key: const Key('idcs-save-top'), onPressed: enabled ? _save : null, child: child)
        : FilledButton.icon(
            key: const Key('idcs-save'),
            onPressed: enabled ? _save : null,
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            icon: _saving ? const SizedBox.shrink() : const Icon(Icons.save_outlined, size: 18),
            label: child,
          );
  }

  Widget _body(bool canEdit) {
    final s = _settings!;
    final hasPdf = s.hasReferencePdf && !_removePdf;
    final shownSigFile = _removeSig ? null : _sigFile;
    final shownSigUrl = _removeSig || _sigFile != null ? null : s.signatureUrl;
    final hasSignature = shownSigFile != null || shownSigUrl != null;
    final sample = idCardSettingsSample(
      company: _company,
      form: _form,
      defaultTerms: s.defaultTerms,
      signatureUrl: _removeSig ? null : s.signatureUrl,
    );

    return RefreshIndicator(
      onRefresh: () async {
        if (_dirty || _saving) return; // never drop unsaved edits
        ref.invalidate(idCardSettingsPageProvider);
        await ref.read(idCardSettingsPageProvider.future).catchError((_) => IdCardSettingsPageData(s, _company));
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text('Employee ID card design, terms and authorised signature',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          if (_apiError != null)
            _Banner(key: const Key('idcs-error'), icon: Icons.error_outline, color: AppColors.error, text: _apiError!),
          if (_saved)
            _Banner(
                key: const Key('idcs-saved'),
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                text: kIdCardSettingsSaved),
          if (!canEdit)
            _Banner(
                key: const Key('idcs-readonly'),
                icon: Icons.lock_outline,
                color: AppColors.primary,
                text: 'You can view these settings but not change them.'),

          // ── Reference design ──
          _Section(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Reference design',
            children: [
              Text(
                'Keep the approved ID card PDF here for reference. Cards are generated from the built-in '
                'front/back template that reproduces this design. The PDF itself isn\'t filled in, because a '
                'design export already contains one person\'s details.',
                style: _hint,
              ),
              const SizedBox(height: 12),
              if (_pdfFile != null)
                Text('${_pdfFile!.name} (${formatIdCardBytes(_pdfFile!.size)}) — saves on Save Changes',
                    key: const Key('idcs-pdf-pending'), style: AppTextStyles.bodySmall)
              else if (hasPdf)
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 10, runSpacing: 6, children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.picture_as_pdf, size: 18, color: AppColors.error),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(s.referencePdfName,
                          key: const Key('idcs-pdf-name'),
                          style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  Text(formatIdCardBytes(s.referencePdfSize), style: _hint),
                  if (s.referencePdfUrl != null)
                    OutlinedButton.icon(
                      key: const Key('idcs-pdf-view'),
                      onPressed: _openingPdf ? null : _viewReferencePdf,
                      icon: _openingPdf
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.open_in_new, size: 16),
                      label: Text(_openingPdf ? 'Opening…' : 'View'),
                    ),
                ])
              else
                Text('No reference PDF uploaded.', key: const Key('idcs-pdf-none'), style: _hint),
              if (canEdit) ...[
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton.icon(
                    key: const Key('idcs-pdf-upload'),
                    onPressed: _saving ? null : _pickPdf,
                    icon: const Icon(Icons.upload_outlined, size: 16),
                    label: Text(hasPdf || _pdfFile != null ? 'Replace PDF' : 'Upload PDF'),
                  ),
                  if (hasPdf || _pdfFile != null)
                    OutlinedButton.icon(
                      key: const Key('idcs-pdf-remove'),
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _pdfFile = null;
                                _removePdf = s.hasReferencePdf;
                                _saved = false;
                              }),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove'),
                    ),
                ]),
              ],
            ],
          ),

          // ── Logo and website (read-only, from Company Info) ──
          _Section(
            icon: Icons.business_outlined,
            title: 'Logo and website',
            children: [
              Row(children: [
                Container(
                  key: const Key('idcs-logo'),
                  width: 96,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: (_company?.logoUrl?.isNotEmpty ?? false)
                      ? Padding(
                          padding: const EdgeInsets.all(4),
                          child: Image.network(_company!.logoUrl!,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Text('No logo', style: _hint.copyWith(fontSize: 11))),
                        )
                      : Text('No logo', style: _hint.copyWith(fontSize: 11)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'The card uses the company logo and website from Company Info'
                    '${(_company?.website.isNotEmpty ?? false) ? ' (${_company!.website})' : ' (no website set)'}.',
                    key: const Key('idcs-website'),
                    style: _hint,
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const Key('idcs-edit-company'),
                  onPressed: () => context.push(AppRoutes.settingsCompany),
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Edit in Company Info'),
                ),
              ),
            ],
          ),

          // ── Card content ──
          _Section(
            icon: Icons.badge_outlined,
            title: 'Card content',
            children: [
              Text('Authorised signature', style: _label),
              const SizedBox(height: 6),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 12, runSpacing: 8, children: [
                Container(
                  key: const Key('idcs-signature'),
                  width: 120,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: shownSigFile != null
                      ? Image.file(File(shownSigFile.path),
                          key: const Key('idcs-signature-file'),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink())
                      : shownSigUrl != null
                          ? Image.network(shownSigUrl,
                              key: const Key('idcs-signature-url'),
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink())
                          : Text('None', key: const Key('idcs-signature-none'), style: _hint.copyWith(fontSize: 11)),
                ),
                if (canEdit) ...[
                  OutlinedButton.icon(
                    key: const Key('idcs-sig-upload'),
                    onPressed: _saving ? null : _pickSignature,
                    icon: const Icon(Icons.upload_outlined, size: 16),
                    label: Text(hasSignature ? 'Replace' : 'Upload'),
                  ),
                  if (hasSignature)
                    OutlinedButton.icon(
                      key: const Key('idcs-sig-remove'),
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _sigFile = null;
                                _removeSig = s.signatureUrl != null;
                                _saved = false;
                              }),
                      icon: const Icon(Icons.delete_outline, size: 16),
                      label: const Text('Remove'),
                    ),
                ],
              ]),
              const SizedBox(height: 4),
              Text(
                'Signature or stamp image (PNG with a transparent background works best). PNG, JPEG or WebP, '
                'up to 2 MB. Stored privately.',
                style: _hint,
              ),
              const SizedBox(height: 18),
              Text('Signature caption', style: _label),
              const SizedBox(height: 6),
              TextField(
                key: const Key('idcs-caption'),
                controller: _caption,
                enabled: canEdit,
                maxLength: kIdCardSignatoryMaxLength,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                decoration: _input(),
                onChanged: (v) => _update(_form.copyWith(signatoryLabel: v)),
              ),
              const SizedBox(height: 10),
              Text('Terms & conditions', style: _label),
              const SizedBox(height: 6),
              TextField(
                key: const Key('idcs-terms'),
                controller: _terms,
                enabled: canEdit,
                minLines: 4,
                maxLines: 8,
                keyboardType: TextInputType.multiline,
                decoration: _input(hint: s.defaultTerms),
                onChanged: (v) => _update(_form.copyWith(terms: v)),
              ),
              const SizedBox(height: 4),
              Text(
                'One condition per line, up to 6. Use {company} for the company name. Leave blank to use the '
                'default conditions shown.',
                style: _hint,
              ),
              const SizedBox(height: 18),
              Text('Personal details printed on the card', style: _label),
              const SizedBox(height: 4),
              for (final (key, label, hint, value, set) in [
                (
                  'show_date_of_birth',
                  'Date of birth',
                  'Front of the card',
                  _form.showDateOfBirth,
                  (bool v) => _form.copyWith(showDateOfBirth: v)
                ),
                (
                  'show_residential_address',
                  'Residential address',
                  'Back of the card',
                  _form.showResidentialAddress,
                  (bool v) => _form.copyWith(showResidentialAddress: v)
                ),
                (
                  'show_contact_details',
                  'Phone and email',
                  'Back of the card (Contact Details)',
                  _form.showContactDetails,
                  (bool v) => _form.copyWith(showContactDetails: v)
                ),
              ])
                CheckboxListTile(
                  key: Key('idcs-toggle-$key'),
                  value: value,
                  onChanged: canEdit ? (v) => _update(set(v ?? false)) : null,
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text.rich(TextSpan(children: [
                    TextSpan(text: label, style: AppTextStyles.bodySmall),
                    TextSpan(text: ' — $hint', style: _hint.copyWith(fontSize: 11.5)),
                  ])),
                ),
            ],
          ),

          // ── Layout preview ──
          _Section(
            icon: Icons.visibility_outlined,
            title: 'Layout preview',
            children: [
              Text.rich(
                TextSpan(style: _hint, children: const [
                  TextSpan(
                      text: 'Sample layout with placeholder text. To preview and print a real card, open an '
                          'employee\'s profile and choose '),
                  TextSpan(text: 'ID Card', style: TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(text: '.'),
                ]),
              ),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, c) {
                final scale = ((c.maxWidth - 16) / IdCardSpec.cardW).clamp(3.0, 5.0);
                return Wrap(
                  key: const Key('idcs-preview'),
                  alignment: WrapAlignment.center,
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    IdCardFrontFace(key: const Key('idcs-preview-front'), data: sample, scale: scale),
                    IdCardBackFace(
                      key: const Key('idcs-preview-back'),
                      data: sample,
                      scale: scale,
                      signatureImage: shownSigFile == null ? null : FileImage(File(shownSigFile.path)),
                    ),
                  ],
                );
              }),
            ],
          ),

          if (canEdit) ...[
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              OutlinedButton(
                key: const Key('idcs-cancel'),
                onPressed: !_dirty || _saving ? null : _resetChanges,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              _saveButton(),
            ]),
          ],
        ],
      ),
    );
  }

  TextStyle get _hint => AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 12.5, height: 1.5);
  TextStyle get _label => AppTextStyles.label.copyWith(fontWeight: FontWeight.w600);

  InputDecoration _input({String? hint}) => InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.children});
  final IconData icon;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Material(
          color: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(children: [
                Icon(icon, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(title, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
              ]),
            ),
            Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
            ),
          ]),
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({super.key, required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary))),
        ]),
      );
}

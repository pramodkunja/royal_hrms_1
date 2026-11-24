import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../approvals/presentation/widgets/approvals_ui.dart' show ApprovalsIconBox;
import '../../../data/models/company_model.dart';
import '../../providers/settings_providers.dart';

// Mirrors the web "Email Branding" card added to the same settings page —
// shows the header/footer that gets wrapped around every outgoing email
// (logo/company name + website/address footer) and lets the fields that
// drive it be edited without leaving this screen. Edits go through the same
// companyProvider used by the full Company Info screen.
class EmailBrandingCard extends ConsumerWidget {
  const EmailBrandingCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyProvider);
    return async.when(
      loading: () => const _BrandingSkeleton(),
      error: (_, __) => _BrandingError(onRetry: () => ref.invalidate(companyProvider)),
      data: (company) => _BrandingCard(company: company),
    );
  }
}

class _BrandingCard extends ConsumerWidget {
  final CompanyModel company;
  const _BrandingCard({required this.company});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLogo = company.logoUrl?.isNotEmpty ?? false;
    // Web's footer text: website | address, city, state — else the company name.
    final addr = [company.address, company.city, company.state].where((s) => s.isNotEmpty).join(', ');
    final footer = [company.website, addr].where((s) => s.isNotEmpty).join('  |  ');
    final footerText = footer.isNotEmpty ? footer : (company.companyName.isNotEmpty ? company.companyName : '—');
    final name = company.companyName.isNotEmpty ? company.companyName : '[Company Name]';

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(t.toUpperCase(),
              style: AppTextStyles.caption.copyWith(
                  fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.textSecondary)),
        );

    return Container(
      key: const Key('email-branding-card'),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          LayoutBuilder(builder: (context, c) {
            final large = MediaQuery.textScalerOf(context).scale(10) / 10 > 1.3 || c.maxWidth < 300;
            final titleBlock = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Email Header & Footer', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 14)),
              Text('Applied to every outgoing email',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11.5)),
            ]);
            final edit = TextButton.icon(
              key: const Key('email-branding-edit'),
              onPressed: () => _openEditor(context, ref),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Edit'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(0, 44)),
            );
            final head = Row(children: [
              ApprovalsIconBox(Icons.palette_outlined, color: AppColors.primary, size: 36),
              const SizedBox(width: 10),
              Expanded(child: titleBlock),
              if (!large) edit,
            ]);
            return large
                ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [head, Align(alignment: Alignment.centerLeft, child: edit)])
                : head;
          }),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              label('Header'),
              Container(
                key: const Key('email-branding-header'),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    child: hasLogo
                        ? ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 44, maxWidth: 180),
                            child: Image.network(company.logoUrl!, fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => _nameText(name)),
                          )
                        : _nameText(name),
                  ),
                  Container(height: 3, color: AppColors.primary),
                ]),
              ),
              const SizedBox(height: 12),
              label('Footer'),
              Container(
                key: const Key('email-branding-footer'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.backgroundLow,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(footerText,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.5)),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _nameText(String name) => Text(name,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, fontSize: 15, color: AppColors.textPrimary));

  Future<void> _openEditor(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: _EmailBrandingEditorSheet(company: company),
      ),
    );
  }
}

class _BrandingSkeleton extends StatelessWidget {
  const _BrandingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
    );
  }
}

/// The company details (header/footer source) could not be loaded: said, with
/// Retry — web falls back to a placeholder preview, but a silently missing
/// card would read as "no branding".
class _BrandingError extends StatelessWidget {
  const _BrandingError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('email-branding-error'),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, size: 18, color: AppColors.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text("Couldn't load the email header & footer.",
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error)),
        ),
        TextButton(
          key: const Key('email-branding-retry'),
          onPressed: onRetry,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary, minimumSize: const Size(0, 44)),
          child: const Text('Retry'),
        ),
      ]),
    );
  }
}

// ── Editor ────────────────────────────────────────────────────────────────────

class _EmailBrandingEditorSheet extends ConsumerStatefulWidget {
  final CompanyModel company;
  const _EmailBrandingEditorSheet({required this.company});

  @override
  ConsumerState<_EmailBrandingEditorSheet> createState() => _EmailBrandingEditorSheetState();
}

class _EmailBrandingEditorSheetState extends ConsumerState<_EmailBrandingEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.company.companyName);
  late final TextEditingController _website = TextEditingController(text: widget.company.website);
  late final TextEditingController _phone = TextEditingController(text: widget.company.officialPhone);
  late final TextEditingController _address = TextEditingController(text: widget.company.address);
  late final TextEditingController _city = TextEditingController(text: widget.company.city);
  String? _selectedState;
  File? _logoFile;
  bool _saving = false;

  static final _urlRe = RegExp(r'^https?://');
  static final _phoneRe = RegExp(r'^[+\d\s\-().\/]{7,20}$');

  @override
  void initState() {
    super.initState();
    _selectedState = widget.company.state.isEmpty ? null : widget.company.state;
  }

  @override
  void dispose() {
    for (final c in [_name, _website, _phone, _address, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 16),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.badge_outlined, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Email Branding',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          Flexible(
            child: Container(
              color: AppColors.background,
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(context).bottom + 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _logoPicker(),
                      const SizedBox(height: 14),
                      _field(_name, 'Company Name *', validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Company name is required' : null),
                      _field(_website, 'Website', keyboardType: TextInputType.url, validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        return _urlRe.hasMatch(v) ? null : 'Must start with http:// or https://';
                      }),
                      _field(_phone, 'Official Phone', keyboardType: TextInputType.phone, validator: (v) {
                        if (v == null || v.isEmpty) return null;
                        return _phoneRe.hasMatch(v) ? null : 'Enter a valid phone number';
                      }),
                      _field(_address, 'Street Address', maxLines: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _field(_city, 'City')),
                          const SizedBox(width: 10),
                          Expanded(child: _stateDropdown()),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _submitButton(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPicker() {
    final hasExisting = widget.company.logoUrl?.isNotEmpty ?? false;
    return Center(
      child: GestureDetector(
        onTap: _pickLogo,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              clipBehavior: Clip.antiAlias,
              child: _logoFile != null
                  ? Image.file(_logoFile!, fit: BoxFit.cover)
                  : hasExisting
                      ? Image.network(widget.company.logoUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(Icons.business, color: AppColors.primary))
                      : Icon(Icons.business, color: AppColors.primary),
            ),
            Positioned(
              bottom: -4, right: -4,
              child: Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  color: AppColors.secondary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        style: AppTextStyles.body,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.error),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _stateDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedState,
        isExpanded: true,
        style: AppTextStyles.body,
        decoration: InputDecoration(
          labelText: 'State',
          labelStyle: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          filled: true,
          fillColor: AppColors.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        items: kIndianStates
            .map((s) => DropdownMenuItem(value: s, child: Text(s, style: AppTextStyles.body, overflow: TextOverflow.ellipsis)))
            .toList(),
        onChanged: (v) => setState(() => _selectedState = v),
      ),
    );
  }

  Widget _submitButton() => FilledButton(
    onPressed: _saving ? null : _submit,
    style: FilledButton.styleFrom(
      minimumSize: const Size(double.infinity, 48),
      backgroundColor: AppColors.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    child: _saving
        ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Text('Save Branding', style: AppTextStyles.label.copyWith(color: Colors.white)),
  );

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final updated = widget.company.copyWith(
      companyName:   _name.text,
      website:       _website.text,
      officialPhone: _phone.text,
      address:       _address.text,
      city:          _city.text,
      state:         _selectedState ?? '',
    );
    final error = await ref.read(companyProvider.notifier).save(updated, logoFile: _logoFile);
    if (!mounted) return;
    setState(() => _saving = false);
    if (error == null) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(error),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }
}

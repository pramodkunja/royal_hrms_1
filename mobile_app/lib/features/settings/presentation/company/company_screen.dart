import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/company_model.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import 'widgets/company_form_fields.dart';

class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key});

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  final _formKey = GlobalKey<FormState>();
  CompanyModel? _draft;
  File? _logoFile;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(companyProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Company Info'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(message: err.toString()),
        data: (company) {
          _draft ??= company;
          final hasLogo = _logoFile != null || (_draft!.logoUrl?.isNotEmpty ?? false);
          return _Body(
            formKey: _formKey,
            company: _draft!,
            logoFile: _logoFile,
            isSaving: _saving,
            onChanged: (updated) => setState(() => _draft = updated),
            onLogoTap: _pickLogo,
            onRemoveLogo: hasLogo ? _removeLogo : null,
            onSave: _submit,
          );
        },
      ),
    );
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _logoFile = File(picked.path));
  }

  void _removeLogo() {
    setState(() {
      if (_logoFile != null) {
        _logoFile = null;
      } else {
        _draft = _draft!.copyWith(logoUrl: '');
      }
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final error = await ref.read(companyProvider.notifier).save(_draft!, logoFile: _logoFile);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Company info saved successfully.'),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final CompanyModel company;
  final File? logoFile;
  final bool isSaving;
  final ValueChanged<CompanyModel> onChanged;
  final VoidCallback onLogoTap;
  final VoidCallback? onRemoveLogo;
  final VoidCallback onSave;

  const _Body({
    required this.formKey,
    required this.company,
    required this.logoFile,
    required this.isSaving,
    required this.onChanged,
    required this.onLogoTap,
    this.onRemoveLogo,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LogoSection(
              currentUrl: company.logoUrl,
              logoFile: logoFile,
              companyName: company.companyName,
              onTap: onLogoTap,
              onRemove: onRemoveLogo,
            ),
            const SizedBox(height: 24),
            CompanyFormFields(company: company, onChanged: onChanged),
            const SizedBox(height: 28),
            _SaveButton(isSaving: isSaving, onSave: onSave),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Save button ───────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;
  const _SaveButton({required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isSaving ? null : onSave,
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: AppColors.primary,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
      ),
      child: isSaving
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.save_outlined, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Save Changes',
                  style: AppTextStyles.label.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Logo section ──────────────────────────────────────────────────────────────

class _LogoSection extends StatelessWidget {
  final String? currentUrl;
  final File? logoFile;
  final String companyName;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _LogoSection({
    this.currentUrl,
    this.logoFile,
    required this.companyName,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Navy gradient banner with centered logo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF102C52), AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: GestureDetector(
                onTap: onTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.6),
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: logoFile != null
                            ? Image.file(logoFile!, fit: BoxFit.cover)
                            : (currentUrl != null && currentUrl!.isNotEmpty)
                                ? Image.network(currentUrl!, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => _logoPlaceholder())
                                : _logoPlaceholder(),
                      ),
                    ),
                    Positioned(
                      bottom: -5,
                      right: -5,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                      ),
                    ),
                    if (onRemove != null)
                      Positioned(
                        top: -5,
                        left: -5,
                        child: GestureDetector(
                          onTap: onRemove,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.close, size: 13, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Info row below the banner
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName.isNotEmpty ? companyName : 'Your Company',
                        style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.touch_app_outlined, size: 13, color: AppColors.textHint),
                          const SizedBox(width: 4),
                          Text(
                            'Tap logo to change',
                            style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'JPG · PNG\nmax 5 MB',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontSize: 10,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    final initial = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'C';
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: Center(
        child: Text(
          initial,
          style: AppTextStyles.h2.copyWith(
            color: AppColors.primary, fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ── Error ─────────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_outlined, size: 52, color: AppColors.textHint),
            const SizedBox(height: 12),
            Text('Could not load company info', style: AppTextStyles.h4),
            const SizedBox(height: 6),
            Text(message, style: AppTextStyles.bodySecondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

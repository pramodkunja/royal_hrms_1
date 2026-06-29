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
      appBar: SettingsAppBar(
        title: 'Company Info',
        trailing: async.hasValue
            ? TextButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                      )
                    : Text('Save',
                        style: AppTextStyles.label.copyWith(
                          color: AppColors.primary, fontWeight: FontWeight.w700,
                        )),
              )
            : null,
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => _ErrorView(message: err.toString()),
        data: (company) {
          _draft ??= company;
          return _Body(
            formKey: _formKey,
            company: _draft!,
            logoFile: _logoFile,
            onChanged: (updated) => setState(() => _draft = updated),
            onLogoTap: _pickLogo,
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
  final ValueChanged<CompanyModel> onChanged;
  final VoidCallback onLogoTap;

  const _Body({
    required this.formKey,
    required this.company,
    required this.logoFile,
    required this.onChanged,
    required this.onLogoTap,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LogoSection(
              currentUrl: company.logoUrl,
              logoFile: logoFile,
              companyName: company.companyName,
              onTap: onLogoTap,
            ),
            const SizedBox(height: 28),
            CompanyFormFields(company: company, onChanged: onChanged),
            const SizedBox(height: 32),
          ],
        ),
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

  const _LogoSection({
    this.currentUrl,
    this.logoFile,
    required this.companyName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppColors.cardShadow,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: logoFile != null
                        ? Image.file(logoFile!, fit: BoxFit.cover)
                        : (currentUrl != null && currentUrl!.isNotEmpty)
                            ? Image.network(currentUrl!, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _logoPlaceholder(companyName))
                            : _logoPlaceholder(companyName),
                  ),
                ),
                Positioned(
                  bottom: -6,
                  right: -6,
                  child: Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
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
                const SizedBox(height: 4),
                Text(
                  'Tap the logo to change it',
                  style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'JPG, PNG • max 5MB',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary, fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder(String name) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'C';
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

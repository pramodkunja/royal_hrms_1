import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/permissions/permission_providers.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_error_state.dart';
import '../../data/models/company_model.dart';
import '../../domain/company_validation.dart';
import '../providers/settings_providers.dart';
import '../widgets/settings_app_bar.dart';
import 'widgets/company_form_fields.dart';
import 'widgets/company_widgets.dart';
import 'widgets/financial_year_section.dart';
import 'widgets/plan_details_tab.dart';

/// Picks a new company logo (web: JPEG, PNG, WebP or SVG). The original file
/// is used as picked — never re-compressed. Tests override it.
final companyLogoPickerProvider = Provider<Future<File?> Function()>((ref) => () async {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: kCompanyLogoExtensions,
      );
      final path = res?.files.single.path;
      return path == null ? null : File(path);
    });

/// Company Information (web settings/company/page.tsx) and, for settings.edit
/// users, Plan Details. [initialTab] mirrors web's `?tab=plan`.
class CompanyScreen extends ConsumerStatefulWidget {
  const CompanyScreen({super.key, this.initialTab = CompanyTab.info});

  final CompanyTab initialTab;

  @override
  ConsumerState<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends ConsumerState<CompanyScreen> {
  final _fieldsKey = GlobalKey<CompanyFormFieldsState>();
  CompanyModel? _draft;
  File? _logoFile;
  bool _saving = false;
  late CompanyTab _tab = widget.initialTab;

  /// Web `logoRemoved`: the saved logo is marked for removal; it is sent as
  /// `remove_logo=true` on Save. Nothing changes on the server until then.
  bool _logoRemoved = false;

  void _snack(String message, {required bool error}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.error : AppColors.success,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(companyProvider);
    // Web: logo Upload/Remove, Save Changes and the Plan Details tab only with
    // settings.edit (usePermission); others see the details read-only.
    final canEdit = ref.watch(permissionProvider('settings.edit'));
    final tab = (canEdit && _tab == CompanyTab.plan) ? CompanyTab.plan : CompanyTab.info;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SettingsAppBar(title: 'Company Info'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => AppErrorState.forError(err, onRetry: () => ref.invalidate(companyProvider)),
        data: (company) {
          _draft ??= company;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                    sliver: SliverToBoxAdapter(child: _top(company, tab)),
                  ),
                  if (canEdit)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabsDelegate(
                        extent: 58 + 30 * (MediaQuery.textScalerOf(context).scale(10) / 10 - 1).clamp(0.0, 1.5),
                        selected: tab,
                        onSelected: (t) {
                          FocusScope.of(context).unfocus();
                          setState(() => _tab = t);
                        },
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 32),
                    sliver: SliverToBoxAdapter(
                      child: tab == CompanyTab.plan ? const PlanDetailsTab() : _info(company, canEdit),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      // Web's bottom Cancel / Save Changes row, kept in reach on a phone;
      // steps aside while the keyboard is open.
      bottomNavigationBar: (async.hasValue && canEdit && tab == CompanyTab.info && !keyboardOpen) ? _bottomBar() : null,
    );
  }

  Widget _top(CompanyModel company, CompanyTab tab) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tab == CompanyTab.plan ? 'Plan Details' : 'Company Information', style: AppTextStyles.h4),
        const SizedBox(height: 2),
        Text(
          tab == CompanyTab.plan
              ? 'Your subscription, the modules it includes, other plans and payment history'
              : 'Legal entity details, statutory identifiers, and registered address',
          style: AppTextStyles.caption.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 14),
        CompanyHeaderCard(
          company: company,
          // Web displayLogo: picked image ?? (removed ? none : saved logo).
          logoUrl: _logoRemoved ? null : company.logoUrl,
          logoFile: _logoFile,
        ),
      ],
    );
  }

  Widget _info(CompanyModel company, bool canEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FinancialYearSection(),
        const SizedBox(height: 16),
        // Read-only without settings.edit (nothing can be saved anyway).
        IgnorePointer(
          key: const Key('company-fields'),
          ignoring: !canEdit,
          child: CompanyFormFields(
            key: _fieldsKey,
            company: _draft!,
            readOnly: !canEdit,
            onChanged: (updated) => setState(() => _draft = updated),
            branding: canEdit ? _logoControls(company) : null,
          ),
        ),
      ],
    );
  }

  Widget _logoControls(CompanyModel company) {
    final hasLogo = _logoFile != null || (!_logoRemoved && (company.logoUrl?.isNotEmpty ?? false));
    final status = _logoFile != null
        ? 'New logo selected: ${_logoFile!.path.split('/').last} — Save Changes to apply.'
        : _logoRemoved
            ? 'The logo will be removed when you save.'
            : hasLogo
                ? 'Logo set.'
                : 'No logo uploaded.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Company Logo', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(
          'Used on payslips and other documents issued in your name · JPEG, PNG, WebP or SVG · Max 5 MB',
          style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 6),
        Text(status, key: const Key('company-logo-status'), style: AppTextStyles.caption),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('company-logo-change'),
              onPressed: _saving ? null : _pickLogo,
              icon: const Icon(Icons.upload_outlined, size: 16),
              label: Text(hasLogo ? 'Change' : 'Upload'),
            ),
            if (hasLogo)
              OutlinedButton.icon(
                key: const Key('company-logo-remove'),
                onPressed: _saving ? null : _removeLogo,
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Remove'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _pickLogo() async {
    final picked = await ref.read(companyLogoPickerProvider)();
    if (picked == null || !mounted) return;
    // Web handleLogoChange: type, then size; a refusal changes nothing.
    final problem = companyLogoError(picked.path, await picked.length());
    if (problem != null) return _snack(problem, error: true);
    if (!mounted) return;
    // A new image replaces any pending removal.
    setState(() {
      _logoFile = picked;
      _logoRemoved = false;
    });
  }

  /// Web handleLogoRemove: local only — drops a picked image and marks the
  /// saved logo for removal. No request, no confirmation.
  void _removeLogo() => setState(() {
        _logoFile = null;
        _logoRemoved = true;
      });

  void _cancel() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.settings);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_fieldsKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    // Web precedence: a picked file is uploaded; otherwise a pending removal
    // is sent as remove_logo=true; otherwise the logo is left alone.
    final error = await ref.read(companyProvider.notifier).save(
          _draft!,
          logoFile: _logoFile,
          removeLogo: _logoFile == null && _logoRemoved,
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (error == null) {
        // The form now mirrors what the server saved (incl. its logo_url);
        // the picked file / pending removal have been applied.
        final saved = ref.read(companyProvider).valueOrNull;
        if (saved != null) _draft = saved;
        _logoFile = null;
        _logoRemoved = false;
      }
      // On failure everything is kept (form edits, picked file, pending
      // removal) so the user can retry; the saved company is unchanged.
    });
    _snack(error ?? 'Company info saved successfully.', error: error != null);
  }

  Widget _bottomBar() {
    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Row(
                children: [
                  OutlinedButton(
                    key: const Key('company-cancel'),
                    onPressed: _saving ? null : _cancel,
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _submit,
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(_saving ? 'Saving…' : 'Save Changes'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(0, 46),
                        textStyle: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabsDelegate extends SliverPersistentHeaderDelegate {
  _TabsDelegate({required this.extent, required this.selected, required this.onSelected});

  final double extent;
  final CompanyTab selected;
  final ValueChanged<CompanyTab> onSelected;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: CompanyTabStrip(selected: selected, onSelected: onSelected),
    );
  }

  @override
  bool shouldRebuild(covariant _TabsDelegate old) => true;
}

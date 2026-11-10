import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/access_control.dart' show userHasPermission;
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../data/models/employee_id_card_model.dart';
import '../id_card/id_card_faces.dart';
import '../id_card/id_card_pdf.dart';
import '../id_card/id_card_spec.dart';
import '../providers/employee_providers.dart';

/// Web /dashboard/employees/<id>/id-card (app/dashboard/employees/[id]/
/// id-card/page.tsx): the employee's ID card — "not on record" warning,
/// front/back preview, print layout (card size or A4 sheet) and Print. On
/// mobile, Print opens the system print dialog (which also offers "Save as
/// PDF") and Share PDF hands the same PDF to any app.
///
/// Access: employees.view + branch scope, as the employee profile
/// (EmployeeIdCardView); the route inherits /dashboard/employees.
class EmployeeIdCardScreen extends ConsumerStatefulWidget {
  const EmployeeIdCardScreen({super.key, required this.employeeId});
  final String employeeId;

  @override
  ConsumerState<EmployeeIdCardScreen> createState() => _EmployeeIdCardScreenState();
}

class _EmployeeIdCardScreenState extends ConsumerState<EmployeeIdCardScreen> {
  IdCardPrintLayout _layout = IdCardPrintLayout.card;
  String? _busy; // 'print' | 'share'
  IdCardPdfAssets? _assets;

  bool get _canView => userHasPermission(ref.read(authStateProvider).valueOrNull?.user, 'employees.view');

  Future<void> _output(IdCardData data, {required bool share}) async {
    if (_busy != null || !_canView) return;
    setState(() => _busy = share ? 'share' : 'print');
    IdCardPaperTooSmall? tooSmall;
    try {
      final assets = _assets ??= await loadIdCardPdfAssets(
        data,
        fonts: ref.read(idCardPdfFontsProvider),
        image: ref.read(idCardImageLoaderProvider),
      );
      final shaped = await rasterizeIdCardTexts(data, assets, rasterize: ref.read(idCardTextRasterizerProvider));
      final layout = _layout;
      final out = ref.read(idCardOutputProvider);
      if (share) {
        // Share: the card-size PDF (each page exactly 50 × 85 mm) or the A4 sheet.
        await out.share(
            await buildIdCardPdf(data, layout, assets, shaped: shaped), idCardFileName(data, widget.employeeId));
      } else {
        // Print: laid out for the paper the print dialog selects — Android
        // has no 50 × 85 mm paper, so the card is centred at actual size on it.
        await out.print(
          (paper) async {
            try {
              return await buildIdCardPdf(data, layout, assets, shaped: shaped, paper: paper);
            } on IdCardPaperTooSmall catch (e) {
              tooSmall = e;
              rethrow;
            }
          },
          'ID Card – ${data.employee.fullName ?? widget.employeeId}',
          idCardPageFormat(layout),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(tooSmall?.message ?? 'Could not create the ID card PDF.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allowed = userHasPermission(ref.watch(authStateProvider).valueOrNull?.user, 'employees.view');
    final async = allowed ? ref.watch(employeeIdCardProvider(widget.employeeId)) : null;
    final data = async?.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to profile',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        titleSpacing: 0,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ID Card', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
          Text(data?.subtitle ?? 'Preview and print',
              key: const Key('idcard-subtitle'),
              style: AppTextStyles.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ]),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('idcard-share'),
                onPressed: data == null || _busy != null ? null : () => _output(data, share: true),
                icon: _busy == 'share' ? _spinner(AppColors.primary) : const Icon(Icons.share_outlined, size: 18),
                label: const Text('Share PDF'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                key: const Key('idcard-print'),
                onPressed: data == null || _busy != null ? null : () => _output(data, share: false),
                icon: _busy == 'print' ? _spinner(Colors.white) : const Icon(Icons.print_outlined, size: 18),
                label: const Text('Print'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              ),
            ),
          ]),
        ),
      ),
      body: !allowed
          ? const _Message(
              key: Key('idcard-error'),
              icon: Icons.lock_outline,
              text: "You don't have permission to generate ID cards.")
          : async!.when(
              loading: () => const Center(
                key: Key('idcard-loading'),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('Loading ID card…'),
                ]),
              ),
              error: (e, _) => _Message(
                key: const Key('idcard-error'),
                icon: Icons.error_outline,
                text: idCardLoadError(e),
                onRetry: () => ref.invalidate(employeeIdCardProvider(widget.employeeId)),
              ),
              data: (d) => RefreshIndicator(
                onRefresh: () async {
                  _assets = null;
                  ref.invalidate(employeeIdCardProvider(widget.employeeId));
                  await ref.read(employeeIdCardProvider(widget.employeeId).future);
                },
                child: _body(d),
              ),
            ),
    );
  }

  Widget _body(IdCardData d) {
    return LayoutBuilder(builder: (context, c) {
      // Web shows both faces enlarged (zoom 1.7 ≈ 6.4 px/mm) and wraps them
      // on narrow screens; on a phone that is one above the other.
      final scale = ((c.maxWidth - 64) / IdCardSpec.cardW).clamp(3.0, 6.4);
      return ListView(padding: const EdgeInsets.all(16), children: [
        if (d.missing.isNotEmpty) ...[
          Container(
            key: const Key('idcard-missing'),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8E6),
              border: Border.all(color: const Color(0xFFF3D58A)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFF7A5A00), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(style: const TextStyle(color: Color(0xFF7A5A00), fontSize: 13), children: [
                    const TextSpan(
                        text: 'Not on record, so left off the card: ', style: TextStyle(fontWeight: FontWeight.w700)),
                    TextSpan(text: '${d.missing.join(', ')}.'),
                    const TextSpan(
                        text:
                            '\nAdd them to the employee profile, Company Info, or Settings → ID Card, then reload this page.',
                        style: TextStyle(fontSize: 12)),
                  ]),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
        ],
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(children: [
                Icon(Icons.visibility_outlined, size: 18, color: AppColors.primary),
                const SizedBox(width: 6),
                Text('Preview', style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text('Print layout', style: AppTextStyles.caption),
                const SizedBox(width: 8),
                DropdownButton<IdCardPrintLayout>(
                  key: const Key('idcard-layout'),
                  value: _layout,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final l in IdCardPrintLayout.values)
                      DropdownMenuItem(
                          value: l,
                          child: Text(l == IdCardPrintLayout.card ? 'Card size' : 'A4 sheet',
                              style: AppTextStyles.bodySmall)),
                  ],
                  onChanged: _busy != null ? null : (v) => setState(() => _layout = v ?? _layout),
                ),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: 28,
                runSpacing: 20,
                children: [
                  for (final front in [true, false])
                    Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(front ? 'FRONT' : 'BACK',
                          style: AppTextStyles.caption.copyWith(
                              fontWeight: FontWeight.w600, letterSpacing: .6, color: AppColors.textSecondary)),
                      const SizedBox(height: 8),
                      front
                          ? IdCardFrontFace(key: const Key('idcard-front'), data: d, scale: scale)
                          : IdCardBackFace(key: const Key('idcard-back'), data: d, scale: scale),
                    ]),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Container(
          key: const Key('idcard-print-hint'),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.info_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(style: AppTextStyles.caption.copyWith(fontSize: 12.5, height: 1.5), children: [
                  TextSpan(text: '${_layout.label}: ', style: const TextStyle(fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: '${_layout.hint} In the print dialog choose your printer and keep the size at '
                          '100% / Actual size (not “Fit to page”). For a double-sided card, use the printer\'s '
                          'two-sided option if it has one; otherwise print the front, re-feed the card and print the back.'),
                ]),
              ),
            ),
          ]),
        ),
      ]);
    });
  }

  Widget _spinner(Color color) =>
      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: color));
}

class _Message extends StatelessWidget {
  const _Message({super.key, required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: AppTextStyles.body),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(key: const Key('idcard-retry'), onPressed: onRetry, child: const Text('Retry')),
            ],
          ]),
        ),
      );
}

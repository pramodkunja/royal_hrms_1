import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/network/api_client.dart' show userFriendlyMessage;
import '../../../../../core/permissions/permission_providers.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../profile/presentation/widgets/profile_widgets.dart';
import '../../../data/models/company_model.dart';
import '../../providers/settings_providers.dart';

// Financial Year Configuration — shown on the Company Information tab, saved
// independently of the company form (web FinancialYearSection.tsx). Leave
// Allocation, Carry Forward, Attendance, Payroll and Reports all derive their
// current / previous / next year from this one setting.
class FinancialYearSection extends ConsumerStatefulWidget {
  const FinancialYearSection({super.key});

  @override
  ConsumerState<FinancialYearSection> createState() => _FinancialYearSectionState();
}

class _FinancialYearSectionState extends ConsumerState<FinancialYearSection> {
  String? _draftMonth;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(financialYearProvider);
    // The server's PUT requires settings.edit; it decides, never the role
    // name. This only controls whether the edit control renders at all.
    final canEdit = ref.watch(permissionProvider('settings.edit'));

    return ProfileSectionCard(
      icon: Icons.calendar_month_outlined,
      title: 'Financial Year Configuration',
      child: async.when(
        loading: () => const Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 10),
            Expanded(child: Text('Loading financial year configuration…')),
          ],
        ),
        error: (err, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userFriendlyMessage(err),
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () => ref.invalidate(financialYearProvider),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
            ),
          ],
        ),
        data: (data) {
          _draftMonth ??= data.startMonth;
          final dirty = _draftMonth != data.startMonth;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure the financial year once, here. Leave Allocation, Carry Forward, Attendance, Payroll, '
                'and Reports all derive their current / previous / next year from this single setting instead of '
                'each assuming a January–December calendar year.',
                style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 14),
              Text(
                'Financial Year Starts In',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              if (canEdit)
                DropdownButtonFormField<String>(
                  initialValue: _draftMonth,
                  isExpanded: true,
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.surface,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.border)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
                  ),
                  items: [for (final m in kMonthNames) DropdownMenuItem(value: m, child: Text(m))],
                  onChanged: (val) => setState(() => _draftMonth = val),
                )
              else
                Text(data.startMonth, style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _YearChip(label: 'Previous Year', value: data.previousFinancialYear, active: false),
                  _YearChip(label: 'Current Year', value: data.currentFinancialYear, active: true),
                  _YearChip(label: 'Next Year', value: data.nextFinancialYear, active: false),
                ],
              ),
              if (canEdit) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: (!dirty || _saving) ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(0, 40),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save_outlined, size: 16),
                      label: Text(_saving ? 'Saving…' : 'Save'),
                    ),
                    if (!dirty && !_saving)
                      Text(
                        'Pick a different month to change it.',
                        style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                      ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    final month = _draftMonth;
    if (month == null) return;
    setState(() => _saving = true);
    final error = await ref.read(financialYearProvider.notifier).save(month);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? 'Financial year configuration updated.'),
      backgroundColor: error == null ? AppColors.success : AppColors.error,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }
}

class _YearChip extends StatelessWidget {
  final String label;
  final String value;
  final bool active;
  const _YearChip({required this.label, required this.value, required this.active});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: active ? AppColors.primary : AppColors.border, width: 1.5),
        color: active ? AppColors.primary.withValues(alpha: 0.06) : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 3),
          Text(value.isEmpty ? '—' : value, style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

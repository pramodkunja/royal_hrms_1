import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_text_styles.dart';
import '../../../../auth/presentation/providers/auth_providers.dart';
import '../../../data/models/company_model.dart';
import '../../providers/settings_providers.dart';

// Financial Year Configuration — shown on the Company Info screen, saved
// independently of the company form (matches web). Leave Allocation, Carry
// Forward, Attendance, Payroll and Reports all derive their current /
// previous / next year from this one setting instead of assuming a
// January–December calendar year.
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
    // The API enforces this server-side too (403 on PUT for anyone else) —
    // this only controls whether the edit control renders at all.
    final role = ref.watch(authStateProvider).valueOrNull?.user?.role ?? '';
    final isSystemAdmin = role == 'system_admin';

    return _Card(
      child: async.when(
        loading: () => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Text('Loading financial year configuration…'),
            ],
          ),
        ),
        error: (err, _) => Text(
          'Could not load financial year configuration.',
          style: AppTextStyles.bodySecondary.copyWith(color: AppColors.error),
        ),
        data: (data) {
          _draftMonth ??= data.startMonth;
          final dirty = _draftMonth != data.startMonth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Configure the financial year once, here. Leave Allocation, Carry '
                'Forward, Attendance, Payroll and Reports all derive their current, '
                'previous and next year from this single setting.',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 14),
              if (isSystemAdmin) ...[
                Text('Financial Year Starts In', style: AppTextStyles.label),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _draftMonth,
                  isExpanded: true,
                  style: AppTextStyles.body,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                  items: kMonthNames
                      .map((m) => DropdownMenuItem(value: m, child: Text(m, style: AppTextStyles.body)))
                      .toList(),
                  onChanged: (val) => setState(() => _draftMonth = val),
                ),
                const SizedBox(height: 16),
              ] else ...[
                Text('Financial Year Starts In', style: AppTextStyles.label),
                const SizedBox(height: 4),
                Text(
                  data.startMonth,
                  style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 16),
              ],
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _YearChip(label: 'Previous Year', value: data.previousFinancialYear, active: false),
                  _YearChip(label: 'Current Year', value: data.currentFinancialYear, active: true),
                  _YearChip(label: 'Next Year', value: data.nextFinancialYear, active: false),
                ],
              ),
              if (isSystemAdmin) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    SizedBox(
                      height: 38,
                      child: FilledButton.icon(
                        onPressed: (!dirty || _saving) ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: _saving
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.save_outlined, size: 16, color: Colors.white),
                        label: Text(
                          _saving ? 'Saving…' : 'Save',
                          style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (!dirty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pick a different month to change it.',
                          style: AppTextStyles.caption.copyWith(color: AppColors.textHint),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

// ── Card shell ────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            color: AppColors.info,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month_outlined, color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Financial Year Configuration',
                    style: AppTextStyles.label.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            child: child,
          ),
        ],
      ),
    );
  }
}

// ── Year chip ─────────────────────────────────────────────────────────────────

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
          Text(
            value.isEmpty ? '—' : value,
            style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w800),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

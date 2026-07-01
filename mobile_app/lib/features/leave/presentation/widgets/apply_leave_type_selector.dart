import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/entities/leave_entity.dart';

// ── Leave type option ─────────────────────────────────────────────────────────

class LeaveTypeOption {
  final String key;        // same as code — 'CL', 'EL', etc.
  final String code;       // 'CL', 'EL', etc.
  final String label;
  final int balance;       // available days (rounded)
  final int total;         // total entitlement days
  final bool isPaid;
  final bool docRequired;
  final Color color;
  final String policy;

  const LeaveTypeOption({
    required this.key,
    required this.code,
    required this.label,
    required this.balance,
    required this.total,
    required this.isPaid,
    required this.docRequired,
    required this.color,
    required this.policy,
  });

  // Build from backend entities
  factory LeaveTypeOption.fromEntities(
    LeaveTypeEntity type,
    LeaveBalanceEntity? balance,
  ) {
    return LeaveTypeOption(
      key:         type.code,
      code:        type.code,
      label:       type.name,
      balance:     balance?.available.round() ?? 0,
      total:       balance?.total.round() ?? type.maxDays,
      isPaid:      type.isPaid,
      docRequired: type.docRequired,
      color:       _colorForCode(type.code),
      policy:      type.policy,
    );
  }

  static List<LeaveTypeOption> listFromEntities(
    List<LeaveTypeEntity> types,
    List<LeaveBalanceEntity> balances,
  ) {
    return types.map((t) {
      final bal = balances.where((b) => b.typeCode == t.code).firstOrNull;
      return LeaveTypeOption.fromEntities(t, bal);
    }).toList();
  }
}

// ── Color by leave type code ──────────────────────────────────────────────────

Color _colorForCode(String code) => switch (code.toUpperCase()) {
  'CL'  => AppColors.primary,
  'EL'  => AppColors.success,
  'SL'  => AppColors.warning,
  'LWP' => AppColors.textSecondary,
  'ML'  => const Color(0xFFAD95CF),
  'PL'  => AppColors.info,
  _     => AppColors.primary,
};

// ── Leave Type Selector Grid ───────────────────────────────────────────────────

class LeaveTypeSelector extends StatelessWidget {
  final List<LeaveTypeOption> types;
  final String selectedKey;
  final ValueChanged<String> onSelect;

  const LeaveTypeSelector({
    super.key,
    required this.types,
    required this.selectedKey,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (types.isEmpty) {
      return const _SectionLabel(text: 'Select Leave Type', required: true);
    }

    final selected =
        types.firstWhere((t) => t.key == selectedKey, orElse: () => types.first);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel(text: 'Select Leave Type', required: true),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: types.map((lt) {
            final isSelected = lt.key == selectedKey;
            final isLwp = lt.code == 'LWP';
            final pct = isLwp
                ? 1.0
                : lt.total > 0
                    ? (lt.balance / lt.total).clamp(0.0, 1.0)
                    : 0.0;
            return GestureDetector(
              onTap: () => onSelect(lt.key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: isSelected
                      ? lt.color.withValues(alpha: 0.1)
                      : AppColors.backgroundLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? lt.color : AppColors.border,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 28, height: 28,
                          decoration: BoxDecoration(
                            color: lt.color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Center(
                            child: Text(lt.code,
                                style: AppTextStyles.caption.copyWith(
                                    color: lt.color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 9)),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            width: 14, height: 14,
                            decoration: BoxDecoration(
                                color: lt.color, shape: BoxShape.circle),
                            child: const Icon(Icons.check,
                                size: 9, color: Colors.white),
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(lt.label,
                        style: AppTextStyles.caption.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    if (isLwp)
                      Text('Unpaid · Unlimited',
                          style: AppTextStyles.caption.copyWith(fontSize: 9))
                    else ...[
                      Text('${lt.balance}d left',
                          style: AppTextStyles.caption.copyWith(
                              fontSize: 9,
                              color: lt.color,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 3,
                          backgroundColor:
                              lt.color.withValues(alpha: 0.12),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(lt.color),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        // Policy note for selected type
        Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          decoration: BoxDecoration(
            color: selected.color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 13, color: selected.color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(selected.policy,
                    style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool required;
  const _SectionLabel({required this.text, this.required = false});

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
          const Text(' *',
              style: TextStyle(
                  color: AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ── Field label (exported for use in apply_leave_tab) ─────────────────────────

class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const FieldLabel({super.key, required this.text, this.required = false});

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
          const Text(' *',
              style: TextStyle(
                  color: AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
      ],
    );
  }
}

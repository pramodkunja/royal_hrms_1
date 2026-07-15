import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/employee_model.dart';
import 'send_wish_sheet.dart';

// ── Date helpers ──────────────────────────────────────────────────────────────
// Mirrors web's WishesTab.tsx `daysUntilAnniversary` / `yearsCompleted`.

/// Days from today until [isoDate]'s month+day next occurs (0 = today).
/// Returns null when [isoDate] is empty/unparsable.
int? _daysUntilAnniversary(String isoDate) {
  if (isoDate.isEmpty) return null;
  final ref = DateTime.tryParse(isoDate);
  if (ref == null) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final thisYear = DateTime(today.year, ref.month, ref.day);
  final diff = thisYear.difference(today).inDays;
  if (diff >= 0) return diff;
  final nextYear = DateTime(today.year + 1, ref.month, ref.day);
  return nextYear.difference(today).inDays;
}

int _yearsCompleted(String isoDate) {
  final ref = DateTime.tryParse(isoDate);
  if (ref == null) return 0;
  final now = DateTime.now();
  var y = now.year - ref.year;
  if (now.month < ref.month || (now.month == ref.month && now.day < ref.day)) {
    y--;
  }
  return y < 0 ? 0 : y;
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

String _fmtDayMonth(String isoDate) {
  final d = DateTime.tryParse(isoDate);
  if (d == null) return '';
  return '${d.day} ${_months[d.month - 1]}';
}

// ── Occasion definition ────────────────────────────────────────────────────

class _Occasion {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final String Function(EmployeeModel) dateOf; // '' = no date field

  const _Occasion({
    required this.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.dateOf,
  });
}

final _occasions = <_Occasion>[
  _Occasion(
    key: 'birthday',
    label: 'Birthday Wish',
    icon: Icons.cake_outlined,
    color: const Color(0xFFE53E3E),
    dateOf: (e) => e.dateOfBirth,
  ),
  _Occasion(
    key: 'anniversary',
    label: 'Work Anniversary Wish',
    icon: Icons.work_outline,
    color: AppColors.primary,
    dateOf: (e) => e.dateOfJoining,
  ),
  const _Occasion(
    key: 'other',
    label: 'Other Occasion',
    icon: Icons.celebration_outlined,
    color: Color(0xFF7C3AED),
    dateOf: _noDate,
  ),
];

String _noDate(EmployeeModel _) => '';

// ── Tab ───────────────────────────────────────────────────────────────────────

class WishesTab extends StatefulWidget {
  final EmployeeModel employee;
  const WishesTab({super.key, required this.employee});

  @override
  State<WishesTab> createState() => _WishesTabState();
}

class _WishesTabState extends State<WishesTab> {
  // Session-only — matches web (`useState<Set<string>>`, not persisted).
  final Set<String> _sentOccasions = {};

  Future<void> _openSendSheet(_Occasion occ) async {
    final sent = await SendWishSheet.show(
      context,
      employee: widget.employee,
      occasionKey: occ.key,
    );
    if (sent && mounted) {
      setState(() => _sentOccasions.add(occ.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    return ListView(
      // See employee_profile_screen.dart's _ProfileTab for why this is
      // required (shared PrimaryScrollController from the enclosing
      // NestedScrollView across every kept-alive TabBarView child).
      primary: false,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      children: [
        // Recipient banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.send_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppTextStyles.body
                        .copyWith(fontSize: 12.5, color: AppColors.textSecondary),
                    children: [
                      const TextSpan(text: 'Wish emails will be sent to '),
                      TextSpan(
                        text: emp.fullName,
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                      ),
                      if (emp.email.isNotEmpty) ...[
                        const TextSpan(text: ' at '),
                        TextSpan(
                          text: emp.email,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        for (final occ in _occasions) ...[
          _OccasionCard(
            occasion: occ,
            employee: emp,
            alreadySent: _sentOccasions.contains(occ.key),
            onTap: () => _openSendSheet(occ),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _OccasionCard extends StatelessWidget {
  final _Occasion occasion;
  final EmployeeModel employee;
  final bool alreadySent;
  final VoidCallback onTap;

  const _OccasionCard({
    required this.occasion,
    required this.employee,
    required this.alreadySent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = occasion.dateOf(employee);
    final daysUntil = dateStr.isNotEmpty ? _daysUntilAnniversary(dateStr) : null;
    final isToday = daysUntil == 0;
    final isSoon = daysUntil != null && daysUntil > 0 && daysUntil <= 7;
    final isAnniversary = occasion.key == 'anniversary';
    final years =
        dateStr.isNotEmpty && isAnniversary ? _yearsCompleted(dateStr) : null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isToday ? occasion.color : AppColors.border,
              width: isToday ? 1.5 : 1,
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: occasion.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(occasion.icon, size: 22, color: occasion.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      occasion.label,
                      style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    _DateLine(
                      dateStr: dateStr,
                      hasDateField: occasion.key != 'other',
                      isToday: isToday,
                      isBirthday: occasion.key == 'birthday',
                      daysUntil: daysUntil,
                      years: years,
                      color: occasion.color,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: onTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: alreadySent ? AppColors.textSecondary : occasion.color,
                  side: BorderSide(
                    color: alreadySent ? AppColors.border : occasion.color,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                icon: Icon(alreadySent ? Icons.send_outlined : occasion.icon, size: 14),
                label: Text(
                  alreadySent ? 'Resend' : 'Send Wish',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        if (isToday)
          Positioned(
            top: -1,
            right: 14,
            child: _Badge(label: 'TODAY', color: occasion.color),
          )
        else if (isSoon)
          Positioned(
            top: -1,
            right: 14,
            child: _Badge(
              label: 'IN $daysUntil DAY${daysUntil == 1 ? '' : 'S'}',
              color: AppColors.warning,
            ),
          ),
      ],
    );
  }
}

class _DateLine extends StatelessWidget {
  final String dateStr;
  final bool hasDateField;
  final bool isToday;
  final bool isBirthday;
  final int? daysUntil;
  final int? years;
  final Color color;

  const _DateLine({
    required this.dateStr,
    required this.hasDateField,
    required this.isToday,
    required this.isBirthday,
    required this.daysUntil,
    required this.years,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (dateStr.isEmpty) {
      return Text(
        hasDateField ? 'No date on record' : 'Send a custom wish for any occasion',
        style: AppTextStyles.caption.copyWith(fontSize: 11.5, color: AppColors.textHint),
      );
    }
    final yearsSuffix =
        (years != null && years! > 0) ? ' · ${years!} yr${years != 1 ? 's' : ''}' : '';
    final text = isToday
        ? '${isBirthday ? 'Birthday' : 'Anniversary'} is today!$yearsSuffix'
        : '${_fmtDayMonth(dateStr)} · $daysUntil day${daysUntil == 1 ? '' : 's'} away$yearsSuffix';

    return Row(
      children: [
        Icon(Icons.calendar_today_outlined,
            size: 11, color: isToday ? color : AppColors.textHint),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(
              fontSize: 11.5,
              color: isToday ? color : AppColors.textSecondary,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(8),
          bottomRight: Radius.circular(8),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

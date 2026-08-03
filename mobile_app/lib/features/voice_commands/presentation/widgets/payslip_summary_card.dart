import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

// Mirrors apps/payroll/models.py's EmployeePayslip.STATUS_CHOICES labels —
// hand-copied client-side (there's no API endpoint that hands back this
// mapping), same spirit as executor_payroll.py's own _STATUS_LABELS dict.
// Falls back to a title-cased raw value for any status this map doesn't
// recognize, so a future status added server-side degrades gracefully
// instead of showing nothing.
const _kStatusLabels = {
  'draft': 'Draft',
  'sent': 'Sent to Employee',
  'acknowledged': 'Acknowledged',
  'queried': 'Query Raised',
  'resolved': 'Query Resolved',
  'paid': 'Paid',
};

String _statusLabel(String raw) {
  return _kStatusLabels[raw] ?? raw.replaceAll('_', ' ').split(' ').map((w) {
    if (w.isEmpty) return w;
    return w[0].toUpperCase() + w.substring(1);
  }).join(' ');
}

// EmployeePayslipSerializer's DecimalFields arrive as strings (e.g. "50000.00")
// — parsed defensively since a malformed/missing value should just render as
// ₹0.00 rather than crash a voice-command result panel.
String _formatCurrency(dynamic value) {
  final parsed = double.tryParse(value?.toString() ?? '') ?? 0.0;
  final parts = parsed.toStringAsFixed(2).split('.');
  final whole = parts[0].startsWith('-') ? parts[0].substring(1) : parts[0];
  final sign = parts[0].startsWith('-') ? '-' : '';
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '$sign₹$buf.${parts[1]}';
}

class PayslipCardData {
  final String? subjectName;
  final String cycleEnd;
  final String grossEarnings;
  final String totalDeductions;
  final String netPay;
  final String statusLabel;

  const PayslipCardData({
    this.subjectName,
    required this.cycleEnd,
    required this.grossEarnings,
    required this.totalDeductions,
    required this.netPay,
    required this.statusLabel,
  });

  /// Recognizes two shapes voice responses put payslip figures in:
  ///  - check_my_payslip: `result` IS the payslip dict directly
  ///    (EmployeePayslipSerializer's own fields).
  ///  - check_employee_payslip: `result` is
  ///    `{outcome: 'single_match', matched: {...}, payslip: {...}}` — the
  ///    same payslip dict nested under 'payslip', with the target
  ///    employee's name available under matched.employee_name.
  /// Returns null for every other intent's result shape (acknowledge_payslip's
  /// empty dict, raise_payslip_query's query record, leave/attendance data,
  /// disambiguation prompts with no payslip resolved yet, etc.) — callers
  /// simply render nothing extra in that case.
  static PayslipCardData? tryExtract(dynamic result) {
    if (result is! Map) return null;
    final map = Map<String, dynamic>.from(result);

    Map<String, dynamic>? payslip;
    String? subjectName;

    if (map['net_pay'] != null && map['gross_earnings'] != null) {
      payslip = map;
    } else if (map['payslip'] is Map) {
      payslip = Map<String, dynamic>.from(map['payslip'] as Map);
      final matched = map['matched'];
      if (matched is Map && matched['employee_name'] is String) {
        subjectName = matched['employee_name'] as String;
      }
    }

    if (payslip == null) return null;
    if (payslip['net_pay'] == null || payslip['cycle_end'] == null || payslip['status'] == null) {
      return null;
    }

    return PayslipCardData(
      subjectName: subjectName,
      cycleEnd: payslip['cycle_end'].toString(),
      grossEarnings: _formatCurrency(payslip['gross_earnings']),
      totalDeductions: _formatCurrency(payslip['total_deductions']),
      netPay: _formatCurrency(payslip['net_pay']),
      statusLabel: _statusLabel(payslip['status'].toString()),
    );
  }
}

/// Visual summary shown under a voice response's spoken message when the
/// result carries real payslip figures (check_my_payslip / a resolved
/// check_employee_payslip match) — a nicety on top of the message text,
/// which already states these same figures in natural language.
class PayslipSummaryCard extends StatelessWidget {
  final PayslipCardData data;
  const PayslipSummaryCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.backgroundLow,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  data.subjectName != null ? "${data.subjectName}'s payslip" : 'Your payslip',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatusChip(label: data.statusLabel),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Period ending ${data.cycleEnd}',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textHint),
          ),
          const SizedBox(height: 8),
          _FigureRow(label: 'Gross earnings', value: data.grossEarnings),
          _FigureRow(label: 'Total deductions', value: data.totalDeductions),
          const Divider(height: 14),
          _FigureRow(label: 'Net pay', value: data.netPay, emphasize: true),
        ],
      ),
    );
  }
}

class _FigureRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;
  const _FigureRow({required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasize
                ? AppTextStyles.label.copyWith(fontWeight: FontWeight.w600)
                : AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          Text(
            value,
            style: emphasize
                ? AppTextStyles.label.copyWith(fontWeight: FontWeight.w700, color: AppColors.primary)
                : AppTextStyles.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  const _StatusChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.infoContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(color: AppColors.info, fontWeight: FontWeight.w600),
      ),
    );
  }
}

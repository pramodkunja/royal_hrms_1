import 'package:flutter/foundation.dart';

// Mirrors backend's EmployeePayslipSerializer (apps/payroll/serializers.py) —
// every money field is a DRF DecimalField, which serializes as a STRING
// (e.g. "50000.00"), not a JSON number. Parse defensively throughout: a
// malformed/missing value should render as ₹0.00, never crash the screen.

double _money(dynamic value) => double.tryParse(value?.toString() ?? '') ?? 0.0;

/// Formats a raw decimal-as-string/num value as "₹12,345.00".
String formatPayslipCurrency(dynamic value) {
  final parsed = _money(value);
  final parts = parsed.toStringAsFixed(2).split('.');
  final negative = parts[0].startsWith('-');
  final whole = negative ? parts[0].substring(1) : parts[0];
  final buf = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buf.write(',');
    buf.write(whole[i]);
  }
  return '${negative ? '-' : ''}₹$buf.${parts[1]}';
}

// Hand-copied from apps/payroll/models.py's EmployeePayslip.STATUS_CHOICES —
// there's no API endpoint that hands back this label mapping (same approach
// already used by the voice-command payslip summary card). Falls back to a
// title-cased raw value so an unrecognized future status still shows
// something reasonable instead of a blank chip.
const _kStatusLabels = {
  'draft': 'Draft',
  'sent': 'Sent',
  'acknowledged': 'Acknowledged',
  'queried': 'Query Raised',
  'resolved': 'Query Resolved',
  'paid': 'Paid',
};

String payslipStatusLabel(String raw) {
  final known = _kStatusLabels[raw];
  if (known != null) return known;
  if (raw.isEmpty) return raw;
  return raw
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

@immutable
class PayslipModel {
  final String id;
  final String cycleStart;
  final String cycleEnd;
  final String payDate;
  final String employeeName;
  final String employeeIdCode;
  final String department;
  final double basic;
  final double hra;
  final double specialAllowance;
  final Map<String, dynamic> otherEarnings;
  final double reimbursements;
  final double bonus;
  final double grossEarnings;
  final int totalWorkingDays;
  final double lopDays;
  final double lopDeduction;
  final double pfEmployee;
  final double esiEmployee;
  final double ptDeduction;
  final double lwfEmployee;
  final double totalDeductions;
  final double netPay;
  final String status;
  // Always null in practice today — EmployeePayslip.payslip_pdf is a
  // FileField nothing on the backend ever populates (confirmed: no view in
  // apps/payroll/views/*.py ever sets it). Kept nullable rather than
  // omitted so the UI can hide/disable a "Download PDF" affordance
  // correctly if the backend ever starts populating it, without a model
  // change.
  final String? payslipPdfUrl;

  const PayslipModel({
    required this.id,
    required this.cycleStart,
    required this.cycleEnd,
    required this.payDate,
    required this.employeeName,
    required this.employeeIdCode,
    required this.department,
    required this.basic,
    required this.hra,
    required this.specialAllowance,
    required this.otherEarnings,
    required this.reimbursements,
    required this.bonus,
    required this.grossEarnings,
    required this.totalWorkingDays,
    required this.lopDays,
    required this.lopDeduction,
    required this.pfEmployee,
    required this.esiEmployee,
    required this.ptDeduction,
    required this.lwfEmployee,
    required this.totalDeductions,
    required this.netPay,
    required this.status,
    this.payslipPdfUrl,
  });

  factory PayslipModel.fromJson(Map<String, dynamic> json) {
    final otherEarningsRaw = json['other_earnings'];
    return PayslipModel(
      id: json['id']?.toString() ?? '',
      cycleStart: json['cycle_start'] as String? ?? '',
      cycleEnd: json['cycle_end'] as String? ?? '',
      payDate: json['pay_date'] as String? ?? '',
      employeeName: json['employee_name'] as String? ?? '',
      employeeIdCode: json['employee_id_code'] as String? ?? '',
      department: json['department'] as String? ?? '',
      basic: _money(json['basic']),
      hra: _money(json['hra']),
      specialAllowance: _money(json['special_allowance']),
      otherEarnings: otherEarningsRaw is Map
          ? Map<String, dynamic>.from(otherEarningsRaw)
          : const {},
      reimbursements: _money(json['reimbursements']),
      bonus: _money(json['bonus']),
      grossEarnings: _money(json['gross_earnings']),
      totalWorkingDays: (json['total_working_days'] as num?)?.toInt() ?? 0,
      lopDays: _money(json['lop_days']),
      lopDeduction: _money(json['lop_deduction']),
      pfEmployee: _money(json['pf_employee']),
      esiEmployee: _money(json['esi_employee']),
      ptDeduction: _money(json['pt_deduction']),
      lwfEmployee: _money(json['lwf_employee']),
      totalDeductions: _money(json['total_deductions']),
      netPay: _money(json['net_pay']),
      status: json['status'] as String? ?? 'draft',
      payslipPdfUrl: json['payslip_pdf'] as String?,
    );
  }

  double get paidDays => totalWorkingDays - lopDays;

  PayslipModel copyWith({String? status}) => PayslipModel(
    id: id,
    cycleStart: cycleStart,
    cycleEnd: cycleEnd,
    payDate: payDate,
    employeeName: employeeName,
    employeeIdCode: employeeIdCode,
    department: department,
    basic: basic,
    hra: hra,
    specialAllowance: specialAllowance,
    otherEarnings: otherEarnings,
    reimbursements: reimbursements,
    bonus: bonus,
    grossEarnings: grossEarnings,
    totalWorkingDays: totalWorkingDays,
    lopDays: lopDays,
    lopDeduction: lopDeduction,
    pfEmployee: pfEmployee,
    esiEmployee: esiEmployee,
    ptDeduction: ptDeduction,
    lwfEmployee: lwfEmployee,
    totalDeductions: totalDeductions,
    netPay: netPay,
    status: status ?? this.status,
    payslipPdfUrl: payslipPdfUrl,
  );
}

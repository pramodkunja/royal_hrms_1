import 'package:flutter/foundation.dart';

// Mirrors backend's EmployeePayslipSerializer (apps/payroll/serializers.py) —
// every money field is a DRF DecimalField, which serializes as a STRING
// (e.g. "50000.00"), not a JSON number. Parse defensively throughout: a
// malformed/missing value should render as ₹0.00, never crash the screen.

double _money(dynamic value) {
  final v = double.tryParse(value?.toString() ?? '') ?? 0.0;
  return v.isFinite ? v : 0.0; // web num(): NaN / Infinity → 0
}

/// Web `num()` of payslipLayout.ts: a saved amount (string or number) as a
/// number; anything unreadable is 0.
double payslipMoney(dynamic value) => _money(value);

/// Web `INR` (components/payroll/PayslipDocument.tsx):
/// `"₹" + Number(n).toLocaleString("en-IN", { maximumFractionDigits: 0 })` —
/// whole rupees (half away from zero, as Intl rounds), Indian digit grouping
/// (₹1,23,45,678), and a negative sign after the ₹ as web prints it.
String formatPayslipInr(dynamic value) {
  final rounded = _money(value).round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();
  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final head = digits.substring(0, digits.length - 3);
    final tail = digits.substring(digits.length - 3);
    final buf = StringBuffer();
    for (var i = 0; i < head.length; i++) {
      if (i > 0 && (head.length - i) % 2 == 0) buf.write(',');
      buf.write(head[i]);
    }
    grouped = '$buf,$tail';
  }
  return '₹${negative ? '-' : ''}$grouped';
}

/// Web `fmtDate` (`toLocaleDateString("en-IN", {day: "2-digit", month: "short",
/// year: "numeric"})`): "09 Nov 2026", with en-IN's "Sept". Date-only values
/// are read as calendar dates (no time-zone shift); unparseable → as given.
String formatPayslipDate(String iso) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(iso);
  if (m == null) return iso.isEmpty ? '—' : iso;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sept', 'Oct', 'Nov', 'Dec'];
  final month = int.parse(m.group(2)!);
  if (month < 1 || month > 12) return iso;
  return '${m.group(3)} ${months[month - 1]} ${m.group(1)}';
}

/// Web masks the account number as "••••" + its last 4 characters; "—" when none.
String maskPayslipAccount(String account) =>
    account.isEmpty ? '—' : '••••${account.length <= 4 ? account : account.substring(account.length - 4)}';

/// A number as JS prints it: 21 not 21.0, 0.5 stays 0.5.
String payslipNumber(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

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

// The employee's own labels, as web's My Payslips STATUS_BADGE
// (app/dashboard/my-payslip/page.tsx:96-104). (HR's profile Payroll tab has
// its own, different wording: kEmployeePayslipStatusLabel.) Falls back to a
// title-cased raw value so an unrecognized future status still shows
// something reasonable instead of a blank chip.
const _kStatusLabels = {
  'paid': 'Paid',
  'sent': 'Received',
  'acknowledged': 'Acknowledged',
  'queried': 'Query open',
  'resolved': 'Query resolved',
  'draft': 'Processing',
  'closed': 'Closed',
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

/// One saved one-time adjustment (`adjustment_items`): web AdjustmentItem.
/// [type] is "addition", "arrear" or "deduction"; the server stores the
/// amount as a string.
@immutable
class PayslipAdjustmentItem {
  const PayslipAdjustmentItem({required this.type, required this.label, required this.amount});
  final String type;
  final String label;
  final double amount;

  static List<PayslipAdjustmentItem> listFrom(Object? raw) => [
        for (final m in (raw is List ? raw : const []).whereType<Map>())
          PayslipAdjustmentItem(
            type: m['type']?.toString() ?? '',
            label: m['label']?.toString() ?? '',
            amount: _money(m['amount']),
          ),
      ];
}

/// The letterhead saved with the payslip (`company_header`); its fields are
/// laid over the live company record, as web does.
@immutable
class PayslipCompanyHeader {
  const PayslipCompanyHeader({
    this.companyName,
    this.address,
    this.city,
    this.state,
    this.pinCode,
    this.cin,
  });
  final String? companyName;
  final String? address;
  final String? city;
  final String? state;
  final String? pinCode;
  final String? cin;

  static PayslipCompanyHeader? from(Object? raw) {
    if (raw is! Map) return null;
    String? s(String k) => raw[k]?.toString();
    return PayslipCompanyHeader(
      companyName: s('company_name'),
      address: s('address'),
      city: s('city'),
      state: s('state'),
      pinCode: s('pin_code'),
      cin: s('cin'),
    );
  }
}

/// Payslip layouts the server saves (`payslip_template`): web "standard" and
/// "wage_slip". Anything else renders as standard, as web does.
const kPayslipTemplateWageSlip = 'wage_slip';

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

  /// Named extra deductions (`other_deductions`, a JSON object), shown by web
  /// between Labour Welfare Fund and Loss of Pay.
  final Map<String, dynamic> otherDeductions;
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

  /// Until when a query may be raised on this payslip (null: no limit).
  final String? queryDeadline;

  /// One-time adjustments (web `adjustment_items`, `adjustments_earning`,
  /// `adjustments_deduction`): itemised when the payslip saved the items,
  /// else only the saved totals.
  final List<PayslipAdjustmentItem> adjustmentItems;
  final double adjustmentsEarning;
  final double adjustmentsDeduction;

  /// Details printed with the payslip when it was processed.
  final String designation;
  final String principalEmployerName;
  final PayslipCompanyHeader? companyHeader;
  final String payslipTemplate;

  /// UAN / ESIC as the server shows them (masked or hidden per payroll
  /// settings): null = hidden, a string = show (possibly empty → "—").
  final String? uanDisplay;
  final String? esicDisplay;

  /// Wage-slip layout settings: deduction rows always listed, and the signed
  /// stamp image link (short-lived; never logged or printed in messages).
  final List<String> fixedDeductionRows;
  final String? stampUrl;

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
    this.otherDeductions = const {},
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
    this.queryDeadline,
    this.adjustmentItems = const [],
    this.adjustmentsEarning = 0,
    this.adjustmentsDeduction = 0,
    this.designation = '',
    this.principalEmployerName = '',
    this.companyHeader,
    this.payslipTemplate = 'standard',
    this.uanDisplay,
    this.esicDisplay,
    this.fixedDeductionRows = const [],
    this.stampUrl,
  });

  bool get isWageSlip => payslipTemplate == kPayslipTemplateWageSlip;

  factory PayslipModel.fromJson(Map<String, dynamic> json) {
    final otherEarningsRaw = json['other_earnings'];
    final otherDeductionsRaw = json['other_deductions'];
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
      otherEarnings: otherEarningsRaw is Map ? Map<String, dynamic>.from(otherEarningsRaw) : const {},
      otherDeductions: otherDeductionsRaw is Map ? Map<String, dynamic>.from(otherDeductionsRaw) : const {},
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
      queryDeadline: json['query_deadline'] as String?,
      adjustmentItems: PayslipAdjustmentItem.listFrom(json['adjustment_items']),
      adjustmentsEarning: _money(json['adjustments_earning']),
      adjustmentsDeduction: _money(json['adjustments_deduction']),
      designation: json['designation']?.toString() ?? '',
      principalEmployerName: json['principal_employer_name']?.toString() ?? '',
      companyHeader: PayslipCompanyHeader.from(json['company_header']),
      payslipTemplate:
          (json['payslip_template']?.toString() ?? '').isEmpty ? 'standard' : json['payslip_template'].toString(),
      uanDisplay: json['uan_display']?.toString(),
      esicDisplay: json['esic_display']?.toString(),
      fixedDeductionRows: [
        for (final r in (json['fixed_deduction_rows'] is List ? json['fixed_deduction_rows'] as List : const []))
          r.toString(),
      ],
      stampUrl: json['stamp_url']?.toString(),
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
        otherDeductions: otherDeductions,
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
        queryDeadline: queryDeadline,
        adjustmentItems: adjustmentItems,
        adjustmentsEarning: adjustmentsEarning,
        adjustmentsDeduction: adjustmentsDeduction,
        designation: designation,
        principalEmployerName: principalEmployerName,
        companyHeader: companyHeader,
        payslipTemplate: payslipTemplate,
        uanDisplay: uanDisplay,
        esicDisplay: esicDisplay,
        fixedDeductionRows: fixedDeductionRows,
        stampUrl: stampUrl,
      );
}

import '../data/models/payslip_model.dart';

// Presentation of a SAVED payslip in the standard and wage-slip layouts — a
// port of web lib/payslipLayout.ts and the row rules of
// components/payroll/PayslipDocument.tsx / WageSlipDocument.tsx.
//
// Nothing here recalculates payroll: every total shown reconciles to the
// stored figures (gross_earnings, total_deductions, net_pay). Payroll stores
// components at their full monthly value and LOP as one deduction; the wage
// slip instead shows each component's "Actual" (full month) and "Earning"
// (for the days paid), splitting LOP across the components in proportion,
// rounded to rupees, with any rounding difference on the largest component,
// so the Earning column always totals the full components minus the saved LOP.

/// JavaScript `Math.round`: halves go toward +∞ (−2.5 → −2), unlike Dart's
/// `round()` which goes away from zero.
int jsRound(double x) => (x + 0.5).floor();

typedef AmountRow = ({String label, double amount});
typedef WageSlipEarning = ({String label, double? actual, double earned});

/// Salary components that make up the processed gross (full-month values):
/// Basic always, then the others only when non-zero.
List<AmountRow> componentRows(PayslipModel slip) {
  final rows = <AmountRow>[
    (label: 'Basic', amount: slip.basic),
    (label: 'HRA', amount: slip.hra),
    (label: 'Special Allowance', amount: slip.specialAllowance),
    for (final e in slip.otherEarnings.entries) (label: e.key, amount: payslipMoney(e.value)),
  ];
  return [
    for (final (i, r) in rows.indexed)
      if (i == 0 || r.amount != 0) r,
  ];
}

/// Splits [lop] across [actuals] (rupees). The result sums to
/// round(sum(actuals) − lop), never below 0.
List<int> splitLop(List<double> actuals, double lop) {
  final total = actuals.fold<double>(0, (a, b) => a + b);
  if (total <= 0) return List.filled(actuals.length, 0);
  final target = jsRound(total - (lop > 0 ? lop : 0)).clamp(0, 1 << 52);
  final factor = target / total;
  final earned = [for (final a in actuals) jsRound(a * factor)];
  final diff = target - earned.fold<int>(0, (a, b) => a + b);
  if (diff != 0) {
    var largest = 0;
    for (final (i, a) in actuals.indexed) {
      if (a > actuals[largest]) largest = i;
    }
    earned[largest] += diff;
  }
  return earned;
}

enum AdjustmentKind { earning, deduction }

/// One-time adjustments of one kind, itemised when the payslip saved the
/// items, else (older payslips) one line for the saved total.
List<AmountRow> adjustmentRows(PayslipModel slip, AdjustmentKind kind) {
  final deduction = kind == AdjustmentKind.deduction;
  final items = slip.adjustmentItems.where((i) => deduction ? i.type == 'deduction' : i.type != 'deduction');
  if (items.isNotEmpty) return [for (final i in items) (label: i.label, amount: i.amount)];
  final total = deduction ? slip.adjustmentsDeduction : slip.adjustmentsEarning;
  return total != 0 ? [(label: deduction ? 'Other deductions' : 'Additions', amount: total)] : const [];
}

/// True when additions are paid on top of the saved gross (the payslip as
/// processed); false once gross was recomputed to include them (after the
/// reimbursement / bonus step). Either way net pay is the saved value.
bool additionsOutsideGross(PayslipModel slip) {
  final additions = slip.adjustmentsEarning;
  if (additions == 0) return false;
  final components = componentRows(slip).fold<double>(0, (a, r) => a + r.amount);
  final inside = components + slip.bonus + slip.reimbursements + additions;
  return (slip.grossEarnings - inside).abs() > 0.5;
}

/// The standard layout's Earnings rows (web PayslipDocument): Basic, HRA,
/// Special Allowance, Bonus, named other earnings, then the additions when
/// they are inside gross. Zero amounts are hidden; negatives are shown.
List<AmountRow> standardEarningRows(PayslipModel p) => [
      (label: 'Basic Salary', amount: p.basic),
      (label: 'House Rent Allowance (HRA)', amount: p.hra),
      (label: 'Special Allowance', amount: p.specialAllowance),
      (label: 'Bonus', amount: p.bonus),
      for (final e in p.otherEarnings.entries) (label: e.key, amount: payslipMoney(e.value)),
      if (!additionsOutsideGross(p)) ...adjustmentRows(p, AdjustmentKind.earning),
    ].where((r) => r.amount != 0).toList();

/// The standard layout's Deductions rows: PF, ESI, PT, LWF, named others,
/// one-time deductions, and Loss of Pay last. Zero amounts hidden.
List<AmountRow> standardDeductionRows(PayslipModel p) => [
      (label: 'Provident Fund (PF)', amount: p.pfEmployee),
      (label: 'ESI', amount: p.esiEmployee),
      (label: 'Professional Tax (PT)', amount: p.ptDeduction),
      (label: 'Labour Welfare Fund', amount: p.lwfEmployee),
      for (final e in p.otherDeductions.entries) (label: e.key, amount: payslipMoney(e.value)),
      ...adjustmentRows(p, AdjustmentKind.deduction),
      (label: 'Loss of Pay (LOP)', amount: p.lopDeduction),
    ].where((r) => r.amount != 0).toList();

/// The "Additions" panel (shown only when additions are paid on top of
/// gross): its rows and total. Null when not shown.
({List<AmountRow> rows, double total})? additionsPanel(PayslipModel p) {
  if (!additionsOutsideGross(p)) return null;
  final rows = adjustmentRows(p, AdjustmentKind.earning);
  final total = rows.fold<double>(0, (a, r) => a + r.amount);
  return total > 0 ? (rows: rows.where((r) => r.amount != 0).toList(), total: total) : null;
}

class WageSlipModel {
  const WageSlipModel({required this.earnings, required this.deductions, required this.totals});
  final List<WageSlipEarning> earnings;
  final List<AmountRow> deductions;
  final ({double actual, double earned, double deductions, double net}) totals;
}

WageSlipModel wageSlipModel(PayslipModel slip) {
  final components = componentRows(slip);
  final earnedParts = splitLop([for (final r in components) r.amount], slip.lopDeduction);
  final earnings = <WageSlipEarning>[
    for (final (i, r) in components.indexed)
      (label: r.label, actual: jsRound(r.amount).toDouble(), earned: earnedParts[i].toDouble()),
    if (slip.bonus != 0) (label: 'Bonus', actual: null, earned: slip.bonus),
    if (slip.reimbursements != 0) (label: 'Reimbursement', actual: null, earned: slip.reimbursements),
    for (final r in adjustmentRows(slip, AdjustmentKind.earning)) (label: r.label, actual: null, earned: r.amount),
  ];

  final deductions = <AmountRow>[
    (label: 'PF', amount: slip.pfEmployee),
    (label: 'PT', amount: slip.ptDeduction),
    (label: 'ESIC', amount: slip.esiEmployee),
    (label: 'LWF', amount: slip.lwfEmployee),
    for (final e in slip.otherDeductions.entries) (label: e.key, amount: payslipMoney(e.value)),
    ...adjustmentRows(slip, AdjustmentKind.deduction),
  ];
  final present = {for (final d in deductions) d.label.toLowerCase()};
  for (final label in slip.fixedDeductionRows) {
    if (!present.contains(label.toLowerCase())) {
      deductions.add((label: label, amount: 0));
      present.add(label.toLowerCase());
    }
  }

  return WageSlipModel(
    earnings: earnings,
    deductions: deductions,
    totals: (
      actual: jsRound(components.fold<double>(0, (a, r) => a + r.amount)).toDouble(),
      earned: earnings.fold<double>(0, (a, e) => a + e.earned),
      // LOP is already taken out of the Earning column, so not repeated here.
      deductions: slip.totalDeductions - slip.lopDeduction,
      net: slip.netPay,
    ),
  );
}

const _months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const _monthsLong = [
  'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', 'JULY', 'AUGUST', 'SEPTEMBER', //
  'OCTOBER', 'NOVEMBER', 'DECEMBER',
];

/// "WAGES SLIP FOR THE MONTH OF SEPTEMBER-2026" for a calendar-month cycle,
/// otherwise "WAGES SLIP FOR THE PERIOD 24 AUG-26 TO 22 SEP-26".
String wageSlipPeriodLabel(String cycleStart, String cycleEnd) {
  List<int>? parts(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    return m == null ? null : [for (var i = 1; i <= 3; i++) int.parse(m.group(i)!)];
  }

  final a = parts(cycleStart), b = parts(cycleEnd);
  if (a == null || b == null || a[1] < 1 || a[1] > 12 || b[1] < 1 || b[1] > 12) {
    return 'WAGES SLIP FOR THE PERIOD $cycleStart TO $cycleEnd';
  }
  final (sy, sm, sd) = (a[0], a[1], a[2]);
  final (ey, em, ed) = (b[0], b[1], b[2]);
  final lastDay = DateTime.utc(sy, sm + 1, 0).day;
  if (sd == 1 && sy == ey && sm == em && ed == lastDay) {
    return 'WAGES SLIP FOR THE MONTH OF ${_monthsLong[sm - 1]}-$sy';
  }
  String fmt(int y, int m, int d) => '$d ${_months[m - 1]}-${(y % 100).toString().padLeft(2, '0')}';
  return 'WAGES SLIP FOR THE PERIOD ${fmt(sy, sm, sd)} TO ${fmt(ey, em, ed)}';
}

/// Web WageSlipDocument `amt`: `toLocaleString("en-IN", {maximumFractionDigits:
/// 2})` — Indian grouping, up to two decimals, no trailing zeros, no ₹.
String formatWageSlipAmount(double n) {
  final scaled = (n.abs() * 100).round(); // half away from zero (ICU halfExpand)
  final whole = scaled ~/ 100;
  final frac = scaled % 100;
  final digits = whole.toString();
  String grouped;
  if (digits.length <= 3) {
    grouped = digits;
  } else {
    final head = digits.substring(0, digits.length - 3);
    final buf = StringBuffer();
    for (var i = 0; i < head.length; i++) {
      if (i > 0 && (head.length - i) % 2 == 0) buf.write(',');
      buf.write(head[i]);
    }
    grouped = '$buf,${digits.substring(digits.length - 3)}';
  }
  final fraction = frac == 0 ? '' : '.${frac.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}';
  final negative = n < 0 && scaled != 0;
  return '${negative ? '-' : ''}$grouped$fraction';
}

/// The letterhead printed on a payslip: the live company record with the
/// fields saved on the payslip laid over it (web
/// `{...company, ...slip.company_header}`); a field the payslip saved wins
/// even when blank.
class PayslipLetterhead {
  const PayslipLetterhead({this.name = '', this.cin = '', this.address = ''});
  final String name;
  final String cin;

  /// "address, city, state, pin" with blank parts left out.
  final String address;

  static PayslipLetterhead merge({
    String name = '',
    String cin = '',
    String addressLine = '',
    String city = '',
    String state = '',
    String pinCode = '',
    PayslipCompanyHeader? saved,
  }) {
    String pick(String live, String? snap) => snap ?? live;
    return PayslipLetterhead(
      name: pick(name, saved?.companyName),
      cin: pick(cin, saved?.cin),
      address: [
        pick(addressLine, saved?.address),
        pick(city, saved?.city),
        pick(state, saved?.state),
        pick(pinCode, saved?.pinCode),
      ].where((p) => p.isNotEmpty).join(', '),
    );
  }
}

/// The label/value cells under the letterhead of the standard layout (web
/// `strip`): Employee ID, Bank, Account No., IFSC, then UAN and ESIC No. only
/// when the server sends a value.
List<(String, String)> standardStrip(
  PayslipModel p, {
  String bankName = '',
  String maskedAccount = '—',
  String ifsc = '',
}) =>
    [
      ('Employee ID', p.employeeIdCode.isNotEmpty ? p.employeeIdCode : '—'),
      ('Bank', bankName.isNotEmpty ? bankName : '—'),
      ('Account No.', maskedAccount),
      ('IFSC Code', ifsc.isNotEmpty ? ifsc : '—'),
      if ((p.uanDisplay ?? '').isNotEmpty) ('UAN', p.uanDisplay!),
      if ((p.esicDisplay ?? '').isNotEmpty) ('ESIC No.', p.esicDisplay!),
    ];

/// The wage slip's employee block (web WageSlipDocument): left column and
/// right column of label/value cells. PF / UAN and ESIC NO. appear whenever
/// the server sends a value (null = hidden), as "—" when empty.
({List<(String, String)> left, List<(String, String)> right}) wageSlipInfo(PayslipModel p) {
  String dash(String v) => v.isEmpty ? '—' : v;
  final paid = p.totalWorkingDays - p.lopDays;
  String n(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  return (
    left: [
      ('EMPLOYEE CODE', dash(p.employeeIdCode)),
      ('EMPLOYEE NAME', dash(p.employeeName)),
      ('DEPARTMENT', dash(p.department)),
      ('DESIGNATION', dash(p.designation)),
    ],
    right: [
      if (p.uanDisplay != null) ('PF / UAN', dash(p.uanDisplay!)),
      if (p.esicDisplay != null) ('ESIC NO.', dash(p.esicDisplay!)),
      ('MONTH DAYS', '${p.totalWorkingDays}'),
      ('PRESENT', n(paid)),
      ('LOP DAYS', n(p.lopDays)),
    ],
  );
}

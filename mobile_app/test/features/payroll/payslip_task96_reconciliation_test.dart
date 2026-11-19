import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_app/features/payroll/data/models/payslip_model.dart';
import 'package:mobile_app/features/payroll/domain/payslip_layout.dart';
import 'package:mobile_app/features/payroll/presentation/payslip_pdf.dart';

import 'payslip_document_parity_test.dart' hide main;

// Task 96: My Payslip — every web payslip section and the financial
// reconciliation behind it. Web: lib/payslipLayout.ts,
// components/payroll/PayslipDocument.tsx, WageSlipDocument.tsx,
// app/dashboard/my-payslip/page.tsx. Backend: EmployeePayslipSerializer
// (apps/payroll/serializers.py). Synthetic payroll only; the mocked server is
// read-only; nothing is logged or sent.
//
// RECONCILIATION RULE (web): nothing is recalculated. Every figure shown is a
// saved server value; the layout only decides WHERE a saved value appears.
// The tests below check (a) that each component lands in the right section,
// (b) that the rows of a consistent payload add up to the saved totals, and
// (c) that an inconsistent payload is shown as saved — never "corrected".

PayslipModel model(Map<String, dynamic> extra) => PayslipModel.fromJson(slip(extra: extra));

/// A payslip whose saved figures are internally consistent (so the rows can
/// be summed): components 50,000 + 20,000 + 12,000 + night 1,500 = 83,500;
/// bonus 1,000; deductions PF 1,800 + PT 200 + canteen 750 + LOP 3,409.
Map<String, dynamic> consistent({Map<String, dynamic> extra = const {}}) => {
      'basic': '50000.00',
      'hra': '20000.00',
      'special_allowance': '12000.00',
      'bonus': '1000.00',
      'other_earnings': {'Night Shift Allowance': 1500},
      'other_deductions': {'Canteen': 750},
      'reimbursements': '0.00',
      'adjustments_earning': '0.00',
      'adjustments_deduction': '0.00',
      'adjustment_items': <Object>[],
      'gross_earnings': '84500.00', // 83,500 + 1,000
      'lop_days': '1',
      'lop_deduction': '3409.00',
      'pf_employee': '1800.00',
      'esi_employee': '0.00',
      'pt_deduction': '200.00',
      'lwf_employee': '0.00',
      'total_deductions': '6159.00', // 1,800 + 200 + 750 + 3,409
      'net_pay': '78341.00', // 84,500 − 6,159
      ...extra,
    };

double sum(Iterable<AmountRow> rows) => rows.fold(0.0, (a, r) => a + r.amount);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('rounding and formatting (JavaScript parity)', () {
    test('Math.round: halves go toward +infinity', () {
      expect([jsRound(2.5), jsRound(-2.5), jsRound(0.49), jsRound(-0.5), jsRound(3409.5)], [3, -2, 0, 0, 3410]);
    });

    test('wage-slip amount: en-IN grouping, up to 2 decimals, no trailing zeros, negatives', () {
      expect(formatWageSlipAmount(0), '0');
      expect(formatWageSlipAmount(999), '999');
      expect(formatWageSlipAmount(1234567.5), '12,34,567.5');
      expect(formatWageSlipAmount(84500), '84,500');
      expect(formatWageSlipAmount(1234.567), '1,234.57');
      expect(formatWageSlipAmount(0.005), '0.01');
      expect(formatWageSlipAmount(-1234.5), '-1,234.5');
      expect(formatWageSlipAmount(-0.001), '0'); // no "-0"
    });

    test('standard INR: whole rupees, negative sign after the rupee mark (web INR)', () {
      expect(formatPayslipInr('-500'), '₹-500');
      expect(formatPayslipInr(-0.4), '₹0');
    });

    test('non-finite or unreadable saved amounts read as 0', () {
      expect(payslipMoney('NaN'), 0);
      expect(payslipMoney('Infinity'), 0);
      expect(payslipMoney(null), 0);
      expect(payslipMoney('12.50'), 12.5);
      expect(payslipMoney(7), 7);
    });
  });

  group('LOP split (web splitLop)', () {
    test('the Earning column totals round(components − LOP); rounding difference goes to the largest component', () {
      final earned = splitLop([50000, 20000, 12000, 1500], 3409);
      expect(earned.fold<int>(0, (a, b) => a + b), jsRound(83500 - 3409));
      // Proportional, so the biggest component carries the rounding remainder.
      expect(earned, [47959, 19183, 11510, 1439]);
      expect(earned.every((e) => e > 0), isTrue);
    });

    test('edge cases: no LOP, LOP above gross, negative LOP, nothing to split', () {
      expect(splitLop([100, 50], 0), [100, 50]);
      expect(splitLop([100, 50], 999), [0, 0]);
      expect(splitLop([100, 50], -30), [100, 50], reason: 'a negative LOP is treated as none');
      expect(splitLop([0, 0], 10), [0, 0]);
      expect(splitLop(const [], 10), isEmpty);
    });

    test('a three-way split that does not divide evenly still sums exactly', () {
      final earned = splitLop([100, 100, 100], 10); // 290 over three equal parts
      expect(earned.fold<int>(0, (a, b) => a + b), 290);
      expect(earned.reduce((a, b) => a > b ? a : b) - earned.reduce((a, b) => a < b ? a : b), lessThanOrEqualTo(1));
    });
  });

  group('adjustments (web adjustmentRows / additionsOutsideGross)', () {
    test('itemised: additions and arrears count as earnings, deductions as deductions', () {
      final p = model(consistent(extra: {
        'adjustment_items': [
          {'type': 'addition', 'label': 'Spot award', 'amount': '500.00'},
          {'type': 'arrear', 'label': 'Arrears Sep', 'amount': '1200.00'},
          {'type': 'deduction', 'label': 'Advance recovery', 'amount': '300.00'},
        ],
      }));
      expect(adjustmentRows(p, AdjustmentKind.earning).map((r) => (r.label, r.amount)),
          [('Spot award', 500.0), ('Arrears Sep', 1200.0)]);
      expect(
          adjustmentRows(p, AdjustmentKind.deduction).map((r) => (r.label, r.amount)), [('Advance recovery', 300.0)]);
    });

    test('older payslips (no items): one line for the saved total', () {
      final p = model(consistent(extra: {'adjustments_earning': '700.00', 'adjustments_deduction': '250.00'}));
      expect(adjustmentRows(p, AdjustmentKind.earning).map((r) => (r.label, r.amount)), [('Additions', 700.0)]);
      expect(
          adjustmentRows(p, AdjustmentKind.deduction).map((r) => (r.label, r.amount)), [('Other deductions', 250.0)]);
      expect(adjustmentRows(model(consistent()), AdjustmentKind.earning), isEmpty);
    });

    test('inside vs outside gross: a half-rupee tolerance, as web', () {
      // Gross excludes the 700 → paid on top.
      expect(additionsOutsideGross(model(consistent(extra: {'adjustments_earning': '700.00'}))), isTrue);
      // Gross already includes it (84,500 + 700).
      expect(
          additionsOutsideGross(
              model(consistent(extra: {'adjustments_earning': '700.00', 'gross_earnings': '85200.00'}))),
          isFalse);
      // 0.4 off is within the tolerance → still "inside".
      expect(
          additionsOutsideGross(
              model(consistent(extra: {'adjustments_earning': '700.00', 'gross_earnings': '85200.40'}))),
          isFalse);
      // 2 rupees off is beyond the tolerance → treated as paid on top.
      expect(
          additionsOutsideGross(
              model(consistent(extra: {'adjustments_earning': '700.00', 'gross_earnings': '85202.00'}))),
          isTrue);
      expect(additionsOutsideGross(model(consistent())), isFalse, reason: 'no additions');
    });
  });

  group('financial reconciliation (rows add up to the saved totals)', () {
    test('standard, no adjustments: earning rows = gross, deduction rows (LOP last) = total deductions', () {
      final p = model(consistent());
      expect(sum(standardEarningRows(p)), p.grossEarnings);
      expect(sum(standardDeductionRows(p)), p.totalDeductions);
      expect(standardDeductionRows(p).last.label, 'Loss of Pay (LOP)');
      expect(p.grossEarnings - p.totalDeductions, p.netPay);
    });

    test('additions inside gross: shown among the earnings, which still equal gross; no separate panel', () {
      final p = model(consistent(extra: {
        'adjustments_earning': '500.00',
        'adjustment_items': [
          {'type': 'addition', 'label': 'Spot award', 'amount': '500.00'}
        ],
        'gross_earnings': '85000.00', // components + bonus + addition
        'net_pay': '78841.00', // 85,000 − 6,159
      }));
      expect(additionsPanel(p), isNull);
      expect(standardEarningRows(p).map((r) => r.label), contains('Spot award'));
      expect(sum(standardEarningRows(p)), p.grossEarnings);
      expect(p.grossEarnings - p.totalDeductions, p.netPay);
    });

    test('additions outside gross: a separate panel; gross − deductions + additions (+ reimbursements) = net', () {
      final p = model(consistent(extra: {
        'adjustments_earning': '1700.00',
        'adjustment_items': [
          {'type': 'addition', 'label': 'Spot award', 'amount': '500.00'},
          {'type': 'arrear', 'label': 'Arrears Sep', 'amount': '1200.00'},
        ],
        'reimbursements': '2500.00',
        // gross stays 84,500 (excludes additions and reimbursements)
        'net_pay': '82541.00', // 84,500 − 6,159 + 1,700 + 2,500
      }));
      final panel = additionsPanel(p)!;
      expect(panel.total, 1700);
      expect(panel.rows.map((r) => r.label), ['Spot award', 'Arrears Sep']);
      expect(standardEarningRows(p).map((r) => r.label), isNot(contains('Spot award')));
      expect(sum(standardEarningRows(p)), p.grossEarnings, reason: 'earnings rows still equal the saved gross');
      expect(p.grossEarnings - p.totalDeductions + panel.total + p.reimbursements, p.netPay);
    });

    test('one-time deductions are listed before LOP and the rows still equal total deductions', () {
      final p = model(consistent(extra: {
        'adjustments_deduction': '300.00',
        'adjustment_items': [
          {'type': 'deduction', 'label': 'Advance recovery', 'amount': '300.00'}
        ],
        'total_deductions': '6459.00',
        'net_pay': '78041.00',
      }));
      final labels = standardDeductionRows(p).map((r) => r.label).toList();
      expect(labels.indexOf('Advance recovery'), lessThan(labels.indexOf('Loss of Pay (LOP)')));
      expect(sum(standardDeductionRows(p)), p.totalDeductions);
      expect(p.grossEarnings - p.totalDeductions, p.netPay);
    });

    test('an INCONSISTENT payload is shown as saved — never corrected (no invented values)', () {
      final p = model(consistent(extra: {'gross_earnings': '90000.00', 'net_pay': '12345.00'}));
      expect(p.grossEarnings, 90000);
      expect(p.netPay, 12345);
      expect(sum(standardEarningRows(p)), isNot(p.grossEarnings));
      expect(wageSlipModel(p).totals.net, 12345, reason: 'the wage slip also prints the stored net pay');
    });

    test('negative and zero values: negatives shown, zeros hidden except Basic in the wage slip', () {
      final p = model(consistent(extra: {
        'other_earnings': {'Correction': -500, 'Zero': 0},
        'basic': '0',
      }));
      expect(standardEarningRows(p).map((r) => (r.label, r.amount)), contains(('Correction', -500.0)));
      expect(standardEarningRows(p).map((r) => r.label), isNot(contains('Zero')));
      expect(standardEarningRows(p).map((r) => r.label), isNot(contains('Basic Salary')));
      expect(componentRows(p).first.label, 'Basic', reason: 'web keeps Basic as the first row even at 0');
      expect(componentRows(p).map((r) => r.label), isNot(contains('Zero')));
    });
  });

  group('wage slip model (web wageSlipModel)', () {
    test('actual vs earning per component; Earning column = components − LOP; totals; net is the stored value', () {
      final p = model(consistent(extra: {
        'payslip_template': 'wage_slip',
        'adjustments_earning': '500.00',
        'adjustment_items': [
          {'type': 'addition', 'label': 'Spot award', 'amount': '500.00'}
        ],
        'reimbursements': '250.00',
      }));
      final m = wageSlipModel(p);
      final components = m.earnings.take(4).toList(); // Basic, HRA, Special, Night Shift
      expect(components.map((e) => e.label), ['Basic', 'HRA', 'Special Allowance', 'Night Shift Allowance']);
      expect(components.map((e) => e.actual), [50000, 20000, 12000, 1500]);
      expect(components.fold<double>(0, (a, e) => a + e.earned), jsRound(83500 - 3409));
      // Bonus / Reimbursement / additions have no "Actual".
      final tail = m.earnings.skip(4).toList();
      expect(tail.map((e) => (e.label, e.actual, e.earned)),
          [('Bonus', null, 1000.0), ('Reimbursement', null, 250.0), ('Spot award', null, 500.0)]);
      expect(m.totals.actual, 83500);
      expect(m.totals.earned, jsRound(83500 - 3409) + 1000 + 250 + 500);
      expect(m.totals.deductions, p.totalDeductions - p.lopDeduction,
          reason: 'LOP is already out of the Earning column');
      expect(m.totals.net, p.netPay);
    });

    test('deduction rows: PF, PT, ESIC, LWF, named, one-time; configured fixed rows added once, case-insensitively',
        () {
      final p = model(consistent(extra: {
        'payslip_template': 'wage_slip',
        'fixed_deduction_rows': ['TDS', 'pf', 'Loan EMI', 'loan emi'],
        'adjustments_deduction': '300.00',
      }));
      final labels = wageSlipModel(p).deductions.map((d) => d.label).toList();
      expect(labels.take(5), ['PF', 'PT', 'ESIC', 'LWF', 'Canteen']);
      expect(labels, containsAll(['Other deductions', 'TDS', 'Loan EMI']));
      expect(labels.where((l) => l.toLowerCase() == 'pf').length, 1, reason: '"pf" already present');
      expect(labels.where((l) => l.toLowerCase() == 'loan emi').length, 1);
      expect(wageSlipModel(p).deductions.firstWhere((d) => d.label == 'TDS').amount, 0);
    });

    test('period label: calendar month, custom cycle, leap February, unreadable dates', () {
      expect(wageSlipPeriodLabel('2026-09-01', '2026-09-30'), 'WAGES SLIP FOR THE MONTH OF SEPTEMBER-2026');
      expect(wageSlipPeriodLabel('2028-02-01', '2028-02-29'), 'WAGES SLIP FOR THE MONTH OF FEBRUARY-2028');
      expect(wageSlipPeriodLabel('2026-02-01', '2026-02-28'), 'WAGES SLIP FOR THE MONTH OF FEBRUARY-2026');
      expect(wageSlipPeriodLabel('2026-08-24', '2026-09-22'), 'WAGES SLIP FOR THE PERIOD 24 AUG-26 TO 22 SEP-26');
      expect(wageSlipPeriodLabel('2026-09-01', '2026-09-29'), 'WAGES SLIP FOR THE PERIOD 1 SEP-26 TO 29 SEP-26');
      expect(wageSlipPeriodLabel('', ''), 'WAGES SLIP FOR THE PERIOD  TO ');
    });

    test('wage-slip info block: PF / UAN and ESIC rows follow the server (null = hidden, empty = "—")', () {
      final shown = wageSlipInfo(model({'uan_display': '********1234', 'esic_display': '', 'designation': 'Analyst'}));
      expect(shown.right.map((r) => r.$1), ['PF / UAN', 'ESIC NO.', 'MONTH DAYS', 'PRESENT', 'LOP DAYS']);
      expect(shown.right.firstWhere((r) => r.$1 == 'ESIC NO.').$2, '—');
      expect(shown.left.firstWhere((r) => r.$1 == 'DESIGNATION').$2, 'Analyst');
      final hidden = wageSlipInfo(model({'uan_display': null, 'esic_display': null}));
      expect(hidden.right.map((r) => r.$1), ['MONTH DAYS', 'PRESENT', 'LOP DAYS']);
      expect(wageSlipInfo(model({'lop_days': '1.5'})).right.firstWhere((r) => r.$1 == 'PRESENT').$2, '20.5');
    });
  });

  group('model mapping of the server fields', () {
    test('reads every payslip field of EmployeePayslipSerializer that web uses', () {
      final p = model({
        'designation': 'Analyst',
        'principal_employer_name': 'Client Co',
        'company_header': {'company_name': 'Saved Co', 'address': 'Old Road', 'city': 'Old City'},
        'payslip_template': 'wage_slip',
        'uan_display': '********9012',
        'esic_display': '*****4567',
        'fixed_deduction_rows': ['TDS'],
        'stamp_url': 'https://files.invalid/stamp',
        'adjustments_earning': '10.00',
        'adjustments_deduction': '5.00',
        'adjustment_items': [
          {'type': 'arrear', 'label': 'A', 'amount': '10.00'}
        ],
      });
      expect(p.isWageSlip, isTrue);
      expect((p.designation, p.principalEmployerName, p.uanDisplay, p.esicDisplay),
          ('Analyst', 'Client Co', '********9012', '*****4567'));
      expect(p.companyHeader!.companyName, 'Saved Co');
      expect(p.companyHeader!.cin, isNull);
      expect(p.fixedDeductionRows, ['TDS']);
      expect(p.adjustmentItems.single.amount, 10);
      expect((p.adjustmentsEarning, p.adjustmentsDeduction), (10.0, 5.0));
      // copyWith (acknowledge) keeps all of it.
      final c = p.copyWith(status: 'acknowledged');
      expect((c.isWageSlip, c.uanDisplay, c.adjustmentItems.length, c.stampUrl),
          (true, '********9012', 1, 'https://files.invalid/stamp'));
    });

    test('missing optional data (an older payslip) defaults safely', () {
      final p = PayslipModel.fromJson(const {'id': 'x'});
      expect(p.isWageSlip, isFalse);
      expect(p.payslipTemplate, 'standard');
      expect((p.uanDisplay, p.esicDisplay, p.companyHeader, p.stampUrl), (null, null, null, null));
      expect(p.adjustmentItems, isEmpty);
      expect(p.fixedDeductionRows, isEmpty);
      expect(PayslipModel.fromJson(const {'id': 'x', 'payslip_template': ''}).payslipTemplate, 'standard');
      expect(PayslipModel.fromJson(const {'id': 'x', 'payslip_template': 'unknown_layout'}).isWageSlip, isFalse);
      expect(
          PayslipModel.fromJson(const {'id': 'x', 'adjustment_items': 'bad', 'fixed_deduction_rows': 5})
              .adjustmentItems,
          isEmpty);
      expect(PayslipModel.fromJson(const {'id': 'x', 'basic': 'NaN'}).basic, 0);
    });

    test('letterhead: saved fields win over the live company, even when blank', () {
      final l = PayslipLetterhead.merge(
        name: 'Live Co',
        cin: 'LIVECIN',
        addressLine: '1 New Street',
        city: 'New City',
        state: 'ST',
        pinCode: '500001',
        saved: const PayslipCompanyHeader(companyName: 'Saved Co', address: '9 Old Road', city: '', cin: null),
      );
      expect(l.name, 'Saved Co');
      expect(l.cin, 'LIVECIN', reason: 'not saved → live value');
      expect(l.address, '9 Old Road, ST, 500001',
          reason: 'a saved blank city replaces the live city (and is left out)');
      expect(PayslipLetterhead.merge(name: 'Live Co').name, 'Live Co');
    });

    test('status labels as web My Payslips (and an unknown status is title-cased)', () {
      expect({
        for (final s in ['paid', 'sent', 'acknowledged', 'queried', 'resolved', 'draft', 'closed'])
          s: payslipStatusLabel(s)
      }, {
        'paid': 'Paid',
        'sent': 'Received',
        'acknowledged': 'Acknowledged',
        'queried': 'Query open',
        'resolved': 'Query resolved',
        'draft': 'Processing',
        'closed': 'Closed',
      });
      expect(payslipStatusLabel('on_hold'), 'On Hold');
    });
  });

  group('screen — standard layout', () {
    testWidgets('one-time additions inside gross appear in Earnings; no panel; breakdown has no "Add."',
        (tester) async {
      await pump(tester, [
        slip(
            extra: consistent(extra: {
          'adjustments_earning': '500.00',
          'adjustment_items': [
            {'type': 'addition', 'label': 'Spot award', 'amount': '500.00'}
          ],
          'gross_earnings': '85000.00',
          'net_pay': '78841.00',
        }))
      ]);
      expect(rowAmount(tester, 'Spot award'), '₹500');
      expect(find.byKey(const Key('payslip-additions')), findsNothing);
      expect(rowAmount(tester, 'Gross Earnings'), '₹85,000');
      expect(textOf(tester, 'payslip-net-breakdown'), 'Gross ₹85,000 − Ded. ₹6,159');
      expect(textOf(tester, 'payslip-net-amount'), '₹78,841');
    });

    testWidgets('arrears + additions outside gross: Additions panel, "+ Add." then "+ Reimb." in the banner',
        (tester) async {
      await pump(tester, [
        slip(
            extra: consistent(extra: {
          'adjustments_earning': '1700.00',
          'adjustment_items': [
            {'type': 'addition', 'label': 'Spot award', 'amount': '500.00'},
            {'type': 'arrear', 'label': 'Arrears Sep', 'amount': '1200.00'},
          ],
          'reimbursements': '2500.00',
          'net_pay': '82541.00',
        }))
      ]);
      final panel = find.byKey(const Key('payslip-additions'));
      expect(panel, findsOneWidget);
      expect(find.descendant(of: panel, matching: find.text('Spot award')), findsOneWidget);
      expect(find.descendant(of: panel, matching: find.text('Arrears Sep')), findsOneWidget);
      expect(textOf(tester, 'payslip-additions-total'), '₹1,700');
      expect(rowAmount(tester, 'Gross Earnings'), '₹84,500', reason: 'saved gross, additions not folded in');
      expect(textOf(tester, 'payslip-net-breakdown'), 'Gross ₹84,500 − Ded. ₹6,159 + Add. ₹1,700 + Reimb. ₹2,500');
      expect(textOf(tester, 'payslip-net-amount'), '₹82,541');
    });

    testWidgets('one-time deductions and the older total-only form', (tester) async {
      await pump(tester, [
        slip(
            extra: consistent(extra: {
          'adjustments_deduction': '300.00',
          'adjustment_items': [
            {'type': 'deduction', 'label': 'Advance recovery', 'amount': '300.00'}
          ],
          'total_deductions': '6459.00',
          'net_pay': '78041.00',
        }))
      ]);
      expect(rowAmount(tester, 'Advance recovery'), '₹300');
      expect(rowAmount(tester, 'Total Deductions'), '₹6,459');
      expect(tester.getTopLeft(find.text('Advance recovery')).dy,
          lessThan(tester.getTopLeft(find.text('Loss of Pay (LOP)')).dy));

      await tester.pumpWidget(const SizedBox());
      await pump(tester, [
        slip(
            extra: consistent(extra: {
          'adjustments_earning': '700.00',
          'adjustments_deduction': '250.00',
          'gross_earnings': '85200.00'
        }))
      ]);
      expect(rowAmount(tester, 'Additions'), '₹700');
      expect(rowAmount(tester, 'Other deductions'), '₹250');
    });

    testWidgets('negative earning shown as ₹-500; negative net shown as saved', (tester) async {
      await pump(tester, [
        slip(
            extra: consistent(extra: {
          'other_earnings': {'Correction': -500},
          'net_pay': '-120.00'
        }))
      ]);
      expect(rowAmount(tester, 'Correction'), '₹-500');
      expect(textOf(tester, 'payslip-net-amount'), '₹-120');
    });

    testWidgets('UAN and ESIC join the strip only when the server sends a value (masked as sent)', (tester) async {
      await pump(tester, [
        slip(extra: {'uan_display': '********1234', 'esic_display': '*****4567'})
      ]);
      final strip = find.byKey(const Key('payslip-strip'));
      for (final t in ['UAN', '********1234', 'ESIC No.', '*****4567']) {
        expect(find.descendant(of: strip, matching: find.text(t)), findsOneWidget, reason: t);
      }
      await tester.pumpWidget(const SizedBox());
      await pump(tester, [
        slip(extra: {'uan_display': null, 'esic_display': ''})
      ]);
      expect(find.descendant(of: find.byKey(const Key('payslip-strip')), matching: find.text('UAN')), findsNothing);
      expect(
          find.descendant(of: find.byKey(const Key('payslip-strip')), matching: find.text('ESIC No.')), findsNothing);
    });

    testWidgets('letterhead as processed: saved company fields over the live company', (tester) async {
      await pump(tester, [
        slip(extra: {
          'company_header': {'company_name': 'Saved Co', 'address': '9 Old Road', 'cin': 'SAVEDCIN'},
        })
      ]);
      expect(find.textContaining('Saved Co · CIN: SAVEDCIN'), findsOneWidget);
      expect(textOf(tester, 'payslip-company-address'), '9 Old Road, Test City, Test State, 500001');
      expect(find.textContaining('Test Co'), findsNothing);
    });

    testWidgets('an older payslip with none of the new fields renders as before', (tester) async {
      final old = slip();
      for (final k in [
        'adjustment_items',
        'adjustments_earning',
        'adjustments_deduction',
        'designation',
        'principal_employer_name',
        'company_header',
        'payslip_template',
        'uan_display',
        'esic_display',
        'fixed_deduction_rows',
        'stamp_url'
      ]) {
        old.remove(k);
      }
      await pump(tester, [old]);
      expect(rowAmount(tester, 'Gross Earnings'), '₹1,23,457');
      expect(find.byKey(const Key('payslip-wage-slip')), findsNothing);
      expect(find.byKey(const Key('payslip-additions')), findsNothing);
      expect(textOf(tester, 'payslip-net-amount'), '₹1,17,297');
    });

    testWidgets('status: "sent" shows "Received" and an "Acknowledge" button; queried shows "Query open"',
        (tester) async {
      await pump(tester, [
        slip(id: 'a', extra: {'status': 'sent'}),
        slip(id: 'b', extra: {'status': 'queried'}),
      ]);
      expect(find.text('Received'), findsWidgets);
      expect(find.text('Query open'), findsWidgets);
      expect(find.text('Acknowledge'), findsOneWidget);
      expect(find.text('Acknowledge Payslip'), findsNothing);
      expect(find.text('View and download your monthly salary statements'), findsOneWidget);
      // Acknowledge is only offered for "sent".
      await tester.tap(find.text('Query open').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('payslip-acknowledge')), findsNothing);
    });
  });

  group('screen — wage-slip layout', () {
    Map<String, dynamic> wage({Map<String, dynamic> extra = const {}}) => slip(
            extra: consistent(extra: {
          'payslip_template': 'wage_slip',
          'cycle_start': '2026-09-01',
          'cycle_end': '2026-09-30',
          'designation': 'Analyst',
          'principal_employer_name': 'Client Co',
          'uan_display': '********1234',
          'esic_display': null,
          'fixed_deduction_rows': ['TDS'],
          ...extra,
        }));

    testWidgets('letterhead, period title, employee block, grid, totals and net as saved', (tester) async {
      await pump(tester, [wage()]);
      expect(find.byKey(const Key('payslip-wage-slip')), findsOneWidget);
      expect(textOf(tester, 'wageslip-title'), 'WAGES SLIP FOR THE MONTH OF SEPTEMBER-2026');
      expect(textOf(tester, 'wageslip-company'), 'Test Co');
      expect(textOf(tester, 'wageslip-principal'), 'Client Co');
      final info = find.byKey(const Key('wageslip-info'));
      for (final t in [
        'EMPLOYEE CODE',
        'TST001',
        'DESIGNATION',
        'Analyst',
        'PF / UAN',
        '********1234',
        'MONTH DAYS',
        '22',
        'PRESENT',
        '21',
        'LOP DAYS',
        '1'
      ]) {
        expect(find.descendant(of: info, matching: find.text(t)), findsWidgets, reason: t);
      }
      expect(find.descendant(of: info, matching: find.text('ESIC NO.')), findsNothing,
          reason: 'null = hidden by payroll settings');
      final grid = find.byKey(const Key('wageslip-grid'));
      for (final t in [
        'SALARY HEAD',
        'ACTUAL',
        'EARNING',
        'DEDUCTION',
        'Basic',
        '50,000',
        'HRA',
        'PF',
        'PT',
        'ESIC',
        'TDS',
        'TOTAL GROSS',
        'TOTAL DEDUCTION',
        'NET SALARY PAY'
      ]) {
        expect(find.descendant(of: grid, matching: find.text(t)), findsWidgets, reason: t);
      }
      expect(find.descendant(of: grid, matching: find.text('83,500')), findsWidgets, reason: 'TOTAL GROSS actual');
      expect(find.descendant(of: grid, matching: find.text('2,750')), findsOneWidget,
          reason: 'total deductions minus LOP (6,159 − 3,409)');
      expect(find.descendant(of: find.byKey(const Key('wageslip-net')), matching: find.text('78,341')), findsOneWidget);
      expect(find.text('Employee Signature'), findsOneWidget);
      expect(find.text('Authorized Signature'), findsOneWidget);
      // The standard sections do not apply to this layout.
      expect(find.text('Net Salary Credited'), findsNothing);
      expect(find.byKey(const Key('payslip-strip')), findsNothing);
      expect(find.byKey(const Key('payslip-footer')), findsNothing);
    });

    testWidgets('no stamp link → no stamp image; a stamp link is never printed as text', (tester) async {
      await pump(tester, [wage()]);
      expect(find.byKey(const Key('wageslip-stamp')), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await pump(tester, [
        wage(extra: {'stamp_url': 'https://files.invalid/stamp?sig=secret'})
      ]);
      expect(find.textContaining('secret'), findsNothing);
      expect(find.textContaining('files.invalid'), findsNothing);
    });

    testWidgets('a custom-cycle wage slip and one with additions / reimbursements has Actual blank on those rows',
        (tester) async {
      await pump(tester, [
        wage(extra: {
          'cycle_start': '2026-08-24',
          'cycle_end': '2026-09-22',
          'reimbursements': '250.00',
          'adjustments_earning': '500.00',
          'adjustment_items': [
            {'type': 'addition', 'label': 'Spot award', 'amount': '500.00'}
          ],
        })
      ]);
      expect(textOf(tester, 'wageslip-title'), 'WAGES SLIP FOR THE PERIOD 24 AUG-26 TO 22 SEP-26');
      final grid = find.byKey(const Key('wageslip-grid'));
      for (final t in ['Bonus', 'Reimbursement', 'Spot award', '1,000', '250', '500']) {
        expect(find.descendant(of: grid, matching: find.text(t)), findsWidgets, reason: t);
      }
    });
  });

  group('screen — failures and empty states', () {
    testWidgets('a server failure shows an error with Retry; Retry loads the payslips', (tester) async {
      var fail = true;
      final base = Server([slip()]);
      final flaky = _Flaky(base, () => fail);
      await pumpWith(tester, flaky);
      expect(find.byKey(const Key('payslip-net-amount')), findsNothing);
      expect(find.text('Retry'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(textOf(tester, 'payslip-net-amount'), '₹1,17,297');
    });

    testWidgets('permission failure (403): the server\'s reason is shown, nothing is rendered', (tester) async {
      final denied = _Denied();
      await pumpWith(tester, denied);
      expect(find.text('You do not have permission to view payslips.'), findsOneWidget);
      expect(find.byKey(const Key('payslip-net-amount')), findsNothing);
      expect(find.text('Net Salary Credited'), findsNothing);
    });

    testWidgets('empty list: web title and description', (tester) async {
      await pump(tester, []);
      expect(find.text('No payslips yet'), findsOneWidget);
      expect(textOf(tester, 'payslip-empty-desc'),
          'Your payslips will appear here once payroll is processed for your account.');
    });

    testWidgets('sensitive payroll figures are never written to the log while rendering', (tester) async {
      final printed = <String>[];
      final original = debugPrint;
      debugPrint = (String? m, {int? wrapWidth}) => printed.add(m ?? '');
      try {
        await pump(tester, [wage2()]);
      } finally {
        debugPrint = original;
      }
      final all = printed.join('\n');
      for (final secret in ['117297', '1,17,297', '000123456789', '********1234']) {
        expect(all.contains(secret), isFalse, reason: secret);
      }
    });
  });

  group('PDF output (print / share)', () {
    test('line helpers mirror the screen rows (adjustments, LOP last, zeros hidden)', () {
      final p = model(consistent(extra: {
        'adjustments_earning': '500.00',
        'adjustment_items': [
          {'type': 'addition', 'label': 'Spot award', 'amount': '500.00'}
        ],
        'gross_earnings': '85000.00',
      }));
      expect(payslipEarningLines(p).map((l) => l.$1), contains('Spot award'));
      expect(payslipDeductionLines(p).last.$1, 'Loss of Pay (LOP)');
      expect(payslipDeductionLines(p).map((l) => l.$1), isNot(contains('ESI')));
    });

    testWidgets('both layouts build into a PDF with the real fonts (adjustments, UAN/ESIC, wage slip)', (tester) async {
      await tester.runAsync(() async {
        final fonts = await loadPayslipPdfFonts();
        const ctx = PayslipPdfContext(
          monthLabel: 'September 2026',
          companyName: 'Test Co',
          companyAddress: '1 Test Road',
          bankName: 'Test Bank',
          accountNumber: '000123456789',
          ifscCode: 'TEST0001234',
          officialPhone: '+91 90000 00000',
        );
        final standard = model(consistent(extra: {
          'uan_display': '********1234',
          'esic_display': '*****4567',
          'adjustments_earning': '1700.00',
          'adjustment_items': [
            {'type': 'arrear', 'label': 'Arrears Sep', 'amount': '1200.00'},
            {'type': 'addition', 'label': 'Spot award', 'amount': '500.00'},
          ],
          'reimbursements': '2500.00',
        }));
        final wageSlip = model(consistent(extra: {
          'payslip_template': 'wage_slip',
          'fixed_deduction_rows': ['TDS']
        }));
        for (final p in [standard, wageSlip]) {
          final bytes = await buildPayslipPdf(p, ctx, fonts).save();
          expect(bytes.length, greaterThan(800));
          expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
        }
      });
    });
  });
}

Map<String, dynamic> wage2() => slip(extra: {'uan_display': '********1234'});

/// The standard server, but the payslips call fails while [fail] says so.
class _Flaky extends Server {
  _Flaky(Server base, this.fail) : super(base.payslips);
  final bool Function() fail;

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path == '/payroll/my-payslips/' && fail()) {
      return ResponseBody.fromString(jsonEncode({'status': 'error', 'message': 'Server error.'}), 500, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
    }
    return super.fetch(o, s, c);
  }
}

/// The payslips call is refused (the account lacks payroll.view_own).
class _Denied extends Server {
  _Denied() : super(const []);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<List<int>>? s, Future<void>? c) async {
    if (o.path == '/payroll/my-payslips/') {
      return ResponseBody.fromString(
          jsonEncode({'status': 'error', 'message': 'You do not have permission to view payslips.'}), 403,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });
    }
    return super.fetch(o, s, c);
  }
}

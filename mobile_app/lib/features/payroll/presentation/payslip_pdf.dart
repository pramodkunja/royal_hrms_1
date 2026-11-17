import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/payslip_model.dart';

// HO-28 (Phase C3): web My Payslips has "Print / Save PDF", which prints the
// rendered payslip (window.print — the browser's dialog also offers "Save as
// PDF"). Its "Download PDF" links to EmployeePayslip.payslip_pdf, which the
// backend never fills today, so on web that button is always disabled.
// Mobile does the equivalent of the print action: it builds the SAME payslip
// the screen shows — from the same GET /payroll/my-payslips/ data (the
// signed-in employee's own, non-draft payslips) plus the same company and
// own-profile details — into a PDF, and hands it to Android's print dialog
// (which includes "Save as PDF") or the share sheet. Nothing is fetched or
// calculated here that the screen doesn't already show; no new endpoint, no
// URL or token is embedded.

/// One line of the earnings / deductions tables, exactly as the screen lists
/// them (zero amounts left out).
typedef PayslipLine = (String, double);

List<PayslipLine> payslipEarningLines(PayslipModel p) => <PayslipLine>[
      ('Basic Salary', p.basic),
      ('House Rent Allowance (HRA)', p.hra),
      ('Special Allowance', p.specialAllowance),
      ('Bonus', p.bonus),
      for (final entry in p.otherEarnings.entries) (entry.key, double.tryParse(entry.value?.toString() ?? '') ?? 0.0),
    ].where((r) => r.$2 != 0).toList();

List<PayslipLine> payslipDeductionLines(PayslipModel p) => <PayslipLine>[
      ('Provident Fund (PF)', p.pfEmployee),
      ('ESI', p.esiEmployee),
      ('Professional Tax (PT)', p.ptDeduction),
      ('Labour Welfare Fund', p.lwfEmployee),
      for (final entry in p.otherDeductions.entries) (entry.key, double.tryParse(entry.value?.toString() ?? '') ?? 0.0),
      ('Loss of Pay (LOP)', p.lopDeduction),
    ].where((r) => r.$2 != 0).toList();

/// What the PDF prints beyond the payslip itself — all already on screen.
class PayslipPdfContext {
  const PayslipPdfContext({
    required this.monthLabel,
    this.companyName = '',
    this.companyCin = '',
    this.companyAddress = '',
    this.bankName = '',
    this.accountNumber = '',
    this.ifscCode = '',
  });

  final String monthLabel;
  final String companyName;
  final String companyCin;
  final String companyAddress;
  final String bankName;

  /// Printed masked (••••1234), as on screen.
  final String accountNumber;
  final String ifscCode;
}

/// `payslip-<employee code>-<YYYY-MM>.pdf`, safe characters only.
String payslipPdfFileName(PayslipModel p) {
  final code = p.employeeIdCode.isEmpty ? 'employee' : p.employeeIdCode;
  final month = p.cycleStart.length >= 7 ? p.cycleStart.substring(0, 7) : 'payslip';
  return 'payslip-$code-$month.pdf'.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
}

/// Fonts for the PDF: the bundled Noto Sans (has the ₹ sign), as the ID card.
class PayslipPdfFonts {
  const PayslipPdfFonts(this.base, this.bold);
  final pw.Font base;
  final pw.Font bold;
}

Future<PayslipPdfFonts> loadPayslipPdfFonts() async => PayslipPdfFonts(
      pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf')),
      pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf')),
    );

/// Builds the A4 payslip document.
pw.Document buildPayslipPdf(PayslipModel p, PayslipPdfContext c, PayslipPdfFonts fonts) {
  final doc = pw.Document(
    title: 'Payslip ${c.monthLabel}',
    author: c.companyName.isEmpty ? 'Royal HRMS' : c.companyName,
    theme: pw.ThemeData.withFont(base: fonts.base, bold: fonts.bold),
  );
  pw.Widget kv(String k, String v) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text(k, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text(v.isEmpty ? '—' : v, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
      ]);
  pw.Widget table(String title, List<PayslipLine> lines, String totalLabel, double total, PdfColor color) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: color, width: .6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Text(title, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: color)),
          pw.SizedBox(height: 4),
          for (final l in lines)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(children: [
                pw.Expanded(child: pw.Text(l.$1, style: const pw.TextStyle(fontSize: 10))),
                pw.Text(formatPayslipInr(l.$2), style: const pw.TextStyle(fontSize: 10)),
              ]),
            ),
          pw.Divider(thickness: .5),
          pw.Row(children: [
            pw.Expanded(child: pw.Text(totalLabel, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold))),
            pw.Text(formatPayslipInr(total), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ]),
        ]),
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      if (c.companyName.isNotEmpty) pw.Text(c.companyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      if (c.companyAddress.isNotEmpty) pw.Text(c.companyAddress, style: const pw.TextStyle(fontSize: 9)),
      if (c.companyCin.isNotEmpty) pw.Text('CIN: ${c.companyCin}', style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 12),
      pw.Text('PAYSLIP — ${c.monthLabel}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
      pw.Text('Salary Date: ${formatPayslipDate(p.payDate)}   ·   Status: ${payslipStatusLabel(p.status)}',
          style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 10),
      pw.Wrap(spacing: 28, runSpacing: 8, children: [
        kv('Employee', p.employeeName),
        kv('Employee ID', p.employeeIdCode),
        kv('Department', p.department),
        kv('Bank', c.bankName),
        kv('Account No.', c.accountNumber.isEmpty ? '' : maskPayslipAccount(c.accountNumber)),
        kv('IFSC Code', c.ifscCode),
        kv('Working Days', '${p.totalWorkingDays}'),
        kv('Paid Days', _days(p.paidDays)),
        kv('Loss of Pay', _days(p.lopDays)),
      ]),
      pw.SizedBox(height: 12),
      table('EARNINGS', payslipEarningLines(p), 'Gross Earnings', p.grossEarnings, PdfColors.green800),
      pw.SizedBox(height: 8),
      table('DEDUCTIONS', payslipDeductionLines(p), 'Total Deductions', p.totalDeductions, PdfColors.red800),
      if (p.reimbursements > 0) ...[
        pw.SizedBox(height: 8),
        pw.Row(children: [
          pw.Expanded(child: pw.Text('Reimbursements', style: const pw.TextStyle(fontSize: 10))),
          pw.Text(formatPayslipInr(p.reimbursements), style: const pw.TextStyle(fontSize: 10)),
        ]),
      ],
      pw.SizedBox(height: 10),
      pw.Container(
        padding: const pw.EdgeInsets.all(10),
        color: PdfColors.blueGrey50,
        child: pw.Row(children: [
          pw.Expanded(child: pw.Text('Net Salary Credited', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
          pw.Text(formatPayslipInr(p.netPay), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
      pw.Spacer(),
      pw.Text('This is a computer-generated payslip and does not require a signature.',
          textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ]),
  ));
  return doc;
}

String _days(double d) => d == d.truncateToDouble() ? d.toInt().toString() : d.toString();

/// Print (Android print dialog, incl. "Save as PDF") or share. Tests override it.
class PayslipPdfOutput {
  const PayslipPdfOutput({required this.print, required this.share});
  final Future<bool> Function(Future<Uint8List> Function(PdfPageFormat) layout, String name) print;
  final Future<bool> Function(Uint8List bytes, String filename) share;
}

final payslipPdfOutputProvider = Provider<PayslipPdfOutput>((ref) => PayslipPdfOutput(
      print: (layout, name) => Printing.layoutPdf(onLayout: layout, name: name, format: PdfPageFormat.a4),
      share: (bytes, filename) => Printing.sharePdf(bytes: bytes, filename: filename),
    ));

/// Font loader, overridable in tests.
final payslipPdfFontsProvider = Provider<Future<PayslipPdfFonts> Function()>((ref) => loadPayslipPdfFonts);

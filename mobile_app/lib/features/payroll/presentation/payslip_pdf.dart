import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/models/payslip_model.dart';
import '../domain/payslip_layout.dart';

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

List<PayslipLine> payslipEarningLines(PayslipModel p) => [for (final r in standardEarningRows(p)) (r.label, r.amount)];

List<PayslipLine> payslipDeductionLines(PayslipModel p) =>
    [for (final r in standardDeductionRows(p)) (r.label, r.amount)];

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
    this.officialPhone = '',
    this.logo,
    this.stamp,
  });

  final String monthLabel;
  final String companyName;
  final String companyCin;
  final String companyAddress;
  final String bankName;

  /// Printed masked (••••1234), as on screen.
  final String accountNumber;
  final String ifscCode;
  final String officialPhone;

  /// Image bytes embedded in the document (fetched without the app's login,
  /// held in memory only): the standard layout's company logo and the wage
  /// slip's stamp. Null leaves them out.
  final Uint8List? logo;
  final Uint8List? stamp;

  PayslipPdfContext withImages({Uint8List? logo, Uint8List? stamp}) => PayslipPdfContext(
        monthLabel: monthLabel,
        companyName: companyName,
        companyCin: companyCin,
        companyAddress: companyAddress,
        bankName: bankName,
        accountNumber: accountNumber,
        ifscCode: ifscCode,
        officialPhone: officialPhone,
        logo: logo,
        stamp: stamp,
      );
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

  if (p.isWageSlip) {
    doc.addPage(_wageSlipPage(p, c));
    return doc;
  }
  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
      if (c.logo != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          // Web: max 48 high, 160 wide, contain.
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.ConstrainedBox(
              constraints: const pw.BoxConstraints(maxHeight: 48, maxWidth: 160),
              child: pw.Image(pw.MemoryImage(c.logo!), fit: pw.BoxFit.contain),
            ),
          ),
        ),
      if (c.companyName.isNotEmpty)
        pw.Text(c.companyName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
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
        if ((p.uanDisplay ?? '').isNotEmpty) kv('UAN', p.uanDisplay!),
        if ((p.esicDisplay ?? '').isNotEmpty) kv('ESIC No.', p.esicDisplay!),
        kv('Working Days', '${p.totalWorkingDays}'),
        kv('Paid Days', _days(p.paidDays)),
        kv('Loss of Pay', _days(p.lopDays)),
      ]),
      pw.SizedBox(height: 12),
      table('EARNINGS', payslipEarningLines(p), 'Gross Earnings', p.grossEarnings, PdfColors.green800),
      pw.SizedBox(height: 8),
      table('DEDUCTIONS', payslipDeductionLines(p), 'Total Deductions', p.totalDeductions, PdfColors.red800),
      if (additionsPanel(p) case final panel?) ...[
        pw.SizedBox(height: 8),
        table('ADDITIONS', [for (final r in panel.rows) (r.label, r.amount)], 'Additions', panel.total,
            PdfColors.green800),
      ],
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
          pw.Expanded(
              child: pw.Text('Net Salary Credited', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
          pw.Text(formatPayslipInr(p.netPay), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ]),
      ),
      pw.Spacer(),
      pw.Text(
          'This is a computer-generated payslip and does not require a signature.'
          '${c.officialPhone.isNotEmpty ? ' For queries contact HR at ${c.officialPhone}.' : ''}',
          textAlign: pw.TextAlign.center,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
    ]),
  ));
  return doc;
}

/// Web WageSlipDocument as an A4 page (saved values only).
pw.Page _wageSlipPage(PayslipModel p, PayslipPdfContext c) {
  final m = wageSlipModel(p);
  final info = wageSlipInfo(p);
  const s = pw.TextStyle(fontSize: 9);
  final b = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold);
  pw.Widget cell(String t, {pw.TextStyle? style, pw.Alignment align = pw.Alignment.centerLeft, PdfColor? fill}) =>
      pw.Container(
        color: fill,
        alignment: align,
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: pw.Text(t, style: style ?? s),
      );
  pw.Widget num(String t, {pw.TextStyle? style}) => cell(t, style: style, align: pw.Alignment.centerRight);
  final infoRows = info.left.length > info.right.length ? info.left.length : info.right.length;
  final rows = m.earnings.length > m.deductions.length ? m.earnings.length : m.deductions.length;
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(32),
    build: (_) => pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(width: .8)),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(children: [
            if (p.principalEmployerName.isNotEmpty)
              pw.Align(alignment: pw.Alignment.centerRight, child: pw.Text(p.principalEmployerName, style: b)),
            pw.Text(c.companyName.isEmpty ? '—' : c.companyName,
                style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.red900,
                    decoration: pw.TextDecoration.underline)),
            if (c.companyAddress.isNotEmpty) pw.Text(c.companyAddress, style: s),
            pw.SizedBox(height: 4),
            pw.Text(wageSlipPeriodLabel(p.cycleStart, p.cycleEnd), style: b),
          ]),
        ),
        pw.Table(border: pw.TableBorder.all(width: .6), columnWidths: {
          0: const pw.FlexColumnWidth(2.2),
          1: const pw.FlexColumnWidth(2.6),
          2: const pw.FlexColumnWidth(2.2),
          3: const pw.FlexColumnWidth(1.8),
        }, children: [
          for (var i = 0; i < infoRows; i++)
            pw.TableRow(children: [
              cell(i < info.left.length ? info.left[i].$1 : '', style: b),
              cell(i < info.left.length ? info.left[i].$2 : ''),
              cell(i < info.right.length ? info.right[i].$1 : '', style: b),
              num(i < info.right.length ? info.right[i].$2 : ''),
            ]),
        ]),
        pw.Table(border: pw.TableBorder.all(width: .6), columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(2),
          3: const pw.FlexColumnWidth(2.4),
          4: const pw.FlexColumnWidth(2),
        }, children: [
          pw.TableRow(children: [
            for (final h in const ['SALARY HEAD', 'ACTUAL', 'EARNING', 'DEDUCTION', ''])
              cell(h, style: b, align: pw.Alignment.center, fill: PdfColors.blue100),
          ]),
          for (var i = 0; i < rows; i++)
            pw.TableRow(children: [
              cell(i < m.earnings.length ? m.earnings[i].label : ''),
              num(i < m.earnings.length && m.earnings[i].actual != null
                  ? formatWageSlipAmount(m.earnings[i].actual!)
                  : ''),
              num(i < m.earnings.length ? formatWageSlipAmount(m.earnings[i].earned) : ''),
              cell(i < m.deductions.length ? m.deductions[i].label : ''),
              num(i < m.deductions.length ? formatWageSlipAmount(m.deductions[i].amount) : ''),
            ]),
          pw.TableRow(children: [
            cell('TOTAL GROSS', style: b),
            num(formatWageSlipAmount(m.totals.actual), style: b),
            num(formatWageSlipAmount(m.totals.earned), style: b),
            cell('TOTAL DEDUCTION', style: b),
            num(formatWageSlipAmount(m.totals.deductions), style: b),
          ]),
          pw.TableRow(children: [
            cell('NET SALARY PAY', style: b),
            pw.Container(),
            num(formatWageSlipAmount(m.totals.net), style: b),
            pw.Container(),
            pw.Container(),
          ]),
        ]),
        pw.SizedBox(height: c.stamp == null ? 70 : 12),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Employee Signature', style: s),
                pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
                  if (c.stamp != null)
                    // Web .ws-stamp: max 80 high, 140 wide, contain.
                    pw.ConstrainedBox(
                      constraints: const pw.BoxConstraints(maxHeight: 80, maxWidth: 140),
                      child: pw.Image(pw.MemoryImage(c.stamp!), fit: pw.BoxFit.contain),
                    ),
                  pw.Text('Authorized Signature', style: s),
                ]),
              ]),
        ),
      ]),
    ),
  );
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

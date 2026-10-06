import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../staff_model.dart';

// ══════════════════════════════════════════════════════════════════════
// Staff salary PDFs: the monthly pay slip (laid out like SKET's existing
// Excel pay slip) and the yearly salary statement.
// ASCII only — the built-in Helvetica has no Unicode glyphs, so "Rs." stands
// in for the rupee sign and plain hyphens for dashes (as in the receipts).
// ══════════════════════════════════════════════════════════════════════

const _red    = PdfColor.fromInt(0xFFE11D1D);
const _dark   = PdfColor.fromInt(0xFF111827);
const _grey   = PdfColor.fromInt(0xFF6B7280);
const _blue   = PdfColor.fromInt(0xFFBDD7EE); // header fill of the Excel slip
const _stripe = PdfColor.fromInt(0xFFF3F4F6);

String _rs(int n) => 'Rs. ${NumberFormat('#,##,###', 'en_IN').format(n)}';
String _num(int n) => NumberFormat('#,##,###', 'en_IN').format(n);
String _d(DateTime? d) => d == null ? '-' : DateFormat('dd MMM yyyy').format(d);
String _v(String s) => s.trim().isEmpty ? '-' : s.trim();

String _orgName(Map<String, dynamic>? org) {
  final v = org?['name'] as String?;
  return (v != null && v.trim().isNotEmpty) ? v.trim() : 'Sri Krishnashraya Educational Trust';
}

String _orgAddress(Map<String, dynamic>? org) => ((org?['address'] as String?) ?? '').trim();

String _amountInWords(int n) {
  if (n <= 0) return 'Zero Rupees Only';
  const ones = ['', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight', 'Nine', 'Ten', 'Eleven',
    'Twelve', 'Thirteen', 'Fourteen', 'Fifteen', 'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen'];
  const tens = ['', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy', 'Eighty', 'Ninety'];
  String w(int x) {
    if (x == 0) return '';
    if (x < 20) return '${ones[x]} ';
    if (x < 100) return '${tens[x ~/ 10]} ${w(x % 10)}';
    if (x < 1000) return '${ones[x ~/ 100]} Hundred ${w(x % 100)}';
    if (x < 100000) return '${w(x ~/ 1000)}Thousand ${w(x % 1000)}';
    if (x < 10000000) return '${w(x ~/ 100000)}Lakh ${w(x % 100000)}';
    return '${w(x ~/ 10000000)}Crore ${w(x % 10000000)}';
  }
  return 'Rupees ${w(n).trim().replaceAll(RegExp(r'\s+'), ' ')} Only';
}

Future<pw.MemoryImage> _logo() async =>
    pw.MemoryImage((await rootBundle.load('assets/images/sket-logo.png')).buffer.asUint8List());

pw.Widget _cell(String text, {bool bold = false, bool right = false, PdfColor? fill, double size = 9.5}) => pw.Container(
  color: fill,
  padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  alignment: right ? pw.Alignment.centerRight : pw.Alignment.centerLeft,
  child: pw.Text(text, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : null, color: _dark)),
);

// "Label : value" rows in a bordered box (employee details block).
pw.Widget _infoTable(List<(String, String)> rows) => pw.Table(
  border: pw.TableBorder.all(color: _dark, width: 0.8),
  defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
  columnWidths: const {0: pw.FlexColumnWidth(1.1), 1: pw.FlexColumnWidth(1.6)},
  children: [
    for (final (l, v) in rows)
      pw.TableRow(children: [_cell(l), _cell(': $v')]),
  ],
);

// Description | Amount table with a blue header and total row.
pw.Widget _amountTable(List<(String, int)> rows, int total) => pw.Table(
  border: pw.TableBorder.all(color: _dark, width: 0.8),
  defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
  columnWidths: const {0: pw.FlexColumnWidth(1.6), 1: pw.FlexColumnWidth(1)},
  children: [
    pw.TableRow(children: [_cell('Description', bold: true, fill: _blue), _cell('Amount', bold: true, fill: _blue, right: true)]),
    for (final (l, v) in rows) pw.TableRow(children: [_cell(l), _cell(_num(v), right: true)]),
    pw.TableRow(children: [_cell('Total', bold: true, fill: _blue), _cell(_num(total), bold: true, fill: _blue, right: true)]),
  ],
);

// ── Monthly pay slip ──────────────────────────────────────────────────
Future<Uint8List> buildStaffPayslipPdf({
  required StaffMember staff,
  required StaffSalary salary,
  Map<String, dynamic>? org,
}) async {
  final logo = await _logo();
  final doc = pw.Document();
  final monthTitle = salaryMonthLabel(salary.month).toUpperCase();

  final earnings = <(String, int)>[
    ('Salary', salary.basic),
    if (salary.hra > 0) ('HRA', salary.hra),
    if (salary.allowances > 0) ('Allowances', salary.allowances),
    ('OverTime', salary.overtime),
    if (salary.bonus > 0) ('Bonus', salary.bonus),
  ];
  final deductions = <(String, int)>[
    ('Leave Deduction', salary.leaveDeduction),
    if (salary.pf > 0) ('PF', salary.pf),
    if (salary.advance > 0) ('Advance', salary.advance),
    if (salary.otherDeduction > 0) ('Other', salary.otherDeduction),
  ];
  final payment = salary.isPaid
      ? 'Paid${salary.paymentMode.isEmpty ? '' : ' (${salaryPaymentModeLabel(salary.paymentMode)})'}'
      : 'Pending';

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 40),
    build: (ctx) => pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: _dark, width: 1.4)),
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: pw.Column(mainAxisSize: pw.MainAxisSize.min, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Header: logo + org name, then the slip date
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.SizedBox(width: 72, height: 60, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          pw.SizedBox(width: 12),
          pw.Expanded(child: pw.Center(child: pw.Text(_orgName(org).toUpperCase(),
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _red,
                  decoration: pw.TextDecoration.underline, decorationColor: _red)))),
        ]),
        if (_orgAddress(org).isNotEmpty) ...[
          pw.SizedBox(height: 4),
          pw.Center(child: pw.Text(_orgAddress(org), textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: _grey))),
        ],
        pw.SizedBox(height: 10),
        pw.Align(alignment: pw.Alignment.centerRight,
            child: pw.Text('Date : ${_d(salary.paidOn ?? DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: _dark))),
        pw.SizedBox(height: 6),
        pw.Divider(color: _dark, thickness: 1.2),
        pw.SizedBox(height: 6),

        pw.Text('PAY SLIP FOR THE MONTH OF $monthTitle',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: _dark)),
        pw.SizedBox(height: 4),
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: _infoTable([
            ('Employee Name', _v(staff.name)),
            ('Staff ID', _v(staff.staffCode)),
            ('Location', _v(staff.centreName)),
            ('PAN NO', _v(staff.panNumber)),
            ('Designation', _v(staff.designation)),
          ])),
          pw.SizedBox(width: 6),
          pw.Expanded(child: _infoTable([
            ('Worked Time', _v(staff.workTimings)),
            ('Worked on Holidays', salary.workedOnHolidays ? 'Yes' : 'No'),
            ('Leave Taken', salary.leaveDaysLabel),
            ('Working Days', salary.workingDays?.toString() ?? '-'),
            ('Payment', payment),
          ])),
        ]),
        pw.SizedBox(height: 10),
        pw.Divider(color: _dark, thickness: 1.2),
        pw.SizedBox(height: 6),

        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('EARNINGS', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            _amountTable(earnings, salary.gross),
          ])),
          pw.SizedBox(width: 6),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('DEDUCTION', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            _amountTable(deductions, salary.deductions),
          ])),
        ]),
        pw.SizedBox(height: 14),

        // Net pay box
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 60),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('NET PAY', style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Table(
              border: pw.TableBorder.all(color: _dark, width: 0.8),
              defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
              columnWidths: const {0: pw.FlexColumnWidth(1.6), 1: pw.FlexColumnWidth(1)},
              children: [
                pw.TableRow(children: [_cell('Gross Earnings', bold: true, fill: _blue), _cell('Net Pay', bold: true, fill: _blue)]),
                pw.TableRow(children: [_cell('Gross Earnings'), _cell(_rs(salary.gross), right: true)]),
                pw.TableRow(children: [_cell('Total Deduction'), _cell(_rs(salary.deductions), right: true)]),
                pw.TableRow(children: [_cell('NET PAY', bold: true), _cell(_rs(salary.net), bold: true, right: true, size: 10.5)]),
              ],
            ),
            pw.SizedBox(height: 4),
            pw.Text(_amountInWords(salary.net), style: pw.TextStyle(fontSize: 8.5, fontStyle: pw.FontStyle.italic, color: _grey)),
          ]),
        ),
        pw.SizedBox(height: 14),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          decoration: pw.BoxDecoration(color: _blue, border: pw.Border.all(color: _dark, width: 0.8)),
          child: pw.Center(child: pw.Text('This is a computer-generated pay slip and does not require a signature.',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
        ),
      ]),
    ),
  ));
  return doc.save();
}

// ── Salary statement for a chosen period ─────────────────────────────
// Months from [from] to [to] inclusive (only year/month are used), e.g. a
// calendar year, a financial year (Apr-Mar) or any range picked on the
// calendar.

// Every month in the period, oldest first.
List<DateTime> salaryPeriodMonths(DateTime from, DateTime to) => [
  for (var d = DateTime(from.year, from.month); !d.isAfter(DateTime(to.year, to.month)); d = DateTime(d.year, d.month + 1)) d,
];

// "YEAR 2026", "FY 2025-26" or "JAN 2026 TO JUN 2026".
String salaryPeriodTitle(DateTime from, DateTime to) {
  if (from.year == to.year && from.month == 1 && to.month == 12) return 'YEAR ${from.year}';
  if (from.month == 4 && to.month == 3 && to.year == from.year + 1) {
    return 'FY ${from.year}-${(to.year % 100).toString().padLeft(2, '0')}';
  }
  final f = DateFormat('MMM yyyy');
  return from.year == to.year && from.month == to.month
      ? f.format(from).toUpperCase()
      : '${f.format(from)} TO ${f.format(to)}'.toUpperCase();
}

Future<Uint8List> buildStaffSalaryStatementPdf({
  required StaffMember staff,
  required DateTime from,
  required DateTime to,
  required List<StaffSalary> salaries, // any months; only the period is used
  Map<String, dynamic>? org,
}) async {
  final logo = await _logo();
  final doc = pw.Document();
  final months = salaryPeriodMonths(from, to);
  final keys = months.map(salaryMonthKey).toSet();
  final byMonth = {for (final s in salaries.where((s) => keys.contains(s.month))) s.month: s};
  final rows = byMonth.values.toList();
  final title = salaryPeriodTitle(from, to);
  int sum(int Function(StaffSalary) f) => rows.fold(0, (a, s) => a + f(s));
  final gross = sum((s) => s.gross), ded = sum((s) => s.deductions), net = sum((s) => s.net);
  final paid = rows.where((s) => s.isPaid).fold<int>(0, (a, s) => a + s.net);
  final leave = rows.fold<double>(0, (a, s) => a + s.leaveDays);

  final head = ['Month', 'Basic', 'HRA + Allow.', 'OT + Bonus', 'Gross', 'Deduct.', 'Net Pay', 'Status', 'Paid On'];
  pw.Widget th(String t, {bool right = false}) => _cell(t, bold: true, fill: _blue, right: right, size: 8.5);
  pw.Widget td(String t, {bool right = false, bool bold = false}) => _cell(t, right: right, bold: bold, size: 8.5);

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
    footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text('Computer-generated statement. Generated on ${_d(DateTime.now())}.', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
      pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
    ]),
    build: (ctx) => [
      pw.Row(children: [
        pw.SizedBox(width: 60, height: 50, child: pw.Image(logo, fit: pw.BoxFit.contain)),
        pw.SizedBox(width: 12),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_orgName(org).toUpperCase(), style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: _red)),
          if (_orgAddress(org).isNotEmpty)
            pw.Text(_orgAddress(org), style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
        ])),
      ]),
      pw.SizedBox(height: 8),
      pw.Divider(color: _dark, thickness: 1.2),
      pw.Center(child: pw.Text('SALARY STATEMENT - $title',
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8))),
      pw.SizedBox(height: 8),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: _infoTable([
          ('Employee Name', _v(staff.name)),
          ('Staff ID', _v(staff.staffCode)),
          ('Designation', _v(staff.designation)),
          ('Location', _v(staff.centreName)),
        ])),
        pw.SizedBox(width: 6),
        pw.Expanded(child: _infoTable([
          ('PAN NO', _v(staff.panNumber)),
          ('Joining Date', _d(staff.joiningDate)),
          ('Bank', _v([staff.bankName, staff.accountNumber].where((x) => x.isNotEmpty).join(' / '))),
          ('Employment', staffEmploymentLabel(staff.employmentType)),
        ])),
      ]),
      pw.SizedBox(height: 12),
      pw.Table(
        border: pw.TableBorder.all(color: _dark, width: 0.6),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
        columnWidths: const {
          0: pw.FlexColumnWidth(1.25), 1: pw.FlexColumnWidth(1.05), 2: pw.FlexColumnWidth(1.1), 3: pw.FlexColumnWidth(1.05),
          4: pw.FlexColumnWidth(1.05), 5: pw.FlexColumnWidth(1.05), 6: pw.FlexColumnWidth(1.1), 7: pw.FlexColumnWidth(1.45), 8: pw.FlexColumnWidth(1.3),
        },
        children: [
          pw.TableRow(children: [for (var i = 0; i < head.length; i++) th(head[i], right: i >= 1 && i <= 6)]),
          for (var i = 0; i < months.length; i++)
            if (byMonth[salaryMonthKey(months[i])] case final s?)
              pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isOdd ? _stripe : null),
                children: [
                  td(DateFormat('MMM yyyy').format(months[i])),
                  td(_num(s.basic), right: true),
                  td(_num(s.hra + s.allowances), right: true),
                  td(_num(s.overtime + s.bonus), right: true),
                  td(_num(s.gross), right: true),
                  td(_num(s.deductions), right: true),
                  td(_num(s.net), right: true, bold: true),
                  td(s.isPaid ? 'Paid' : 'Pending'),
                  td(_d(s.paidOn)),
                ])
            else
              pw.TableRow(
                decoration: pw.BoxDecoration(color: i.isOdd ? _stripe : null),
                children: [
                  td(DateFormat('MMM yyyy').format(months[i])),
                  for (var c = 0; c < 6; c++) td('-', right: true),
                  td('Not recorded'), td('-'),
                ]),
          pw.TableRow(children: [
            th('Total'),
            th(_num(sum((s) => s.basic)), right: true),
            th(_num(sum((s) => s.hra + s.allowances)), right: true),
            th(_num(sum((s) => s.overtime + s.bonus)), right: true),
            th(_num(gross), right: true),
            th(_num(ded), right: true),
            th(_num(net), right: true),
            th(''), th(''),
          ]),
        ],
      ),
      pw.SizedBox(height: 14),
      pw.Table(
        border: pw.TableBorder.all(color: _dark, width: 0.6),
        defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
        columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(1.4)},
        children: [
          pw.TableRow(children: [_cell('Summary', bold: true, fill: _blue), _cell(title, bold: true, fill: _blue, right: true)]),
          pw.TableRow(children: [_cell('Months recorded'), _cell('${rows.length} of ${months.length}', right: true)]),
          pw.TableRow(children: [_cell('Total gross earnings'), _cell(_rs(gross), right: true)]),
          pw.TableRow(children: [_cell('Total deductions'), _cell(_rs(ded), right: true)]),
          pw.TableRow(children: [_cell('Total net pay', bold: true), _cell(_rs(net), right: true, bold: true)]),
          pw.TableRow(children: [_cell('Paid'), _cell(_rs(paid), right: true)]),
          pw.TableRow(children: [_cell('Pending'), _cell(_rs(net - paid), right: true)]),
          pw.TableRow(children: [_cell('Leave taken (days)'),
            _cell(leave == leave.roundToDouble() ? '${leave.toInt()}' : '$leave', right: true)]),
        ],
      ),
    ],
  ));
  return doc.save();
}

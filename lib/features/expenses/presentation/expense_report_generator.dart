import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── PDF expense report ────────────────────────────────────────────────────
// Expenses screen → download icon: a period expense statement matching the
// donation statement's look — org header, centered orange section bars,
// itemized voucher table, category breakdown, grand total in words, and the
// statutory PAN/12AA/80G footer.

const _statutoryLine =
    'Trust PAN: AATTS6672D  |  12AA Registration: AATTS6672D25BL01  |  80G Certification: AATTS6672D25BL02';
const _orgName = 'Sri Krishnashraya Educational Trust';
// ASCII hyphens only: the built-in Helvetica has no Unicode support, so an
// en/em dash is silently dropped and prints as a gap (same reason the amounts
// say "Rs." instead of the rupee glyph).
const _orgAddress = 'No. 50, 2nd cross, Ripco Shanthinikethan layout, near SJES College, Medahalli, '
    'Virgo Nagar Post, Bangalore - 560049. Mob: 9986064411, 9620794141. '
    'Email: aakrishnashraya@gmail.com Website: www.krishnashraya.in';

class ExpenseReportRow {
  const ExpenseReportRow({
    required this.date,
    required this.voucherNo,
    required this.paidTo,
    required this.category,
    required this.method,
    required this.amount,
  });
  final String date, voucherNo, paidTo, category, method;
  final int amount;
}

String _fmt(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) { parts.insert(0, rest.substring(rest.length - 2)); rest = rest.substring(0, rest.length - 2); }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}

String _amountInWords(int n) {
  if (n == 0) return 'Zero Rupees Only';
  const ones = ['','One','Two','Three','Four','Five','Six','Seven','Eight','Nine',
    'Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'];
  const tens = ['','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'];
  String words(int num) {
    if (num == 0) return '';
    if (num < 20) return '${ones[num]} ';
    if (num < 100) return '${tens[num ~/ 10]} ${words(num % 10)}';
    if (num < 1000) return '${ones[num ~/ 100]} Hundred ${words(num % 100)}';
    if (num < 100000) return '${words(num ~/ 1000)}Thousand ${words(num % 1000)}';
    if (num < 10000000) return '${words(num ~/ 100000)}Lakh ${words(num % 100000)}';
    return '${words(num ~/ 10000000)}Crore ${words(num % 10000000)}';
  }
  return 'Rupees ${words(n).trim()} Only';
}

Future<Uint8List> buildExpenseReportPdf({
  required List<ExpenseReportRow> rows,
  required String periodLabel,
  String categoryFilter = 'All',
}) async {
  final doc = pw.Document();
  final logoData = await rootBundle.load('assets/images/sket-logo.png');
  final logo = pw.MemoryImage(logoData.buffer.asUint8List());

  final orange   = PdfColor.fromInt(0xFFF97316);
  final grey     = PdfColor.fromInt(0xFF6B7280);
  final dark     = PdfColor.fromInt(0xFF1F2937);
  final bgLight  = PdfColor.fromInt(0xFFF8FAFC);
  final bgStripe = PdfColor.fromInt(0xFFF3F4F6);
  final white    = PdfColor.fromInt(0xFFFFFFFF);

  final total = rows.fold<int>(0, (s, r) => s + r.amount);
  final byCategory = <String, int>{};
  for (final r in rows) {
    byCategory[r.category] = (byCategory[r.category] ?? 0) + r.amount;
  }
  final catEntries = byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  final now = DateTime.now();
  const months = ['January','February','March','April','May','June','July',
    'August','September','October','November','December'];
  final generatedOn = '${now.day.toString().padLeft(2, '0')} ${months[now.month - 1]} ${now.year}';

  pw.Widget sectionBar(String title) => pw.Container(
    width: double.infinity, color: orange,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: pw.Text(title, textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: white, letterSpacing: 0.3)),
  );

  pw.Widget th(String label, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: pw.Text(label, textAlign: align,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 0.2)),
  );

  pw.Widget td(String text, {bool bold = false, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: pw.Text(text, textAlign: align,
        style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: dark)),
  );

  // Each entry below is a TOP-LEVEL MultiPage child. They must NOT be wrapped
  // in one outer Column: Column is not a SpanningWidget, so a month with more
  // vouchers than fit on one A4 page made MultiPage throw ("Widget won't fit
  // into the page…") and the download failed with "Could not generate the
  // report". As separate children the voucher Table (which IS spanning) flows
  // onto as many pages as it needs.
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
    footer: (ctx) => pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 8),
      child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
          style: pw.TextStyle(fontSize: 7.5, color: grey)),
    ),
    build: (ctx) => [
      // Header: logo + org lockup (left) | title (right), then the address bar.
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Image(logo, height: 58),
            pw.SizedBox(height: 6),
            pw.Text(_orgName, style: pw.TextStyle(fontSize: 10, color: dark)),
            pw.Text('(Registered Charitable Trust)', style: pw.TextStyle(fontSize: 8.5, color: grey)),
          ]),
          pw.Expanded(child: pw.Align(
            alignment: pw.Alignment.topRight,
            child: pw.Text('EXPENSE REPORT',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 0.2,
                    decoration: pw.TextDecoration.underline, decorationColor: dark, decorationThickness: 1.2)),
          )),
        ]),
        pw.SizedBox(height: 14),
        pw.Container(
          width: double.infinity, color: orange,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: pw.Text(_orgAddress, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: white)),
        ),
        pw.SizedBox(height: 16),

        // ── REPORT DETAILS ───────────────────────────────────────────
        sectionBar('REPORT DETAILS'),
        pw.Table(columnWidths: const {
          0: pw.FlexColumnWidth(1.3), 1: pw.FlexColumnWidth(2.0),
          2: pw.FlexColumnWidth(1.3), 3: pw.FlexColumnWidth(2.0),
        }, children: [
          pw.TableRow(children: [
            pw.Padding(padding: const pw.EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: pw.Text('Period', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: dark))),
            pw.Padding(padding: const pw.EdgeInsets.fromLTRB(4, 8, 10, 8),
                child: pw.Text(periodLabel, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark))),
            pw.Padding(padding: const pw.EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: pw.Text('Generated On', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: dark))),
            pw.Padding(padding: const pw.EdgeInsets.fromLTRB(4, 8, 10, 8),
                child: pw.Text(generatedOn, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark))),
          ]),
          pw.TableRow(decoration: pw.BoxDecoration(color: bgStripe), children: [
            pw.Padding(padding: const pw.EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: pw.Text('Total Expenses', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: dark))),
            pw.Padding(padding: const pw.EdgeInsets.fromLTRB(4, 8, 10, 8),
                child: pw.Text('${rows.length}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark))),
            pw.Padding(padding: const pw.EdgeInsets.fromLTRB(10, 8, 4, 8),
                child: pw.Text('Category', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: dark))),
            pw.Padding(padding: const pw.EdgeInsets.fromLTRB(4, 8, 10, 8),
                child: pw.Text(categoryFilter, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark))),
          ]),
        ]),
        pw.SizedBox(height: 16),
        sectionBar('EXPENSE DETAILS'),
      ]),

      // ── EXPENSE DETAILS ──────────────────────────────────────────────
      // Own top-level child so it can span pages; the column header row is
      // repeated at the top of every page it flows onto.
      if (rows.isEmpty)
        pw.Padding(padding: const pw.EdgeInsets.all(14),
            child: pw.Text('No expenses recorded for this period.', style: pw.TextStyle(fontSize: 9.5, color: grey)))
      else
        pw.Table(
          columnWidths: const {
            0: pw.FlexColumnWidth(0.6), 1: pw.FlexColumnWidth(1.3), 2: pw.FlexColumnWidth(1.7),
            3: pw.FlexColumnWidth(2.0), 4: pw.FlexColumnWidth(1.6), 5: pw.FlexColumnWidth(1.2),
            6: pw.FlexColumnWidth(1.3),
          },
          children: [
            pw.TableRow(repeat: true, decoration: pw.BoxDecoration(color: bgStripe), children: [
              th('Sl.No'), th('Date'), th('Voucher No.'), th('Paid To'),
              th('Category'), th('Mode'), th('Amount (Rs.)', align: pw.TextAlign.right),
            ]),
            ...rows.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(color: e.key.isOdd ? bgLight : white),
              children: [
                td('${e.key + 1}'), td(e.value.date), td(e.value.voucherNo),
                td(e.value.paidTo), td(e.value.category), td(e.value.method),
                td(_fmt(e.value.amount), bold: true, align: pw.TextAlign.right),
              ],
            )),
          ],
        ),
      pw.SizedBox(height: 16),

      // ── CATEGORY BREAKDOWN ───────────────────────────────────────────
      if (catEntries.isNotEmpty) ...[
        sectionBar('CATEGORY BREAKDOWN'),
        pw.Table(
          columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.4), 2: pw.FlexColumnWidth(1.2)},
          children: [
            pw.TableRow(repeat: true, decoration: pw.BoxDecoration(color: bgStripe), children: [
              th('Category'), th('Amount (Rs.)', align: pw.TextAlign.right), th('Share', align: pw.TextAlign.right),
            ]),
            ...catEntries.map((e) => pw.TableRow(children: [
              td(e.key),
              td(_fmt(e.value), bold: true, align: pw.TextAlign.right),
              td(total > 0 ? '${(e.value * 100 / total).round()}%' : '-', align: pw.TextAlign.right),
            ])),
          ],
        ),
        pw.SizedBox(height: 16),
      ],

      // ── SUMMARY ──────────────────────────────────────────────────────
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        sectionBar('EXPENSE SUMMARY'),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Total Spent', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.Text('Rs. ${_fmt(total)}.00', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: orange)),
          ]),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 4),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('AMOUNT IN WORDS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: grey, letterSpacing: 0.3)),
            pw.SizedBox(height: 3),
            pw.Text(_amountInWords(total), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: orange)),
          ]),
        ),
      ]),
      pw.SizedBox(height: 20),

      // ── Statutory footer ─────────────────────────────────────────────
      pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        sectionBar('STATUTORY REGISTRATION DETAILS'),
        pw.Container(
          width: double.infinity,
          color: bgStripe,
          padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(_statutoryLine, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.SizedBox(height: 5),
            pw.Text('This is an electronically generated internal expense report. No signature is required.',
                style: pw.TextStyle(fontSize: 7.5, color: grey)),
          ]),
        ),
      ]),
    ],
  ));
  return doc.save();
}

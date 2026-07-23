import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/utils/native_file_saver.dart';
import '../../../core/network/api_client.dart';

// Fetches organization identity (name/address/PAN/12A/80G/etc.) configured in
// Settings → Organization on the backend. Returns null (never throws) on any
// failure so the receipt still renders with the hardcoded fallbacks below —
// this must never block a donor from getting their receipt.
Future<Map<String, dynamic>?> fetchOrgSettings() async {
  try {
    final r = await apiClient.get('/settings/organization');
    return (r['data'] as Map).cast<String, dynamic>();
  } catch (_) {
    return null;
  }
}

// Hardcoded fallback identity — used whenever Settings → Organization hasn't
// been configured yet (or couldn't be reached), so the receipt never regresses
// to blank/missing org details.
const _orgFallback = {
  'name': 'Sri Krishnashraya Educational Trust',
  'address': '# 88/1, 84/1, 84/5, Sant Baba Hardas Ram Dam, Thammarasanahalli, Chikka Haralagere, Sulibele, Bangalore - 562129',
  'pan': 'AATTS6672D',
  'reg12A': 'ITBA/EXM/S/12AA/2018-19/A/10252',
  'cert80G': 'ATTS6672DF20221',
  'email': 'krishnashryahome@gmail.com',
};

String _org(Map<String, dynamic>? org, String key) {
  final v = org?[key] as String?;
  if (v != null && v.trim().isNotEmpty) return v;
  return _orgFallback[key] ?? '';
}

// Receipt palette (shared by the on-screen sheet + the PDF export).
const _orange   = Color(0xFFF97316);
const _grey     = Color(0xFF6B7280);
const _dark     = Color(0xFF1F2937);
const _border   = Color(0xFFE5E7EB);
const _bgLight  = Color(0xFFF8FAFC);

class DonationReceipt {
  const DonationReceipt({
    required this.receiptNo,
    required this.donorName,
    required this.donorPhone,
    required this.donorCity,
    required this.donorPan,
    required this.donationType,
    required this.amount,
    required this.paymentMode,
    required this.date,
    required this.taxExemption,
    this.donorEmail = '',
    this.donorAddress = '',
    this.donorState = '',
    this.donorPincode = '',
    this.donorCountry = '',
    this.reference = '',
    this.notes = '',
  });

  final String receiptNo;
  final String donorName;
  final String donorPhone;
  final String donorCity;
  final String donorPan;
  final String donationType;
  final int amount;
  final String paymentMode;
  final String date;
  final bool taxExemption;
  final String donorEmail;
  final String donorAddress;
  final String donorState;
  final String donorPincode;
  final String donorCountry;
  final String reference;
  // Free-text description entered when the donation was recorded — shown on
  // the invoice in place of the generic contribution blurb when present.
  final String notes;

  // Full postal address for display — donorCity/donorState/etc. are separate
  // fields on the donor record, joined here for a single-line render.
  String get donorFullAddress => [donorAddress, donorCity, donorState, donorPincode, donorCountry]
      .where((s) => s.trim().isNotEmpty)
      .join(', ');
}

String _amountInWords(int n) {
  if (n == 0) return 'Zero Rupees Only';
  const ones = ['','One','Two','Three','Four','Five','Six','Seven','Eight','Nine',
    'Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen','Seventeen','Eighteen','Nineteen'];
  const tens = ['','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'];
  String words(int num) {
    if (num == 0) return '';
    if (num < 20) return '${ones[num]} ';
    if (num < 100) {
      final onesPart = num % 10 == 0 ? '' : '-${ones[num % 10]}';
      return '${tens[num ~/ 10]}$onesPart ';
    }
    if (num < 1000) return '${ones[num ~/ 100]} Hundred ${words(num % 100)}';
    if (num < 100000) return '${words(num ~/ 1000)}Thousand ${words(num % 1000)}';
    if (num < 10000000) return '${words(num ~/ 100000)}Lakh ${words(num % 100000)}';
    return '${words(num ~/ 10000000)}Crore ${words(num % 10000000)}';
  }
  return 'Rupees ${words(n).trim()} Only';
}

String _fmt(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) { parts.insert(0, rest.substring(rest.length - 2)); rest = rest.substring(0, rest.length - 2); }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},${last3}';
}

String buildReceiptText(DonationReceipt r) => '''
SRI KRISHNASHRAYA EDUCATIONAL TRUST — DONATION RECEIPT
══════════════════════════════════════
Receipt No : ${r.receiptNo}
Date       : ${r.date}
Payment    : ${r.paymentMode}
──────────────────────────────────────
Donor      : ${r.donorName}
${r.donorPhone.isNotEmpty ? 'Phone      : ${r.donorPhone}\n' : ''}${r.donorEmail.isNotEmpty ? 'Email      : ${r.donorEmail}\n' : ''}${r.donorFullAddress.isNotEmpty ? 'Address    : ${r.donorFullAddress}\n' : ''}${r.donorPan.isNotEmpty ? 'PAN        : ${r.donorPan}\n' : ''}──────────────────────────────────────
Type       : ${r.donationType}
Amount     : ₹${_fmt(r.amount)}.00
──────────────────────────────────────
${_amountInWords(r.amount)}
──────────────────────────────────────
Trust PAN: AATTS6672D
12AB Reg : AATTS6672D25BL01
80G Approval : AATTS6672D25BL02
${r.taxExemption ? '✓ 80G Tax Exemption Applicable\n' : ''}══════════════════════════════════════
Thanks for your support!
''';

// ── PDF receipt (branded, with logo) ──────────────────────────────────────────
// Full-page A4 invoice-style layout — logo, orange address bar, recipient +
// receipt-info columns, itemized donation table, amount-in-words / totals,
// and a statutory registration footer.
// Uses "Rs." instead of the ₹ glyph because the default PDF font (Helvetica)
// can't render the rupee symbol.
Future<Uint8List> buildReceiptPdf(DonationReceipt r, {Map<String, dynamic>? org}) async {
  final doc = pw.Document();
  final logoData = await rootBundle.load('assets/images/sket-logo.png');
  final logo = pw.MemoryImage(logoData.buffer.asUint8List());

  final orange   = PdfColor.fromInt(0xFFF97316);
  final grey     = PdfColor.fromInt(0xFF6B7280);
  final dark     = PdfColor.fromInt(0xFF1F2937);
  final brd      = PdfColor.fromInt(0xFFE5E7EB);
  final bgLight  = PdfColor.fromInt(0xFFF8FAFC);
  final white    = PdfColor.fromInt(0xFFFFFFFF);
  final amtStr   = 'Rs. ${_fmt(r.amount)}.00';
  final orgAddress = _org(org, 'address');
  final orgPan     = _org(org, 'pan');
  final org12A     = _org(org, 'reg12A');
  final org80G     = _org(org, 'cert80G');
  final orgEmail   = _org(org, 'email');
  final locationLine = [r.donorCity, r.donorState, r.donorCountry]
      .where((s) => s.trim().isNotEmpty).join(', ');

  // MultiPage (not a fixed-size Page): a Page silently clips/positions any
  // content past its bottom edge when it overflows. MultiPage flows the
  // overflow onto another page instead.
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
    build: (ctx) => [pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Header: logo (wordmark is baked into the asset)
      pw.Image(logo, height: 46),
      pw.SizedBox(height: 16),

      // Full-width orange address bar
      if (orgAddress.isNotEmpty)
        pw.Container(
          width: double.infinity,
          color: orange,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: pw.Text(orgAddress, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: white)),
        ),
      pw.SizedBox(height: 20),

      // Recipient (left) | Receipt info (right)
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(flex: 6, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('RECIPIENT:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 0.5)),
          pw.SizedBox(height: 5),
          pw.Text(r.donorName, style: pw.TextStyle(fontSize: 18, color: dark)),
          pw.SizedBox(height: 4),
          if (r.donorPhone.isNotEmpty) pw.Text(r.donorPhone, style: pw.TextStyle(fontSize: 9.5, color: grey)),
          if (locationLine.isNotEmpty) pw.Text(locationLine, style: pw.TextStyle(fontSize: 9.5, color: grey)),
          if (r.donorPan.isNotEmpty) ...[
            pw.SizedBox(height: 3),
            pw.Text('PAN: ${r.donorPan}', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: orange)),
          ],
        ])),
        pw.SizedBox(width: 16),
        pw.Expanded(flex: 5, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(
            width: double.infinity,
            color: orange,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Text('Receipt for #${r.receiptNo}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: white)),
          ),
          pw.Container(
            width: double.infinity,
            color: bgLight,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Transaction Date: ${r.date}', style: pw.TextStyle(fontSize: 8.5, color: dark)),
              pw.SizedBox(height: 2),
              pw.Text('Mode: ${r.paymentMode}', style: pw.TextStyle(fontSize: 8.5, color: dark)),
              if (r.reference.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text('Gateway Ref: ${r.reference}', style: pw.TextStyle(fontSize: 8.5, color: dark)),
              ],
            ]),
          ),
        ])),
      ]),
      pw.SizedBox(height: 22),

      // Itemized donation table
      pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(2.6),
          1: pw.FlexColumnWidth(3.6),
          2: pw.FlexColumnWidth(1),
          3: pw.FlexColumnWidth(1.5),
          4: pw.FlexColumnWidth(1.7),
        },
        children: [
          pw.TableRow(decoration: pw.BoxDecoration(color: orange), children: [
            _th('DONATION / SERVICE'),
            _th('DESCRIPTION'),
            _th('UNIT', align: pw.TextAlign.center),
            _th('COST', align: pw.TextAlign.right),
            _th('TOTAL', align: pw.TextAlign.right),
          ]),
          pw.TableRow(children: [
            _td(r.donationType, dark, bold: true),
            _td(
              r.notes.trim().isNotEmpty
                ? r.notes.trim()
                : 'Contribution allocated towards trust operational support, community '
                  'educational aid, and welfare programs.'
                  '${r.taxExemption ? ' Clean tax exemption applicable.' : ''}',
              grey, size: 8.5,
            ),
            _td('1', dark, align: pw.TextAlign.center),
            _td(_fmt(r.amount), dark, align: pw.TextAlign.right),
            _td(amtStr, dark, bold: true, align: pw.TextAlign.right),
          ]),
        ],
      ),
      pw.SizedBox(height: 18),
      pw.Container(height: 1.2, color: dark),
      pw.SizedBox(height: 22),

      pw.Center(child: pw.Text('Receipt for Payment', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: dark))),
      pw.SizedBox(height: 18),

      // Amount in words (left) | Subtotal / Tax / Total (right)
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(flex: 6, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('RECEIPT FOR PAYMENT (AMOUNT IN WORDS)', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 0.3)),
          pw.SizedBox(height: 8),
          pw.Text(_amountInWords(r.amount), style: pw.TextStyle(fontSize: 13, fontStyle: pw.FontStyle.italic, color: orange)),
        ])),
        pw.SizedBox(width: 16),
        pw.Expanded(flex: 4, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          _totRowPdf('Subtotal', amtStr, grey),
          _totRowPdf('Tax (0%)', 'Rs. 0.00', grey),
          _totRowPdf('Total', amtStr, dark, bold: true),
        ])),
      ]),
      pw.SizedBox(height: 22),
      pw.Container(height: 1, color: brd),
      pw.SizedBox(height: 20),

      pw.Center(child: pw.Text('Thanks for your support!',
          style: pw.TextStyle(fontSize: 14, fontStyle: pw.FontStyle.italic, fontWeight: pw.FontWeight.bold, color: orange))),
      pw.SizedBox(height: 22),

      // Statutory footer bar (PAN / 12AA / 80G) + disclaimer
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(color: bgLight, border: pw.Border(left: pw.BorderSide(color: orange, width: 3))),
        padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('STATUTORY REGISTRATION DETAILS (TAX BENEFITS)',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: orange, letterSpacing: 0.3)),
          pw.SizedBox(height: 5),
          pw.Text('Trust PAN: $orgPan   |   12AA Registration: $org12A   |   80G Certification: $org80G',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: dark)),
          pw.SizedBox(height: 5),
          pw.Text(
            'This is an electronically generated receipt confirmation. No physical signature is required.'
            '${orgEmail.isNotEmpty ? ' For verification or support, write to $orgEmail.' : ''}',
            style: pw.TextStyle(fontSize: 7.5, color: grey)),
        ]),
      ),
    ])],
  ));
  return doc.save();
}

const _fullMonths = ['January','February','March','April','May','June','July',
  'August','September','October','November','December'];
String _fmtFullDate(DateTime d) => '${d.day.toString().padLeft(2,'0')} ${_fullMonths[d.month-1]} ${d.year}';
String _fmtMonthYear(DateTime d) => '${_fullMonths[d.month-1]} ${d.year}';
String _fmtHyphenDate(DateTime d) {
  const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day.toString().padLeft(2,'0')}-${m[d.month-1]}-${d.year}';
}

// ── PDF donation contribution statement (multiple donations, one donor) ──
// Donor Profile → Donations → "Download All": a single statement covering
// every completed donation on record for this donor, matching SKET's
// standard "Donation Contribution Statement" format.
Future<Uint8List> buildDonationStatementPdf({
  required Map<String, dynamic> donor,
  required List<Map<String, dynamic>> donations,
  Map<String, dynamic>? org,
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
  final pdfBorder = PdfColor.fromInt(0xFFE5E7EB);

  final orgName    = _org(org, 'name');
  final orgAddress = _org(org, 'address');
  final orgPan     = _org(org, 'pan');
  final org12A     = _org(org, 'reg12A');
  final org80G     = _org(org, 'cert80G');
  final orgEmail   = _org(org, 'email');

  DateTime? parseDate(Map<String, dynamic> d) {
    final raw = d['createdAt'] as String? ?? d['date'] as String?;
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  final sorted = [...donations]..sort((a, b) {
    final da = parseDate(a); final db = parseDate(b);
    if (da == null || db == null) return 0;
    return da.compareTo(db);
  });

  final totalAmount = sorted.fold<int>(0, (sum, d) => sum + ((d['amount'] as num?)?.toInt() ?? 0));
  final firstDate = sorted.isNotEmpty ? parseDate(sorted.first) : null;
  final lastDate  = sorted.isNotEmpty ? parseDate(sorted.last)  : null;
  final now = DateTime.now();

  final donorName   = donor['name'] as String? ?? 'Donor';
  final donorCode   = donor['donorCode'] as String? ?? '—';
  final latest      = sorted.isNotEmpty ? sorted.last : const <String, dynamic>{};
  final receiptRef  = latest['receiptNo'] as String? ?? '—';
  final paymentMode = (latest['paymentMode'] as String? ?? latest['paymentMethod'] as String? ?? '—').replaceAll('_', ' ');
  final gatewayRef  = (latest['reference'] as String?)?.trim().isNotEmpty == true ? (latest['reference'] as String).trim() : '—';
  final statementNo = 'SKET/DCS/${now.year}/${(donorCode.hashCode.abs() % 999999).toString().padLeft(6, '0')}';

  // Label | Value cells sit side by side (not stacked) — label bold+small,
  // value bold+regular — matching the reference statement's horizontal grid.
  pw.Widget detailLabel(String label, {required bool shaded}) => pw.Container(
    color: shaded ? bgStripe : white,
    padding: const pw.EdgeInsets.fromLTRB(10, 8, 4, 8),
    child: pw.Text(label, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: dark)),
  );
  pw.Widget detailValue(String value, {required bool shaded}) => pw.Container(
    color: shaded ? bgStripe : white,
    padding: const pw.EdgeInsets.fromLTRB(4, 8, 10, 8),
    child: pw.Text(value, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark)),
  );

  pw.TableRow detailRow(String l1, String v1, String l2, String v2, {required bool shaded}) => pw.TableRow(children: [
    detailLabel(l1, shaded: shaded),
    detailValue(v1, shaded: shaded),
    detailLabel(l2, shaded: shaded),
    detailValue(v2, shaded: shaded),
  ]);

  pw.TableRow itemRow(int i, Map<String, dynamic> d) {
    final typeMap = d['type'] as Map<String, dynamic>?;
    final purpose = typeMap?['label'] as String? ?? d['donationType'] as String? ?? 'Donation';
    final receipt = d['receiptNo'] as String? ?? '—';
    final dt = parseDate(d);
    return pw.TableRow(
      decoration: pw.BoxDecoration(color: i.isOdd ? bgLight : white),
      children: [
        _td(dt != null ? _fmtHyphenDate(dt) : '—', dark, size: 8.5),
        _td(receipt, dark, size: 8.5),
        _td(purpose, dark, size: 8.5),
        _td(dt != null ? _fullMonths[dt.month - 1] : '—', dark, size: 8.5),
        _td('1 Month', dark, size: 8.5),
        _td(_fmt((d['amount'] as num?)?.toInt() ?? 0), dark, bold: true, align: pw.TextAlign.right, size: 8.5),
      ],
    );
  }

  pw.Widget summaryRow(String label, String value, {bool bold = false, PdfColor? valueColor, double size = 9.5}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 4),
    child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(label, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: dark)),
      pw.Text(value, style: pw.TextStyle(fontSize: bold ? size + 1 : size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: valueColor ?? dark)),
    ]),
  );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
    build: (ctx) => [pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Header: logo + org name lockup (left) | big title (right)
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Image(logo, height: 42),
          pw.SizedBox(height: 6),
          pw.Text(orgName, style: pw.TextStyle(fontSize: 10, color: dark)),
          pw.Text('(Registered Charitable Trust)', style: pw.TextStyle(fontSize: 8.5, color: grey)),
        ]),
        pw.Expanded(child: pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Text('DONATION CONTRIBUTION\nSTATEMENT', textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: 19, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 0.2)),
        )),
      ]),
      pw.SizedBox(height: 14),

      if (orgAddress.isNotEmpty)
        pw.Container(
          width: double.infinity,
          color: orange,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: pw.Text(orgAddress, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: white)),
        ),
      pw.SizedBox(height: 16),

      // ── STATEMENT DETAILS ──────────────────────────────────────────
      pw.Container(
        width: double.infinity, color: orange,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: pw.Text('STATEMENT DETAILS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: white, letterSpacing: 0.3)),
      ),
      pw.Table(columnWidths: const {
        0: pw.FlexColumnWidth(1.3),
        1: pw.FlexColumnWidth(2.0),
        2: pw.FlexColumnWidth(1.3),
        3: pw.FlexColumnWidth(2.0),
      }, children: [
        detailRow('Statement No.', statementNo, 'Donor ID', donorCode, shaded: false),
        detailRow('Receipt Reference', receiptRef, 'Donor Name', donorName, shaded: true),
        detailRow('Statement Duration',
            firstDate != null && lastDate != null ? '${_fmtFullDate(firstDate)} - ${_fmtFullDate(lastDate)}' : '—',
            'Generated On', _fmtFullDate(now), shaded: false),
        detailRow('Payment Mode', paymentMode, 'Gateway Reference', gatewayRef, shaded: true),
      ]),
      pw.SizedBox(height: 16),

      // ── DONATION CONTRIBUTION DETAILS ──────────────────────────────
      pw.Container(
        width: double.infinity, color: orange,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: pw.Text('DONATION CONTRIBUTION DETAILS', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: white, letterSpacing: 0.3)),
      ),
      pw.Table(
        columnWidths: const {
          0: pw.FlexColumnWidth(1.3),
          1: pw.FlexColumnWidth(1.6),
          2: pw.FlexColumnWidth(1.8),
          3: pw.FlexColumnWidth(1.2),
          4: pw.FlexColumnWidth(1.0),
          5: pw.FlexColumnWidth(1.3),
        },
        children: [
          pw.TableRow(decoration: pw.BoxDecoration(color: bgStripe), children: [
            _thGray('Date', dark),
            _thGray('Receipt No.', dark),
            _thGray('Purpose', dark),
            _thGray('Duration', dark),
            _thGray('Units', dark),
            _thGray('Amount (Rs.)', dark, align: pw.TextAlign.right),
          ]),
          ...sorted.asMap().entries.map((e) => itemRow(e.key, e.value)),
        ],
      ),
      pw.SizedBox(height: 16),

      // ── CONTRIBUTION SUMMARY ───────────────────────────────────────
      pw.Container(
        width: double.infinity, color: orange,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: pw.Text('CONTRIBUTION SUMMARY', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: white, letterSpacing: 0.3)),
      ),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: pw.Column(children: [
          summaryRow('Statement Duration', firstDate != null && lastDate != null ? '${_fmtMonthYear(firstDate)} – ${_fmtMonthYear(lastDate)}' : '—'),
          summaryRow('Total Donations', '${sorted.length}'),
          summaryRow('Total Units', '${sorted.length} Month${sorted.length == 1 ? '' : 's'}'),
          summaryRow('Subtotal', 'Rs. ${_fmt(totalAmount)}.00'),
          summaryRow('Tax (0%)', 'Rs. 0.00'),
          pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4), child: pw.Container(height: 1, color: pdfBorder)),
          summaryRow('Grand Total', 'Rs. ${_fmt(totalAmount)}.00', bold: true, valueColor: orange),
        ]),
      ),
      pw.SizedBox(height: 6),

      pw.Text('AMOUNT IN WORDS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 0.3)),
      pw.SizedBox(height: 5),
      pw.Text(_amountInWords(totalAmount), style: pw.TextStyle(fontSize: 12.5, fontStyle: pw.FontStyle.italic, color: orange)),
      pw.SizedBox(height: 20),

      pw.Center(child: pw.Text('Thank You Message', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark))),
      pw.SizedBox(height: 6),
      pw.Center(child: pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 24),
        child: pw.Text(
          'Thank you for your generous contribution to $orgName. Your support enables us to provide '
          'education, shelter, nutrition, healthcare, and holistic development for underprivileged children.',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 9, color: grey, lineSpacing: 1.4),
        ),
      )),
      pw.SizedBox(height: 20),

      // Statutory footer bar (PAN / 12AA / 80G) + disclaimer
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(color: bgLight, border: pw.Border(left: pw.BorderSide(color: orange, width: 3))),
        padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('STATUTORY REGISTRATION DETAILS (TAX BENEFITS)',
              style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: orange, letterSpacing: 0.3)),
          pw.SizedBox(height: 5),
          pw.Text('Trust PAN: $orgPan | 12AA Registration: $org12A | 80G Certification: $org80G',
              style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: dark)),
          pw.SizedBox(height: 5),
          pw.Text(
            'This is an electronically generated statement. No physical signature is required.'
            '${orgEmail.isNotEmpty ? ' For verification or support, write to $orgEmail.' : ''}',
            style: pw.TextStyle(fontSize: 7.5, color: grey)),
        ]),
      ),
    ])],
  ));
  return doc.save();
}

pw.Widget _th(String label, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(label, textAlign: align,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFFFFFFFF), letterSpacing: 0.3)),
    );

// Light-gray column-header cell (as opposed to _th's orange/white) — used by
// the donation contribution statement's itemized table, whose header row
// sits below an orange section title bar rather than being orange itself.
pw.Widget _thGray(String label, PdfColor color, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: pw.Text(label, textAlign: align,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: color, letterSpacing: 0.2)),
    );

pw.Widget _td(String text, PdfColor color, {bool bold = false, double size = 9, pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: pw.Text(text, textAlign: align,
          style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color, lineSpacing: 1.4)),
    );

pw.Widget _totRowPdf(String label, String value, PdfColor color, {bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: bold ? 12 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        pw.SizedBox(width: 24),
        pw.SizedBox(width: 84, child: pw.Text(value, textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: bold ? 12 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color))),
      ]));

// ── Receipt Bottom Sheet ──────────────────────────────────────────────────────

Future<void> showReceiptSheet(BuildContext context, DonationReceipt receipt, {Map<String, dynamic>? org}) async {
  // Fetch org settings once up front if the caller didn't already have them,
  // so the sheet (and any PDF download from it) render with real org data.
  final orgData = org ?? await fetchOrgSettings();
  if (!context.mounted) return;
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ReceiptSheet(receipt: receipt, org: orgData),
  );
}

class _ReceiptSheet extends StatelessWidget {
  const _ReceiptSheet({required this.receipt, this.org});
  final DonationReceipt receipt;
  final Map<String, dynamic>? org;

  @override
  Widget build(BuildContext context) {
    final amtStr = '₹${_fmt(receipt.amount)}.00';
    final orgAddress = _org(org, 'address');
    final orgPan     = _org(org, 'pan');
    final org12A     = _org(org, 'reg12A');
    final org80G     = _org(org, 'cert80G');
    final orgEmail   = _org(org, 'email');
    final locationLine = [receipt.donorCity, receipt.donorState, receipt.donorCountry]
        .where((s) => s.trim().isNotEmpty).join(', ');

    return DraggableScrollableSheet(
      initialChildSize: 0.94,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          Expanded(child: SingleChildScrollView(
            controller: sc,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

              // ── HEADER: logo (wordmark baked into the asset) ──────────
              Image.asset('assets/images/sket-logo.png',
                  height: 40, fit: BoxFit.contain, alignment: Alignment.centerLeft),
              const SizedBox(height: 14),

              // ── Full-width orange address bar ─────────────────────────
              if (orgAddress.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(4)),
                  child: Text(orgAddress,
                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              const SizedBox(height: 18),

              // ── RECIPIENT (left) | Receipt info (right) ───────────────
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 6, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('RECIPIENT:',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _dark, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Text(receipt.donorName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: _dark)),
                  const SizedBox(height: 5),
                  if (receipt.donorPhone.isNotEmpty)
                    Text(receipt.donorPhone, style: const TextStyle(fontSize: 11.5, color: _grey)),
                  if (locationLine.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(locationLine, style: const TextStyle(fontSize: 11.5, color: _grey)),
                  ],
                  if (receipt.donorPan.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('PAN: ${receipt.donorPan}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _orange)),
                  ],
                ])),
                const SizedBox(width: 14),
                Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: const BoxDecoration(
                      color: _orange,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                    child: Text('Receipt for #${receipt.receiptNo}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: const BoxDecoration(
                      color: _bgLight,
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(6)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Transaction Date: ${receipt.date}', style: const TextStyle(fontSize: 10.5, color: _dark)),
                      const SizedBox(height: 3),
                      Text('Mode: ${receipt.paymentMode}', style: const TextStyle(fontSize: 10.5, color: _dark)),
                      if (receipt.reference.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text('Gateway Ref: ${receipt.reference}', style: const TextStyle(fontSize: 10.5, color: _dark)),
                      ],
                    ]),
                  ),
                ])),
              ]),
              const SizedBox(height: 20),

              // ── Itemized donation table ────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(4)),
                child: Row(children: const [
                  Expanded(flex: 3, child: Text('DONATION / SERVICE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))),
                  Expanded(flex: 4, child: Text('DESCRIPTION', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))),
                  Expanded(flex: 1, child: Text('UNIT', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))),
                  Expanded(flex: 2, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white))),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: Text(receipt.donationType,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _dark))),
                  Expanded(flex: 4, child: Text(
                      receipt.notes.trim().isNotEmpty
                        ? receipt.notes.trim()
                        : 'Contribution allocated towards trust operational support, community educational aid, and welfare programs.'
                          '${receipt.taxExemption ? ' Clean tax exemption applicable.' : ''}',
                      style: const TextStyle(fontSize: 10, color: _grey, height: 1.4))),
                  const Expanded(flex: 1, child: Text('1', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: _dark))),
                  Expanded(flex: 2, child: Text(amtStr, textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _dark))),
                ]),
              ),
              const SizedBox(height: 8),
              Container(height: 1.4, color: _dark),
              const SizedBox(height: 18),

              const Center(child: Text('Receipt for Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _dark))),
              const SizedBox(height: 16),

              // ── Amount in words (left) | Subtotal / Tax / Total (right) ──
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 6, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('RECEIPT FOR PAYMENT (AMOUNT IN WORDS)',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _dark, letterSpacing: 0.3)),
                  const SizedBox(height: 6),
                  Text(_amountInWords(receipt.amount),
                      style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, color: _orange)),
                ])),
                const SizedBox(width: 12),
                Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  _totRow('Subtotal', amtStr),
                  _totRow('Tax (0%)', '₹0.00'),
                  _totRow('Total', amtStr, bold: true, large: true, color: _dark),
                ])),
              ]),
              const SizedBox(height: 18),
              Container(height: 1, color: _border),
              const SizedBox(height: 16),

              const Center(child: Text('Thanks for your support!',
                  style: TextStyle(fontSize: 15, fontStyle: FontStyle.italic, fontWeight: FontWeight.w800, color: _orange))),
              const SizedBox(height: 18),

              // ── STATUTORY FOOTER BAR ─────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _bgLight,
                  border: const Border(left: BorderSide(color: _orange, width: 3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('STATUTORY REGISTRATION DETAILS (TAX BENEFITS)',
                      style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _orange, letterSpacing: 0.3)),
                  const SizedBox(height: 6),
                  Text(
                      'Trust PAN: $orgPan  |  12AA Registration: $org12A  |  80G Certification: $org80G',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _dark, height: 1.4)),
                  const SizedBox(height: 6),
                  Text(
                      'This is an electronically generated receipt confirmation. No physical signature is required.'
                      '${orgEmail.isNotEmpty ? ' For verification or support, write to $orgEmail.' : ''}',
                      style: const TextStyle(fontSize: 8.5, color: _grey, height: 1.4)),
                ]),
              ),
              const SizedBox(height: 24),
            ]),
          )),

          // ── Action buttons ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            child: Row(children: [
              OutlinedButton(
                onPressed: () async {
                  try {
                    await Printing.layoutPdf(onLayout: (_) => buildReceiptPdf(receipt, org: org));
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Could not open print dialog'),
                        backgroundColor: Color(0xFFF2685E),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _orange,
                  side: const BorderSide(color: _orange),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Icon(Icons.print_outlined, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final bytes = await buildReceiptPdf(receipt, org: org);
                    final filename = 'Receipt_${receipt.receiptNo.replaceAll('/', '-')}.pdf';
                    final ok = await NativeFileSaver.saveBytes(filename, bytes, 'application/pdf');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'Receipt saved as PDF' : 'Failed to save'),
                        backgroundColor: _orange,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Could not generate PDF'),
                        backgroundColor: Color(0xFFF2685E),
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  }
                },
                icon: const Icon(Icons.download_outlined, size: 16),
                label: const Text('Download'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _orange,
                  side: const BorderSide(color: _orange),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('Done'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _totRow(String label, String value, {bool bold = false, bool large = false, Color? color}) {
    final c = color ?? (large ? _dark : _grey);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(label, style: TextStyle(
            fontSize: large ? 13 : 11, color: c,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        const SizedBox(width: 28),
        SizedBox(
          width: 84,
          child: Text(value, textAlign: TextAlign.right, style: TextStyle(
              fontSize: large ? 13 : 11, color: c,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        ),
      ]),
    );
  }
}

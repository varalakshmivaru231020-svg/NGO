import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/native_file_saver.dart';

// Receipt palette (shared by the on-screen sheet + the PDF export).
const _orange   = Color(0xFFE87722);
const _orangeLt = Color(0xFFFFF3E8);
const _grey     = Color(0xFF5A7068);
const _dark     = Color(0xFF1A2A24);
const _border   = Color(0xFFE5E7EB);

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
SAKSHAM FOUNDATION — DONATION RECEIPT
══════════════════════════════════════
Receipt No : ${r.receiptNo}
Date       : ${r.date}
Payment    : ${r.paymentMode}
──────────────────────────────────────
Donor      : ${r.donorName}
${r.donorPhone.isNotEmpty ? 'Phone      : ${r.donorPhone}\n' : ''}${r.donorCity.isNotEmpty ? 'City       : ${r.donorCity}\n' : ''}${r.donorPan.isNotEmpty ? 'PAN        : ${r.donorPan}\n' : ''}──────────────────────────────────────
Type       : ${r.donationType}
Amount     : ₹${_fmt(r.amount)}.00
──────────────────────────────────────
${_amountInWords(r.amount)}
──────────────────────────────────────
Trust PAN: AATTS6672D
12AA Reg : ITBA/EXM/S/12AA/2018-19
80G Cert : AATTS6672DF2022
${r.taxExemption ? '✓ 80G Tax Exemption Applicable\n' : ''}══════════════════════════════════════
Thanks for your support!
''';

// ── PDF receipt (branded, with logo) ──────────────────────────────────────────
// Uses "Rs." instead of the ₹ glyph because the default PDF font (Helvetica)
// can't render the rupee symbol.
Future<Uint8List> buildReceiptPdf(DonationReceipt r) async {
  final doc = pw.Document();
  final logoData = await rootBundle.load('assets/images/sket-logo.png');
  final logo = pw.MemoryImage(logoData.buffer.asUint8List());

  final orange   = PdfColor.fromInt(0xFFE87722);
  final orangeLt = PdfColor.fromInt(0xFFFFF3E8);
  final grey     = PdfColor.fromInt(0xFF5A7068);
  final dark     = PdfColor.fromInt(0xFF1A2A24);
  final brd      = PdfColor.fromInt(0xFFE5E7EB);
  final amtStr   = 'Rs. ${_fmt(r.amount)}.00';

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(34),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Header: logo + org | receipt badge
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Image(logo, height: 46),
          pw.SizedBox(height: 8),
          pw.Text('Sri Krishnashraya Educational Trust', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: dark)),
          pw.SizedBox(height: 2),
          pw.Text('# 88/1, 84/1, 84/5, Sant Baba Hardas Ram Dam,\nThammarasanahalli, Chikka Haralagere, Sulibele,\nBangalore - 562129.',
              style: pw.TextStyle(fontSize: 8.5, color: grey, lineSpacing: 2)),
        ])),
        pw.SizedBox(width: 16),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: pw.BoxDecoration(color: orange, borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Text('Receipt #${r.receiptNo}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white))),
          pw.SizedBox(height: 6),
          pw.Text('Date: ${r.date}', style: pw.TextStyle(fontSize: 9, color: grey)),
          pw.Text('Payment: ${r.paymentMode}', style: pw.TextStyle(fontSize: 9, color: grey)),
        ]),
      ]),
      pw.SizedBox(height: 16),
      pw.Divider(color: brd, thickness: 1),
      pw.SizedBox(height: 10),
      // Donor
      pw.Text('DONOR', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: grey)),
      pw.SizedBox(height: 3),
      pw.Text(r.donorName, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: orange)),
      if (r.donorCity.isNotEmpty) pw.Text(r.donorCity, style: pw.TextStyle(fontSize: 10, color: grey)),
      if (r.donorPhone.isNotEmpty) pw.Text(r.donorPhone, style: pw.TextStyle(fontSize: 10, color: grey)),
      if (r.donorPan.isNotEmpty) pw.Text('PAN: ${r.donorPan}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: orange)),
      pw.SizedBox(height: 16),
      // Line-item table
      pw.Table(border: pw.TableBorder.all(color: brd, width: 0.5), columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(1)}, children: [
        pw.TableRow(decoration: pw.BoxDecoration(color: orange), children: [
          _pdfCell('DESCRIPTION', bold: true, color: PdfColors.white),
          _pdfCell('AMOUNT', bold: true, color: PdfColors.white, align: pw.TextAlign.right),
        ]),
        pw.TableRow(children: [
          _pdfCell('${r.donationType}\nContribution towards trust operational support, community educational aid, and welfare programs.', color: dark),
          _pdfCell(amtStr, color: dark, align: pw.TextAlign.right),
        ]),
      ]),
      pw.SizedBox(height: 14),
      // Totals
      pw.Align(alignment: pw.Alignment.centerRight, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
        _totRowPdf('Subtotal', amtStr, grey),
        _totRowPdf('Tax (0%)', 'Rs. 0.00', grey),
        pw.SizedBox(height: 4),
        _totRowPdf('Total', amtStr, dark, bold: true),
      ])),
      pw.SizedBox(height: 14),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: pw.BoxDecoration(color: orangeLt, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Text(_amountInWords(r.amount), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: orange))),
      pw.SizedBox(height: 14),
      pw.Text('Thanks for your support!', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: dark)),
      pw.SizedBox(height: 12),
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: orangeLt, borderRadius: pw.BorderRadius.circular(6)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('STATUTORY REGISTRATION DETAILS (TAX BENEFITS)', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: orange)),
          pw.SizedBox(height: 6),
          pw.Text('Trust PAN: AATTS6672D   |   12AA Registration: ITBA/EXM/S/12AA/2018-19/A/10252   |   80G Certification: ATTS6672DF20221',
              style: pw.TextStyle(fontSize: 9, color: grey)),
          if (r.taxExemption) ...[
            pw.SizedBox(height: 4),
            pw.Text('80G Tax Exemption Applicable', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: orange)),
          ],
          pw.SizedBox(height: 4),
          pw.Text('This is an electronically generated receipt. No physical signature is required.', style: pw.TextStyle(fontSize: 8.5, color: grey)),
        ])),
    ]),
  ));
  return doc.save();
}

pw.Widget _pdfCell(String text, {bool bold = false, PdfColor? color, pw.TextAlign align = pw.TextAlign.left}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: pw.Text(text, textAlign: align,
          style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)));

pw.Widget _totRowPdf(String label, String value, PdfColor color, {bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: bold ? 12 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        pw.SizedBox(width: 30),
        pw.SizedBox(width: 90, child: pw.Text(value, textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: bold ? 12 : 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color))),
      ]));

// ── Receipt Bottom Sheet ──────────────────────────────────────────────────────

Future<void> showReceiptSheet(BuildContext context, DonationReceipt receipt) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _ReceiptSheet(receipt: receipt),
  );
}

class _ReceiptSheet extends StatelessWidget {
  const _ReceiptSheet({required this.receipt});
  final DonationReceipt receipt;

  @override
  Widget build(BuildContext context) {
    final amtStr = '₹${_fmt(receipt.amount)}.00';

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

              // ── TOP: Logo left | Receipt box right ─────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Logo block
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Foundation logo
                  Image.asset('assets/images/sket-logo.png',
                      height: 50, fit: BoxFit.contain, alignment: Alignment.centerLeft),
                  const SizedBox(height: 8),
                  const Text('Sri Krishnashraya Educational Trust',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _dark)),
                  const SizedBox(height: 2),
                  const Text('# 88/1, 84/1, 84/5, Sant Baba Hardas Ram Dam,\nThammarasanahalli, Chikka Haralagere,\nSulibele, Bangalore – 562129.',
                      style: TextStyle(fontSize: 9.5, color: _grey, height: 1.5)),
                ])),
                const SizedBox(width: 16),
                // Receipt badge
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(8)),
                    child: Text('Receipt for #${receipt.receiptNo}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                  const SizedBox(height: 6),
                  Text('Transaction Date: ${receipt.date}',
                      style: const TextStyle(fontSize: 10, color: _grey, fontWeight: FontWeight.w500)),
                ]),
              ]),

              const SizedBox(height: 20),
              Divider(color: _border, thickness: 1),
              const SizedBox(height: 14),

              // ── RECIPIENT ───────────────────────────────────────────
              const Text('RECIPIENT:',
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.8)),
              const SizedBox(height: 4),
              Text(receipt.donorName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _orange)),
              if (receipt.donorCity.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(receipt.donorCity,
                    style: const TextStyle(fontSize: 12, color: _grey)),
              ],
              if (receipt.donorPhone.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(receipt.donorPhone,
                    style: const TextStyle(fontSize: 12, color: _grey)),
              ],
              if (receipt.donorPan.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('PAN: ${receipt.donorPan}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _orange)),
              ],

              const SizedBox(height: 20),

              // ── TABLE ───────────────────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(8),
                ),
                clipBehavior: Clip.hardEdge,
                child: Column(children: [
                  // Header row
                  Container(
                    color: _orange,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(children: const [
                      Expanded(flex: 5, child: Text('PRODUCT / SERVICE',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5))),
                      Expanded(flex: 7, child: Text('DESCRIPTION',
                          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5))),
                      SizedBox(width: 8),
                      Text('QTY', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                      SizedBox(width: 16),
                      Text('COST', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                      SizedBox(width: 12),
                      Text('TOTAL', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: Colors.white)),
                    ]),
                  ),
                  // Data row
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(flex: 5, child: Text(receipt.donationType,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _dark))),
                      Expanded(flex: 7, child: Text(
                          'Contribution allocated towards trust operational support, community educational aid, and welfare programs. Clean tax exemption applicable.',
                          style: const TextStyle(fontSize: 10, color: _grey, height: 1.4))),
                      const SizedBox(width: 8),
                      const Text('1', style: TextStyle(fontSize: 12, color: _grey)),
                      const SizedBox(width: 10),
                      Text(_fmt(receipt.amount),
                          style: const TextStyle(fontSize: 12, color: _dark, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text('₹${_fmt(receipt.amount)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _dark)),
                    ]),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // ── TOTALS (right-aligned) ──────────────────────────────
              const Align(
                alignment: Alignment.centerRight,
                child: Text('Receipt for Payment',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _dark)),
              ),
              const SizedBox(height: 8),
              _totRow('Subtotal', amtStr),
              _totRow('Tax (0%)', '₹0.00'),
              const Divider(thickness: 1, color: _border),
              _totRow('Total', amtStr, bold: true, large: true),

              const SizedBox(height: 16),

              // ── Amount in words ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: _orangeLt, borderRadius: BorderRadius.circular(8)),
                child: Text(_amountInWords(receipt.amount),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _orange)),
              ),

              const SizedBox(height: 16),
              const Text('Thanks for your support!',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _dark)),
              const SizedBox(height: 14),

              // ── STATUTORY DETAILS ───────────────────────────────────
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: const Border(left: BorderSide(color: _orange, width: 3)),
                  color: _orangeLt,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(6), bottomRight: Radius.circular(6)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('STATUTORY REGISTRATION DETAILS (TAX BENEFITS)',
                      style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: _orange, letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  const Text('• Trust PAN: AATTS6672D  |  • 12AA Registration: ITBA/EXM/S/12AA/2018-19/A/10252  |  • 80G Certification: ATTS6672DF20221',
                      style: TextStyle(fontSize: 9, color: _grey, height: 1.5)),
                  const SizedBox(height: 4),
                  Text('• Payment Mode / Gateway Reference: ${receipt.paymentMode}',
                      style: const TextStyle(fontSize: 9, color: _grey)),
                  const SizedBox(height: 6),
                  const Text('This is an electronically generated receipt confirmation. No physical signature is required. For verification or support, write to krishnashryahome@gmail.com.',
                      style: TextStyle(fontSize: 8.5, color: _grey, height: 1.4)),
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
              Expanded(child: OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final bytes = await buildReceiptPdf(receipt);
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

  Widget _totRow(String label, String value, {bool bold = false, bool large = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
        Text(label, style: TextStyle(
            fontSize: large ? 14 : 12, color: large ? _dark : _grey,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        const SizedBox(width: 40),
        SizedBox(
          width: 100,
          child: Text(value, textAlign: TextAlign.right, style: TextStyle(
              fontSize: large ? 14 : 12, color: large ? _dark : _grey,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        ),
      ]),
    );
}

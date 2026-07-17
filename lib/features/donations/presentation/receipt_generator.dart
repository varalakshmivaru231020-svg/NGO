import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/native_file_saver.dart';

// Receipt palette (shared by the on-screen sheet + the PDF export).
const _orange   = Color(0xFFF97316);
const _orangeLt = Color(0xFFFFF1E7);
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
SRI KRISHNASHRAYA EDUCATIONAL TRUST — DONATION RECEIPT
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
12AB Reg : AATTS6672D25BL01
80G Approval : AATTS6672D25BL02
${r.taxExemption ? '✓ 80G Tax Exemption Applicable\n' : ''}══════════════════════════════════════
Thanks for your support!
''';

// ── PDF receipt (branded, with logo) ──────────────────────────────────────────
// Compact half-page layout: A5 cut from A4 (full A4 width, half A4 height),
// the way physical trust/NGO receipt books are commonly printed.
// Uses "Rs." instead of the ₹ glyph because the default PDF font (Helvetica)
// can't render the rupee symbol.
Future<Uint8List> buildReceiptPdf(DonationReceipt r) async {
  final doc = pw.Document();
  final logoData = await rootBundle.load('assets/images/sket-logo.png');
  final logo = pw.MemoryImage(logoData.buffer.asUint8List());

  final orange   = PdfColor.fromInt(0xFFF97316);
  final orangeLt = PdfColor.fromInt(0xFFFFF1E7);
  final grey     = PdfColor.fromInt(0xFF6B7280);
  final dark     = PdfColor.fromInt(0xFF1F2937);
  final brd      = PdfColor.fromInt(0xFFE5E7EB);
  final bgLight  = PdfColor.fromInt(0xFFF8FAFC);
  final amtStr   = 'Rs. ${_fmt(r.amount)}.00';

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5.landscape,
    margin: const pw.EdgeInsets.fromLTRB(22, 18, 22, 16),
    build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Header: logo + org (left) | receipt no + date + mode (right)
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Image(logo, height: 32),
        pw.SizedBox(width: 10),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('Sri Krishnashraya Educational Trust', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: dark)),
          pw.SizedBox(height: 1),
          pw.Text('# 88/1, 84/1, 84/5, Thammarasanahalli, Sulibele, Bangalore - 562129',
              style: pw.TextStyle(fontSize: 7.5, color: grey)),
        ])),
        pw.SizedBox(width: 12),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('Receipt No: ${r.receiptNo}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: orange)),
          pw.SizedBox(height: 2),
          pw.Text('Date: ${r.date}', style: pw.TextStyle(fontSize: 8.5, color: grey)),
          pw.Text('Payment: ${r.paymentMode}', style: pw.TextStyle(fontSize: 8.5, color: grey)),
        ]),
      ]),
      pw.SizedBox(height: 8),
      pw.Divider(color: brd, thickness: 1),
      pw.SizedBox(height: 8),

      // Donor Details | Donation Details, side by side
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Expanded(flex: 4, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('DONOR DETAILS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: orange, letterSpacing: 0.5)),
          pw.SizedBox(height: 4),
          pw.Text(r.donorName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: dark)),
          if (r.donorPhone.isNotEmpty) pw.Text('Mobile: ${r.donorPhone}', style: pw.TextStyle(fontSize: 9, color: grey)),
          if (r.donorCity.isNotEmpty) pw.Text(r.donorCity, style: pw.TextStyle(fontSize: 9, color: grey)),
          if (r.donorPan.isNotEmpty) pw.Text('PAN: ${r.donorPan}', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: orange)),
        ])),
        pw.Container(width: 1, margin: const pw.EdgeInsets.symmetric(horizontal: 7.5), color: brd),
        pw.Expanded(flex: 5, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text('DONATION DETAILS', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: orange, letterSpacing: 0.5)),
          pw.SizedBox(height: 4),
          pw.Text(r.donationType, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: dark)),
          pw.Text('Amount: $amtStr    Qty: 1', style: pw.TextStyle(fontSize: 9, color: grey)),
          pw.SizedBox(height: 2),
          pw.Text('Contribution towards trust operational support, community educational aid, and welfare programs.',
              style: pw.TextStyle(fontSize: 8, color: grey, lineSpacing: 1.5)),
        ])),
      ]),
      pw.SizedBox(height: 10),
      pw.Divider(color: brd, thickness: 1),
      pw.SizedBox(height: 8),

      // Amount in words (left) | Subtotal / Tax / Grand Total box (right)
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: pw.BoxDecoration(color: orangeLt, borderRadius: pw.BorderRadius.circular(5)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('AMOUNT IN WORDS', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: orange, letterSpacing: 0.5)),
            pw.SizedBox(height: 2),
            pw.Text(_amountInWords(r.amount), style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: dark)),
          ]),
        )),
        pw.SizedBox(width: 14),
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: brd), borderRadius: pw.BorderRadius.circular(5)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            _totRowPdf('Subtotal', amtStr, grey),
            _totRowPdf('Tax (0%)', 'Rs. 0.00', grey),
            pw.Container(margin: const pw.EdgeInsets.symmetric(vertical: 3), width: 140, height: 1, color: brd),
            _totRowPdf('Grand Total', amtStr, orange, bold: true),
          ]),
        ),
      ]),
      pw.SizedBox(height: 10),

      // Statutory footer bar (PAN / 12AB / 80G) + disclaimer
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: pw.BoxDecoration(color: bgLight, borderRadius: pw.BorderRadius.circular(5), border: pw.Border.all(color: brd, width: 0.5)),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(
            'PAN: AATTS6672D   |   12AB: AATTS6672D25BL01   |   80G: AATTS6672D25BL02'
            '${r.taxExemption ? '   |   Eligible for 80G Tax Exemption' : ''}',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: dark)),
          pw.SizedBox(height: 3),
          pw.Text('Electronically generated receipt — no signature required. Thanks for your support!',
              style: pw.TextStyle(fontSize: 7, color: grey)),
        ]),
      ),
    ]),
  ));
  return doc.save();
}

pw.Widget _totRowPdf(String label, String value, PdfColor color, {bool bold = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
        pw.Text(label, style: pw.TextStyle(fontSize: bold ? 11 : 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color)),
        pw.SizedBox(width: 24),
        pw.SizedBox(width: 80, child: pw.Text(value, textAlign: pw.TextAlign.right,
            style: pw.TextStyle(fontSize: bold ? 11 : 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: color))),
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

              // ── HEADER: logo + org (left) | receipt no / date / mode (right) ──
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Image.asset('assets/images/sket-logo.png',
                    height: 34, fit: BoxFit.contain, alignment: Alignment.centerLeft),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Sri Krishnashraya Educational Trust',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _dark)),
                  const SizedBox(height: 2),
                  const Text('# 88/1, 84/1, 84/5, Thammarasanahalli, Sulibele, Bangalore – 562129',
                      style: TextStyle(fontSize: 9, color: _grey)),
                ])),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('Receipt No: ${receipt.receiptNo}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _orange)),
                  const SizedBox(height: 3),
                  Text('Date: ${receipt.date}',
                      style: const TextStyle(fontSize: 10, color: _grey, fontWeight: FontWeight.w500)),
                  Text('Payment: ${receipt.paymentMode}',
                      style: const TextStyle(fontSize: 10, color: _grey, fontWeight: FontWeight.w500)),
                ]),
              ]),

              const SizedBox(height: 14),
              Divider(color: _border, thickness: 1),
              const SizedBox(height: 12),

              // ── DONOR DETAILS | DONATION DETAILS ────────────────────
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(flex: 4, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('DONOR DETAILS',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _orange, letterSpacing: 0.6)),
                  const SizedBox(height: 5),
                  Text(receipt.donorName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _dark)),
                  if (receipt.donorPhone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text('Mobile: ${receipt.donorPhone}', style: const TextStyle(fontSize: 11, color: _grey)),
                  ],
                  if (receipt.donorCity.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(receipt.donorCity, style: const TextStyle(fontSize: 11, color: _grey)),
                  ],
                  if (receipt.donorPan.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('PAN: ${receipt.donorPan}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _orange)),
                  ],
                ])),
                const SizedBox(width: 14),
                Container(width: 1, color: _border, margin: const EdgeInsets.only(top: 2)),
                const SizedBox(width: 14),
                Expanded(flex: 5, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('DONATION DETAILS',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _orange, letterSpacing: 0.6)),
                  const SizedBox(height: 5),
                  Text(receipt.donationType,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _dark)),
                  const SizedBox(height: 2),
                  Text('Amount: $amtStr   ·   Qty: 1',
                      style: const TextStyle(fontSize: 11, color: _grey)),
                  const SizedBox(height: 4),
                  const Text(
                      'Contribution towards trust operational support, community educational aid, and welfare programs.',
                      style: TextStyle(fontSize: 10, color: _grey, height: 1.4)),
                ])),
              ]),

              const SizedBox(height: 16),
              Divider(color: _border, thickness: 1),
              const SizedBox(height: 12),

              // ── Amount in words (left) | Subtotal / Tax / Grand Total (right) ──
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(color: _orangeLt, borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('AMOUNT IN WORDS',
                        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: _orange, letterSpacing: 0.6)),
                    const SizedBox(height: 3),
                    Text(_amountInWords(receipt.amount),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _dark)),
                  ]),
                )),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: _border), borderRadius: BorderRadius.circular(8)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _totRow('Subtotal', amtStr),
                    _totRow('Tax (0%)', '₹0.00'),
                    const Divider(thickness: 1, color: _border, height: 12),
                    _totRow('Grand Total', amtStr, bold: true, large: true, color: _orange),
                  ]),
                ),
              ]),

              const SizedBox(height: 14),

              // ── STATUTORY FOOTER BAR ─────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _bgLight,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                      'PAN: AATTS6672D  |  12AB: AATTS6672D25BL01  |  80G: AATTS6672D25BL02'
                      '${receipt.taxExemption ? '  |  Eligible for 80G Tax Exemption' : ''}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: _dark, height: 1.4)),
                  const SizedBox(height: 5),
                  const Text(
                      'Electronically generated receipt — no signature required. Thanks for your support! '
                      'For verification or support, write to krishnashryahome@gmail.com.',
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

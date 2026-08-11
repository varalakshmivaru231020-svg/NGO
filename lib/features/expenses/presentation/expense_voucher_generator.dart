import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../../core/utils/native_file_saver.dart';

// Voucher palette — mirrors the physical SKET payment voucher form: mostly
// black/white with a small orange accent for the amount, not the orange-heavy
// donation-receipt scheme.
const _dark   = Color(0xFF1F2937);
const _grey   = Color(0xFF6B7280);
const _border = Color(0xFF1F2937);
const _accent = Color(0xFFF97316);

class ExpenseVoucher {
  const ExpenseVoucher({
    required this.voucherNo,
    required this.paidTo,
    required this.purpose,
    required this.categoryLabel,
    required this.amount,
    required this.paymentMode,
    required this.date,
    this.reference = '',
    this.preparedBy = '',
    this.approvedBy = '',
    this.receivedBy = '',
    this.notes = '',
  });

  final String voucherNo;
  final String paidTo;
  final String purpose;
  final String categoryLabel;
  final int amount;
  final String paymentMode;
  final String date;
  final String reference;
  final String preparedBy;
  final String approvedBy;
  final String receivedBy;
  final String notes;
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

const _modeLabels = {
  'CASH': 'Cash', 'UPI': 'UPI', 'BANK_TRANSFER': 'Bank Transfer', 'CHEQUE': 'Cheque', 'CARD': 'Card',
};

const _orgAddress = 'No. 50, 2nd cross, Ripco Shanthinikethan layout, near SJES College, Medahalli, '
    // ASCII only: the built-in Helvetica has no Unicode support, so an en dash
    // is dropped from the PDF and prints as a gap.
    'Virgo Nagar Post, Bangalore - 560049. Mob: 9986064411, 9620794141. '
    'Email: aakrishnashraya@gmail.com Website: www.krishnashraya.in';

const _statutoryLine = 'Trust PAN: AATTS6672D  |  12AA Registration: AATTS6672D25BL01  |  80G Certification: AATTS6672D25BL02';

// ── PDF voucher — mirrors the physical SKET "Payment Voucher" form: centered
// title/org header, Voucher No./Date row, inline Paid To, a two-column body
// (Being paid towards + Rupees on the left, a boxed amount on the right), and
// a plain Prepared/Approved/Received-by footer. Half-page A5-landscape, same
// convention as the donation receipt.
Future<Uint8List> buildVoucherPdf(ExpenseVoucher v) async {
  final doc = pw.Document();

  final dark   = PdfColor.fromInt(0xFF1F2937);
  final grey   = PdfColor.fromInt(0xFF6B7280);
  final brd    = PdfColor.fromInt(0xFF1F2937);
  final accent = PdfColor.fromInt(0xFFF97316);
  final amtStr = 'Rs. ${_fmt(v.amount)}.00';
  final modeLabel = _modeLabels[v.paymentMode] ?? v.paymentMode;

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.a5.landscape,
    margin: const pw.EdgeInsets.all(16),
    build: (ctx) => pw.Container(
      decoration: pw.BoxDecoration(border: pw.Border.all(color: brd, width: 1.2)),
      // min so the outline wraps the content instead of stretching to the
      // page bottom and printing as a huge empty box.
      child: pw.Column(mainAxisSize: pw.MainAxisSize.min, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        // Header: centered title + org details
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.fromLTRB(20, 14, 20, 12),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Container(
              padding: const pw.EdgeInsets.only(bottom: 2),
              decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: dark, width: 1.4))),
              child: pw.Text('PAYMENT VOUCHER', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, letterSpacing: 1.5)),
            ),
            pw.SizedBox(height: 8),
            pw.Text('SRI KRISHNASHRAYA EDUCATIONAL TRUST',
                textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 5),
            pw.Container(
              width: 420,
              child: pw.Text(_orgAddress, textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(fontSize: 8, color: grey, lineSpacing: 1.6)),
            ),
          ]),
        ),
        pw.Divider(color: brd, thickness: 1.2, height: 1),

        // Voucher No. / Date
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text('Voucher No.: ${v.voucherNo}', style: pw.TextStyle(fontSize: 9.5, color: dark)),
            pw.Text('Date: ${v.date}', style: pw.TextStyle(fontSize: 9.5, color: dark)),
          ]),
        ),

        // Paid to
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: pw.RichText(text: pw.TextSpan(children: [
            pw.TextSpan(text: 'Paid to ', style: pw.TextStyle(fontSize: 10, color: dark)),
            pw.TextSpan(text: v.paidTo, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.TextSpan(text: '  (${v.categoryLabel})', style: pw.TextStyle(fontSize: 8.5, color: grey)),
          ])),
        ),
        pw.Divider(color: brd, thickness: 1.2, height: 1),

        // Being paid towards / Rupees (left) | Amount box (right).
        // A Table (not Expanded) so the row is only as tall as its content —
        // Expanded stretched it to the page bottom as a big empty box.
        pw.Table(
          columnWidths: const {0: pw.FlexColumnWidth(7), 1: pw.FlexColumnWidth(3)},
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.full,
          children: [pw.TableRow(children: [
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(color: brd, width: 1.2))),
              child: pw.ConstrainedBox(
                constraints: const pw.BoxConstraints(minHeight: 90),
                child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Being paid towards ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark)),
                    pw.TextSpan(text: v.purpose, style: pw.TextStyle(fontSize: 10, color: dark)),
                  ])),
                  pw.SizedBox(height: 18),
                  pw.RichText(text: pw.TextSpan(children: [
                    pw.TextSpan(text: 'Rupees ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: dark)),
                    pw.TextSpan(text: _amountInWords(v.amount).replaceFirst('Rupees ', ''), style: pw.TextStyle(fontSize: 10, color: dark)),
                  ])),
                  if (v.notes.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 14),
                    pw.RichText(text: pw.TextSpan(children: [
                      pw.TextSpan(text: 'Internal Notes: ', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: grey)),
                      pw.TextSpan(text: v.notes.trim(), style: pw.TextStyle(fontSize: 9, color: grey)),
                    ])),
                  ],
                ]),
              ),
            ),
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              alignment: pw.Alignment.center,
              child: pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
                pw.Text(amtStr, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: accent)),
                pw.SizedBox(height: 2),
                pw.Text('AMOUNT', style: pw.TextStyle(fontSize: 7, color: grey, letterSpacing: 0.5)),
                pw.SizedBox(height: 10),
                pw.Text('Payment: $modeLabel', style: pw.TextStyle(fontSize: 8.5, color: grey)),
                if (v.reference.isNotEmpty) ...[
                  pw.SizedBox(height: 2),
                  pw.Text('Ref: ${v.reference}', style: pw.TextStyle(fontSize: 8.5, color: grey)),
                ],
              ]),
            ),
          ])],
        ),
        pw.Divider(color: brd, thickness: 1.2, height: 1),

        // Prepared / Approved / Received by
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(20, 14, 20, 10),
          child: pw.Row(children: [
            _signatureCol('Prepared by', v.preparedBy, dark, grey, brd),
            _signatureCol('Approved by', v.approvedBy, dark, grey, brd),
            _signatureCol('Received by', v.receivedBy, dark, grey, brd),
          ]),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(20, 0, 20, 4),
          child: pw.Container(
            width: double.infinity,
            child: pw.Text(_statutoryLine, textAlign: pw.TextAlign.center,
                style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: dark)),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: pw.Container(
            width: double.infinity,
            child: pw.Text('This is an internal payment voucher. Electronically generated - no signature required unless printed.',
                textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, color: grey)),
          ),
        ),
      ]),
    ),
  ));
  return doc.save();
}

pw.Widget _signatureCol(String label, String value, PdfColor dark, PdfColor grey, PdfColor brd) =>
  pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.only(bottom: 5),
      margin: const pw.EdgeInsets.only(bottom: 5),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: brd))),
      child: pw.Text(value.isNotEmpty ? value : ' ', textAlign: pw.TextAlign.center,
          style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: dark)),
    ),
    pw.Text(label, style: pw.TextStyle(fontSize: 8, color: grey)),
  ]));

// ── Voucher Bottom Sheet ───────────────────────────────────────────────────

Future<void> showVoucherSheet(BuildContext context, ExpenseVoucher voucher) async {
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _VoucherSheet(voucher: voucher),
  );
}

class _VoucherSheet extends StatelessWidget {
  const _VoucherSheet({required this.voucher});
  final ExpenseVoucher voucher;

  @override
  Widget build(BuildContext context) {
    final amtStr = '₹${_fmt(voucher.amount)}.00';
    final modeLabel = _modeLabels[voucher.paymentMode] ?? voucher.paymentMode;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
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
            padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(border: Border.all(color: _border, width: 1.2)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [

                // ── Centered title + org header ──────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Column(children: [
                    Container(
                      padding: const EdgeInsets.only(bottom: 3),
                      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _dark, width: 1.6))),
                      child: const Text('PAYMENT VOUCHER',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    ),
                    const SizedBox(height: 10),
                    const Text('SRI KRISHNASHRAYA EDUCATIONAL TRUST', textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    const Text(_orgAddress, textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 10, color: _grey, height: 1.5)),
                  ]),
                ),
                const Divider(height: 1, thickness: 1.2, color: _border),

                // ── Voucher No. / Date ───────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('Voucher No.: ${voucher.voucherNo}', style: const TextStyle(fontSize: 12, color: _dark, fontWeight: FontWeight.w600)),
                    Text('Date: ${voucher.date}', style: const TextStyle(fontSize: 12, color: _dark, fontWeight: FontWeight.w600)),
                  ]),
                ),

                // ── Paid to ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                  child: RichText(text: TextSpan(style: const TextStyle(fontSize: 13, color: _dark), children: [
                    const TextSpan(text: 'Paid to '),
                    TextSpan(text: voucher.paidTo, style: const TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: '  (${voucher.categoryLabel})', style: const TextStyle(fontSize: 11, color: _grey)),
                  ])),
                ),
                const Divider(height: 1, thickness: 1.2, color: _border),

                // ── Being paid towards / Rupees | Amount box ─────────
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(flex: 7, child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: _border, width: 1.2))),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      RichText(text: TextSpan(style: const TextStyle(fontSize: 13, color: _dark, height: 1.4), children: [
                        const TextSpan(text: 'Being paid towards ', style: TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: voucher.purpose),
                      ])),
                      const SizedBox(height: 20),
                      RichText(text: TextSpan(style: const TextStyle(fontSize: 13, color: _dark), children: [
                        const TextSpan(text: 'Rupees ', style: TextStyle(fontWeight: FontWeight.w800)),
                        TextSpan(text: _amountInWords(voucher.amount).replaceFirst('Rupees ', '')),
                      ])),
                      if (voucher.notes.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        RichText(text: TextSpan(style: const TextStyle(fontSize: 11.5, color: _grey), children: [
                          const TextSpan(text: 'Internal Notes: ', style: TextStyle(fontWeight: FontWeight.w800)),
                          TextSpan(text: voucher.notes.trim()),
                        ])),
                      ],
                    ]),
                  )),
                  Expanded(flex: 3, child: Container(
                    padding: const EdgeInsets.all(14),
                    alignment: Alignment.center,
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(amtStr, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _accent)),
                      const SizedBox(height: 2),
                      const Text('AMOUNT', style: TextStyle(fontSize: 9, color: _grey, letterSpacing: 0.6)),
                      const SizedBox(height: 12),
                      Text('Payment: $modeLabel', style: const TextStyle(fontSize: 11, color: _grey)),
                      if (voucher.reference.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text('Ref: ${voucher.reference}', style: const TextStyle(fontSize: 11, color: _grey)),
                      ],
                    ]),
                  )),
                ])),
                const Divider(height: 1, thickness: 1.2, color: _border),

                // ── Prepared / Approved / Received by ────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                  child: Row(children: [
                    _signatureColumn('Prepared by', voucher.preparedBy),
                    _signatureColumn('Approved by', voucher.approvedBy),
                    _signatureColumn('Received by', voucher.receivedBy),
                  ]),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 6),
                  child: Text(_statutoryLine, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _dark, height: 1.4)),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text('This is an internal payment voucher. Electronically generated — no signature required unless printed.',
                      textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, color: _grey, height: 1.4)),
                ),
              ]),
            ),
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
                    final bytes = await buildVoucherPdf(voucher);
                    final filename = 'Voucher_${voucher.voucherNo.replaceAll('/', '-')}.pdf';
                    final ok = await NativeFileSaver.saveBytes(filename, bytes, 'application/pdf');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? 'Voucher saved as PDF' : 'Failed to save'),
                        backgroundColor: _dark,
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
                  foregroundColor: _dark,
                  side: const BorderSide(color: _dark),
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
                  backgroundColor: _accent,
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

  Widget _signatureColumn(String label, String value) => Expanded(
    child: Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 6),
        margin: const EdgeInsets.only(bottom: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _dark))),
        child: Text(value.isNotEmpty ? value : ' ', textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dark)),
      ),
      Text(label, style: const TextStyle(fontSize: 10.5, color: _grey)),
    ]),
  );
}

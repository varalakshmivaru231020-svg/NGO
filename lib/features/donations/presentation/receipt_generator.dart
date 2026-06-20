import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/native_file_saver.dart';

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

  static const _teal   = Color(0xFF0B6E5D);
  static const _tealLt = Color(0xFFD6F3EC);
  static const _grey   = Color(0xFF5A7068);
  static const _dark   = Color(0xFF1A2A24);
  static const _orange = Color(0xFFE0921A);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
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
            child: Column(children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                decoration: const BoxDecoration(color: _teal),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Saksham Foundation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                    SizedBox(height: 2),
                    Text('NGO Management System', style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ]),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Receipt #${receipt.receiptNo}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _teal)),
                      Text(receipt.date, style: const TextStyle(fontSize: 9, color: _grey)),
                    ]),
                  ),
                ]),
              ),
              Container(width: double.infinity, color: _tealLt,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
                child: const Text('Bangalore, Karnataka, India', style: TextStyle(fontSize: 9, color: _teal))),

              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  // Recipient
                  const Text('RECIPIENT', style: TextStyle(fontSize: 9, color: _grey, fontWeight: FontWeight.w700, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Text(receipt.donorName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _dark)),
                  if (receipt.donorPhone.isNotEmpty) Text(receipt.donorPhone, style: const TextStyle(fontSize: 12, color: _grey)),
                  if (receipt.donorCity.isNotEmpty) Text(receipt.donorCity, style: const TextStyle(fontSize: 12, color: _grey)),
                  if (receipt.donorPan.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('PAN: ${receipt.donorPan}', style: const TextStyle(fontSize: 11, color: _teal, fontWeight: FontWeight.w700)),
                  ],

                  const SizedBox(height: 20),
                  Divider(color: Colors.grey.shade200),
                  const SizedBox(height: 12),

                  // Payment info chips
                  Row(children: [
                    _chip(Icons.payment, receipt.paymentMode),
                    const SizedBox(width: 8),
                    _chip(Icons.calendar_today_outlined, receipt.date),
                  ]),

                  const SizedBox(height: 20),

                  // Donation row
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: _tealLt, width: 1.5), borderRadius: BorderRadius.circular(12)),
                    child: Column(children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: const BoxDecoration(color: _teal, borderRadius: BorderRadius.vertical(top: Radius.circular(11))),
                        child: const Row(children: [
                          Expanded(flex: 3, child: Text('PRODUCT / SERVICE', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700))),
                          Expanded(flex: 1, child: Text('QTY', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('TOTAL', style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 3, child: Text(receipt.donationType,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _dark))),
                          const Expanded(flex: 1, child: Text('1',
                            style: TextStyle(fontSize: 13, color: _grey), textAlign: TextAlign.center)),
                          Expanded(flex: 2, child: Text('₹${_fmt(receipt.amount)}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _teal), textAlign: TextAlign.right)),
                        ]),
                      ),
                    ]),
                  ),

                  const SizedBox(height: 16),

                  // Totals
                  _totRow('Subtotal', '₹${_fmt(receipt.amount)}.00'),
                  _totRow('Tax (0%)', '₹0.00'),
                  const Divider(thickness: 1.5, color: _teal),
                  _totRow('Total', '₹${_fmt(receipt.amount)}.00', bold: true, large: true, color: _dark),

                  const SizedBox(height: 16),

                  // Amount in words
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: _tealLt, borderRadius: BorderRadius.circular(8)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('AMOUNT IN WORDS', style: TextStyle(fontSize: 8, color: _teal, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                      const SizedBox(height: 4),
                      Text(_amountInWords(receipt.amount),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _orange)),
                    ]),
                  ),

                  const SizedBox(height: 16),
                  const Center(child: Text('Thanks for your support!',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _teal))),
                  const SizedBox(height: 16),

                  // Statutory
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: const Border(left: BorderSide(color: _orange, width: 3)),
                      color: const Color(0xFFFFFBF5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('STATUTORY REGISTRATION DETAILS (TAX BENEFITS)',
                        style: TextStyle(fontSize: 8, color: _orange, fontWeight: FontWeight.w700, letterSpacing: 0.6)),
                      SizedBox(height: 5),
                      Text('• Trust PAN: AATTS6672D  |  • 12AA Reg: ITBA/EXM/S/12AA/2018-19  |  • 80G Cert: AATTS6672DF2022',
                        style: TextStyle(fontSize: 9, color: _grey)),
                      SizedBox(height: 4),
                      Text('Electronically generated receipt. No physical signature required.',
                        style: TextStyle(fontSize: 8.5, color: _grey)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ]),
          )),

          // Action buttons
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            child: Column(children: [
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  onPressed: () async {
                    final filename = 'Receipt_${receipt.receiptNo.replaceAll('/', '-')}.txt';
                    final ok = await NativeFileSaver.saveText(filename, buildReceiptText(receipt));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ok ? '✓ Receipt saved to Downloads' : 'Failed to save'),
                        backgroundColor: _teal,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  },
                  icon: const Icon(Icons.download_outlined, size: 16),
                  label: const Text('Download'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _teal,
                    side: const BorderSide(color: _teal),
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
                    backgroundColor: _teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                )),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: _tealLt, borderRadius: BorderRadius.circular(8)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: _teal),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 11, color: _teal, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _totRow(String label, String value, {bool bold = false, bool large = false, Color color = _grey}) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: large ? 14 : 12, color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: large ? 14 : 12, color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w500)),
      ]),
    );
}

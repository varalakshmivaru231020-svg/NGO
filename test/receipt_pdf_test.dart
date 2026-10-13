import 'package:flutter_test/flutter_test.dart';
import 'package:saksham_app/features/donations/presentation/receipt_generator.dart';

// A single donation receipt used to be one non-spanning Column inside
// MultiPage — any receipt taller than one A4 page (long description/address)
// made the release build loop forever, so Print/Download just kept loading.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  DonationReceipt receipt({String notes = '', String address = ''}) => DonationReceipt(
        receiptNo: 'SKET/2026/00055', donorName: 'Test Donor', donorPhone: '9999999999', donorCity: 'Bengaluru',
        donorPan: 'ABCDE1234F', donationType: 'Education Fund', amount: 200000, paymentMode: 'Bank Transfer',
        date: '29 Sep 2026', taxExemption: true, notes: notes, donorAddress: address,
      );

  test('generates a normal receipt', () async {
    final bytes = await buildReceiptPdf(receipt()).timeout(const Duration(seconds: 20));
    expect(bytes.length, greaterThan(1000));
  });

  test('generates a receipt with a very long description', () async {
    final long = List.filled(40, 'Annual sponsorship for books, uniforms and meals.').join(' ');
    final bytes = await buildReceiptPdf(receipt(notes: long, address: long)).timeout(const Duration(seconds: 20));
    // Must actually flow onto a second page (that's the case that hung).
    expect(RegExp(r'/Count (\d+)').allMatches(String.fromCharCodes(bytes)).map((m) => int.parse(m.group(1)!)),
        contains(greaterThan(1)));
  });
}

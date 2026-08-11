import 'package:flutter_test/flutter_test.dart';
import 'package:saksham_app/features/donations/presentation/receipt_generator.dart';

// A donor statement lists every donation on record. Long donor histories used
// to overflow a single A4 page and hang the export — the itemised table has to
// span pages.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const donor = {'name': 'Test Donor', 'donorCode': 'DNR-0001'};

  List<Map<String, dynamic>> donations(int n) => List.generate(n, (i) => {
        'date': '2026-0${(i % 9) + 1}-15T00:00:00.000Z',
        'receiptNo': 'RCP/2026/${(i + 1).toString().padLeft(5, '0')}',
        'donationType': 'General Donation',
        'amount': 500 + i,
      });

  test('generates a short donor statement', () async {
    final bytes = await buildDonationStatementPdf(donor: donor, donations: donations(5));
    expect(bytes.length, greaterThan(1000));
  });

  test('generates a long donor statement (120 donations)', () async {
    final bytes = await buildDonationStatementPdf(donor: donor, donations: donations(120));
    expect(bytes.length, greaterThan(1000));
  });

  test('generates a statement for a donor with no donations', () async {
    final bytes = await buildDonationStatementPdf(donor: donor, donations: const []);
    expect(bytes.length, greaterThan(1000));
  });
}

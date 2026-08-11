import 'package:flutter_test/flutter_test.dart';
import 'package:saksham_app/features/expenses/presentation/expense_report_generator.dart';

// The Expenses screen's period download (This Month / All Time …) feeds every
// matching voucher into one PDF. A month with more rows than fit on a single
// A4 page must still generate — it used to throw inside MultiPage and surface
// as "Could not generate the report".
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  List<ExpenseReportRow> rows(int n) => List.generate(n, (i) => ExpenseReportRow(
        date: '07 Aug 2026',
        voucherNo: 'EXP/2026/${(i + 1).toString().padLeft(6, '0')}',
        paidTo: 'Vendor ${i + 1}',
        category: i.isEven ? 'Office Expenses' : 'Transportation',
        method: 'UPI',
        amount: 1000 + i,
      ));

  test('generates a single-page report', () async {
    final bytes = await buildExpenseReportPdf(rows: rows(8), periodLabel: 'August 2026');
    expect(bytes.length, greaterThan(1000));
  });

  test('generates a multi-page report (130 expenses)', () async {
    final bytes = await buildExpenseReportPdf(rows: rows(130), periodLabel: 'All recorded expenses');
    expect(bytes.length, greaterThan(1000));
  });

  test('generates an empty-period report', () async {
    final bytes = await buildExpenseReportPdf(rows: const [], periodLabel: 'July 2026');
    expect(bytes.length, greaterThan(1000));
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saksham_app/core/theme/app_theme.dart';
import 'package:saksham_app/features/donations/presentation/receipt_generator.dart';
import 'package:saksham_app/features/expenses/presentation/expense_voucher_generator.dart';

// The receipt / voucher sheets are drag-to-resize bottom sheets. On wide
// screens showAppSheet shows them in a centred dialog instead, where they used
// to lay out as a blank white box. Both sizes must render the content.
void main() {
  const receipt = DonationReceipt(
    receiptNo: 'SKET/2026/00055', donorName: 'Test Donor', donorPhone: '9999999999', donorCity: 'Bengaluru',
    donorPan: 'ABCDE1234F', donationType: 'Education Fund', amount: 200000, paymentMode: 'BANK_TRANSFER',
    date: '29 Sep 2026', taxExemption: true,
  );
  const voucher = ExpenseVoucher(
    voucherNo: 'EXP/2026/000001', paidTo: 'Test Vendor', purpose: 'Groceries', categoryLabel: 'Food',
    amount: 4500, paymentMode: 'CASH', date: '06 Oct 2026',
  );
  final org = <String, dynamic>{'name': 'Sri Krishnashraya Educational Trust', 'address': 'Sulibele, Bangalore'};

  Future<void> open(WidgetTester tester, Size size, void Function(BuildContext) show) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The test font draws every glyph as a full square, far wider than real
    // text, so rows report horizontal overflow that doesn't happen in the app.
    // Only those are ignored; layout failures still fail the test.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed by')) return;
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Builder(builder: (ctx) => Scaffold(body: Center(child: TextButton(onPressed: () => show(ctx), child: const Text('open'))))),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final (label, size) in [('desktop', const Size(1400, 900)), ('phone', const Size(400, 860))]) {
    testWidgets('donation receipt renders on $label', (tester) async {
      await open(tester, size, (ctx) => showReceiptSheet(ctx, receipt, org: org));
      expect(tester.takeException(), isNull);
      expect(find.text('Done'), findsOneWidget);
      expect(find.textContaining('SKET/2026/00055'), findsWidgets);
    });

    testWidgets('expense voucher renders on $label', (tester) async {
      await open(tester, size, (ctx) => showVoucherSheet(ctx, voucher));
      expect(tester.takeException(), isNull);
      expect(find.textContaining('EXP/2026/000001'), findsWidgets);
    });
  }
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:saksham_app/features/staff/presentation/staff_salary_pdf.dart';
import 'package:saksham_app/features/staff/staff_model.dart';

// Pay slip + yearly salary statement. Set SKET_PDF_OUT to a folder to also
// write the generated files there for a visual check.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final staff = StaffMember(
    id: 's1', staffCode: 'STF0001', name: 'Udaya', designation: 'Marketing Executive',
    centreName: 'Sulibele', workTimings: '9:00 AM - 6:00 PM', panNumber: '',
    basicSalary: 20000, bankName: 'SBI', accountNumber: '12345678901',
    joiningDate: DateTime(2025, 6, 1),
  );
  final jan = StaffSalary(
    id: 'm1', month: '2026-01', basic: 20000, overtime: 1500, workedOnHolidays: true,
    status: 'PAID', paidOn: DateTime(2026, 2, 14), paymentMode: 'BANK_TRANSFER',
  );
  const feb = StaffSalary(
    id: 'm2', month: '2026-02', basic: 20000, hra: 1000, leaveDays: 1.5, leaveDeduction: 800, pf: 2400,
  );
  final org = {'name': 'Sri Krishnashraya Educational Trust'};

  Future<void> save(String name, List<int> bytes) async {
    final out = Platform.environment['SKET_PDF_OUT'];
    if (out != null && out.isNotEmpty) await File('$out/$name').writeAsBytes(bytes);
  }

  test('generates a pay slip', () async {
    final bytes = await buildStaffPayslipPdf(staff: staff, salary: jan, org: org);
    expect(bytes.length, greaterThan(1000));
    await save('payslip.pdf', bytes);
  });

  test('generates a pay slip with every deduction type', () async {
    final bytes = await buildStaffPayslipPdf(staff: staff, salary: feb);
    expect(bytes.length, greaterThan(1000));
  });

  test('generates a calendar-year statement', () async {
    final bytes = await buildStaffSalaryStatementPdf(
        staff: staff, from: DateTime(2026, 1), to: DateTime(2026, 12), salaries: [jan, feb], org: org);
    expect(bytes.length, greaterThan(1000));
    await save('yearly.pdf', bytes);
  });

  test('generates a statement for a custom range with no records', () async {
    final bytes = await buildStaffSalaryStatementPdf(
        staff: staff, from: DateTime(2025, 3), to: DateTime(2025, 7), salaries: [jan, feb]);
    expect(bytes.length, greaterThan(1000));
  });

  test('a multi-year range spans pages', () async {
    final bytes = await buildStaffSalaryStatementPdf(
        staff: staff, from: DateTime(2022, 1), to: DateTime(2026, 12), salaries: [jan, feb]);
    expect(bytes.length, greaterThan(1000));
    await save('range.pdf', bytes);
  });

  test('period titles', () {
    expect(salaryPeriodTitle(DateTime(2026, 1), DateTime(2026, 12)), 'YEAR 2026');
    expect(salaryPeriodTitle(DateTime(2025, 4), DateTime(2026, 3)), 'FY 2025-26');
    expect(salaryPeriodTitle(DateTime(2026, 1), DateTime(2026, 6)), 'JAN 2026 TO JUN 2026');
    expect(salaryPeriodMonths(DateTime(2025, 11), DateTime(2026, 2)).length, 4);
  });
}

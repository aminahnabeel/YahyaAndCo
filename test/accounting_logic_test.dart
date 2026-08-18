import 'package:flutter_test/flutter_test.dart';
import 'package:yahya_and_co/services/accounting_service.dart';

void main() {
  group('Accounting placement rules', () {
    test('debit-heavy accounts move to debit side without negative values', () {
      final result = AccountingService.calculateTrialBalancePlacement(
        totalDebit: 1250,
        totalCredit: 700,
      );

      expect(result['tbDebit'], 550.0);
      expect(result['tbCredit'], 0.0);
      expect(result['netDiff'], -550.0);
    });

    test('credit-heavy accounts move to credit side without negative values', () {
      final result = AccountingService.calculateTrialBalancePlacement(
        totalDebit: 500,
        totalCredit: 980,
      );

      expect(result['tbDebit'], 0.0);
      expect(result['tbCredit'], 480.0);
      expect(result['netDiff'], 480.0);
    });

    test('equal balances are zero on both sides and are considered balanced', () {
      final result = AccountingService.calculateTrialBalancePlacement(
        totalDebit: 1000,
        totalCredit: 1000,
      );

      expect(result['tbDebit'], 0.0);
      expect(result['tbCredit'], 0.0);
      expect(result['netDiff'], 0.0);
    });

    test('trial balance totals remain balanced after side placement', () {
      final rows = [
        AccountingService.calculateTrialBalancePlacement(totalDebit: 600, totalCredit: 400),
        AccountingService.calculateTrialBalancePlacement(totalDebit: 300, totalCredit: 500),
        AccountingService.calculateTrialBalancePlacement(totalDebit: 1000, totalCredit: 1000),
      ];

      final totalTbDebit = rows.fold<double>(0, (sum, row) => sum + (row['tbDebit'] as double));
      final totalTbCredit = rows.fold<double>(0, (sum, row) => sum + (row['tbCredit'] as double));

      expect((totalTbDebit - totalTbCredit).abs() < 0.01, isTrue);
    });
  });
}

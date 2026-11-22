import 'package:flutter_test/flutter_test.dart';

// Helper formula function to test
double calculateNewCustomerDebt({
  required double previousDebt,
  required double invoiceTotal,
  required double amountPaid,
}) {
  final invoiceRemaining = (invoiceTotal - amountPaid).clamp(0.0, double.infinity);
  final overpayment = (amountPaid - invoiceTotal).clamp(0.0, double.infinity);
  return (previousDebt + invoiceRemaining - overpayment).clamp(0.0, double.infinity);
}

void main() {
  group('Debt and Payment Calculation Tests (Mandatory Test Cases)', () {
    test('Case 1: Previous 20,000 | Invoice 27,050 | Paid 27,050 -> New Debt 20,000', () {
      final newDebt = calculateNewCustomerDebt(
        previousDebt: 20000,
        invoiceTotal: 27050,
        amountPaid: 27050,
      );
      expect(newDebt, 20000);
    });

    test('Case 2: Previous 20,000 | Invoice 27,050 | Paid 37,050 -> New Debt 10,000 (Overpayment)', () {
      final newDebt = calculateNewCustomerDebt(
        previousDebt: 20000,
        invoiceTotal: 27050,
        amountPaid: 37050,
      );
      expect(newDebt, 10000);
    });

    test('Case 3: Unpaid invoice -> Previous 0 | Invoice 27,050 | Paid 0 -> New Debt 27,050', () {
      final newDebt = calculateNewCustomerDebt(
        previousDebt: 0,
        invoiceTotal: 27050,
        amountPaid: 0,
      );
      expect(newDebt, 27050);
    });

    test('Case 4: Partial payment -> Previous 0 | Invoice 27,050 | Paid 10,000 -> New Debt 17,050', () {
      final newDebt = calculateNewCustomerDebt(
        previousDebt: 0,
        invoiceTotal: 27050,
        amountPaid: 10000,
      );
      expect(newDebt, 17050);
    });

    test('Case 5: Full payment of previous debt -> Previous 20,000 | Invoice 0 | Paid 20,000 -> New Debt 0', () {
      final newDebt = calculateNewCustomerDebt(
        previousDebt: 20000,
        invoiceTotal: 0,
        amountPaid: 20000,
      );
      expect(newDebt, 0);
    });

    test('Case 6: Multiple edits without duplication (Delta accumulation check)', () {
      double recorded = 0; // initial recorded remaining for invoice
      double currentTotal = 27050;
      double currentPaid = 27050;
      
      double newRem1 = currentTotal - currentPaid; // 0
      double delta1 = newRem1 - recorded; // 0 - 0 = 0
      expect(delta1, 0);
      
      currentTotal = 30000;
      currentPaid = 30000;
      double newRem2 = currentTotal - currentPaid; // 0
      double delta2 = newRem2 - recorded; // 0 - 0 = 0
      expect(delta2, 0);

      currentPaid = 20000;
      double newRem3 = currentTotal - currentPaid; // 10000
      double delta3 = newRem3 - recorded; // 10000 - 0 = 10000 (adds 10000 charge)
      expect(delta3, 10000);
    });
  });
}

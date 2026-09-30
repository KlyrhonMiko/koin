import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/ledger/ledger.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/planned_payment.dart';
import 'package:koin/core/models/debt.dart';
import 'package:koin/core/models/debt_item.dart';

void main() {
  group('Ledger Domain Module & Seams', () {
    test('InMemoryLedgerAdapter records, retrieves, and voids transactions', () async {
      final ledger = InMemoryLedgerAdapter();

      final tx = AppTransaction(
        id: 'tx_1',
        note: 'Test coffee',
        amount: 4.50,
        date: DateTime.now(),
        type: TransactionType.expense,
        categoryId: 'cat_food',
        accountId: 'acc_cash',
        plannedPaymentId: 'plan_sub_1',
      );

      await ledger.recordTransaction(tx);
      final list = await ledger.getTransactions();
      expect(list.length, 1);
      expect(list.first.note, 'Test coffee');

      final voidResult = await ledger.voidTransaction('tx_1');
      expect(voidResult.transactionId, 'tx_1');
      expect(voidResult.hadPlannedPaymentRollback, isTrue);
      expect(voidResult.affectedPlannedPaymentId, 'plan_sub_1');

      final emptyList = await ledger.getTransactions();
      expect(emptyList.isEmpty, isTrue);
    });
  });

  group('Deep Debt Domain Model', () {
    test('Calculates progress, remainingAmount, and settlement state', () {
      final debt = Debt(
        id: 'debt_1',
        personName: 'Alice',
        amount: 1000.0,
        currentAmount: 250.0,
        type: DebtType.owedToMe,
        startDate: DateTime(2026, 1, 1),
        totalInstallments: 4,
      );

      expect(debt.remainingAmount, 750.0);
      expect(debt.progress, 0.25);
      expect(debt.isSettled, isFalse);
      expect(debt.perInstallmentAmount, 250.0);
      expect(debt.paidInstallmentsCount, 1);
      expect(debt.remainingInstallmentsCount, 3);
    });

    test('Identifies settled state when currentAmount reaches or exceeds amount', () {
      final settledDebt = Debt(
        id: 'debt_2',
        personName: 'Bob',
        amount: 500.0,
        currentAmount: 500.0,
        type: DebtType.iOwe,
        startDate: DateTime(2026, 1, 1),
      );

      expect(settledDebt.progress, 1.0);
      expect(settledDebt.isSettled, isTrue);
      expect(settledDebt.remainingAmount, 0.0);
    });

    test('Sums itemized amounts accurately across sub-purchases', () {
      final item1 = DebtItem(
        id: 'item_1',
        debtId: 'debt_3',
        name: 'Headphones',
        amount: 200.0,
        totalInstallments: 2,
        firstPaymentDate: DateTime(2026, 1, 1),
      );
      final item2 = DebtItem(
        id: 'item_2',
        debtId: 'debt_3',
        name: 'Keyboard',
        amount: 150.0,
        totalInstallments: 3,
        firstPaymentDate: DateTime(2026, 1, 1),
      );

      final debt = Debt(
        id: 'debt_3',
        personName: 'Credit Card',
        amount: 350.0,
        type: DebtType.iOwe,
        startDate: DateTime(2026, 1, 1),
        items: [item1, item2],
      );

      expect(debt.totalItemizedAmount, 350.0);
      expect(item1.perInstallmentAmount, 100.0);
      expect(item2.perInstallmentAmount, 50.0);
    });
  });

  group('PlannedPayment Domain Schedule Logic', () {
    test('computePreviousDate rolls back daily, weekly, monthly frequencies accurately', () {
      final monthly = PlannedPayment(
        id: 'plan_1',
        title: 'Rent',
        amount: 1200.0,
        type: TransactionType.expense,
        categoryId: 'cat_rent',
        accountId: 'acc_bank',
        startDate: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 4, 15),
        frequency: PaymentFrequency.monthly,
      );

      expect(monthly.computePreviousDate(), DateTime(2026, 3, 15));

      final weekly = PlannedPayment(
        id: 'plan_2',
        title: 'Gym',
        amount: 15.0,
        type: TransactionType.expense,
        categoryId: 'cat_health',
        accountId: 'acc_bank',
        startDate: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 3, 21),
        frequency: PaymentFrequency.weekly,
      );

      expect(weekly.computePreviousDate(), DateTime(2026, 3, 14));
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  group('AppTransaction Model Tests', () {
    test('should create transaction with empty note by default', () {
      final tx = AppTransaction(
        id: '1',
        amount: 100.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        categoryId: 'cat_1',
        accountId: 'acc_1',
      );

      expect(tx.note, '');
    });

    test('should map note to title in toMap for DB compatibility', () {
      final tx = AppTransaction(
        id: '1',
        note: 'Test Note',
        amount: 100.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        categoryId: 'cat_1',
        accountId: 'acc_1',
      );

      final map = tx.toMap();
      expect(map['title'], 'Test Note');
    });

    test('should map title from map to note in fromMap', () {
      final now = DateTime.now();
      final map = {
        'id': '1',
        'title': 'DB Title',
        'amount': 100.0,
        'date': now.toIso8601String(),
        'type': 'expense',
        'categoryId': 'cat_1',
        'accountId': 'acc_1',
      };

      final tx = AppTransaction.fromMap(map);
      expect(tx.note, 'DB Title');
    });

    test('should handle missing title in fromMap with empty string', () {
      final now = DateTime.now();
      final map = {
        'id': '1',
        'amount': 100.0,
        'date': now.toIso8601String(),
        'type': 'expense',
        'categoryId': 'cat_1',
        'accountId': 'acc_1',
      };

      final tx = AppTransaction.fromMap(map);
      expect(tx.note, '');
    });
  });

  group('TransactionGroup Domain Model Tests', () {
    test('groups transactions by day and sorts groups descending', () {
      final tx1 = AppTransaction(
        id: '1',
        amount: 25.0,
        date: DateTime(2026, 10, 2, 10, 30),
        type: TransactionType.expense,
        categoryId: 'cat_1',
        accountId: 'acc_1',
      );
      final tx2 = AppTransaction(
        id: '2',
        amount: 100.0,
        date: DateTime(2026, 10, 2, 14, 0),
        type: TransactionType.income,
        categoryId: 'cat_2',
        accountId: 'acc_1',
      );
      final tx3 = AppTransaction(
        id: '3',
        amount: 50.0,
        date: DateTime(2026, 10, 1, 9, 0),
        type: TransactionType.expense,
        categoryId: 'cat_1',
        accountId: 'acc_1',
      );

      final groups = TransactionGroup.groupTransactions([tx1, tx2, tx3]);

      expect(groups.length, 2);
      expect(groups[0].date, DateTime(2026, 10, 2));
      expect(groups[0].transactions.length, 2);
      // Net balance on 2026-10-02: +100 - 25 = +75
      expect(groups[0].netBalance, 75.0);

      expect(groups[1].date, DateTime(2026, 10, 1));
      expect(groups[1].transactions.length, 1);
      // Net balance on 2026-10-01: -50
      expect(groups[1].netBalance, -50.0);
    });

    test('transfers do not alter daily net balance', () {
      final transferTx = AppTransaction(
        id: 'tx_t',
        amount: 200.0,
        date: DateTime(2026, 10, 2, 11, 0),
        type: TransactionType.transfer,
        categoryId: 'cat_transfer',
        accountId: 'acc_1',
        toAccountId: 'acc_2',
      );

      final groups = TransactionGroup.groupTransactions([transferTx]);
      expect(groups.length, 1);
      expect(groups[0].netBalance, 0.0);
    });
  });

  group('TransactionFilter Deepening Tests', () {
    test('activeFilterCount correctly tallies active non-query criteria', () {
      const emptyFilter = TransactionFilter();
      expect(emptyFilter.activeFilterCount, 0);
      expect(emptyFilter.summaryText, '');

      final activeFilter = TransactionFilter(
        type: TransactionType.expense,
        categoryIds: {'cat_1', 'cat_2'},
        minAmount: 10.0,
        maxAmount: 100.0,
      );

      // 1 (type) + 2 (categoryIds) + 1 (minAmount) + 1 (maxAmount) = 5
      expect(activeFilter.activeFilterCount, 5);
      expect(
        activeFilter.summaryText,
        'Expense • 2 categories • Amount range',
      );
    });
  });

  group('CategoryBudgetMetrics Domain Tests', () {
    test('computes percentage, overBudgetAmount, and isNearLimit accurately', () {
      final category = TransactionCategory(
        id: 'cat_dining',
        name: 'Dining',
        iconCodePoint: 1234,
        colorHex: '#FF5722',
        type: TransactionType.expense,
      );

      final normalMetrics = CategoryBudgetMetrics(
        category: category,
        budget: 100.0,
        spent: 85.0,
        progress: 0.85,
        remaining: 15.0,
        isOverBudget: false,
      );

      expect(normalMetrics.percent, 85.0);
      expect(normalMetrics.formattedPercent, '85%');
      expect(normalMetrics.overBudgetAmount, 0.0);
      expect(normalMetrics.isNearLimit, isTrue);

      final overMetrics = CategoryBudgetMetrics(
        category: category,
        budget: 100.0,
        spent: 125.0,
        progress: 1.0,
        remaining: 0.0,
        isOverBudget: true,
      );

      expect(overMetrics.percent, 125.0);
      expect(overMetrics.formattedPercent, '125%');
      expect(overMetrics.overBudgetAmount, 25.0);
      expect(overMetrics.isNearLimit, isFalse);
    });
  });
}


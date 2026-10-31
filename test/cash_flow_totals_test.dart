import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/models/models.dart';

void main() {
  final now = DateTime(2026, 10, 15, 12);
  AppTransaction transaction(
    String id,
    TransactionType type,
    double amount,
    DateTime date, {
    bool debt = false,
    String? transferId,
  }) => AppTransaction(
    id: id,
    type: type,
    amount: amount,
    date: date,
    accountId: id,
    categoryId: 'category',
    isDebtTransfer: debt,
    transferId: transferId,
  );

  test('period totals follow boundaries; lifetime totals exclude future and loan principal', () {
    final transactions = [
      transaction('current-income', TransactionType.income, 100, now),
      transaction(
        'month-income',
        TransactionType.income,
        200,
        DateTime(2026, 10, 1),
      ),
      transaction(
        'year-income',
        TransactionType.income,
        300,
        DateTime(2026, 9, 1),
      ),
      transaction(
        'old-income',
        TransactionType.income,
        400,
        DateTime(2025, 1, 1),
      ),
      transaction('expense', TransactionType.expense, 20, now),
      transaction(
        'fee',
        TransactionType.expense,
        5,
        now,
        transferId: 'transfer',
      ),
      transaction(
        'old-expense',
        TransactionType.expense,
        30,
        DateTime(2025, 1, 1),
      ),
      transaction('transfer', TransactionType.transfer, 1000, now),
      transaction('loan-in', TransactionType.income, 2000, now, debt: true),
      transaction('loan-out', TransactionType.expense, 3000, now, debt: true),
      transaction(
        'future-income',
        TransactionType.income,
        4000,
        now.add(const Duration(seconds: 1)),
      ),
      transaction(
        'future-expense',
        TransactionType.expense,
        5000,
        now.add(const Duration(seconds: 1)),
      ),
    ];
    for (final (period, income) in [
      (AnalysisPeriod.week, 100),
      (AnalysisPeriod.month, 300),
      (AnalysisPeriod.year, 600),
    ]) {
      final totals = SpendingAnalysis.calculate(
        transactions: transactions,
        baseDate: now,
        period: period,
        asOf: now,
      );
      expect(totals.totalIncome, income);
      expect(totals.totalExpense, 25);
      expect(totals.allTimeIncome, 1000);
      expect(totals.allTimeExpense, 55);
    }
    final historical = SpendingAnalysis.calculate(
      transactions: transactions,
      baseDate: DateTime(2025, 1),
      period: AnalysisPeriod.month,
      asOf: now,
    );
    expect(historical.totalIncome, 400);
    expect(historical.totalExpense, 30);
    expect(historical.allTimeIncome, 1000);
    expect(historical.allTimeExpense, 55);
  });

  test('empty history and income-only history keep valid zero spending', () {
    for (final transactions in [
      <AppTransaction>[],
      [transaction('income', TransactionType.income, 100, now)],
    ]) {
      final totals = SpendingAnalysis.calculate(
        transactions: transactions,
        baseDate: now,
        period: AnalysisPeriod.month,
        asOf: now,
      );
      expect(totals.totalIncome, transactions.isEmpty ? 0 : 100);
      expect(totals.allTimeIncome, totals.totalIncome);
      expect(totals.totalExpense, 0);
      expect(totals.allTimeExpense, 0);
      expect(totals.filteredTransactions, isEmpty);
    }
  });
}

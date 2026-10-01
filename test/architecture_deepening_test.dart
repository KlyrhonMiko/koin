import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/coach/coach_engine.dart';

void main() {
  group('TransactionFilter Deep Domain Tests', () {
    final txList = [
      AppTransaction(
        id: 'tx_1',
        amount: 50.0,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        accountId: 'acc_wallet',
        note: 'Lunch at Jollibee',
        date: DateTime(2026, 10, 1, 12, 30),
      ),
      AppTransaction(
        id: 'tx_2',
        amount: 120.0,
        type: TransactionType.expense,
        categoryId: 'cat_groceries',
        accountId: 'acc_bank',
        note: 'Supermarket supplies',
        date: DateTime(2026, 9, 25, 10, 0),
      ),
      AppTransaction(
        id: 'tx_3',
        amount: 2500.0,
        type: TransactionType.income,
        categoryId: 'cat_salary',
        accountId: 'acc_bank',
        note: 'Bi-monthly paycheck',
        date: DateTime(2026, 9, 30, 9, 0),
      ),
      AppTransaction(
        id: 'tx_4',
        amount: 200.0,
        type: TransactionType.transfer,
        categoryId: 'cat_transfer',
        toAccountId: 'acc_wallet',
        accountId: 'acc_bank',
        note: 'ATM withdrawal',
        date: DateTime(2026, 10, 1, 8, 0),
      ),
    ];

    test('matches and apply return all transactions when filter is empty', () {
      const filter = TransactionFilter();
      expect(filter.isEmpty, isTrue);
      expect(filter.apply(txList).length, equals(4));
    });

    test('filters accurately by TransactionType', () {
      const expenseFilter = TransactionFilter(type: TransactionType.expense);
      final expenses = expenseFilter.apply(txList);
      expect(expenses.length, equals(2));
      expect(expenses.every((tx) => tx.type == TransactionType.expense), isTrue);

      const incomeFilter = TransactionFilter(type: TransactionType.income);
      final incomes = incomeFilter.apply(txList);
      expect(incomes.length, equals(1));
      expect(incomes.first.id, equals('tx_3'));
    });

    test('filters by Category and Account ID sets', () {
      const catFilter = TransactionFilter(categoryIds: {'cat_food'});
      final filteredCats = catFilter.apply(txList);
      expect(filteredCats.length, equals(1));
      expect(filteredCats.first.id, equals('tx_1'));

      const accFilter = TransactionFilter(accountIds: {'acc_wallet'});
      final filteredAccs = accFilter.apply(txList);
      expect(filteredAccs.length, equals(1));
      expect(filteredAccs.first.id, equals('tx_1'));
    });

    test('filters by Min and Max amount thresholds', () {
      const amountFilter = TransactionFilter(minAmount: 100.0, maxAmount: 300.0);
      final results = amountFilter.apply(txList);
      expect(results.length, equals(2)); // 120 and 200
      expect(results.map((t) => t.id), containsAll(['tx_2', 'tx_4']));
    });

    test('filters by query across note text and category names', () {
      final categoryNames = {
        'cat_food': 'Food & Dining',
        'cat_groceries': 'Groceries',
        'cat_salary': 'Salary',
      };

      const noteQuery = TransactionFilter(query: 'jollibee');
      expect(noteQuery.apply(txList, categoryNamesById: categoryNames).length, equals(1));

      const catQuery = TransactionFilter(query: 'dining');
      expect(catQuery.apply(txList, categoryNamesById: categoryNames).length, equals(1));
    });

    test('filters by inclusive DateRange', () {
      final range = DateTimeRange(
        start: DateTime(2026, 10, 1),
        end: DateTime(2026, 10, 1),
      );
      final dateFilter = TransactionFilter(dateRange: range);
      final results = dateFilter.apply(txList);
      expect(results.length, equals(2)); // tx_1 and tx_4 on Oct 1
      expect(results.map((t) => t.id), containsAll(['tx_1', 'tx_4']));
    });
  });

  group('SpendingAnalysis & AnalysisPeriod Deep Domain Tests', () {
    final baseDate = DateTime(2026, 10, 15);

    test('AnalysisPeriod computes weekly, monthly, and yearly windows accurately', () {
      final weekRange = AnalysisPeriod.week.dateRange(baseDate);
      expect(weekRange.start.weekday, equals(DateTime.monday));
      expect(weekRange.end.weekday, equals(DateTime.sunday));

      final monthRange = AnalysisPeriod.month.dateRange(baseDate);
      expect(monthRange.start, equals(DateTime(2026, 10, 1)));
      expect(monthRange.end.month, equals(10));
      expect(monthRange.end.day, equals(31));

      final yearRange = AnalysisPeriod.year.dateRange(baseDate);
      expect(yearRange.start, equals(DateTime(2026, 1, 1)));
      expect(yearRange.end.month, equals(12));
      expect(yearRange.end.day, equals(31));
    });

    test('AnalysisPeriod computes previous comparison windows accurately', () {
      final prevMonth = AnalysisPeriod.month.previousDateRange(baseDate);
      expect(prevMonth.start, equals(DateTime(2026, 9, 1)));
      expect(prevMonth.end.month, equals(9));
      expect(prevMonth.end.day, equals(30));

      final prevYear = AnalysisPeriod.year.previousDateRange(baseDate);
      expect(prevYear.start, equals(DateTime(2025, 1, 1)));
      expect(prevYear.end.year, equals(2025));
    });

    test('SpendingAnalysis calculates current vs previous totals and trend %', () {
      final sampleTransactions = [
        // Current month (October 2026)
        AppTransaction(
          id: 't1',
          amount: 200.0,
          type: TransactionType.expense,
          categoryId: 'food',
          accountId: 'a1',
          date: DateTime(2026, 10, 5),
        ),
        AppTransaction(
          id: 't2',
          amount: 300.0,
          type: TransactionType.expense,
          categoryId: 'transport',
          accountId: 'a1',
          date: DateTime(2026, 10, 12),
        ),
        // Prior month (September 2026)
        AppTransaction(
          id: 't3',
          amount: 400.0,
          type: TransactionType.expense,
          categoryId: 'food',
          accountId: 'a1',
          date: DateTime(2026, 9, 20),
        ),
      ];

      final analysis = SpendingAnalysis.calculate(
        transactions: sampleTransactions,
        baseDate: baseDate,
        period: AnalysisPeriod.month,
      );

      expect(analysis.totalExpense, equals(500.0));
      expect(analysis.previousExpense, equals(400.0));
      expect(analysis.isIncrease, isTrue);
      // diff = +100 / 400 = 25%
      expect(analysis.trendPercentage, closeTo(25.0, 0.01));
      expect(analysis.filteredTransactions.length, equals(2));

      // Category breakdown sorted descending
      expect(analysis.categoryBreakdown.length, equals(2));
      expect(analysis.categoryBreakdown.first.categoryId, equals('transport'));
      expect(analysis.categoryBreakdown.first.amount, equals(300.0));
      expect(analysis.categoryBreakdown.first.percentage, closeTo(60.0, 0.01));
    });
  });

  group('BudgetOverview Deep Domain Model Tests', () {
    final categories = [
      TransactionCategory(
        id: 'cat_dining',
        name: 'Dining',
        iconCodePoint: 1,
        colorHex: '#FF0000',
        type: TransactionType.expense,
        budget: 1000.0,
        isPercentBudget: false,
      ),
      TransactionCategory(
        id: 'cat_invest',
        name: 'Investing',
        iconCodePoint: 2,
        colorHex: '#00FF00',
        type: TransactionType.expense,
        budgetPercent: 20.0,
        isPercentBudget: true, // 20% of income (e.g. 5000 = 1000)
      ),
      TransactionCategory(
        id: 'cat_other',
        name: 'Other',
        iconCodePoint: 3,
        colorHex: '#0000FF',
        type: TransactionType.expense,
        budget: null,
      ),
    ];

    test('BudgetOverview calculates totals, resolved budgets, and progress', () {
      final spending = {
        'cat_dining': 600.0,
        'cat_invest': 500.0,
        'cat_other': 150.0,
      };

      final overview = BudgetOverview.calculate(
        categories: categories,
        categorySpending: spending,
        totalIncome: 5000.0,
      );

      expect(overview.budgetedCategories.length, equals(2));
      expect(overview.unbudgetedCategories.length, equals(1));
      // Dining: 1000 + Invest: 20% of 5000 (1000) = 2000 total budget
      expect(overview.totalBudget, equals(2000.0));
      // Dining: 600 + Invest: 500 = 1100 total spent
      expect(overview.totalSpent, equals(1100.0));
      expect(overview.overallProgress, closeTo(1100 / 2000, 0.01));
      expect(overview.overallPercent, equals('55'));

      final diningMetric = overview.metricsByCategory['cat_dining']!;
      expect(diningMetric.spent, equals(600.0));
      expect(diningMetric.budget, equals(1000.0));
      expect(diningMetric.remaining, equals(400.0));
      expect(diningMetric.isOverBudget, isFalse);
    });

    test('identifies over-budget state accurately', () {
      final overSpending = {
        'cat_dining': 1200.0,
      };

      final overview = BudgetOverview.calculate(
        categories: categories,
        categorySpending: overSpending,
        totalIncome: 5000.0,
      );

      final diningMetric = overview.metricsByCategory['cat_dining']!;
      expect(diningMetric.isOverBudget, isTrue);
      expect(diningMetric.remaining, equals(0.0));
    });
  });

  group('SavingsGoal Pace & CoachEngine Tests', () {
    final goal = SavingsGoal(
      id: 'g1',
      name: 'Emergency Fund',
      targetAmount: 1200.0,
      currentAmount: 300.0,
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 12, 31),
    );

    test('SavingsGoal computes elapsed days, expected amount, and pace directly', () {
      final today = DateTime(2026, 7, 1); // ~halfway through year
      expect(goal.elapsedDays(today), greaterThan(150));
      expect(goal.expectedAmountToday(today), greaterThan(500.0));
      expect(goal.currentWeeklyPace(today), greaterThan(0));
      expect(goal.goalGap(today), greaterThan(0));
    });

    test('CoachEngine simulates goal status, projected finish, and required pace', () {
      final engine = CoachEngine(goal: goal, today: DateTime(2026, 6, 1));
      final result = engine.simulate();

      expect(result.weeklyAmountRequired, greaterThan(0));
      expect(result.status, isNotNull);
      expect(result.newDeadline, equals(DateTime(2026, 12, 31)));

      final presets = engine.generatePresets(500.0);
      expect(presets, isA<List<double>>());
    });
  });

  group('Ledger Seam Debt Repayment Voiding Tests', () {
    test('InMemoryLedgerAdapter voids debt repayment and cleans up transactions', () async {
      final ledger = InMemoryLedgerAdapter();
      final debt = Debt(
        id: 'd1',
        personName: 'Alex',
        amount: 1000.0,
        currentAmount: 200.0,
        type: DebtType.owedToMe,
        startDate: DateTime(2026, 1, 1),
      );
      final repayment = DebtRepayment(
        id: 'rep_1',
        debtId: 'd1',
        amount: 150.0,
        date: DateTime(2026, 10, 1),
        accountId: 'acc_wallet',
      );

      final tx = await ledger.recordDebtRepayment(
        debt: debt,
        repayment: repayment,
        categoryId: 'cat_others_inc',
      );
      expect(tx, isNotNull);
      expect((await ledger.getTransactions()).length, equals(1));

      // Now void the repayment through the seam
      await ledger.voidDebtRepayment(repayment);
      expect((await ledger.getTransactions()).length, equals(0));
    });
  });
}

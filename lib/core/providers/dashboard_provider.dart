import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/account_provider.dart';

import 'calendar_provider.dart';
import 'effective_transaction_clock_provider.dart';

class DashboardStats {
  final double totalIncome;
  final double totalExpense;
  final double currentBalance;
  final List<Account> accounts;
  final Map<String, double> accountBalances;
  final Map<String, double> categorySpending;
  final double allTimeIncome;
  final double allTimeExpense;
  final Map<String, double> allTimeCategorySpending;
  final DateTime referenceDate;

  DashboardStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.currentBalance,
    required this.accounts,
    required this.accountBalances,
    required this.categorySpending,
    this.allTimeIncome = 0.0,
    this.allTimeExpense = 0.0,
    this.allTimeCategorySpending = const {},
    DateTime? referenceDate,
  }) : referenceDate = referenceDate ?? DateTime.now();

  factory DashboardStats.empty() {
    return DashboardStats(
      totalIncome: 0,
      totalExpense: 0,
      currentBalance: 0,
      accounts: [],
      accountBalances: {},
      categorySpending: {},
      allTimeIncome: 0,
      allTimeExpense: 0,
      allTimeCategorySpending: {},
    );
  }

  /// Pure domain calculator for dashboard financial metrics and account balances.
  /// Monthly metrics (totalIncome, totalExpense, categorySpending) are evaluated for [referenceDate] (defaults to current month).
  /// Account balances and currentBalance represent cumulative lifetime totals.
  factory DashboardStats.calculate({
    required List<Account> accounts,
    required List<AppTransaction> transactions,
    DateTime? referenceDate,
    DateTime? asOf,
  }) {
    final now = asOf ?? DateTime.now();
    final targetDate = referenceDate ?? now;
    double monthlyIncome = 0;
    double monthlyExpense = 0;
    double allTimeInc = 0;
    double allTimeExp = 0;
    Map<String, double> balances = {};
    Map<String, double> monthlyCatSpending = {};
    Map<String, double> allTimeCatSpending = {};

    for (final account in accounts) {
      balances[account.id] = account.initialBalance;
    }
    for (final transaction in transactions) {
      if (transaction.date.isAfter(now)) continue;
      final inMonth =
          transaction.date.year == targetDate.year &&
          transaction.date.month == targetDate.month;
      // Hiding or excluding an account changes balance visibility, never history.
      if (transaction.type == TransactionType.income) {
        allTimeInc += transaction.amount;
        if (inMonth) monthlyIncome += transaction.amount;
      } else if (transaction.type == TransactionType.expense) {
        allTimeExp += transaction.amount;
        allTimeCatSpending[transaction.categoryId] =
            (allTimeCatSpending[transaction.categoryId] ?? 0) +
            transaction.amount;
        if (inMonth) {
          monthlyExpense += transaction.amount;
          monthlyCatSpending[transaction.categoryId] =
              (monthlyCatSpending[transaction.categoryId] ?? 0) +
              transaction.amount;
        }
      }
      if (balances.containsKey(transaction.accountId)) {
        balances[transaction.accountId] =
            balances[transaction.accountId]! +
            (transaction.type == TransactionType.income
                ? transaction.amount
                : -transaction.amount);
      }
      if (transaction.type == TransactionType.transfer &&
          balances.containsKey(transaction.toAccountId)) {
        balances[transaction.toAccountId!] =
            balances[transaction.toAccountId!]! + transaction.amount;
      }
    }

    double currentBalance = 0;
    for (var a in accounts) {
      if (!a.excludeFromTotal) {
        currentBalance += balances[a.id] ?? 0;
      }
    }

    return DashboardStats(
      totalIncome: monthlyIncome,
      totalExpense: monthlyExpense,
      currentBalance: currentBalance,
      accounts: accounts,
      accountBalances: balances,
      categorySpending: monthlyCatSpending,
      allTimeIncome: allTimeInc,
      allTimeExpense: allTimeExp,
      allTimeCategorySpending: allTimeCatSpending,
      referenceDate: targetDate,
    );
  }
}

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  ref.watch(calendarDayProvider);
  final now = ref.watch(effectiveTransactionClockProvider);
  final transactionsState = ref.watch(transactionProvider);
  final accountsState = ref.watch(accountProvider);

  if (transactionsState.value != null && accountsState.value != null) {
    return DashboardStats.calculate(
      accounts: accountsState.value!,
      asOf: now,
      transactions: transactionsState.value!,
    );
  }
  return transactionsState.maybeWhen(
    data: (transactions) {
      return accountsState.maybeWhen(
        data: (accounts) => DashboardStats.calculate(
          accounts: accounts,
          asOf: now,
          transactions: transactions,
        ),
        orElse: () => DashboardStats.empty(),
      );
    },
    orElse: () => DashboardStats.empty(),
  );
});

final monthlyDashboardStatsProvider = Provider.family<DashboardStats, DateTime>(
  (ref, date) {
    ref.watch(calendarDayProvider);
    final now = ref.watch(effectiveTransactionClockProvider);
    final transactionsState = ref.watch(transactionProvider);
    final accountsState = ref.watch(accountProvider);

    if (transactionsState.value != null && accountsState.value != null) {
      return DashboardStats.calculate(
        accounts: accountsState.value!,
        asOf: now,
        transactions: transactionsState.value!,
        referenceDate: date,
      );
    }

    return transactionsState.maybeWhen(
      data: (transactions) {
        return accountsState.maybeWhen(
          data: (accounts) => DashboardStats.calculate(
            accounts: accounts,
            asOf: now,
            transactions: transactions,
            referenceDate: date,
          ),
          orElse: () => DashboardStats.empty(),
        );
      },
      orElse: () => DashboardStats.empty(),
    );
  },
);

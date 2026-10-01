import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/account_provider.dart';

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
  }) {
    final targetDate = referenceDate ?? DateTime.now();
    double monthlyIncome = 0;
    double monthlyExpense = 0;
    double allTimeInc = 0;
    double allTimeExp = 0;
    Map<String, double> balances = {};
    Map<String, double> monthlyCatSpending = {};
    Map<String, double> allTimeCatSpending = {};

    final includedAccountIds = accounts
        .where((a) => !a.excludeFromTotal)
        .map((a) => a.id)
        .toSet();

    for (var a in accounts) {
      balances[a.id] = a.initialBalance;
    }

    for (var t in transactions) {
      final isSourceIncluded = includedAccountIds.contains(t.accountId);
      final isDestIncluded =
          t.toAccountId != null && includedAccountIds.contains(t.toAccountId);

      final isCurrentMonth =
          t.date.year == targetDate.year && t.date.month == targetDate.month;

      if (t.type == TransactionType.income) {
        if (isSourceIncluded) {
          allTimeInc += t.amount;
          if (isCurrentMonth) monthlyIncome += t.amount;
        }
        balances[t.accountId] = (balances[t.accountId] ?? 0) + t.amount;
      } else if (t.type == TransactionType.expense) {
        if (isSourceIncluded) {
          allTimeExp += t.amount;
          allTimeCatSpending[t.categoryId] =
              (allTimeCatSpending[t.categoryId] ?? 0) + t.amount;

          if (isCurrentMonth) {
            monthlyExpense += t.amount;
            monthlyCatSpending[t.categoryId] =
                (monthlyCatSpending[t.categoryId] ?? 0) + t.amount;
          }
        }
        balances[t.accountId] = (balances[t.accountId] ?? 0) - t.amount;
      } else if (t.type == TransactionType.transfer) {
        // Internal transfer between included/excluded accounts
        if (isSourceIncluded && !isDestIncluded) {
          // Moving money Out of included pool
          allTimeExp += t.amount;
          if (isCurrentMonth) monthlyExpense += t.amount;
        } else if (!isSourceIncluded && isDestIncluded) {
          // Moving money Into included pool
          allTimeInc += t.amount;
          if (isCurrentMonth) monthlyIncome += t.amount;
        }
        // Both included or both excluded -> no net change to total income/expense

        balances[t.accountId] = (balances[t.accountId] ?? 0) - t.amount;
        if (t.toAccountId != null) {
          balances[t.toAccountId!] = (balances[t.toAccountId!] ?? 0) + t.amount;
        }
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
  final transactionsState = ref.watch(transactionProvider);
  final accountsState = ref.watch(accountProvider);

  return transactionsState.maybeWhen(
    data: (transactions) {
      return accountsState.maybeWhen(
        data: (accounts) => DashboardStats.calculate(
          accounts: accounts,
          transactions: transactions,
        ),
        orElse: () => DashboardStats.empty(),
      );
    },
    orElse: () => DashboardStats.empty(),
  );
});

final monthlyDashboardStatsProvider =
    Provider.family<DashboardStats, DateTime>((ref, date) {
  final transactionsState = ref.watch(transactionProvider);
  final accountsState = ref.watch(accountProvider);

  return transactionsState.maybeWhen(
    data: (transactions) {
      return accountsState.maybeWhen(
        data: (accounts) => DashboardStats.calculate(
          accounts: accounts,
          transactions: transactions,
          referenceDate: date,
        ),
        orElse: () => DashboardStats.empty(),
      );
    },
    orElse: () => DashboardStats.empty(),
  );
});

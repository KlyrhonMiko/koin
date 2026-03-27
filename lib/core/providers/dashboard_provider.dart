import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/account.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/account_provider.dart';

class DashboardStats {
  final double totalIncome;
  final double totalExpense;
  final double currentBalance;
  final List<Account> accounts;
  final Map<String, double> accountBalances;
  final Map<String, double> categorySpending;
  
  DashboardStats({
    required this.totalIncome,
    required this.totalExpense,
    required this.currentBalance,
    required this.accounts,
    required this.accountBalances,
    required this.categorySpending,
  });

  factory DashboardStats.empty() {
    return DashboardStats(
      totalIncome: 0, 
      totalExpense: 0, 
      currentBalance: 0, 
      accounts: [], 
      accountBalances: {},
      categorySpending: {},
    );
  }
}

final dashboardStatsProvider = Provider<DashboardStats>((ref) {
  final transactionsState = ref.watch(transactionProvider);
  final accountsState = ref.watch(accountProvider);

  return transactionsState.maybeWhen(
    data: (transactions) {
      return accountsState.maybeWhen(
        data: (accounts) {
          double income = 0;
          double expense = 0;
          Map<String, double> balances = {};
          Map<String, double> catSpending = {};

          final includedAccountIds = accounts.where((a) => !a.excludeFromTotal).map((a) => a.id).toSet();

          for (var a in accounts) {
            balances[a.id] = a.initialBalance;
          }

          for (var t in transactions) {
            final isSourceIncluded = includedAccountIds.contains(t.accountId);
            final isDestIncluded = t.toAccountId != null && includedAccountIds.contains(t.toAccountId);

            if (t.type == TransactionType.income) {
              if (isSourceIncluded) income += t.amount;
              balances[t.accountId] = (balances[t.accountId] ?? 0) + t.amount;
            } else if (t.type == TransactionType.expense) {
              if (isSourceIncluded) {
                expense += t.amount;
                // track category spending only for included accounts
                catSpending[t.categoryId] = (catSpending[t.categoryId] ?? 0) + t.amount;
              }
              balances[t.accountId] = (balances[t.accountId] ?? 0) - t.amount;
            } else if (t.type == TransactionType.transfer) {
              // Internal transfer between included/excluded accounts
              if (isSourceIncluded && !isDestIncluded) {
                // Moving money Out of included pool
                expense += t.amount;
              } else if (!isSourceIncluded && isDestIncluded) {
                // Moving money Into included pool
                income += t.amount;
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
            totalIncome: income,
            totalExpense: expense,
            currentBalance: currentBalance,
            accounts: accounts,
            accountBalances: balances,
            categorySpending: catSpending,
          );
        },
        orElse: () => DashboardStats.empty(),
      );
    },
    orElse: () => DashboardStats.empty(),
  );
});

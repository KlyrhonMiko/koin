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
          double totalInitialBalances = 0;
          Map<String, double> balances = {};
          Map<String, double> catSpending = {};

          for (var a in accounts) {
            totalInitialBalances += a.initialBalance;
            balances[a.id] = a.initialBalance;
          }

          for (var t in transactions) {
            if (t.type == TransactionType.income) {
              income += t.amount;
              balances[t.accountId] = (balances[t.accountId] ?? 0) + t.amount;
            } else if (t.type == TransactionType.expense) {
              expense += t.amount;
              balances[t.accountId] = (balances[t.accountId] ?? 0) - t.amount;
              
              // track category spending
              catSpending[t.categoryId] = (catSpending[t.categoryId] ?? 0) + t.amount;
            } else if (t.type == TransactionType.transfer) {
              // Transfers decrease source and increase destination
              balances[t.accountId] = (balances[t.accountId] ?? 0) - t.amount;
              if (t.toAccountId != null) {
                balances[t.toAccountId!] = (balances[t.toAccountId!] ?? 0) + t.amount;
              }
            }
          }

          return DashboardStats(
            totalIncome: income,
            totalExpense: expense,
            currentBalance: (totalInitialBalances + income - expense),
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

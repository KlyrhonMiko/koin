import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/forecasting/cashflow_forecaster.dart';
import 'package:koin/core/repositories/forecast_repository.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/debt_provider.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/planned_payment_provider.dart';

export 'package:koin/core/forecasting/cashflow_forecaster.dart'
    show ForecastData, ForecastHorizon;

final forecastProvider = FutureProvider.family<ForecastData, int>((
  ref,
  filterIndex,
) async {
  // Register dependencies before awaiting. Never substitute empty financial
  // data while a dependency is loading or has failed.
  final transactionsFuture = ref.watch(transactionProvider.future);
  final accountsFuture = ref.watch(accountProvider.future);
  final debtsFuture = ref.watch(debtsProvider.future);
  final savingsFuture = ref.watch(savingsGoalsProvider.future);
  final paymentsFuture = ref.watch(plannedPaymentProvider.future);
  final forecastRepo = ref.watch(forecastRepositoryProvider);
  final transactions = await transactionsFuture;
  final accounts = await accountsFuture;
  final debts = await debtsFuture;
  final savings = await savingsFuture;
  final payments = await paymentsFuture;
  final now = DateTime.now();
  final dashboardStats = DashboardStats.calculate(
    accounts: accounts,
    transactions: transactions.where((tx) => !tx.date.isAfter(now)).toList(),
    referenceDate: now,
  );
  final includedIds = accounts
      .where((account) => !account.excludeFromTotal)
      .map((account) => account.id)
      .toSet();
  final history = await forecastRepo.getHistory(
    transactions: transactions,
    accounts: accounts,
    referenceDate: now,
  );

  return CashflowForecaster.calculate(
    historicalVariableInflows: history.inflows,
    historicalVariableOutflows: history.outflows,
    plannedPayments: payments
        .where((payment) => includedIds.contains(payment.accountId))
        .toList(),
    debts: debts
        .where(
          (debt) =>
              debt.accountId == null || includedIds.contains(debt.accountId),
        )
        .toList(),
    savingsGoals: savings,
    currentBaseline: dashboardStats.currentBalance,
    horizon: ForecastHorizon.fromIndex(filterIndex),
    referenceDate: now,
  );
});

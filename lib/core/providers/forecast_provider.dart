import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/forecasting/cashflow_forecaster.dart';
import 'package:koin/core/repositories/forecast_repository.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/debt_provider.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/providers/transaction_provider.dart';

export 'package:koin/core/forecasting/cashflow_forecaster.dart'
    show ForecastData, ForecastHorizon;

final forecastProvider = FutureProvider.family<ForecastData, int>((
  ref,
  filterIndex,
) async {
  // Recompute when core stats change
  ref.watch(transactionProvider);
  final dashboardStats = ref.watch(dashboardStatsProvider);
  final debtsAsync = ref.watch(debtsProvider);
  final savingsAsync = ref.watch(computedSavingsGoalsProvider);

  final forecastRepo = ref.read(forecastRepositoryProvider);
  final variableInflows = await forecastRepo.getHistoricalVariableInflows();
  final variableOutflows = await forecastRepo.getHistoricalVariableOutflows();
  final plannedPayments = await forecastRepo.getUnexcludedPlannedPayments();

  return CashflowForecaster.calculate(
    historicalVariableInflows: variableInflows,
    historicalVariableOutflows: variableOutflows,
    plannedPayments: plannedPayments,
    debts: debtsAsync.value ?? [],
    savingsGoals: savingsAsync.value ?? [],
    currentBaseline: dashboardStats.currentBalance,
    horizon: ForecastHorizon.fromIndex(filterIndex),
  );
});

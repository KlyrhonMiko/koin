import 'package:koin/core/models/models.dart';

/// Projection timeframe for financial cashflow forecasts.
enum ForecastHorizon {
  weekly(7.0 / 30.44),
  monthly(1.0),
  yearly(12.0);

  final double scaleFactor;

  const ForecastHorizon(this.scaleFactor);

  static ForecastHorizon fromIndex(int index) {
    switch (index) {
      case 0:
        return ForecastHorizon.weekly;
      case 1:
        return ForecastHorizon.monthly;
      case 2:
        return ForecastHorizon.yearly;
      default:
        return ForecastHorizon.monthly;
    }
  }
}

/// Resulting projection calculated by [CashflowForecaster].
class ForecastData {
  final double forecastedInflow;
  final double forecastedOutflow;
  final double currentBaseline;
  final double predictedNetBalance;
  final bool isWarning;

  const ForecastData({
    required this.forecastedInflow,
    required this.forecastedOutflow,
    required this.currentBaseline,
    required this.predictedNetBalance,
    required this.isWarning,
  });
}

/// Deep Domain Module: Encapsulates cashflow forecasting mathematics,
/// including Exponential Moving Average (EMA) for variable transactions,
/// recurrence period conversions for planned payments, debt installment amortization,
/// and horizon projection scaling.
class CashflowForecaster {
  /// Computes the Exponential Moving Average (EMA) of a monthly historical time-series.
  static double calculateEMA(List<double> data, {int period = 3}) {
    if (data.isEmpty) return 0.0;
    final alpha = 2.0 / (period + 1);
    double ema = data.first;
    for (int i = 1; i < data.length; i++) {
      ema = (data[i] * alpha) + (ema * (1 - alpha));
    }
    return ema;
  }

  /// Calculates the monthly normalized flow (inflow or outflow) from active planned payments.
  static ({double monthlyInflow, double monthlyOutflow})
  calculatePlannedPaymentsMonthly({
    required List<PlannedPayment> payments,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    double inflow = 0.0;
    double outflow = 0.0;

    for (final pp in payments) {
      if (pp.endDate != null && pp.endDate!.isBefore(now)) continue;

      double monthlyAmount = 0.0;
      switch (pp.frequency) {
        case PaymentFrequency.daily:
          monthlyAmount = pp.amount * 30.44;
          break;
        case PaymentFrequency.weekly:
          monthlyAmount = pp.amount * (30.44 / 7);
          break;
        case PaymentFrequency.biWeekly:
          monthlyAmount = pp.amount * (30.44 / 14);
          break;
        case PaymentFrequency.monthly:
        case PaymentFrequency.flexible:
          monthlyAmount = pp.amount;
          break;
        case PaymentFrequency.quarterly:
          monthlyAmount = pp.amount / 3;
          break;
        case PaymentFrequency.yearly:
          monthlyAmount = pp.amount / 12;
          break;
      }

      if (pp.type == TransactionType.income) {
        inflow += monthlyAmount;
      } else if (pp.type == TransactionType.expense) {
        outflow += monthlyAmount;
      }
    }

    return (monthlyInflow: inflow, monthlyOutflow: outflow);
  }

  /// Calculates monthly normalized inflow or outflow from active debts and recurring installments.
  static ({double monthlyInflow, double monthlyOutflow}) calculateDebtsMonthly({
    required List<Debt> debts,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    double inflow = 0.0;
    double outflow = 0.0;

    for (final debt in debts) {
      if (debt.remainingAmount <= 0) continue;

      final payment = debt.upcomingPaymentAmount;
      if (payment <= 0) continue;

      double monthlyPayment = 0.0;

      // If there are no installments, it's a lump sum debt
      if (debt.totalInstallments <= 0 && debt.items.isEmpty) {
        if (debt.dueDate != null) {
          final daysToDue = debt.dueDate!.difference(now).inDays;
          if (daysToDue > 0) {
            monthlyPayment = (debt.remainingAmount / daysToDue) * 30.44;
          } else {
            // Overdue or due this month
            monthlyPayment = debt.remainingAmount;
          }
        } else {
          monthlyPayment = 0.0;
        }
      } else {
        // True recurring installment
        switch (debt.frequency) {
          case InstallmentFrequency.weekly:
            monthlyPayment = payment * (30.44 / 7);
            break;
          case InstallmentFrequency.biweekly:
            monthlyPayment = payment * (30.44 / 14);
            break;
          case InstallmentFrequency.monthly:
            monthlyPayment = payment;
            break;
          case InstallmentFrequency.yearly:
            monthlyPayment = payment / 12;
            break;
        }
      }

      if (monthlyPayment > 0) {
        if (debt.type == DebtType.owedToMe) {
          inflow += monthlyPayment;
        } else if (debt.type == DebtType.iOwe) {
          outflow += monthlyPayment;
        }
      }
    }

    return (monthlyInflow: inflow, monthlyOutflow: outflow);
  }

  /// Calculates monthly outflow required to fund active milestone savings goals.
  static double calculateSavingsMonthly({
    required List<SavingsGoal> savingsGoals,
  }) {
    double monthlyOutflow = 0.0;
    for (final goal in savingsGoals) {
      if (!goal.isStash &&
          (goal.remainingAmount ?? 0) > 0 &&
          (goal.remainingDays ?? 0) > 0) {
        monthlyOutflow += (goal.monthlyNeeded ?? 0);
      }
    }
    return monthlyOutflow;
  }

  /// Calculates the complete forecast projection across the requested horizon.
  static ForecastData calculate({
    required List<double> historicalVariableInflows,
    required List<double> historicalVariableOutflows,
    required List<PlannedPayment> plannedPayments,
    required List<Debt> debts,
    required List<SavingsGoal> savingsGoals,
    required double currentBaseline,
    required ForecastHorizon horizon,
    DateTime? referenceDate,
  }) {
    // 1. Variable layer (EMA)
    double monthlyInflow = calculateEMA(historicalVariableInflows);
    double monthlyOutflow = calculateEMA(historicalVariableOutflows);

    // 2. Fixed layer: Planned Payments
    final planned = calculatePlannedPaymentsMonthly(
      payments: plannedPayments,
      referenceDate: referenceDate,
    );
    monthlyInflow += planned.monthlyInflow;
    monthlyOutflow += planned.monthlyOutflow;

    // 3. Fixed layer: Debts
    final debtFlows = calculateDebtsMonthly(
      debts: debts,
      referenceDate: referenceDate,
    );
    monthlyInflow += debtFlows.monthlyInflow;
    monthlyOutflow += debtFlows.monthlyOutflow;

    // 4. Goals layer: Savings Goals
    monthlyOutflow += calculateSavingsMonthly(savingsGoals: savingsGoals);

    // Scale to requested horizon
    final forecastedInflow = monthlyInflow * horizon.scaleFactor;
    final forecastedOutflow = monthlyOutflow * horizon.scaleFactor;
    final predictedNetBalance =
        currentBaseline + forecastedInflow - forecastedOutflow;

    return ForecastData(
      forecastedInflow: forecastedInflow,
      forecastedOutflow: forecastedOutflow,
      currentBaseline: currentBaseline,
      predictedNetBalance: predictedNetBalance,
      isWarning: predictedNetBalance < 0,
    );
  }
}

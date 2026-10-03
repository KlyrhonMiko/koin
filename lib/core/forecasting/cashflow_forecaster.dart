import 'dart:math' as math;

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

/// Projects variable monthly cashflow with an EMA and known commitments using
/// their calendar schedules. Debt and goal projections are capped at the
/// remaining principal or target, rather than extrapolated indefinitely.
class CashflowForecaster {
  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _addMonths(DateTime anchor, int months) {
    final month = DateTime(anchor.year, anchor.month + months);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, math.min(anchor.day, lastDay));
  }

  /// Forecasts cover today up to (but excluding) the horizon end date.
  static DateTime horizonEnd(ForecastHorizon horizon, DateTime referenceDate) {
    final start = _day(referenceDate);
    return switch (horizon) {
      ForecastHorizon.weekly => DateTime(
        start.year,
        start.month,
        start.day + 7,
      ),
      ForecastHorizon.monthly => _addMonths(start, 1),
      ForecastHorizon.yearly => _addMonths(start, 12),
    };
  }

  static DateTime _occurrence(
    DateTime anchor,
    int index, {
    int? days,
    int? months,
  }) {
    if (days != null) {
      return DateTime(anchor.year, anchor.month, anchor.day + days * index);
    }
    return _addMonths(anchor, months! * index);
  }

  /// Counts outstanding scheduled occurrences, including unpaid arrears.
  static int _paymentCount(PlannedPayment payment, DateTime end) {
    final anchor = _day(payment.nextDate);
    final start = _day(payment.startDate);
    final last = payment.endDate == null ? null : _day(payment.endDate!);
    final (days, months) = switch (payment.frequency) {
      PaymentFrequency.daily => (1, null),
      PaymentFrequency.weekly => (7, null),
      PaymentFrequency.biWeekly => (14, null),
      PaymentFrequency.monthly => (null, 1),
      PaymentFrequency.quarterly => (null, 3),
      PaymentFrequency.yearly => (null, 12),
      PaymentFrequency.flexible => (null, null),
    };
    var count = 0;
    for (var i = 0; ; i++) {
      final due = days == null && months == null
          ? anchor
          : _occurrence(anchor, i, days: days, months: months);
      if (!due.isBefore(end) || (last != null && due.isAfter(last))) break;
      if (!due.isBefore(start)) count++;
      // Flexible payments have one known date, no assumed recurrence.
      if (days == null && months == null) break;
    }
    return count;
  }

  static double _debtProjection(Debt debt, DateTime end) {
    if (debt.remainingAmount <= 0) return 0;
    final (days, months) = switch (debt.frequency) {
      InstallmentFrequency.weekly => (7, null),
      InstallmentFrequency.biweekly => (14, null),
      InstallmentFrequency.monthly => (null, 1),
      InstallmentFrequency.yearly => (null, 12),
    };
    if (debt.items.isNotEmpty) {
      // Allocate repayments to the oldest item installments first. Items can
      // start at different dates and stop after their own installment count.
      final events = <({DateTime date, double amount})>[];
      for (final item in debt.items) {
        final count = math.max(1, item.totalInstallments);
        for (var i = 0; i < count; i++) {
          final due = _occurrence(
            _day(item.firstPaymentDate),
            i,
            days: days,
            months: months,
          );
          if (!due.isBefore(end)) break;
          events.add((date: due, amount: item.amount / count));
        }
      }
      events.sort((a, b) => a.date.compareTo(b.date));
      var paid = debt.currentAmount;
      var projected = 0.0;
      for (final event in events) {
        final covered = math.min(paid, event.amount);
        paid -= covered;
        projected += event.amount - covered;
      }
      return projected.clamp(0.0, debt.remainingAmount);
    }
    if (debt.totalInstallments <= 0) {
      final due = debt.dueDate;
      return due != null && _day(due).isBefore(end) ? debt.remainingAmount : 0;
    }
    final installment = debt.perInstallmentAmount;
    if (installment <= 0) return 0;
    // Explicit due dates describe the next installment; otherwise use the
    // original schedule and subtract recorded repayments, including partials.
    final anchor = _day(debt.dueDate ?? debt.startDate);
    final count = debt.dueDate == null
        ? debt.totalInstallments
        : debt.remainingInstallmentsCount;
    var projected = 0.0;
    for (var i = 0; i < count; i++) {
      final due = _occurrence(anchor, i, days: days, months: months);
      if (!due.isBefore(end)) break;
      projected += installment;
    }
    final paid = debt.dueDate == null
        ? debt.currentAmount
        : debt.currentAmount % installment;
    return (projected - paid).clamp(0.0, debt.remainingAmount);
  }

  static double _savingsProjection(
    SavingsGoal goal,
    DateTime start,
    DateTime end,
  ) {
    final remaining = goal.remainingAmount ?? 0;
    if (goal.isStash || remaining <= 0 || goal.endDate == null) return 0;
    final deadline = _day(goal.endDate!);
    final fundingStart = _day(goal.startDate).isAfter(start)
        ? _day(goal.startDate)
        : start;
    if (!deadline.isAfter(fundingStart) || !end.isAfter(fundingStart)) return 0;
    final fundingEnd = end.isBefore(deadline) ? end : deadline;
    final daysRemaining = deadline.difference(fundingStart).inDays;
    final daysProjected = fundingEnd.difference(fundingStart).inDays;
    return (remaining * daysProjected / daysRemaining).clamp(0.0, remaining);
  }

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
    final start = _day(referenceDate ?? DateTime.now());
    final end = horizonEnd(horizon, start);
    // Scale only unknown variable flows. Known commitments use actual dates.
    var forecastedInflow =
        calculateEMA(historicalVariableInflows) * horizon.scaleFactor;
    var forecastedOutflow =
        calculateEMA(historicalVariableOutflows) * horizon.scaleFactor;
    for (final payment in plannedPayments) {
      if (payment.endDate != null && _day(payment.endDate!).isBefore(start)) {
        continue;
      }
      final amount = payment.amount * _paymentCount(payment, end);
      if (payment.type == TransactionType.income) forecastedInflow += amount;
      if (payment.type == TransactionType.expense) forecastedOutflow += amount;
    }
    for (final debt in debts) {
      final amount = _debtProjection(debt, end);
      if (debt.type == DebtType.owedToMe) forecastedInflow += amount;
      if (debt.type == DebtType.iOwe) forecastedOutflow += amount;
    }
    for (final goal in savingsGoals) {
      forecastedOutflow += _savingsProjection(goal, start, end);
    }
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

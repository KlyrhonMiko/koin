import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/transaction_provider.dart';
import 'package:koin/core/providers/debt_provider.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/models/models.dart';

class ForecastData {
  final double forecastedInflow;
  final double forecastedOutflow;
  final double currentBaseline;
  final double predictedNetBalance;
  final bool isWarning;

  ForecastData({
    required this.forecastedInflow,
    required this.forecastedOutflow,
    required this.currentBaseline,
    required this.predictedNetBalance,
    required this.isWarning,
  });
}

final forecastProvider = FutureProvider.family<ForecastData, int>((ref, filterIndex) async {
  // Recompute when core stats change
  ref.watch(transactionProvider);
  final dashboardStats = ref.watch(dashboardStatsProvider);
  final debtsAsync = ref.watch(debtsProvider);
  final savingsAsync = ref.watch(computedSavingsGoalsProvider);

  final dbHelper = DatabaseHelper.instance;
  final db = await dbHelper.database;

  // 1. Variable Layer (EMA of unbudgeted / non-planned items)
  final variableInflowRes = await db.rawQuery('''
    SELECT strftime('%Y-%m', date) as period, SUM(amount) as total
    FROM transactions
    WHERE type = 'income'
      AND plannedPaymentId IS NULL
      AND accountId IN (SELECT id FROM accounts WHERE excludeFromTotal = 0)
    GROUP BY strftime('%Y-%m', date)
    ORDER BY period ASC
  ''');

  final variableOutflowRes = await db.rawQuery('''
    SELECT strftime('%Y-%m', date) as period, SUM(amount) as total
    FROM transactions
    WHERE type = 'expense'
      AND plannedPaymentId IS NULL
      AND debtRepaymentId IS NULL
      AND accountId IN (SELECT id FROM accounts WHERE excludeFromTotal = 0)
    GROUP BY strftime('%Y-%m', date)
    ORDER BY period ASC
  ''');

  double calculateEMA(List<Map<String, Object?>> data) {
    if (data.isEmpty) return 0.0;
    const period = 3;
    const alpha = 2.0 / (period + 1);
    double ema = (data.first['total'] as num).toDouble();
    for (int i = 1; i < data.length; i++) {
      final value = (data[i]['total'] as num).toDouble();
      ema = (value * alpha) + (ema * (1 - alpha));
    }
    return ema;
  }

  double monthlyInflow = calculateEMA(variableInflowRes);
  double monthlyOutflow = calculateEMA(variableOutflowRes);

  final now = DateTime.now();

  // 2. Fixed Layer: Planned Payments
  final plannedPaymentsRes = await db.rawQuery('''
    SELECT * FROM planned_payments
    WHERE accountId IN (SELECT id FROM accounts WHERE excludeFromTotal = 0)
       OR accountId IS NULL
  ''');

  for (var row in plannedPaymentsRes) {
    final pp = PlannedPayment.fromMap(row);
    if (pp.endDate != null && pp.endDate!.isBefore(now)) continue;
    
    double monthlyAmount = 0.0;
    switch (pp.frequency) {
      case PaymentFrequency.daily: monthlyAmount = pp.amount * 30.44; break;
      case PaymentFrequency.weekly: monthlyAmount = pp.amount * (30.44 / 7); break;
      case PaymentFrequency.biWeekly: monthlyAmount = pp.amount * (30.44 / 14); break;
      case PaymentFrequency.monthly: monthlyAmount = pp.amount; break;
      case PaymentFrequency.quarterly: monthlyAmount = pp.amount / 3; break;
      case PaymentFrequency.yearly: monthlyAmount = pp.amount / 12; break;
      case PaymentFrequency.flexible: monthlyAmount = pp.amount; break;
    }

    if (pp.type == TransactionType.income) {
      monthlyInflow += monthlyAmount;
    } else if (pp.type == TransactionType.expense) {
      monthlyOutflow += monthlyAmount;
    }
  }

  // 3. Fixed Layer: Debts
  if (debtsAsync.value != null) {
    for (var debt in debtsAsync.value!) {
      if (debt.remainingAmount <= 0) continue;
      
      double payment = debt.upcomingPaymentAmount;
      if (payment > 0) {
        double monthlyPayment = 0.0;
        
        // If there are no installments, it's a lump sum debt, NOT a recurring payment
        if (debt.totalInstallments <= 0 && debt.items.isEmpty) {
          if (debt.dueDate != null) {
            final daysToDue = debt.dueDate!.difference(now).inDays;
            if (daysToDue > 0) {
              // Spread the lump sum cost over the months remaining until due
              monthlyPayment = (debt.remainingAmount / daysToDue) * 30.44;
            } else {
              // Overdue or due this month
              monthlyPayment = debt.remainingAmount;
            }
          } else {
            // No due date and no installments - don't blindly deduct the whole amount every month.
            // We could deduct a tiny fraction, or just ignore it from the recurring forecast.
            monthlyPayment = 0; 
          }
        } else {
          // It's a true recurring installment
          switch (debt.frequency) {
            case InstallmentFrequency.weekly: monthlyPayment = payment * (30.44 / 7); break;
            case InstallmentFrequency.biweekly: monthlyPayment = payment * (30.44 / 14); break;
            case InstallmentFrequency.monthly: monthlyPayment = payment; break;
            case InstallmentFrequency.yearly: monthlyPayment = payment / 12; break;
          }
        }

        if (monthlyPayment > 0) {
          if (debt.type == DebtType.owedToMe) {
            monthlyInflow += monthlyPayment;
          } else if (debt.type == DebtType.iOwe) {
            monthlyOutflow += monthlyPayment;
          }
        }
      }
    }
  }

  // 4. Goals Layer: Savings Goals
  if (savingsAsync.value != null) {
    for (var goal in savingsAsync.value!) {
      if (!goal.isStash && (goal.remainingAmount ?? 0) > 0 && (goal.remainingDays ?? 0) > 0) {
        monthlyOutflow += (goal.monthlyNeeded ?? 0);
      }
    }
  }

  // Scale proportionally
  double scaleFactor = 1.0;
  if (filterIndex == 0) {
    scaleFactor = 7.0 / 30.44; // Weekly
  } else if (filterIndex == 1) {
    scaleFactor = 1.0; // Monthly
  } else if (filterIndex == 2) {
    scaleFactor = 12.0; // Yearly
  }

  final forecastedInflow = monthlyInflow * scaleFactor;
  final forecastedOutflow = monthlyOutflow * scaleFactor;

  final currentBaseline = dashboardStats.currentBalance;
  final predictedNetBalance = currentBaseline + forecastedInflow - forecastedOutflow;

  return ForecastData(
    forecastedInflow: forecastedInflow,
    forecastedOutflow: forecastedOutflow,
    currentBaseline: currentBaseline,
    predictedNetBalance: predictedNetBalance,
    isWarning: predictedNetBalance < 0,
  );
});

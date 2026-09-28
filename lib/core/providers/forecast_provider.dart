import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/providers/dashboard_provider.dart';
import 'package:koin/core/providers/transaction_provider.dart';

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
  // Recompute when transactions or dashboard stats change
  ref.watch(transactionProvider);
  final dashboardStats = ref.watch(dashboardStatsProvider);

  final dbHelper = DatabaseHelper.instance;
  final db = await dbHelper.database;

  // Always calculate using Monthly groups for stability
  final inflowRes = await db.rawQuery('''
    SELECT strftime('%Y-%m', date) as period, SUM(amount) as total
    FROM transactions
    WHERE type = 'income'
      AND accountId IN (SELECT id FROM accounts WHERE excludeFromTotal = 0)
    GROUP BY strftime('%Y-%m', date)
    ORDER BY period ASC
  ''');

  final outflowRes = await db.rawQuery('''
    SELECT strftime('%Y-%m', date) as period, SUM(amount) as total
    FROM transactions
    WHERE type = 'expense'
      AND accountId IN (SELECT id FROM accounts WHERE excludeFromTotal = 0)
    GROUP BY strftime('%Y-%m', date)
    ORDER BY period ASC
  ''');

  // Calculate Monthly EMA
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

  final monthlyInflowEma = calculateEMA(inflowRes);
  final monthlyOutflowEma = calculateEMA(outflowRes);

  // Scale the monthly EMA proportionally based on the selected view
  double scaleFactor = 1.0;
  if (filterIndex == 0) {
    scaleFactor = 7.0 / 30.44; // Weekly (Days in a week / Avg days in a month)
  } else if (filterIndex == 1) {
    scaleFactor = 1.0; // Monthly
  } else if (filterIndex == 2) {
    scaleFactor = 12.0; // Yearly
  }

  final forecastedInflow = monthlyInflowEma * scaleFactor;
  final forecastedOutflow = monthlyOutflowEma * scaleFactor;

  // The Predicted Net Balance
  final currentBaseline = dashboardStats.currentBalance;
  final predictedNetBalance = currentBaseline + forecastedInflow - forecastedOutflow;

  return ForecastData(
    forecastedInflow: forecastedInflow,
    forecastedOutflow: forecastedOutflow,
    currentBaseline: currentBaseline,
    predictedNetBalance: predictedNetBalance,
    isWarning: forecastedOutflow > forecastedInflow,
  );
});

import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  test('short histories keep the baseline and do not claim evaluation', () {
    final result = ForecastEvaluation.select([100, 200, 100]);
    expect(result.method, VariableForecastMethod.movingAverage);
    expect(result.meanAbsoluteError, isNull);
    expect(result.evaluatedMonths, 0);
  });

  test('rolling evaluation selects a better method for a rising series', () {
    final result = ForecastEvaluation.select([
      100,
      200,
      300,
      400,
      500,
      600,
      700,
    ]);
    expect(result.method, VariableForecastMethod.lastMonth);
    expect(result.meanAbsoluteError, 100);
    expect(result.monthlyEstimate, 700);
  });

  test('future observations cannot change earlier held-out errors', () {
    final errors = ForecastEvaluation.netErrors(
      [100, 200, 300, 400, 500, 600],
      [20, 20, 20, 20, 20, 20],
    );
    final extended = ForecastEvaluation.netErrors(
      [100, 200, 300, 400, 500, 600, 100000],
      [20, 20, 20, 20, 20, 20, 0],
    );
    expect(extended.take(errors.length), orderedEquals(errors));
  });

  test(
    'positive final balance still warns about a shortfall before payday',
    () {
      final start = DateTime(2026, 10, 1);
      PlannedPayment scheduled(
        String id,
        TransactionType type,
        int day,
        double amount,
      ) => PlannedPayment(
        id: id,
        title: id,
        amount: amount,
        type: type,
        categoryId: 'category',
        accountId: 'main',
        startDate: start,
        nextDate: DateTime(2026, 10, day),
        frequency: PaymentFrequency.flexible,
      );
      final result = CashflowForecaster.calculate(
        historicalVariableInflows: [],
        historicalVariableOutflows: [],
        plannedPayments: [
          scheduled('rent', TransactionType.expense, 2, 200),
          scheduled('salary', TransactionType.income, 5, 500),
        ],
        debts: [],
        savingsGoals: [],
        currentBaseline: 100,
        horizon: ForecastHorizon.weekly,
        referenceDate: start,
      );
      expect(result.predictedNetBalance, 400);
      expect(result.firstShortfallDate, DateTime(2026, 10, 2));
      expect(result.isWarning, isTrue);
      expect(result.dailyBalances.length, 7);
      expect(result.dailyBalances.last.balance, result.predictedNetBalance);
      expect(result.lowerNetBalance, isNull);
    },
  );

  test(
    'historical variation ranges require six errors and widen with horizon',
    () {
      ForecastData project(int months, ForecastHorizon horizon) =>
          CashflowForecaster.calculate(
            historicalVariableInflows: List.filled(months, 300),
            historicalVariableOutflows: List.generate(
              months,
              (i) => i.isEven ? 100.0 : 250.0,
            ),
            plannedPayments: [],
            debts: [],
            savingsGoals: [],
            currentBaseline: 1000,
            horizon: horizon,
            referenceDate: DateTime(2026, 10, 1),
          );
      expect(project(8, ForecastHorizon.monthly).lowerNetBalance, isNull);
      final monthly = project(12, ForecastHorizon.monthly);
      final yearly = project(12, ForecastHorizon.yearly);
      expect(
        monthly.lowerNetBalance,
        lessThanOrEqualTo(monthly.predictedNetBalance),
      );
      expect(
        monthly.upperNetBalance,
        greaterThanOrEqualTo(monthly.predictedNetBalance),
      );
      expect(
        yearly.upperNetBalance! - yearly.lowerNetBalance!,
        greaterThan(monthly.upperNetBalance! - monthly.lowerNetBalance!),
      );
      expect(
        yearly.dailyBalances.last.balance,
        closeTo(yearly.predictedNetBalance, 1e-8),
      );
    },
  );
}

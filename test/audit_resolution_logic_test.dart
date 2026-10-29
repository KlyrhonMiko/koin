import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

class _FailingOrder extends InMemoryCategoryAdapter {
  _FailingOrder({required super.initial});
  @override
  Future<void> updateCategoryPositions(
    List<TransactionCategory> categories,
  ) async {
    throw StateError('Disk write failed');
  }
}

void main() {
  TransactionCategory category(String id, int position) => TransactionCategory(
    id: id,
    name: id,
    position: position,
    iconCodePoint: KoinIcons.wallet.codePoint,
    colorHex: '#00D09E',
    type: TransactionType.expense,
  );

  test('filtered reorder changes only the visible category slots', () async {
    final c = ProviderContainer(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(
            initial: [
              category('hidden', 0),
              category('taxi', 1),
              category('flight', 2),
            ],
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(categoriesProvider.future);
    await c
        .read(categoriesProvider.notifier)
        .reorderCategories(
          0,
          1,
          TransactionType.expense,
          visibleIds: ['taxi', 'flight'],
        );
    expect(c.read(categoriesProvider).value!.map((c) => c.id), [
      'hidden',
      'flight',
      'taxi',
    ]);
  });

  test(
    'failed reorder restores stored order and returns the failure',
    () async {
      final c = ProviderContainer(
        overrides: [
          categoryRepositoryProvider.overrideWithValue(
            _FailingOrder(
              initial: [category('first', 0), category('second', 1)],
            ),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(categoriesProvider.future);
      await expectLater(
        c
            .read(categoriesProvider.notifier)
            .reorderCategories(0, 1, TransactionType.expense),
        throwsStateError,
      );
      expect(c.read(categoriesProvider).value!.map((c) => c.id), [
        'first',
        'second',
      ]);
    },
  );

  test('a selected calendar deadline remains tomorrow throughout today', () {
    final goal = SavingsGoal(
      id: 'goal',
      name: 'Goal',
      targetAmount: 1000,
      startDate: DateTime(2026, 10, 1),
      endDate: DateTime(2026, 10, 30),
    );
    expect(goal.remainingDaysAt(DateTime(2026, 10, 29, 23, 59)), 1);
    expect(goal.remainingDaysAt(DateTime(2026, 10, 30, 12)), 0);
    expect(goal.remainingDaysAt(DateTime(2026, 10, 31)), -1);
  });

  test('ended recurrence keeps a valid unpaid occurrence available', () {
    final now = DateTime(2026, 10, 29);
    final payment = PlannedPayment(
      id: 'rent',
      title: 'Rent',
      amount: 1000,
      type: TransactionType.expense,
      categoryId: 'rent',
      accountId: 'cash',
      startDate: DateTime(2026, 1, 1),
      endDate: DateTime(2026, 10, 28),
      nextDate: DateTime(2026, 10, 26),
      frequency: PaymentFrequency.monthly,
    );
    expect(payment.isEligible(now), isFalse);
    expect(payment.canProcess(now), isTrue);
    expect(
      UpcomingTimeline.calculate(
        payments: [payment],
        debts: [],
        now: now,
      ).length,
      1,
    );
    final forecast = CashflowForecaster.calculate(
      historicalVariableInflows: [],
      historicalVariableOutflows: [],
      plannedPayments: [payment],
      debts: [],
      savingsGoals: [],
      currentBaseline: 2000,
      horizon: ForecastHorizon.weekly,
      referenceDate: now,
    );
    expect(forecast.forecastedOutflow, 1000);
    expect(forecast.predictedNetBalance, 1000);
    expect(
      payment.copyWith(nextDate: DateTime(2026, 11, 26)).canProcess(now),
      isFalse,
    );
    expect(
      payment.copyWith(frequency: PaymentFrequency.flexible).canProcess(now),
      isFalse,
    );
  });

  test('zero-income allocations retain spending and over-allocation state', () {
    final c = category(
      'food',
      0,
    ).copyWith(isPercentBudget: true, budgetPercent: 20);
    final overview = BudgetOverview.calculate(
      categories: [c],
      categorySpending: {'food': 500},
      totalIncome: 0,
    );
    final metric = overview.metricsByCategory['food']!;
    expect(metric.spent, 500);
    expect(metric.budget, 0);
    expect(metric.isOverBudget, isTrue);
    expect(metric.progress, 1);
    expect(c.isOverBudget(spent: 500, totalIncome: 0), isTrue);
  });

  test(
    'currency relabeling preserves unchanged decimals but validates new input',
    () {
      final yen = Currency.supportedCurrencies.firstWhere(
        (c) => c.code == 'JPY',
      );
      expect(yen.tryParseInput('100.50', originalValue: 100.5), 100.5);
      expect(yen.tryParseInput('100.75', originalValue: 100.5), isNull);
      expect(yen.tryParseInput('100.50'), isNull);
      expect(yen.tryParseInput('101', originalValue: 100.5), 101);
      expect(yen.precisionFor(0.25), 2);
      expect(yen.precisionFor(100), 0);
    },
  );
}

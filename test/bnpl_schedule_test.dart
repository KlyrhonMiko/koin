import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/models/debts/debt.dart';
import 'package:koin/core/models/debts/debt_item.dart';
import 'package:koin/core/forecasting/cashflow_forecaster.dart';
import 'package:koin/core/models/cashflow/upcoming_entry.dart';

void main() {
  DebtItem purchase(String id, double amount, int count, DateTime first) =>
      DebtItem(
        id: id,
        debtId: 'provider',
        name: id,
        amount: amount,
        totalInstallments: count,
        firstPaymentDate: first,
      );

  test(
    'new purchase defaults to the next shared day, not a provider month',
    () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      for (final anchor in [DateTime(2000, 1, 5), DateTime(2099, 1, 5)]) {
        final debt = Debt(
          id: 'provider',
          personName: 'Shop',
          amount: 100,
          type: DebtType.iOwe,
          startDate: anchor,
          isPurchaseAccount: true,
          items: [purchase('future purchase', 100, 1, DateTime(2099, 12, 5))],
        );
        var expected = debt.monthlyBillDate(now.year, now.month);
        if (expected.isBefore(today)) {
          expected = debt.monthlyBillDate(now.year, now.month + 1);
        }
        expect(debt.nextPurchaseBillDate, expected);
      }
    },
  );

  test('combined bills decrease as individual purchases finish', () {
    final debt = Debt(
      id: 'provider',
      personName: 'Shop',
      amount: 1000,
      type: DebtType.iOwe,
      startDate: DateTime(2026, 9, 5),
      isPurchaseAccount: true,
      items: [
        purchase('ends October', 400, 2, DateTime(2026, 9, 5)),
        purchase('ends November', 600, 3, DateTime(2026, 9, 5)),
      ],
    );
    expect(debt.upcomingPaymentAmount, 400);
    expect(debt.resolvedDueDate, DateTime(2026, 9, 5));
    final septemberPaid = debt.copyWith(currentAmount: 400);
    expect(septemberPaid.upcomingPaymentAmount, 400);
    expect(septemberPaid.nextDueDate, DateTime(2026, 10, 5));
    final octoberPaid = debt.copyWith(currentAmount: 800);
    expect(octoberPaid.upcomingPaymentAmount, 200);
    expect(octoberPaid.nextDueDate, DateTime(2026, 11, 5));
    final timeline = UpcomingTimeline.calculate(
      payments: [],
      debts: [octoberPaid],
    );
    expect(timeline.entries.single.amount, 200);
    expect(timeline.entries.single.subtitle, 'BNPL bill');
    expect(timeline.entries.single.dueDate, DateTime(2026, 11, 5));
    expect(debt.copyWith(currentAmount: 1000).upcomingPaymentAmount, 0);
  });

  test(
    'a partly paid purchase adds only its remaining balance to future bills',
    () {
      final debt = Debt(
        id: 'provider',
        personName: 'Shop',
        amount: 900,
        currentAmount: 300,
        type: DebtType.iOwe,
        startDate: DateTime(2026, 9, 5),
        isPurchaseAccount: true,
        items: [purchase('existing', 900, 3, DateTime(2026, 9, 5))],
      );
      final added = debt.copyWith(
        amount: 1300,
        items: [
          ...debt.items,
          purchase('remaining two bills', 400, 2, DateTime(2026, 10, 5)),
        ],
      );
      expect(added.remainingAmount, 1000);
      expect(added.nextDueDate, DateTime(2026, 10, 5));
      expect(added.upcomingPaymentAmount, 500);
      expect(added.copyWith(currentAmount: 800).upcomingPaymentAmount, 500);
    },
  );

  test('monthly bills retain day 31 after February', () {
    final debt = Debt(
      id: 'provider',
      personName: 'Shop',
      amount: 600,
      type: DebtType.iOwe,
      startDate: DateTime(2027, 1, 31),
      isPurchaseAccount: true,
      items: [purchase('February start', 600, 2, DateTime(2027, 2, 28))],
    );
    expect(debt.nextDueDate, DateTime(2027, 2, 28));
    expect(
      debt.copyWith(currentAmount: 300).nextDueDate,
      DateTime(2027, 3, 31),
    );
    final forecast = CashflowForecaster.calculate(
      historicalVariableInflows: [],
      historicalVariableOutflows: [],
      plannedPayments: [],
      debts: [debt.copyWith(currentAmount: 300)],
      savingsGoals: [],
      currentBaseline: 1000,
      horizon: ForecastHorizon.weekly,
      referenceDate: DateTime(2027, 3, 22),
    );
    expect(forecast.forecastedOutflow, 0);
    expect(Debt.fromMap(debt.toMap()).isPurchaseAccount, isTrue);
    final legacy = debt.toMap()..remove('isPurchaseAccount');
    expect(Debt.fromMap(legacy).isPurchaseAccount, isFalse);
  });

  test('different starting months enter only their own combined bills', () {
    final debt = Debt(
      id: 'provider',
      personName: 'Shop',
      amount: 1200,
      type: DebtType.iOwe,
      startDate: DateTime(2026, 10, 5),
      isPurchaseAccount: true,
      items: [
        purchase('October start', 200, 2, DateTime(2026, 10, 5)),
        purchase('November start', 400, 2, DateTime(2026, 11, 5)),
        purchase('December start', 600, 2, DateTime(2026, 12, 5)),
      ],
    );
    expect(debt.nextDueDate, DateTime(2026, 10, 5));
    expect(debt.upcomingPaymentAmount, 100);
    final octoberPaid = debt.copyWith(currentAmount: 100);
    expect(octoberPaid.nextDueDate, DateTime(2026, 11, 5));
    expect(octoberPaid.upcomingPaymentAmount, 300);
    final novemberPaid = debt.copyWith(currentAmount: 400);
    expect(novemberPaid.nextDueDate, DateTime(2026, 12, 5));
    expect(novemberPaid.upcomingPaymentAmount, 500);
    final decemberPaid = debt.copyWith(currentAmount: 900);
    expect(decemberPaid.nextDueDate, DateTime(2027, 1, 5));
    expect(decemberPaid.upcomingPaymentAmount, 300);

    final forecast = CashflowForecaster.calculate(
      historicalVariableInflows: [],
      historicalVariableOutflows: [],
      plannedPayments: [],
      debts: [debt],
      savingsGoals: [],
      currentBaseline: 2000,
      horizon: ForecastHorizon.monthly,
      referenceDate: DateTime(2026, 10, 1),
    );
    expect(forecast.forecastedOutflow, 100);
  });
}

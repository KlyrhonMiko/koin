import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/forecasting/forecast_history.dart';

class DelayedAccounts extends InMemoryAccountAdapter {
  final Completer<List<Account>> pending = Completer<List<Account>>();

  @override
  Future<List<Account>> getAccounts() => pending.future;
}

AppTransaction transaction(
  String id,
  DateTime date,
  double amount, {
  TransactionType type = TransactionType.expense,
  String accountId = 'main',
  String? plannedPaymentId,
  String? debtRepaymentId,
}) => AppTransaction(
  id: id,
  amount: amount,
  date: date,
  type: type,
  categoryId: 'category',
  accountId: accountId,
  plannedPaymentId: plannedPaymentId,
  debtRepaymentId: debtRepaymentId,
);

ForecastData project({
  DateTime? date,
  ForecastHorizon horizon = ForecastHorizon.monthly,
  List<PlannedPayment> payments = const [],
  List<Debt> debts = const [],
  List<SavingsGoal> goals = const [],
}) => CashflowForecaster.calculate(
  historicalVariableInflows: [],
  historicalVariableOutflows: [],
  plannedPayments: payments,
  debts: debts,
  savingsGoals: goals,
  currentBaseline: 1000,
  horizon: horizon,
  referenceDate: date ?? DateTime(2026, 10, 3),
);

PlannedPayment payment(
  DateTime next, {
  PaymentFrequency frequency = PaymentFrequency.monthly,
  double amount = 100,
  DateTime? end,
}) => PlannedPayment(
  id: 'payment',
  title: 'Bill',
  amount: amount,
  type: TransactionType.expense,
  categoryId: 'category',
  accountId: 'main',
  startDate: next,
  nextDate: next,
  frequency: frequency,
  endDate: end,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Forecast provider consistency', () {
    final account = Account(
      id: 'main',
      name: 'Main',
      iconCodePoint: 1,
      colorHex: '#000000',
      initialBalance: 1000,
    );

    ProviderContainer containerFor({
      AccountRepository? accounts,
      InMemoryPlannedPaymentAdapter? payments,
      List<Debt> debts = const [],
    }) => ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
        accountRepositoryProvider.overrideWithValue(
          accounts ?? InMemoryAccountAdapter(initial: [account]),
        ),
        debtRepositoryProvider.overrideWithValue(
          InMemoryDebtAdapter(initial: debts),
        ),
        savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
        plannedPaymentRepositoryProvider.overrideWithValue(
          payments ?? InMemoryPlannedPaymentAdapter(),
        ),
        forecastRepositoryProvider.overrideWithValue(InMemoryForecastAdapter()),
      ],
    );

    test(
      'waits for account loading rather than forecasting a zero balance',
      () async {
        final accounts = DelayedAccounts();
        final container = containerFor(accounts: accounts);
        addTearDown(container.dispose);
        final subscription = container.listen(forecastProvider(1), (_, _) {});
        addTearDown(subscription.close);
        final result = container.read(forecastProvider(1).future);
        await Future<void>.delayed(Duration.zero);
        expect(container.read(forecastProvider(1)).isLoading, isTrue);
        accounts.pending.complete([account]);
        expect((await result).currentBaseline, 1000);
      },
    );

    test(
      'refreshes after a schedule edit without needing a transaction',
      () async {
        final now = DateTime.now();
        final bill = payment(DateTime(now.year, now.month, now.day + 1));
        final payments = InMemoryPlannedPaymentAdapter(initial: [bill]);
        final container = containerFor(payments: payments);
        addTearDown(container.dispose);
        final subscription = container.listen(forecastProvider(0), (_, _) {});
        addTearDown(subscription.close);
        expect(
          (await container.read(forecastProvider(0).future)).forecastedOutflow,
          100,
        );
        await container
            .read(plannedPaymentProvider.notifier)
            .updatePlannedPayment(bill.copyWith(amount: 250));
        expect(
          (await container.read(forecastProvider(0).future)).forecastedOutflow,
          250,
        );
      },
    );

    test('excludes debt and schedules attached to excluded accounts', () async {
      final now = DateTime.now();
      final hidden = account.copyWith(id: 'hidden', excludeFromTotal: true);
      final bill = payment(
        DateTime(now.year, now.month, now.day + 1),
      ).copyWith(accountId: 'hidden');
      final container = containerFor(
        accounts: InMemoryAccountAdapter(initial: [account, hidden]),
        payments: InMemoryPlannedPaymentAdapter(initial: [bill]),
        debts: [
          Debt(
            id: 'debt',
            personName: 'Person',
            amount: 500,
            type: DebtType.iOwe,
            accountId: 'hidden',
            startDate: now,
            dueDate: now,
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(forecastProvider(1).future);
      expect(result.currentBaseline, 1000);
      expect(result.forecastedOutflow, 0);
    });
  });
  group('Forecast observation windows', () {
    ForecastHistory history(List<AppTransaction> transactions, DateTime now) =>
        ForecastHistory.fromTransactions(
          transactions: transactions,
          includedAccountIds: {'main'},
          referenceDate: now,
        );

    test('fills idle months and aligns income and expense samples', () {
      final result = history([
        transaction('jan', DateTime(2026, 1, 1), 300),
        transaction(
          'mar',
          DateTime(2026, 3, 4),
          900,
          type: TransactionType.income,
        ),
      ], DateTime(2026, 4, 3));
      expect(result.outflows, [300, 0, 0]);
      expect(result.inflows, [0, 0, 900]);
    });

    test('excludes unfinished current month and future entries', () {
      final result = history([
        transaction('aug', DateTime(2026, 8, 1), 600),
        transaction('sep', DateTime(2026, 9, 1), 600),
        transaction('oct', DateTime(2026, 10, 1), 15),
        transaction('future', DateTime(2026, 11, 1), 50000),
      ], DateTime(2026, 10, 3));
      expect(result.outflows, [600, 600]);
      // Old aggregation produced EMA([600,600,15,50000]) = 25153.75.
      expect(CashflowForecaster.calculateEMA(result.outflows), 600);
    });

    test(
      'excludes linked repayments in both directions and hidden accounts',
      () {
        final result = history([
          transaction('observation', DateTime(2026, 9, 1), 100),
          transaction(
            'repayment',
            DateTime(2026, 9, 2),
            400,
            type: TransactionType.income,
            debtRepaymentId: 'debt',
          ),
          transaction(
            'expense-debt',
            DateTime(2026, 9, 3),
            500,
            debtRepaymentId: 'other',
          ),
          transaction(
            'planned',
            DateTime(2026, 9, 3),
            700,
            plannedPaymentId: 'bill',
          ),
          transaction('hidden', DateTime(2026, 9, 3), 900, accountId: 'hidden'),
        ], DateTime(2026, 10, 3));
        expect(result.outflows, [100]);
        expect(result.inflows, [0]);
      },
    );

    test('normalizes cold-start history after seven complete days', () {
      final transactions = [
        for (var day = 10; day <= 16; day++)
          transaction('$day', DateTime(2026, 10, day), 10),
        transaction('today', DateTime(2026, 10, 17), 1000),
      ];
      expect(history(transactions, DateTime(2026, 10, 17)).outflows, [310]);
      expect(history(transactions, DateTime(2026, 10, 16)).outflows, isEmpty);
    });

    test('omits partial first month when complete months exist', () {
      final result = history([
        transaction('partial', DateTime(2026, 8, 28), 40),
        transaction('full', DateTime(2026, 9, 1), 600),
      ], DateTime(2026, 10, 3));
      expect(result.outflows, [600]);
    });

    test('uses at most twelve recent completed months', () {
      final result = history([
        transaction('old', DateTime(2024, 1, 1), 99999),
        transaction('recent', DateTime(2026, 9, 1), 100),
      ], DateTime(2026, 10, 3));
      expect(result.outflows.length, 12);
      expect(result.outflows.take(11), everyElement(0));
      expect(result.outflows.last, 100);
    });
  });

  group('Dated commitments', () {
    test(
      'weekly forecast counts bills only when due in the next seven days',
      () {
        final result = project(
          horizon: ForecastHorizon.weekly,
          payments: [
            payment(DateTime(2026, 10, 5), amount: 120),
            payment(DateTime(2026, 10, 15), amount: 800),
            payment(DateTime(2026, 10, 10), amount: 900),
          ],
        );
        expect(result.forecastedOutflow, 120);
        expect(result.predictedNetBalance, 880);
      },
    );

    test('includes payments due today despite time of day', () {
      expect(
        project(
          date: DateTime(2026, 10, 3, 23),
          horizon: ForecastHorizon.weekly,
          payments: [payment(DateTime(2026, 10, 3))],
        ).forecastedOutflow,
        100,
      );
    });

    test('stops payments on their inclusive end date', () {
      final result = project(
        horizon: ForecastHorizon.yearly,
        payments: [payment(DateTime(2026, 10, 5), end: DateTime(2026, 11, 5))],
      );
      expect(result.forecastedOutflow, 200);
    });

    test('clamps month-end dates without drifting into March', () {
      final result = project(
        date: DateTime(2027, 1, 31),
        horizon: ForecastHorizon.monthly,
        payments: [payment(DateTime(2027, 1, 31))],
      );
      expect(
        CashflowForecaster.horizonEnd(
          ForecastHorizon.monthly,
          DateTime(2027, 1, 31),
        ),
        DateTime(2027, 2, 28),
      );
      expect(result.forecastedOutflow, 100);
    });

    test('flexible payments do not imply monthly recurrence', () {
      expect(
        project(
          horizon: ForecastHorizon.yearly,
          payments: [
            payment(
              DateTime(2026, 10, 5),
              frequency: PaymentFrequency.flexible,
            ),
          ],
        ).forecastedOutflow,
        100,
      );
    });

    test('lump-sum debt appears once and only when it is due', () {
      final debt = Debt(
        id: 'debt',
        personName: 'Person',
        amount: 600,
        type: DebtType.iOwe,
        startDate: DateTime(2026, 10, 1),
        dueDate: DateTime(2026, 11, 5),
      );
      expect(project(debts: [debt]).forecastedOutflow, 0);
      expect(
        project(
          horizon: ForecastHorizon.yearly,
          debts: [debt],
        ).forecastedOutflow,
        600,
      );
      expect(
        project(
          debts: [debt.copyWith(dueDate: DateTime(2026, 10, 2))],
        ).forecastedOutflow,
        600,
      );
    });

    test('installments respect partial payments and remaining principal', () {
      final debt = Debt(
        id: 'debt',
        personName: 'Person',
        amount: 1000,
        currentAmount: 850,
        totalInstallments: 10,
        type: DebtType.iOwe,
        startDate: DateTime(2026, 2, 5),
      );
      expect(project(debts: [debt]).forecastedOutflow, 50);
      expect(
        project(
          horizon: ForecastHorizon.yearly,
          debts: [debt],
        ).forecastedOutflow,
        150,
      );
    });

    test(
      'itemized debt uses individual start dates and stops completed items',
      () {
        final debt = Debt(
          id: 'debt',
          personName: 'Person',
          amount: 600,
          currentAmount: 200,
          type: DebtType.iOwe,
          startDate: DateTime(2026, 8, 5),
          items: [
            DebtItem(
              id: 'early',
              debtId: 'debt',
              name: 'Early',
              amount: 200,
              totalInstallments: 2,
              firstPaymentDate: DateTime(2026, 8, 5),
            ),
            DebtItem(
              id: 'future',
              debtId: 'debt',
              name: 'Future',
              amount: 400,
              totalInstallments: 4,
              firstPaymentDate: DateTime(2026, 12, 5),
            ),
          ],
        );
        expect(project(debts: [debt]).forecastedOutflow, 0);
        expect(
          project(
            horizon: ForecastHorizon.yearly,
            debts: [debt],
          ).forecastedOutflow,
          400,
        );
      },
    );

    test('savings use reference date and never exceed remaining target', () {
      final goal = SavingsGoal(
        id: 'goal',
        name: 'Goal',
        targetAmount: 1000,
        currentAmount: 700,
        startDate: DateTime(2026, 10, 1),
        endDate: DateTime(2026, 10, 13),
      );
      expect(
        project(
          horizon: ForecastHorizon.weekly,
          goals: [goal],
        ).forecastedOutflow,
        210,
      );
      expect(
        project(
          horizon: ForecastHorizon.yearly,
          goals: [goal],
        ).forecastedOutflow,
        300,
      );
    });

    test('future savings goals do not require funding before their start', () {
      final goal = SavingsGoal(
        id: 'goal',
        name: 'Future',
        targetAmount: 1000,
        startDate: DateTime(2026, 12, 1),
        endDate: DateTime(2027, 1, 1),
      );
      expect(project(goals: [goal]).forecastedOutflow, 0);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/forecasting/forecast_history.dart';

AppTransaction entry(
  String id,
  DateTime date,
  double amount, {
  TransactionType type = TransactionType.expense,
  String? plannedPaymentId,
  String? debtRepaymentId,
}) => AppTransaction(
  id: id,
  accountId: 'cash',
  categoryId: 'category',
  date: date,
  amount: amount,
  type: type,
  plannedPaymentId: plannedPaymentId,
  debtRepaymentId: debtRepaymentId,
);

PlannedPayment schedule({
  PaymentFrequency frequency = PaymentFrequency.flexible,
  DateTime? nextDate,
}) => PlannedPayment(
  id: 'allowance',
  title: 'Income',
  amount: 200,
  type: TransactionType.income,
  accountId: 'cash',
  categoryId: 'category',
  frequency: frequency,
  startDate: DateTime(2026, 9, 25),
  nextDate: nextDate ?? DateTime(2026, 9, 25),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime(2026, 10, 15, 13);
  final entries = [
    entry('first', DateTime(2026, 9, 24), 1400),
    entry('income', DateTime(2026, 9, 25), 800, type: TransactionType.income),
    entry(
      'sep-flex',
      DateTime(2026, 9, 29),
      200,
      type: TransactionType.income,
      plannedPaymentId: 'allowance',
    ),
    entry('oct-spending', DateTime(2026, 10, 10), 1200),
    entry(
      'oct-income',
      DateTime(2026, 10, 11),
      1800,
      type: TransactionType.income,
      plannedPaymentId: 'allowance',
    ),
    entry(
      'other-income',
      DateTime(2026, 10, 14),
      1800,
      type: TransactionType.income,
    ),
    entry('debt', DateTime(2026, 10, 14), 2000, debtRepaymentId: 'repayment'),
    entry('today', DateTime(2026, 10, 15), 9000),
    entry('future', DateTime(2026, 10, 16), 9000),
  ];

  test('cold start uses complete days across the month boundary', () {
    final history = ForecastHistory.fromTransactions(
      transactions: entries,
      includedAccountIds: {'cash'},
      plannedPayments: [schedule()],
      referenceDate: now,
    );
    expect(history.observedDays, 21);
    expect(history.inflows.single, closeTo(4600 * 31 / 21, 0.001));
    expect(history.outflows.single, closeTo(2600 * 31 / 21, 0.001));
  });

  test('recurring linked income stays in the scheduled layer', () {
    final history = ForecastHistory.fromTransactions(
      transactions: entries,
      includedAccountIds: {'cash'},
      plannedPayments: [schedule(frequency: PaymentFrequency.monthly)],
      referenceDate: now,
    );
    expect(history.inflows.single, closeTo(2600 * 31 / 21, 0.001));
  });

  test('cold-start horizons scale daily rates by actual projected days', () {
    final history = ForecastHistory.fromTransactions(
      transactions: entries,
      includedAccountIds: {'cash'},
      plannedPayments: [schedule()],
      referenceDate: now,
    );
    for (final horizon in ForecastHorizon.values) {
      final result = CashflowForecaster.calculate(
        historicalVariableInflows: history.inflows,
        historicalVariableOutflows: history.outflows,
        plannedPayments: [],
        debts: [],
        savingsGoals: [],
        currentBaseline: 1000,
        horizon: horizon,
        referenceDate: now,
        historyDays: history.observedDays,
      );
      final start = DateTime(now.year, now.month, now.day);
      final days = CashflowForecaster.horizonEnd(horizon, now)
          .difference(start).inDays;
      expect(result.forecastedInflow, closeTo(4600 * days / 21, 0.001));
      expect(result.forecastedOutflow, closeTo(2600 * days / 21, 0.001));
    }
  });

  test(
    'complete monthly samples include flexible receipts without run rate',
    () {
      final history = ForecastHistory.fromTransactions(
        transactions: entries,
        includedAccountIds: {'cash'},
        plannedPayments: [schedule()],
        referenceDate: DateTime(2026, 11, 1),
      );
      expect(history.observedDays, isNull);
      expect(history.inflows, [3600]);
      expect(history.outflows, [19200]);
    },
  );

  test('processed flexible date is not counted again as overdue income', () {
    expect(
      ForecastHistory.outstandingPayments(
        payments: [schedule()],
        transactions: entries,
        referenceDate: now,
      ),
      isEmpty,
    );
  });

  test('rescheduled and unprocessed flexible dates remain forecastable', () {
    final next = schedule(nextDate: DateTime(2026, 10, 20));
    expect(
      ForecastHistory.outstandingPayments(
        payments: [next],
        transactions: [
          ...entries,
          entry(
            'future-receipt',
            DateTime(2026, 10, 20),
            200,
            type: TransactionType.income,
            plannedPaymentId: 'allowance',
          ),
        ],
        referenceDate: now,
      ),
      [next],
    );
    final unprocessed = schedule();
    expect(
      ForecastHistory.outstandingPayments(
        payments: [unprocessed],
        transactions: [],
        referenceDate: now,
      ),
      [unprocessed],
    );
  });

  test('recurring next payment is retained after a recorded receipt', () {
    final recurring = schedule(frequency: PaymentFrequency.monthly);
    expect(
      ForecastHistory.outstandingPayments(
        payments: [recurring],
        transactions: entries,
        referenceDate: now,
      ),
      [recurring],
    );
  });

  test(
    'production provider carries cold-start history and removes paid flexible dates',
    () async {
      final today = DateTime.now();
      final firstDay = DateTime(today.year, today.month, today.day - 7);
      final payment = schedule(nextDate: firstDay);
      final container = ProviderContainer(
        overrides: [
          ledgerProvider.overrideWithValue(
            InMemoryLedgerAdapter(
              initial: [
                entry(
                  'receipt',
                  firstDay,
                  200,
                  type: TransactionType.income,
                  plannedPaymentId: 'allowance',
                ),
              ],
            ),
          ),
          accountRepositoryProvider.overrideWithValue(
            InMemoryAccountAdapter(
              initial: [
                Account(
                  id: 'cash',
                  name: 'Cash',
                  iconCodePoint: 1,
                  colorHex: '#000000',
                  initialBalance: 1000,
                ),
              ],
            ),
          ),
          debtRepositoryProvider.overrideWithValue(InMemoryDebtAdapter()),
          savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
          plannedPaymentRepositoryProvider.overrideWithValue(
            InMemoryPlannedPaymentAdapter(initial: [payment]),
          ),
          forecastRepositoryProvider.overrideWithValue(SqliteForecastAdapter()),
        ],
      );
      addTearDown(container.dispose);
      final result = await container.read(forecastProvider(1).future);
      expect(result.historyDays, 7);
      final monthDays = DateTime(today.year, today.month + 1, 0).day;
      expect(result.forecastedInflow, closeTo(200 * monthDays / 7, 0.001));
      expect(result.currentBaseline, 1200);
    },
  );
}

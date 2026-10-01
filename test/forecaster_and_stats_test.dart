import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  group('CashflowForecaster Deep Domain Tests', () {
    test('calculateEMA calculates correct exponential moving average', () {
      expect(CashflowForecaster.calculateEMA([]), 0.0);

      // Single item returns itself
      expect(CashflowForecaster.calculateEMA([100.0]), 100.0);

      // Period 3: alpha = 2 / (3 + 1) = 0.5
      // Series: [100.0, 200.0] -> 200 * 0.5 + 100 * 0.5 = 150.0
      expect(CashflowForecaster.calculateEMA([100.0, 200.0]), 150.0);

      // Series: [100.0, 200.0, 300.0] -> 300 * 0.5 + 150 * 0.5 = 225.0
      expect(CashflowForecaster.calculateEMA([100.0, 200.0, 300.0]), 225.0);
    });

    test(
      'calculatePlannedPaymentsMonthly normalizes frequencies correctly',
      () {
        final now = DateTime(2026, 10, 1);
        final payments = [
          PlannedPayment(
            id: 'pp_1',
            title: 'Daily Coffee',
            amount: 5.0,
            type: TransactionType.expense,
            frequency: PaymentFrequency.daily,
            startDate: DateTime(2026, 1, 1),
            nextDate: DateTime(2026, 10, 2),
            accountId: 'acc_1',
            categoryId: 'cat_coffee',
          ),
          PlannedPayment(
            id: 'pp_2',
            title: 'Monthly Salary',
            amount: 5000.0,
            type: TransactionType.income,
            frequency: PaymentFrequency.monthly,
            startDate: DateTime(2026, 1, 1),
            nextDate: DateTime(2026, 10, 15),
            accountId: 'acc_1',
            categoryId: 'cat_salary',
          ),
          PlannedPayment(
            id: 'pp_3',
            title: 'Expired Subscription',
            amount: 20.0,
            type: TransactionType.expense,
            frequency: PaymentFrequency.monthly,
            startDate: DateTime(2025, 1, 1),
            nextDate: DateTime(2025, 6, 1),
            endDate: DateTime(2026, 1, 1), // Before referenceDate
            accountId: 'acc_1',
            categoryId: 'cat_sub',
          ),
        ];

        final result = CashflowForecaster.calculatePlannedPaymentsMonthly(
          payments: payments,
          referenceDate: now,
        );

        // pp_1: 5 * 30.44 = 152.2
        // pp_3 is expired -> ignored
        expect(result.monthlyOutflow, closeTo(152.2, 0.01));
        // pp_2: 5000.0
        expect(result.monthlyInflow, closeTo(5000.0, 0.01));
      },
    );

    test(
      'calculateDebtsMonthly converts installment frequencies accurately',
      () {
        final debts = [
          Debt(
            id: 'd_1',
            personName: 'Alice',
            amount: 1200.0,
            currentAmount: 200.0,
            type: DebtType.owedToMe,
            frequency: InstallmentFrequency.monthly,
            totalInstallments: 12,
            startDate: DateTime(2026, 1, 1),
          ),
          Debt(
            id: 'd_2',
            personName: 'Bob',
            amount: 500.0,
            currentAmount: 0.0,
            type: DebtType.iOwe,
            frequency: InstallmentFrequency.weekly,
            totalInstallments: 10,
            startDate: DateTime(2026, 1, 1),
          ),
        ];

        final flows = CashflowForecaster.calculateDebtsMonthly(debts: debts);

        // d_1: 1200 / 12 = 100/mo incoming
        expect(flows.monthlyInflow, closeTo(100.0, 0.01));
        // d_2: 500 / 10 = 50/week * (30.44 / 7) = 217.428.../mo outgoing
        expect(flows.monthlyOutflow, closeTo(50.0 * (30.44 / 7), 0.01));
      },
    );

    test(
      'calculate returns projected net balance across different horizons',
      () {
        final forecastMonthly = CashflowForecaster.calculate(
          historicalVariableInflows: [1000.0, 1000.0],
          historicalVariableOutflows: [600.0, 600.0],
          plannedPayments: [],
          debts: [],
          savingsGoals: [],
          currentBaseline: 5000.0,
          horizon: ForecastHorizon.monthly,
        );

        // Net change = 1000 - 600 = +400. Balance = 5400.
        expect(forecastMonthly.forecastedInflow, 1000.0);
        expect(forecastMonthly.forecastedOutflow, 600.0);
        expect(forecastMonthly.predictedNetBalance, 5400.0);
        expect(forecastMonthly.isWarning, false);

        final forecastYearly = CashflowForecaster.calculate(
          historicalVariableInflows: [1000.0, 1000.0],
          historicalVariableOutflows: [600.0, 600.0],
          plannedPayments: [],
          debts: [],
          savingsGoals: [],
          currentBaseline: 5000.0,
          horizon: ForecastHorizon.yearly,
        );

        // Yearly scale factor: 12.0
        expect(forecastYearly.forecastedInflow, 12000.0);
        expect(forecastYearly.forecastedOutflow, 7200.0);
        expect(forecastYearly.predictedNetBalance, 5000.0 + 4800.0);
        expect(forecastYearly.isWarning, false);
      },
    );
  });

  group('DashboardStats.calculate Domain Tests', () {
    test('calculates balances, net worth, and honors excluded accounts', () {
      final accounts = [
        Account(
          id: 'acc_main',
          name: 'Main Wallet',
          initialBalance: 1000.0,
          excludeFromTotal: false,
          iconCodePoint: 1,
          colorHex: '#000000',
        ),
        Account(
          id: 'acc_secret',
          name: 'Hidden Stash',
          initialBalance: 5000.0,
          excludeFromTotal: true,
          iconCodePoint: 2,
          colorHex: '#000000',
        ),
      ];

      final transactions = [
        AppTransaction(
          id: 'tx_1',
          amount: 200.0,
          date: DateTime(2026, 10, 1),
          type: TransactionType.income,
          categoryId: 'cat_salary',
          accountId: 'acc_main',
        ),
        AppTransaction(
          id: 'tx_2',
          amount: 50.0,
          date: DateTime(2026, 10, 1),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          accountId: 'acc_main',
        ),
        AppTransaction(
          id: 'tx_3',
          amount: 100.0,
          date: DateTime(2026, 10, 1),
          type: TransactionType.expense,
          categoryId: 'cat_food',
          accountId:
              'acc_secret', // Should not affect currentBalance or catSpending
        ),
      ];

      final stats = DashboardStats.calculate(
        accounts: accounts,
        transactions: transactions,
      );

      expect(stats.totalIncome, 200.0);
      expect(stats.totalExpense, 50.0);
      // Main balance: 1000 + 200 - 50 = 1150
      expect(stats.accountBalances['acc_main'], 1150.0);
      // Secret balance: 5000 - 100 = 4900
      expect(stats.accountBalances['acc_secret'], 4900.0);
      // Current net balance only includes acc_main
      expect(stats.currentBalance, 1150.0);
      // Category spending only tracks included accounts
      expect(stats.categorySpending['cat_food'], 50.0);
    });

    test(
      'internal transfer between included and excluded pool mutates net total',
      () {
        final accounts = [
          Account(
            id: 'acc_in',
            name: 'Included Account',
            initialBalance: 1000.0,
            excludeFromTotal: false,
            iconCodePoint: 1,
            colorHex: '#000000',
          ),
          Account(
            id: 'acc_out',
            name: 'Excluded Account',
            initialBalance: 500.0,
            excludeFromTotal: true,
            iconCodePoint: 2,
            colorHex: '#000000',
          ),
        ];

        // Transfer from included to excluded -> counts as expense from user's visible net pool
        final tx = AppTransaction(
          id: 'tx_transfer',
          amount: 300.0,
          date: DateTime(2026, 10, 1),
          type: TransactionType.transfer,
          categoryId: 'cat_others',
          accountId: 'acc_in',
          toAccountId: 'acc_out',
        );

        final stats = DashboardStats.calculate(
          accounts: accounts,
          transactions: [tx],
        );

        expect(stats.totalExpense, 300.0);
        expect(stats.accountBalances['acc_in'], 700.0);
        expect(stats.accountBalances['acc_out'], 800.0);
        expect(stats.currentBalance, 700.0);
      },
    );
  });

  group('Atomic Transfer & Seam Tests', () {
    test(
      'InMemoryLedgerAdapter records transfer with optional fee atomically',
      () async {
        final ledger = InMemoryLedgerAdapter();

        final transferTx = AppTransaction(
          id: 'tx_transfer_1',
          amount: 500.0,
          date: DateTime(2026, 10, 1),
          type: TransactionType.transfer,
          categoryId: 'cat_others',
          accountId: 'acc_bank',
          toAccountId: 'acc_cash',
        );

        final feeTx = AppTransaction(
          id: 'tx_fee_1',
          amount: 15.0,
          date: DateTime(2026, 10, 1),
          type: TransactionType.expense,
          categoryId: 'cat_others',
          accountId: 'acc_bank',
          note: 'Transfer Fee',
        );

        final result = await ledger.recordTransfer(
          transferTransaction: transferTx,
          feeTransaction: feeTx,
        );

        expect(result.hasFee, true);
        expect(result.transferTransaction.id, 'tx_transfer_1');
        expect(result.feeTransaction?.id, 'tx_fee_1');

        final allTxs = await ledger.getTransactions();
        expect(allTxs.length, 2);
      },
    );
  });
}

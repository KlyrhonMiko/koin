import 'package:flutter_test/flutter_test.dart';
import 'package:koin/koin.dart';

void main() {

  TestWidgetsFlutterBinding.ensureInitialized();

  group('AccountRepository Seam & InMemory Adapter', () {
    test('inserts, orders by position, updates, and deletes accounts', () async {
      final repo = InMemoryAccountAdapter(initial: [
        Account(id: 'acc_1', name: 'Cash', iconCodePoint: 1, colorHex: '#000', position: 1),
        Account(id: 'acc_2', name: 'Bank', iconCodePoint: 2, colorHex: '#111', position: 0),
      ]);

      var accounts = await repo.getAccounts();
      expect(accounts.length, 2);
      expect(accounts.first.name, 'Bank'); // position 0 first
      expect(accounts.last.name, 'Cash'); // position 1 second

      // Insert new account
      final newAcc = Account(
        id: 'acc_3',
        name: 'Savings',
        iconCodePoint: 3,
        colorHex: '#222',
        position: 2,
      );
      await repo.insertAccount(newAcc);
      accounts = await repo.getAccounts();
      expect(accounts.length, 3);
      expect(accounts.last.name, 'Savings');

      // Update account
      await repo.updateAccount(newAcc.copyWith(name: 'High Yield Savings'));
      accounts = await repo.getAccounts();
      expect(accounts.last.name, 'High Yield Savings');

      // Reorder positions
      await repo.updateAccountPositions([
        accounts[2].copyWith(position: 0),
        accounts[0].copyWith(position: 1),
        accounts[1].copyWith(position: 2),
      ]);
      accounts = await repo.getAccounts();
      expect(accounts.first.name, 'High Yield Savings');

      // Delete account
      await repo.deleteAccount('acc_3');
      accounts = await repo.getAccounts();
      expect(accounts.length, 2);
      expect(accounts.any((a) => a.id == 'acc_3'), isFalse);
    });
  });

  group('CategoryRepository Seam & InMemory Adapter', () {
    test('manages categories, positions, and CRUD correctly', () async {
      final repo = InMemoryCategoryAdapter(initial: [
        TransactionCategory(
          id: 'cat_1',
          name: 'Food',
          iconCodePoint: 10,
          colorHex: '#FF0',
          type: TransactionType.expense,
          position: 0,
        ),
      ]);

      var categories = await repo.getCategories();
      expect(categories.length, 1);
      expect(categories.first.name, 'Food');

      // Insert
      final cat2 = TransactionCategory(
        id: 'cat_2',
        name: 'Salary',
        iconCodePoint: 20,
        colorHex: '#0F0',
        type: TransactionType.income,
        position: 1,
      );
      await repo.insertCategory(cat2);
      categories = await repo.getCategories();
      expect(categories.length, 2);

      // Update
      await repo.updateCategory(cat2.copyWith(name: 'Bonus'));
      categories = await repo.getCategories();
      expect(categories.any((c) => c.name == 'Bonus'), isTrue);

      // Delete
      await repo.deleteCategory('cat_1');
      categories = await repo.getCategories();
      expect(categories.length, 1);
      expect(categories.first.id, 'cat_2');
    });
  });

  group('DebtRepository Seam & InMemory Adapter', () {
    test('persists debts, handles itemized obligations and repayment mutations', () async {
      final repo = InMemoryDebtAdapter(initial: [
        Debt(
          id: 'debt_1',
          personName: 'Alice',
          amount: 500.0,
          currentAmount: 100.0,
          startDate: DateTime(2026, 1, 1),
          type: DebtType.owedToMe,
          sortOrder: 0,
        ),
      ]);

      var debts = await repo.getDebts();
      expect(debts.length, 1);
      expect(debts.first.personName, 'Alice');
      expect(debts.first.remainingAmount, 400.0);

      // Add sub-item
      final item = DebtItem(
        id: 'item_1',
        debtId: 'debt_1',
        name: 'Concert Ticket',
        amount: 150.0,
        totalInstallments: 1,
        firstPaymentDate: DateTime(2026, 1, 2),
      );
      await repo.insertDebtItem(item);
      debts = await repo.getDebts();
      expect(debts.first.items.length, 1);
      expect(debts.first.items.first.name, 'Concert Ticket');

      // Add repayment
      final repayment = DebtRepayment(
        id: 'rep_1',
        debtId: 'debt_1',
        amount: 200.0,
        date: DateTime(2026, 1, 10),
      );
      await repo.insertDebtRepayment(repayment);
      debts = await repo.getDebts();
      expect(debts.first.currentAmount, 300.0);
      expect(debts.first.remainingAmount, 200.0);

      final repayments = await repo.getDebtRepayments('debt_1');
      expect(repayments.length, 1);
      expect(repayments.first.amount, 200.0);

      // Debt increase repayment
      final increase = DebtRepayment(
        id: 'rep_2',
        debtId: 'debt_1',
        amount: 100.0,
        date: DateTime(2026, 1, 15),
        isIncrease: true,
      );
      await repo.insertDebtRepayment(increase);
      debts = await repo.getDebts();
      expect(debts.first.amount, 600.0);

      // Delete item
      await repo.deleteDebtItem(item);
      debts = await repo.getDebts();
      expect(debts.first.items.isEmpty, isTrue);

      // Delete debt
      await repo.deleteDebt('debt_1');
      debts = await repo.getDebts();
      expect(debts.isEmpty, isTrue);
    });
  });

  group('PlannedPaymentRepository Seam & InMemory Adapter', () {
    test('persists schedules, handles queries and CRUD', () async {
      final repo = InMemoryPlannedPaymentAdapter();
      final schedule = PlannedPayment(
        id: 'pp_1',
        title: 'Internet Bill',
        amount: 60.0,
        type: TransactionType.expense,
        frequency: PaymentFrequency.monthly,
        startDate: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 2, 1),
        categoryId: 'cat_bills',
        accountId: 'acc_1',
      );


      await repo.insertPlannedPayment(schedule);
      var list = await repo.getPlannedPayments();
      expect(list.length, 1);
      expect(list.first.title, 'Internet Bill');

      await repo.updatePlannedPayment(schedule.copyWith(amount: 75.0));
      list = await repo.getPlannedPayments();
      expect(list.first.amount, 75.0);

      final unexcluded = await repo.getUnexcludedPlannedPayments();
      expect(unexcluded.length, 1);

      await repo.deletePlannedPayment('pp_1');
      list = await repo.getPlannedPayments();
      expect(list.isEmpty, isTrue);
    });
  });

  group('SavingsRepository Seam & InMemory Adapter', () {
    test('tracks goals and updates balances on log mutations and deletions', () async {
      final repo = InMemorySavingsAdapter();
      final goal = SavingsGoal(
        id: 'goal_1',
        name: 'New Laptop',
        targetAmount: 2000.0,
        currentAmount: 500.0,
        startDate: DateTime(2026, 1, 1),
      );

      await repo.insertSavingsGoal(goal);
      var goals = await repo.getSavingsGoals();
      expect(goals.length, 1);
      expect(goals.first.currentAmount, 500.0);

      // Add log
      final log1 = SavingsLog(
        id: 'log_1',
        goalId: 'goal_1',
        amount: 250.0,
        date: DateTime(2026, 1, 15),
      );
      await repo.insertSavingsLog(log1);
      goals = await repo.getSavingsGoals();
      expect(goals.first.currentAmount, 750.0);

      var logs = await repo.getSavingsLogs('goal_1');
      expect(logs.length, 1);

      // Update log (adjust amount to 300)
      final updatedLog1 = SavingsLog(
        id: log1.id,
        goalId: log1.goalId,
        amount: 300.0,
        date: log1.date,
      );
      await repo.updateSavingsLog(log1, updatedLog1);
      goals = await repo.getSavingsGoals();
      expect(goals.first.currentAmount, 800.0);

      // Delete log (rolls back 300)
      await repo.deleteSavingsLog(updatedLog1);
      goals = await repo.getSavingsGoals();
      expect(goals.first.currentAmount, 500.0);
    });
  });

  group('ForecastRepository Seam & InMemory Adapter', () {
    test('returns deterministic variable cashflows and schedules', () async {
      final repo = InMemoryForecastAdapter(
        inflows: [1000.0, 1200.0],
        outflows: [800.0, 950.0],
        plannedPayments: [
          PlannedPayment(
            id: 'pp_f',
            title: 'Salary',
            amount: 3000.0,
            type: TransactionType.income,
            frequency: PaymentFrequency.monthly,
            startDate: DateTime(2026, 1, 1),
            nextDate: DateTime(2026, 2, 1),
            categoryId: 'cat_salary',
            accountId: 'acc_1',
          ),

        ],
      );

      final inflows = await repo.getHistoricalVariableInflows();
      final outflows = await repo.getHistoricalVariableOutflows();
      final pp = await repo.getUnexcludedPlannedPayments();

      expect(inflows, [1000.0, 1200.0]);
      expect(outflows, [800.0, 950.0]);
      expect(pp.length, 1);
      expect(pp.first.title, 'Salary');
    });
  });

  group('AppMaintenanceService Seam & InMemory Adapter', () {
    test('coordinates maintenance operations deterministically', () async {
      final maintenance = InMemoryMaintenanceAdapter();

      final backup = await maintenance.createBackup();
      expect(backup, isNotNull);
      expect(backup!.fileName, 'koin_backup_test');

      final restored = await maintenance.restoreBackup('dummy/path.db');
      expect(restored, isTrue);

      await maintenance.clearTransactions();
      expect(maintenance.clearedTransactions, isTrue);

      await maintenance.clearAllData();
      expect(maintenance.clearedAllData, isTrue);

      await maintenance.factoryReset();
      expect(maintenance.factoryResetDone, isTrue);
    });
  });

  group('TransferDraft Deep Domain Model', () {
    final now = DateTime(2026, 2, 1);

    test('validates required fields, account uniqueness, and amount boundaries', () {
      // Missing fields
      final draftMissing = TransferDraft(
        sourceAccountId: '',
        destinationAccountId: 'acc_dest',
        rawAmount: 100.0,
        date: now,
      );
      expect(
        draftMissing.validate(),
        TransferDraftValidationError.missingRequiredFields,
      );

      // Same account
      final draftSame = TransferDraft(
        sourceAccountId: 'acc_1',
        destinationAccountId: 'acc_1',
        rawAmount: 100.0,
        date: now,
      );
      expect(draftSame.validate(), TransferDraftValidationError.sameAccount);

      // Non-positive amount
      final draftInvalidAmount = TransferDraft(
        sourceAccountId: 'acc_1',
        destinationAccountId: 'acc_2',
        rawAmount: 0.0,
        date: now,
      );
      expect(
        draftInvalidAmount.validate(),
        TransferDraftValidationError.invalidAmount,
      );

      // Fee exceeds amount
      final draftFeeTooHigh = TransferDraft(
        sourceAccountId: 'acc_1',
        destinationAccountId: 'acc_2',
        rawAmount: 50.0,
        enteredFee: 60.0,
        date: now,
      );
      expect(
        draftFeeTooHigh.validate(),
        TransferDraftValidationError.feeExceedsAmount,
      );

      // Valid draft
      final validDraft = TransferDraft(
        sourceAccountId: 'acc_1',
        destinationAccountId: 'acc_2',
        rawAmount: 200.0,
        enteredFee: 5.0,
        note: 'Rent split',
        date: now,
      );
      expect(validDraft.validate(), isNull);
    });

    test('computes fee, net amount, and builds transfer & fee transactions atomically', () {
      final accountWithPercentageFee = Account(
        id: 'acc_1',
        name: 'Checking',
        iconCodePoint: 1,
        colorHex: '#000',
        transferFeeAmount: 2.0, // 2%
        isTransferFeePercentage: true,
      );

      final draft = TransferDraft(
        sourceAccountId: 'acc_1',
        destinationAccountId: 'acc_2',
        rawAmount: 500.0,
        enteredFee: 2.0,
        isFeePercentage: true,
        note: 'Savings Transfer',
        date: now,
      );

      final fee = draft.calculateFeeAmount(accountWithPercentageFee);
      expect(fee, 10.0); // 2% of 500

      final net = draft.calculateNetAmount(accountWithPercentageFee);
      expect(net, 490.0);

      final transactions = draft.buildTransactions(
        existingId: 'custom_id',
        sourceAccount: accountWithPercentageFee,
      );

      expect(transactions.transferTransaction.id, 'custom_id');
      expect(transactions.transferTransaction.amount, 490.0);
      expect(transactions.transferTransaction.type, TransactionType.transfer);
      expect(transactions.transferTransaction.toAccountId, 'acc_2');

      expect(transactions.feeTransaction, isNotNull);
      expect(transactions.feeTransaction!.amount, 10.0);
      expect(transactions.feeTransaction!.type, TransactionType.expense);
      expect(transactions.feeTransaction!.accountId, 'acc_1');
      expect(transactions.feeTransaction!.note, 'Transfer Fee: Savings Transfer');
    });
  });

  group('ReportSummary and ReportService Pipeline', () {
    test('calculates accurate aggregate metrics for reporting', () {
      final txList = [
        AppTransaction(
          id: 't1',
          amount: 1500.0,
          date: DateTime(2026, 1, 1),
          type: TransactionType.income,
          categoryId: 'salary',
          accountId: 'bank',
        ),
        AppTransaction(
          id: 't2',
          amount: 400.0,
          date: DateTime(2026, 1, 2),
          type: TransactionType.expense,
          categoryId: 'groceries',
          accountId: 'bank',
        ),
        AppTransaction(
          id: 't3',
          amount: 100.0,
          date: DateTime(2026, 1, 3),
          type: TransactionType.expense,
          categoryId: 'utilities',
          accountId: 'cash',
        ),
      ];

      final summary = ReportSummary.fromTransactions(txList);
      expect(summary.totalIncome, 1500.0);
      expect(summary.totalExpense, 500.0);
      expect(summary.netBalance, 1000.0);
    });

    test('generateReport generates valid CSV payload with header and data rows', () async {
      final categories = <TransactionCategory>[
        TransactionCategory(
          id: 'c1',
          name: 'Food',
          iconCodePoint: 1,
          colorHex: '#000',
          type: TransactionType.expense,
        ),
      ];
      final accounts = <Account>[
        Account(id: 'a1', name: 'Wallet', iconCodePoint: 1, colorHex: '#000'),
      ];
      final transactions = <AppTransaction>[
        AppTransaction(
          id: 't1',
          amount: 25.5,
          date: DateTime(2026, 1, 5, 12, 30),
          type: TransactionType.expense,
          categoryId: 'c1',
          accountId: 'a1',
          note: 'Lunch with team',
        ),
      ];

      final payload = await ReportService.generateReport(
        transactions: transactions,
        categories: categories,
        accounts: accounts,
        currencySymbol: '\$',
        isPdf: false,
        timestamp: DateTime(2026, 1, 5),
      );

      expect(payload.extension, 'csv');
      expect(payload.fileName, 'Koin_Report_20260105_000000.csv');
      expect(payload.bytes.isNotEmpty, isTrue);

      final content = String.fromCharCodes(payload.bytes);
      expect(content.contains('Date,Amount,Type,Category,Account,To Account,Note'), isTrue);
      expect(content.contains('25.5'), isTrue);
      expect(content.contains('Lunch with team'), isTrue);
    });
  });

  group('DebtRepository saveDebtWithItems & DebtSummary Domain Tests', () {
    test('saveDebtWithItems synchronizes parent debt and items atomically', () async {
      final repo = InMemoryDebtAdapter();
      final debt = Debt(
        id: 'debt_1',
        personName: 'Bob',
        amount: 250.0,
        type: DebtType.iOwe,
        startDate: DateTime(2026, 1, 1),
        totalInstallments: 3,
      );
      final item1 = DebtItem(
        id: 'item_1',
        debtId: 'debt_1',
        name: 'Headphones',
        amount: 150.0,
        totalInstallments: 2,
        firstPaymentDate: DateTime(2026, 1, 1),
      );
      final item2 = DebtItem(
        id: 'item_2',
        debtId: 'debt_1',
        name: 'Keyboard',
        amount: 100.0,
        totalInstallments: 1,
        firstPaymentDate: DateTime(2026, 1, 15),
      );

      await repo.saveDebtWithItems(debt, [item1, item2]);
      var debts = await repo.getDebts();
      expect(debts.length, 1);
      expect(debts.first.items.length, 2);

      // Remove item1, update item2, and add item3
      final updatedItem2 = item2.copyWith(amount: 120.0);
      final item3 = DebtItem(
        id: 'item_3',
        debtId: 'debt_1',
        name: 'Mouse',
        amount: 80.0,
        totalInstallments: 1,
        firstPaymentDate: DateTime(2026, 2, 1),
      );
      final updatedDebt = debt.copyWith(amount: 200.0);

      await repo.saveDebtWithItems(updatedDebt, [updatedItem2, item3]);
      debts = await repo.getDebts();
      expect(debts.first.amount, 200.0);
      expect(debts.first.items.length, 2);
      expect(debts.first.items.any((i) => i.id == 'item_1'), isFalse);
      expect(debts.first.items.firstWhere((i) => i.id == 'item_2').amount, 120.0);
      expect(debts.first.items.any((i) => i.id == 'item_3'), isTrue);
    });

    test('DebtSummary accurately computes net balance, active loans, and overdue counts', () {
      final now = DateTime(2026, 6, 1);
      final debts = [
        Debt(
          id: 'd1',
          personName: 'Alice',
          amount: 500.0,
          currentAmount: 200.0, // remaining 300
          type: DebtType.owedToMe,
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 5, 1), // overdue
          totalInstallments: 5,
        ),
        Debt(
          id: 'd2',
          personName: 'Bank',
          amount: 200.0,
          currentAmount: 50.0, // remaining 150
          type: DebtType.iOwe,
          startDate: DateTime(2026, 2, 1),
          dueDate: DateTime(2026, 7, 1), // not overdue
          totalInstallments: 4,
        ),
        Debt(
          id: 'd3',
          personName: 'Charlie',
          amount: 100.0,
          currentAmount: 100.0, // settled
          type: DebtType.owedToMe,
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 4, 1),
        ),
      ];

      final summary = DebtSummary.calculate(debts, now: now);

      // net = +300 (owedToMe) - 150 (iOwe) = 150
      expect(summary.netBalance, 150.0);
      expect(summary.totalOwedToMe, 300.0);
      expect(summary.totalIOwe, 150.0);
      expect(summary.totalRepaid, 350.0); // 200 + 50 + 100
      expect(summary.totalOriginalPrincipal, 800.0);
      expect(summary.activeCount, 2);
      expect(summary.settledCount, 1);
      expect(summary.overdueCount, 1); // d1 is overdue, d3 settled doesn't count as active overdue
      expect(summary.isNegative, isFalse);
    });
  });

  group('UpcomingTimeline Domain Tests', () {
    test('UpcomingTimeline merges payments and debt installments into sorted timeline', () {
      final now = DateTime(2026, 6, 1);
      final payments = [
        PlannedPayment(
          id: 'p1',
          title: 'Internet',
          amount: 60.0,
          type: TransactionType.expense,
          categoryId: 'c1',
          accountId: 'a1',
          startDate: DateTime(2026, 1, 1),
          nextDate: DateTime(2026, 6, 10),
          frequency: PaymentFrequency.monthly,
        ),
        PlannedPayment(
          id: 'p2',
          title: 'Salary',
          amount: 3000.0,
          type: TransactionType.income,
          categoryId: 'c2',
          accountId: 'a1',
          startDate: DateTime(2026, 1, 1),
          nextDate: DateTime(2026, 6, 5),
          frequency: PaymentFrequency.monthly,
        ),
      ];

      final debts = [
        Debt(
          id: 'd1',
          personName: 'Car Loan',
          amount: 1200.0,
          currentAmount: 200.0,
          type: DebtType.iOwe,
          startDate: DateTime(2026, 1, 1),
          dueDate: DateTime(2026, 6, 2),
          totalInstallments: 12,
        ),
      ];

      final timeline = UpcomingTimeline.calculate(
        payments: payments,
        debts: debts,
        now: now,
      );

      expect(timeline.length, 3);
      // Sorted chronologically: d1 (June 2), p2 (June 5), p1 (June 10)
      expect(timeline.entries[0].id, 'd1');
      expect(timeline.entries[0].isDebt, isTrue);
      expect(timeline.entries[0].amount, 100.0); // 1200 / 12
      expect(timeline.entries[0].isExpense, isTrue);

      expect(timeline.entries[1].id, 'p2');
      expect(timeline.entries[1].isPayment, isTrue);
      expect(timeline.entries[1].isExpense, isFalse);

      expect(timeline.entries[2].id, 'p1');
      expect(timeline.entries[2].isPayment, isTrue);
      expect(timeline.entries[2].isExpense, isTrue);

      expect(timeline.take(2).length, 2);
      expect(timeline.totalExpenseDue, 160.0); // 100 debt + 60 internet
      expect(timeline.totalIncomeDue, 3000.0);
    });

    test('UpcomingEntry formats due status accurately', () {
      final now = DateTime(2026, 6, 10);
      final todayEntry = UpcomingEntry(
        id: '1',
        title: 'Rent',
        amount: 1000,
        dueDate: DateTime(2026, 6, 10),
        isExpense: true,
        kind: UpcomingEntryKind.plannedPayment,
      );
      final tomorrowEntry = UpcomingEntry(
        id: '2',
        title: 'Water',
        amount: 40,
        dueDate: DateTime(2026, 6, 11),
        isExpense: true,
        kind: UpcomingEntryKind.plannedPayment,
      );
      final overdueEntry = UpcomingEntry(
        id: '3',
        title: 'Electricity',
        amount: 80,
        dueDate: DateTime(2026, 6, 8),
        isExpense: true,
        kind: UpcomingEntryKind.plannedPayment,
      );

      expect(todayEntry.formattedDueStatus(now), 'Due today');
      expect(tomorrowEntry.formattedDueStatus(now), 'Due tomorrow');
      expect(overdueEntry.formattedDueStatus(now), '2d overdue');
      expect(overdueEntry.isOverdue(now), isTrue);
    });
  });

  group('Account & SavingsSummary Domain Tests', () {
    test('Account.computeAdjustedInitialBalance calculates correct offset', () {
      final account = Account(
        id: 'acc_1',
        name: 'Checking',
        iconCodePoint: 123,
        colorHex: '#00FF00',
        initialBalance: 500.0,
      );

      // If current balance with transactions is 450, but user sets target balance to 600,
      // difference is +150, so new initialBalance must be 500 + 150 = 650.
      final adjusted = account.computeAdjustedInitialBalance(
        targetBalance: 600.0,
        currentBalance: 450.0,
      );
      expect(adjusted, 650.0);
    });

    test('SavingsSummary computes totals, progress percentage, and goal statuses', () {
      final goals = [
        SavingsGoal(
          id: 'g1',
          name: 'Vacation',
          currentAmount: 400.0,
          targetAmount: 1000.0,
          startDate: DateTime(2026, 1, 1),
        ),
        SavingsGoal(
          id: 'g2',
          name: 'Rainy Day Stash',
          currentAmount: 600.0,
          startDate: DateTime(2026, 1, 1),
          isStash: true,
        ),
        SavingsGoal(
          id: 'g3',
          name: 'New Phone',
          currentAmount: 1000.0,
          targetAmount: 1000.0,
          startDate: DateTime(2026, 1, 1),
        ),
      ];

      final summary = SavingsSummary.calculate(goals);

      expect(summary.totalSaved, 2000.0); // 400 + 600 + 1000
      expect(summary.totalTarget, 2000.0); // 1000 (g1) + 1000 (g3)
      expect(summary.overallProgress, 1.0);
      expect(summary.overallPercent, 100);
      expect(summary.totalGoalsCount, 3);
      expect(summary.activeGoalsCount, 1); // g1 active, g2 is stash, g3 is completed
      expect(summary.stashesCount, 1);
      expect(summary.completedGoalsCount, 1);
    });
  });
}


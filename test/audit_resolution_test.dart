import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/database_version.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper.instance;
  late Directory directory;
  late Database db;
  late SavingsSpendingApprovals approvals;
  late SqliteLedgerAdapter ledger;
  final date = DateTime(2026, 1, 1);

  Debt debt({double total = 100, double paid = 0}) => Debt(
    id: 'debt',
    personName: 'Friend',
    amount: total,
    currentAmount: paid,
    type: DebtType.iOwe,
    startDate: date,
    totalInstallments: 3,
  );
  AppTransaction expense({String id = 'expense', double amount = 600}) =>
      AppTransaction(
        id: id,
        amount: amount,
        date: date,
        type: TransactionType.expense,
        accountId: 'default_account',
        categoryId: 'cat_others',
      );

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('koin_resolution_');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await helper.database;
    await db.update('accounts', {'initialBalance': 1000});
    approvals = SavingsSpendingApprovals();
    ledger = SqliteLedgerAdapter(savingsApprovals: approvals);
    await helper.insertSavingsGoal(
      SavingsGoal(
        id: 'goal',
        name: 'Reserve',
        startDate: date,
        linkedAccountId: 'default_account',
        isStash: true,
      ),
    );
    await helper.insertSavingsLog(
      SavingsLog(id: 'deposit', goalId: 'goal', amount: 500, date: date),
    );
  });
  tearDown(() async {
    await helper.close();
    expect(
      directory.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      true,
    );
    await directory.delete(recursive: true);
  });
  Future<double> saved() async =>
      (await helper.getSavingsGoals()).single.currentAmount;
  void approve({
    String id = 'expense',
    int debit = 60000,
    int release = 10000,
  }) => approvals.approve(
    id,
    SavingsSpendingApproval(
      accountId: 'default_account',
      debitCents: debit,
      goalCents: {'goal': release},
    ),
  );

  test('consent interrupted before save never changes savings', () async {
    approve();
    await helper.close();
    expect(await saved(), 500);
    expect(await helper.getTransactions(), isEmpty);
    expect(await helper.getSavingsLogs('goal'), hasLength(1));
  });
  test('expense and authorized release commit and delete together', () async {
    approve();
    await ledger.recordTransaction(expense());
    expect(await saved(), 400);
    expect(await helper.getTransactions(), hasLength(1));
    await ledger.voidTransaction('expense');
    expect(await saved(), 500);
    expect(await helper.getSavingsLogs('goal'), hasLength(1));
  });
  test(
    'savings balance aggregates incoming transfers and effective dates',
    () async {
      for (final tx in [
        expense(id: 'incoming', amount: 100).copyWith(
          type: TransactionType.transfer,
          accountId: 'bank_account',
          toAccountId: 'default_account',
        ),
        expense(id: 'earlier', amount: 25),
        expense(id: 'future', amount: 10000).copyWith(
          type: TransactionType.income,
          date: DateTime.now().add(const Duration(days: 1)),
        ),
      ]) {
        await db.insert('transactions', tx.toMap());
      }
      approve(debit: 65000, release: 7500);
      await ledger.recordTransaction(expense(amount: 650));
      expect(await saved(), 425);
      expect(await helper.getTransactions(), hasLength(4));
      await ledger.voidTransaction('expense');
      expect(await saved(), 500);
    },
  );
  test('failed expense rolls back its savings release', () async {
    approve();
    await db.execute(
      "CREATE TRIGGER reject_expense BEFORE INSERT ON transactions BEGIN SELECT RAISE(ABORT, 'write failed'); END",
    );
    await expectLater(ledger.recordTransaction(expense()), throwsA(anything));
    expect(await saved(), 500);
    expect(await helper.getSavingsLogs('goal'), hasLength(1));
    expect(await db.query('savings_spending_links'), isEmpty);
  });
  test('failed transfer fee rolls back transfer and savings', () async {
    approve(id: 'transfer');
    await db.execute(
      "CREATE TRIGGER reject_fee BEFORE INSERT ON transactions WHEN NEW.transferId IS NOT NULL BEGIN SELECT RAISE(ABORT, 'fee failed'); END",
    );
    await expectLater(
      ledger.recordTransfer(
        transferTransaction: expense(
          id: 'transfer',
          amount: 590,
        ).copyWith(type: TransactionType.transfer, toAccountId: 'bank_account'),
        feeTransaction: expense(id: 'fee', amount: 10),
      ),
      throwsA(anything),
    );
    expect(await saved(), 500);
    expect(await helper.getTransactions(), isEmpty);
  });
  test(
    'changed consent and spending without consent cannot consume savings',
    () async {
      approve(debit: 59000);
      await expectLater(
        ledger.recordTransaction(expense()),
        throwsA(isA<FinancialValidationException>()),
      );
      approvals.clear('expense');
      await expectLater(
        ledger.recordTransaction(expense()),
        throwsA(isA<FinancialValidationException>()),
      );
      expect(await saved(), 500);
    },
  );
  test('upgrade repairs old orphan releases but preserves deposits', () async {
    await helper.insertSavingsLogs([
      SavingsLog(
        id: 'interrupted',
        goalId: 'goal',
        amount: -100,
        date: date,
        transactionId: 'missing',
      ),
    ], spendingAmount: 600);
    await db.setVersion(46);
    await helper.close();
    expect(await saved(), 500);
    expect(await helper.getSavingsLogs('goal'), hasLength(1));
    expect(await (await helper.database).getVersion(), databaseSchemaVersion);
  });
  test('rounded installments advance and allocate the final cent', () {
    expect(debt().upcomingPaymentAmount, 33.33);
    expect(debt(paid: 33.33).upcomingPaymentAmount, 33.33);
    expect(debt(paid: 33.33).nextDueDate, DateTime(2026, 2, 1));
    expect(debt(paid: 66.66).upcomingPaymentAmount, 33.34);
    expect(debt(paid: 66.66).nextDueDate, DateTime(2026, 3, 1));
    expect(debt(paid: 100).upcomingPaymentAmount, 0);
    expect(debt(paid: 33).upcomingPaymentAmount, closeTo(.33, .000001));
    expect(debt(paid: 33).upcomingPayment(decimalDigits: 0), 33);
    expect(
      debt(paid: 33).nextPaymentDate(decimalDigits: 0),
      DateTime(2026, 2, 1),
    );
  });
  test(
    'failed debt expense rolls back payment, balance and savings together',
    () async {
      await helper.insertDebt(debt(total: 1000));
      approve();
      await db.execute(
        "CREATE TRIGGER reject_debt_expense BEFORE INSERT ON transactions BEGIN SELECT RAISE(ABORT, 'write failed'); END",
      );
      await expectLater(
        ledger.recordDebtRepayment(
          debt: debt(total: 1000),
          repayment: DebtRepayment(
            id: 'payment',
            debtId: 'debt',
            amount: 600,
            date: date,
            accountId: 'default_account',
          ),
          categoryId: 'cat_others',
          transactionId: 'expense',
        ),
        throwsA(anything),
      );
      expect((await helper.getDebts()).single.currentAmount, 0);
      expect(await helper.getDebtRepayments('debt'), isEmpty);
      expect(await saved(), 500);
      expect(await helper.getTransactions(), isEmpty);
    },
  );

  test(
    'failed scheduled expense does not advance or release savings',
    () async {
      final payment = PlannedPayment(
        id: 'schedule',
        title: 'Bill',
        amount: 600,
        type: TransactionType.expense,
        categoryId: 'cat_others',
        accountId: 'default_account',
        startDate: date,
        nextDate: date,
        frequency: PaymentFrequency.monthly,
      );
      await helper.insertPlannedPayment(payment);
      approve();
      await db.execute(
        "CREATE TRIGGER reject_scheduled_expense BEFORE INSERT ON transactions BEGIN SELECT RAISE(ABORT, 'write failed'); END",
      );
      await expectLater(
        ledger.recordPlannedPaymentOccurrence(
          payment: payment,
          amount: 600,
          accountId: 'default_account',
          categoryId: 'cat_others',
          transactionId: 'expense',
          date: date,
        ),
        throwsA(anything),
      );
      expect((await helper.getPlannedPayments()).single.nextDate, date);
      expect(await saved(), 500);
      expect(await helper.getTransactions(), isEmpty);
      expect(await db.query('planned_payment_occurrences'), isEmpty);
    },
  );

  test('itemized installment schedule uses the same rounding', () {
    final d = debt(paid: 33.33).copyWith(
      items: [
        DebtItem(
          id: 'item',
          debtId: 'debt',
          name: 'Purchase',
          amount: 100,
          totalInstallments: 3,
          firstPaymentDate: date,
        ),
      ],
    );
    expect(d.upcomingPaymentAmount, 33.33);
    expect(d.nextDueDate, DateTime(2026, 2, 1));
    expect(
      d
          .installmentSchedule()
          .map((e) => (e.amount * 100).round())
          .fold<int>(0, (a, b) => a + b),
      10000,
    );
  });

  test(
    'zero-decimal currency has matching upcoming and forecast installments',
    () {
      final d = debt(paid: 33);
      final upcoming = UpcomingTimeline.calculate(
        payments: [],
        debts: [d],
        now: DateTime(2026, 2, 1),
        decimalDigits: 0,
      ).entries.single;
      expect(upcoming.amount, 33);
      expect(upcoming.dueDate, DateTime(2026, 2, 1));
      final forecast = CashflowForecaster.calculate(
        historicalVariableInflows: [],
        historicalVariableOutflows: [],
        plannedPayments: [],
        debts: [d],
        savingsGoals: [],
        currentBaseline: 1000,
        horizon: ForecastHorizon.monthly,
        referenceDate: DateTime(2026, 2, 1),
        decimalDigits: 0,
      );
      expect(forecast.forecastedOutflow, 33);
    },
  );
  test(
    'lowering total and changing direction preserve all existing records',
    () async {
      await helper.insertDebt(debt());
      await ledger.recordDebtRepayment(
        debt: debt(),
        repayment: DebtRepayment(
          id: 'payment',
          debtId: 'debt',
          amount: 80,
          date: date,
          accountId: 'default_account',
        ),
        categoryId: 'cat_others',
      );
      await expectLater(
        helper.saveDebtWithItems(debt(total: 50), []),
        throwsA(isA<FinancialValidationException>()),
      );
      await expectLater(
        helper.saveDebtWithItems(debt().copyWith(type: DebtType.owedToMe), []),
        throwsA(isA<FinancialValidationException>()),
      );
      final persisted = (await helper.getDebts()).single;
      expect(persisted.amount, 100);
      expect(persisted.currentAmount, 80);
      await helper.saveDebtWithItems(debt(total: 120, paid: 0), []);
      expect((await helper.getDebts()).single.currentAmount, 80);
      expect(
        (await ledger.getTransactions()).single.type,
        TransactionType.expense,
      );
    },
  );
  test('deleting debt refreshes cached activity references', () async {
    await helper.insertDebt(debt());
    await ledger.recordDebtRepayment(
      debt: debt(),
      repayment: DebtRepayment(
        id: 'payment',
        debtId: 'debt',
        amount: 20,
        date: date,
        accountId: 'default_account',
      ),
      categoryId: 'cat_others',
    );
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final sub = c.listen(transactionProvider, (_, _) {});
    addTearDown(sub.close);
    await c.read(transactionProvider.future);
    await c.read(debtsProvider.future);
    await c.read(debtsProvider.notifier).deleteDebt('debt');
    expect(
      (await c.read(transactionProvider.future)).single.debtRepaymentId,
      isNull,
    );
  });
}

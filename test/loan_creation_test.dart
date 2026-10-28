import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/database_version.dart';
import 'package:koin/features/reports/report_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper.instance;
  final ledger = SqliteLedgerAdapter();
  late Directory directory;
  late Database db;
  final now = DateTime.now();

  Debt loan({double amount = 100, String? account = 'cash'}) => Debt(
    id: 'loan',
    personName: 'Alex',
    amount: amount,
    type: DebtType.owedToMe,
    startDate: now,
    accountId: account,
  );

  Future<double> balance(String account) async => TransactionRules.balance(
    (await helper.getAccounts()).firstWhere((a) => a.id == account),
    await ledger.getTransactions(),
  );

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('koin_loan_');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await helper.database;
    for (final id in ['cash', 'bank']) {
      await helper.insertAccount(
        Account(
          id: id,
          name: id,
          initialBalance: id == 'cash' ? 200 : 0,
          iconCodePoint: 0,
          colorHex: '#008080',
        ),
      );
    }
  });

  tearDown(() async {
    await helper.close();
    await directory.delete(recursive: true);
  });

  test(
    'funding records one deduction and an unpaid loan, even on retry',
    () async {
      await helper.createLoan(loan(), transactionId: 'funding');
      await helper.createLoan(loan(), transactionId: 'funding');
      final debt = (await helper.getDebts()).single;
      expect(debt.amount, 100);
      expect(debt.currentAmount, 0);
      expect(debt.remainingAmount, 100);
      expect(await balance('cash'), 100);
      expect(await ledger.getTransactions(), hasLength(1));
      final history = (await helper.getDebtRepayments('loan')).single;
      expect(history.isIncrease, isTrue);
      expect(history.note, 'Loan to Alex');
      await helper.saveDebtWithItems(
        debt.copyWith(personName: 'Alex Smith'),
        [],
      );
      expect(await balance('cash'), 100);
      expect(await ledger.getTransactions(), hasLength(1));
    },
  );

  test(
    'invalid or unfunded loans leave no debt, history, or deduction',
    () async {
      for (final debt in [
        loan(account: null),
        loan(account: 'missing'),
        loan(amount: 201),
        loan(amount: 0),
        loan(amount: double.nan),
        loan().copyWith(type: DebtType.iOwe),
      ]) {
        await expectLater(
          helper.createLoan(debt, transactionId: 'funding'),
          throwsA(isA<FinancialValidationException>()),
        );
        expect(await helper.getDebts(), isEmpty);
        expect(await helper.getDebtRepayments('loan'), isEmpty);
        expect(await ledger.getTransactions(), isEmpty);
      }
      expect(await balance('cash'), 200);
    },
  );

  test('existing debt changes no account balance', () async {
    await helper.saveDebtWithItems(loan(), []);
    expect(await balance('cash'), 200);
    expect(await ledger.getTransactions(), isEmpty);
    expect((await helper.getDebts()).single.remainingAmount, 100);
  });

  test('future installments still deduct money lent today', () async {
    await helper.createLoan(
      loan().copyWith(
        totalInstallments: 4,
        startDate: now.add(const Duration(days: 30)),
      ),
      transactionId: 'funding',
    );
    expect(await balance('cash'), 100);
  });

  test('repayments enter the receiving account without inflating income or spending', () async {
    await helper.createLoan(loan(), transactionId: 'funding');
    await ledger.recordDebtRepayment(
      debt: loan(),
      repayment: DebtRepayment(
        id: 'receipt',
        debtId: 'loan',
        amount: 40,
        date: now,
        accountId: 'bank',
      ),
      categoryId: null,
    );
    expect(await balance('cash'), 100);
    expect(await balance('bank'), 40);
    expect((await helper.getDebts()).single.remainingAmount, 60);
    final transactions = await ledger.getTransactions();
    expect(transactions.every((tx) => tx.isDebtTransfer), isTrue);
    final stats = DashboardStats.calculate(
      accounts: await helper.getAccounts(),
      transactions: transactions,
    );
    expect(stats.totalExpense, 0);
    expect(stats.totalIncome, 0);
    expect(stats.categorySpending, isEmpty);
    final budget = BudgetOverview.calculateForMonth(
      categories: await helper.getCategories(),
      transactions: transactions,
    );
    expect(budget.totalSpent, 0);
    expect(
      SpendingAnalysis.calculate(
        transactions: transactions,
        baseDate: now,
        period: AnalysisPeriod.month,
      ).totalExpense,
      0,
    );
    final report = ReportSummary.fromTransactions(transactions);
    expect(report.totalIncome, 0);
    expect(report.totalExpense, 0);
    expect(
      TransactionGroup.groupTransactions(transactions).single.dailyTotal,
      0,
    );
    for (final type in [TransactionType.income, TransactionType.expense]) {
      expect(TransactionFilter(type: type).apply(transactions), isEmpty);
      expect(
        (await helper.getTransactionPage(
          filter: TransactionFilter(type: type),
          categoryNamesById: const {},
        )).items,
        isEmpty,
      );
    }
    final page = await helper.getTransactionPage(
      filter: const TransactionFilter(),
      categoryNamesById: const {},
    );
    expect(page.dayTotals.values.single, 0);
    expect(
      TransactionPage.fromTransactions(
        transactions,
        filter: const TransactionFilter(),
        categoryNamesById: const {},
      ).dayTotals,
      page.dayTotals,
    );
  });

  test(
    'editing funding keeps the loan classification and synchronizes the amount',
    () async {
      final funding = await helper.createLoan(loan(), transactionId: 'funding');
      await ledger.updateTransaction(
        AppTransaction(
          id: funding.id,
          note: 'Loan correction',
          amount: 120,
          date: now,
          type: TransactionType.expense,
          categoryId: 'cat_others',
          accountId: 'cash',
        ),
      );
      expect(await balance('cash'), 80);
      expect((await helper.getDebts()).single.amount, 120);
      expect((await ledger.getTransactions()).single.isDebtTransfer, isTrue);
    },
  );

  test('funding cannot be removed beneath repayments; reversal restores balances once', () async {
    await helper.createLoan(loan(), transactionId: 'funding');
    final funding = (await helper.getDebtRepayments('loan')).single;
    final receipt = DebtRepayment(
      id: 'receipt',
      debtId: 'loan',
      amount: 40,
      date: now,
      accountId: 'bank',
    );
    await ledger.recordDebtRepayment(
      debt: loan(),
      repayment: receipt,
      categoryId: null,
    );
    await expectLater(
      ledger.voidTransaction('funding'),
      throwsA(isA<FinancialValidationException>()),
    );
    await expectLater(
      ledger.voidDebtRepayment(funding),
      throwsA(isA<FinancialValidationException>()),
    );
    expect(await balance('cash'), 100);
    await ledger.voidDebtRepayment(receipt);
    await ledger.voidDebtRepayment(funding);
    await ledger.voidDebtRepayment(funding);
    expect(await balance('cash'), 200);
    expect(await balance('bank'), 0);
    expect((await helper.getDebts()).single.amount, 0);
  });

  test(
    'savings release and loan funding commit together and reverse together',
    () async {
      await helper.insertSavingsGoal(
        SavingsGoal(
          id: 'saved',
          name: 'Savings',
          startDate: now,
          linkedAccountId: 'cash',
          isStash: true,
        ),
      );
      await helper.insertSavingsLog(
        SavingsLog(id: 'deposit', goalId: 'saved', amount: 150, date: now),
      );
      await expectLater(
        helper.createLoan(loan(), transactionId: 'funding'),
        throwsA(isA<FinancialValidationException>()),
      );
      expect(await helper.getDebts(), isEmpty);
      expect((await helper.getSavingsGoals()).single.currentAmount, 150);
      await helper.createLoan(
        loan(),
        transactionId: 'funding',
        approvedGoalCents: {'saved': 5000},
      );
      expect((await helper.getSavingsGoals()).single.currentAmount, 100);
      await ledger.voidDebtRepayment(
        (await helper.getDebtRepayments('loan')).single,
      );
      expect((await helper.getSavingsGoals()).single.currentAmount, 150);
      expect(await balance('cash'), 200);
    },
  );

  test('deleting the IOU keeps cash history classified as a loan', () async {
    await helper.createLoan(loan(), transactionId: 'funding');
    await helper.deleteDebt('loan');
    final tx = (await ledger.getTransactions()).single;
    expect(tx.debtRepaymentId, isNull);
    expect(tx.isDebtTransfer, isTrue);
    expect(tx.countsAsExpense, isFalse);
    expect(await balance('cash'), 100);
  });

  test(
    'version 47 upgrade preserves existing transactions and their balances',
    () async {
      await ledger.recordTransaction(
        AppTransaction(
          id: 'old',
          amount: 25,
          date: now,
          type: TransactionType.expense,
          categoryId: 'cat_others',
          accountId: 'cash',
        ),
      );
      await db.execute('ALTER TABLE transactions DROP COLUMN isDebtTransfer');
      await db.setVersion(47);
      await helper.close();
      db = await helper.database;
      expect(await db.getVersion(), databaseSchemaVersion);
      final tx = (await ledger.getTransactions()).single;
      expect(tx.isDebtTransfer, isFalse);
      expect(tx.countsAsExpense, isTrue);
      expect(await balance('cash'), 175);
    },
  );
}

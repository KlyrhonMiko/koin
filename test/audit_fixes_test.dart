import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/database_version.dart';
import 'package:koin/core/maintenance/database_snapshot.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper.instance;
  final ledger = SqliteLedgerAdapter();
  late Directory directory;
  late Database db;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('koin_audit_fixes_');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await helper.database;
    await db.update('accounts', {'initialBalance': 10000});
  });
  tearDown(() async {
    await helper.close();
    final target = directory.absolute.path;
    expect(target.startsWith(Directory.systemTemp.absolute.path), isTrue);
    await directory.delete(recursive: true);
  });

  Future<AppTransaction> repayment() async {
    final debt = Debt(
      id: 'debt',
      personName: 'Friend',
      amount: 1000,
      currentAmount: 100,
      type: DebtType.iOwe,
      startDate: today,
    );
    await helper.insertDebt(debt);
    return (await ledger.recordDebtRepayment(
      debt: debt,
      repayment: DebtRepayment(
        id: 'payment',
        debtId: debt.id,
        amount: 50,
        date: today,
        accountId: 'default_account',
      ),
      categoryId: 'cat_others',
    ))!;
  }

  test(
    'repayment edits reject overpayment and preserve both records',
    () async {
      final tx = await repayment();
      await expectLater(
        ledger.updateTransaction(tx.copyWith(amount: 1500)),
        throwsA(isA<FinancialValidationException>()),
      );
      expect((await helper.getDebts()).single.currentAmount, 150);
      expect((await ledger.getTransactions()).single.amount, 50);
      expect((await helper.getDebtRepayments('debt')).single.amount, 50);
    },
  );

  test('linked payment cannot become income or a transfer', () async {
    final tx = await repayment();
    await expectLater(
      ledger.updateTransaction(tx.copyWith(type: TransactionType.income)),
      throwsA(isA<FinancialValidationException>()),
    );
    await helper.insertAccount(
      Account(
        id: 'other',
        name: 'Other',
        iconCodePoint: 0,
        colorHex: '#00D09E',
      ),
    );
    await expectLater(
      ledger.updateTransfer(
        tx.copyWith(type: TransactionType.transfer, toAccountId: 'other'),
        null,
      ),
      throwsA(isA<FinancialValidationException>()),
    );
    expect(
      (await ledger.getTransactions()).single.type,
      TransactionType.expense,
    );
    expect((await helper.getDebts()).single.currentAmount, 150);
  });

  test('percentage fees round to currency precision and round-trip through editors', () {
    for (final digits in [0, 2]) {
      final draft = TransferDraft(
        sourceAccountId: 'a',
        destinationAccountId: 'b',
        rawAmount: 10.01,
        enteredFee: 1,
        isFeePercentage: true,
        decimalDigits: digits,
        date: today,
      );
      final fee = draft.calculateFeeAmount();
      expect(fee, digits == 0 ? 0 : 0.1);
      expect(draft.calculateTotalDebit(), 10.01 + fee);
      expect(
        Currency.supportedCurrencies.first.tryParseInput(fee.toString()),
        fee,
      );
    }
  });

  PlannedPayment schedule({DateTime? end}) => PlannedPayment(
    id: 'daily',
    title: 'Daily income',
    amount: 10,
    type: TransactionType.income,
    categoryId: 'cat_salary',
    accountId: 'default_account',
    startDate: today.subtract(const Duration(days: 2)),
    nextDate: today.subtract(const Duration(days: 2)),
    endDate: end,
    frequency: PaymentFrequency.daily,
    isAutoProcess: true,
  );

  test(
    'catch-up keeps due dates and deleting an automatic occurrence skips it',
    () async {
      await helper.insertPlannedPayment(schedule());
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final automatic = container.read(automaticPaymentsProvider.notifier);
      await automatic.processDue(now: now);
      final entries = await ledger.getTransactions();
      expect(entries.map((t) => t.date).toSet(), {
        today,
        today.subtract(const Duration(days: 1)),
        today.subtract(const Duration(days: 2)),
      });
      await ledger.voidTransaction(entries.first.id);
      await automatic.processDue(now: now);
      expect(await ledger.getTransactions(), hasLength(2));
      expect(
        (await helper.getPlannedPayments()).single.nextDate,
        today.add(const Duration(days: 1)),
      );
    },
  );

  test(
    'expired automatic schedules catch up through their final eligible day',
    () async {
      await helper.insertPlannedPayment(
        schedule(end: today.subtract(const Duration(days: 1))),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await container
          .read(automaticPaymentsProvider.notifier)
          .processDue(now: now);
      expect(await ledger.getTransactions(), hasLength(2));
      expect((await helper.getPlannedPayments()).single.nextDate, today);
      expect(container.read(automaticPaymentsProvider).problems, isEmpty);
    },
  );

  test('future expenses are excluded from actual spending and balances', () {
    final future = AppTransaction(
      id: 'future',
      amount: 10,
      date: now.add(const Duration(minutes: 5)),
      type: TransactionType.expense,
      categoryId: 'cat_food',
      accountId: 'cash',
    );
    final stats = DashboardStats.calculate(
      accounts: [
        Account(
          id: 'cash',
          name: 'Cash',
          initialBalance: 100,
          iconCodePoint: 0,
          colorHex: '#00D09E',
        ),
      ],
      transactions: [future],
    );
    expect(stats.currentBalance, 100);
    expect(stats.totalExpense, 0);
    expect(stats.allTimeExpense, 0);
    final analysis = SpendingAnalysis.calculate(
      transactions: [future],
      baseDate: now,
      period: AnalysisPeriod.month,
    );
    expect(analysis.categorySpendingMap, isEmpty);
  });

  test(
    'clearing transactions refreshes restored savings and their history',
    () async {
      await helper.insertSavingsGoal(
        SavingsGoal(
          id: 'goal',
          name: 'Reserve',
          currentAmount: 800,
          isStash: true,
          startDate: today,
          linkedAccountId: 'default_account',
        ),
      );
      await helper.insertSavingsLogs([
        SavingsLog(
          id: 'release',
          goalId: 'goal',
          amount: -50,
          date: today,
          transactionId: 'spend',
        ),
      ], spendingAmount: 250);
      await helper.insertTransaction(
        AppTransaction(
          id: 'spend',
          amount: 250,
          date: today,
          type: TransactionType.expense,
          categoryId: 'cat_others',
          accountId: 'default_account',
        ),
      );
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        (await container.read(savingsGoalsProvider.future))
            .single
            .currentAmount,
        750,
      );
      expect(
        await container.read(savingsLogsProvider('goal').future),
        hasLength(1),
      );
      await container.read(appMaintenanceProvider).clearTransactions();
      expect(
        (await container.read(savingsGoalsProvider.future))
            .single
            .currentAmount,
        800,
      );
      expect(await container.read(savingsLogsProvider('goal').future), isEmpty);
    },
  );

  test('clearing data invalidates cached debt repayments', () async {
    await repayment();
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      await container.read(debtRepaymentsProvider('debt').future),
      hasLength(1),
    );
    await container.read(appMaintenanceProvider).clearAllData();
    expect(
      await container.read(debtRepaymentsProvider('debt').future),
      isEmpty,
    );
  });

  test(
    'version 43 migration and backup retain archived entities and history',
    () async {
      await helper.insertTransaction(
        AppTransaction(
          id: 'history',
          amount: 20,
          date: today,
          type: TransactionType.income,
          categoryId: 'cat_salary',
          accountId: 'default_account',
        ),
      );
      await db.execute('ALTER TABLE accounts DROP COLUMN isArchived');
      await db.execute('ALTER TABLE categories DROP COLUMN isArchived');
      await db.setVersion(43);
      await helper.close();
      db = await helper.database;
      expect(await db.getVersion(), databaseSchemaVersion);
      expect(
        (await helper.getAccounts())
            .firstWhere((a) => a.id == 'default_account')
            .isArchived,
        isFalse,
      );
      final account = (await helper.getAccounts()).firstWhere(
        (a) => a.id == 'default_account',
      );
      final category = (await helper.getCategories()).firstWhere(
        (c) => c.id == 'cat_salary',
      );
      await helper.updateAccount(account.copyWith(isArchived: true));
      await helper.updateCategory(category.copyWith(isArchived: true));
      final backup = '${directory.path}/archive.db';
      await DatabaseSnapshot.create(db, backup);
      await helper.deleteAccount(account.id);
      expect(await helper.restoreDatabase(backup), isTrue);
      db = await helper.database;
      expect(
        (await helper.getAccounts())
            .firstWhere((a) => a.id == 'default_account')
            .isArchived,
        isTrue,
      );
      expect(
        (await helper.getCategories())
            .firstWhere((c) => c.id == category.id)
            .isArchived,
        isTrue,
      );
      final saved = (await ledger.getTransactions()).single;
      expect(saved.accountId, account.id);
      expect(saved.categoryId, category.id);
      expect(saved.amount, 20);
    },
  );
}

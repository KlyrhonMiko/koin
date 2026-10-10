import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper.instance;
  final ledger = SqliteLedgerAdapter();
  late Directory directory;
  late Database db;
  AppTransaction expense({
    double amount = 500,
    String account = 'default_account',
    DateTime? date,
  }) => AppTransaction(
    id: 'expense',
    amount: amount,
    accountId: account,
    date: date ?? DateTime(2026, 10, 10),
    type: TransactionType.expense,
    categoryId: 'cat_others',
    note: 'Groceries',
  );
  SavingsLog release({
    String id = 'release',
    String goal = 'goal',
    double amount = -437,
  }) => SavingsLog(
    id: id,
    goalId: goal,
    amount: amount,
    date: DateTime(2026, 10, 10),
    note: 'Automatically released for spending',
    transactionId: 'expense',
  );
  Future<void> record() async {
    await helper.insertSavingsLogs([release()], spendingAmount: 500);
    await ledger.recordTransaction(expense());
  }

  Future<double> saved(String id) async => (await helper.getSavingsGoals())
      .firstWhere((g) => g.id == id)
      .currentAmount;
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('koin_savings_links_');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await helper.database;
    final account = (await helper.getAccounts()).firstWhere(
      (a) => a.id == 'default_account',
    );
    await helper.updateAccount(account.copyWith(initialBalance: 563));
    await helper.insertAccount(
      Account(
        id: 'other',
        name: 'Other',
        iconCodePoint: 0,
        colorHex: '#000000',
        initialBalance: 1000,
      ),
    );
  });
  setUp(() async {
    await db.delete('transactions');
    await db.delete('savings_logs');
    await db.delete('savings_spending_links');
    await db.delete('savings_goals');
    await helper.insertSavingsGoal(
      SavingsGoal(
        id: 'goal',
        name: 'End of Year',
        startDate: DateTime(2026),
        linkedAccountId: 'default_account',
        isStash: true,
      ),
    );
    await helper.insertSavingsLog(
      SavingsLog(
        id: 'deposit',
        goalId: 'goal',
        amount: 500,
        date: DateTime(2026),
      ),
    );
  });
  tearDownAll(() async {
    await helper.close();
    expect(
      directory.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      isTrue,
    );
    await directory.delete(recursive: true);
  });
  test(
    'transaction deletion removes linked releases and restores savings once',
    () async {
      await record();
      expect(await saved('goal'), 63);
      await ledger.voidTransaction('expense');
      expect(await saved('goal'), 500);
      expect((await helper.getSavingsLogs('goal')).map((l) => l.id), [
        'deposit',
      ]);
      await ledger.voidTransaction('expense');
      expect(await saved('goal'), 500);
    },
  );
  test('automatic releases cannot be deleted directly from savings', () async {
    await record();
    await expectLater(helper.deleteSavingsLog(release()), throwsStateError);
    expect((await ledger.getTransactions()).single.amount, 500);
    expect(await saved('goal'), 63);
    expect((await helper.getSavingsLogs('goal')).length, 2);
  });
  test(
    'expense amount edits recalculate the shortfall in both directions',
    () async {
      await record();
      await ledger.updateTransaction(expense(amount: 200));
      expect(await saved('goal'), 363);
      expect(
        (await helper.getSavingsLogs(
          'goal',
        )).firstWhere((l) => l.transactionId != null).amount,
        -137,
      );
      await ledger.updateTransaction(expense(amount: 550));
      expect(await saved('goal'), 13);
      expect(
        (await helper.getSavingsLogs(
          'goal',
        )).firstWhere((l) => l.transactionId != null).amount,
        -487,
      );
    },
  );
  test(
    'reducing below spendable funds removes the release and later edits recreate it',
    () async {
      await record();
      await ledger.updateTransaction(expense(amount: 50));
      expect(await saved('goal'), 500);
      expect((await helper.getSavingsLogs('goal')).length, 1);
      await ledger.updateTransaction(expense(amount: 300));
      expect(await saved('goal'), 263);
      expect(
        (await helper.getSavingsLogs(
          'goal',
        )).firstWhere((l) => l.transactionId != null).amount,
        -237,
      );
    },
  );
  test('automatic release edits cannot change the recorded expense', () async {
    await record();
    final edited = SavingsLog(
      id: 'release',
      goalId: 'goal',
      amount: -100,
      date: DateTime(2026, 10, 11),
      note: 'Edited release',
    );
    await expectLater(
      helper.updateSavingsLog(release(), edited),
      throwsStateError,
    );
    final transaction = (await ledger.getTransactions()).single;
    expect(transaction.amount, 500);
    expect(transaction.date, DateTime(2026, 10, 10));
    expect(await saved('goal'), 63);
    expect(
      (await helper.getSavingsLogs(
        'goal',
      )).firstWhere((l) => l.id == 'release').transactionId,
      'expense',
    );
  });
  test(
    'failed transaction and release edits leave both records unchanged',
    () async {
      await record();
      await expectLater(
        ledger.updateTransaction(expense(amount: 700)),
        throwsStateError,
      );
      expect(await saved('goal'), 63);
      expect((await ledger.getTransactions()).single.amount, 500);
      await expectLater(
        helper.updateSavingsLog(release(), release(amount: -600)),
        throwsStateError,
      );
      expect(await saved('goal'), 63);
      expect((await ledger.getTransactions()).single.amount, 500);
    },
  );
  test(
    'multi-goal release edits and deletion keep all goals synchronized',
    () async {
      final first = (await helper.getSavingsGoals()).single;
      await helper.updateSavingsGoal(first.copyWith(currentAmount: 200));
      await helper.insertSavingsGoal(
        SavingsGoal(
          id: 'second',
          name: 'Trip',
          currentAmount: 300,
          startDate: DateTime(2026, 2),
          linkedAccountId: 'default_account',
          isStash: true,
        ),
      );
      await helper.insertSavingsLogs([
        release(amount: -200),
        release(id: 'release2', goal: 'second', amount: -237),
      ], spendingAmount: 500);
      await ledger.recordTransaction(expense());
      await ledger.updateTransaction(expense(amount: 300));
      expect(await saved('goal'), 0);
      expect(await saved('second'), 263);
      await ledger.voidTransaction('expense');
      expect(await saved('goal'), 200);
      expect(await saved('second'), 300);
      expect(await ledger.getTransactions(), isEmpty);
    },
  );
  test(
    'changing accounts restores original savings and releases from the new account',
    () async {
      await record();
      await helper.insertSavingsGoal(
        SavingsGoal(
          id: 'other-goal',
          name: 'Other savings',
          currentAmount: 600,
          startDate: DateTime(2026),
          linkedAccountId: 'other',
          isStash: true,
        ),
      );
      await ledger.updateTransaction(expense(account: 'other'));
      expect(await saved('goal'), 500);
      expect(await saved('other-goal'), 500);
      expect((await helper.getSavingsLogs('other-goal')).single.amount, -100);
    },
  );
  test('links and deletion rules survive reopening the database', () async {
    await record();
    await helper.close();
    db = await helper.database;
    expect(
      (await helper.getSavingsLogs(
        'goal',
      )).firstWhere((l) => l.id == 'release').transactionId,
      'expense',
    );
    await ledger.voidTransaction('expense');
    expect(await saved('goal'), 500);
  });
  test(
    'version 36 migration preserves existing unlinked savings history',
    () async {
      await record();
      await db.execute('DROP TRIGGER savings_spending_recorded');
      await db.execute('DROP TRIGGER savings_spending_deleted');
      await db.execute('DROP INDEX savings_log_transaction');
      await db.execute('DROP TABLE savings_spending_links');
      await db.execute('ALTER TABLE savings_logs DROP COLUMN transactionId');
      await db.setVersion(36);
      await helper.close();
      db = await helper.database;
      expect(await db.getVersion(), 37);
      expect(await saved('goal'), 63);
      expect((await helper.getSavingsLogs('goal')).length, 2);
      expect(
        (await helper.getSavingsLogs(
          'goal',
        )).every((l) => l.transactionId == null),
        true,
      );
      expect((await ledger.getTransactions()).single.amount, 500);
    },
  );
  test(
    'abandoned draft release is restored without creating a transaction',
    () async {
      await helper.insertSavingsLogs([release()], spendingAmount: 500);
      await helper.rollbackSavingsRelease('expense');
      expect(await saved('goal'), 500);
      expect((await helper.getSavingsLogs('goal')).length, 1);
      expect(await ledger.getTransactions(), isEmpty);
    },
  );
}

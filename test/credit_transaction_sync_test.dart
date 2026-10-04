import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Database db;
  final helper = DatabaseHelper.instance;
  final ledger = SqliteLedgerAdapter();

  final debt = Debt(
    id: 'credit',
    personName: 'Credit card',
    amount: 1000,
    currentAmount: 100,
    type: DebtType.iOwe,
    startDate: DateTime(2026, 1, 1),
  );

  Future<AppTransaction> record({bool isIncrease = false}) async {
    return (await ledger.recordDebtRepayment(
      debt: debt,
      repayment: DebtRepayment(
        id: 'payment',
        debtId: debt.id,
        amount: 50,
        date: DateTime(2026, 10, 1),
        accountId: 'default_account',
        note: 'Original note',
        isIncrease: isIncrease,
      ),
      categoryId: 'cat_others',
    ))!;
  }

  // Simulates an editor that submits financial fields without origin links.
  AppTransaction edit(AppTransaction tx, {double amount = 80}) =>
      AppTransaction(
        id: tx.id,
        amount: amount,
        date: DateTime(2026, 10, 4),
        note: 'Updated note',
        type: tx.type,
        categoryId: 'cat_food',
        accountId: 'edited_account',
      );

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('koin_credit_sync_');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await helper.database;
    await helper.insertAccount(
      Account(
        id: 'edited_account',
        name: 'Edited account',
        iconCodePoint: 0xe041,
        colorHex: '#00D09E',
      ),
    );
  });

  setUp(() async {
    await db.delete('transactions');
    await db.delete('debt_repayments');
    await db.delete('debts');
    await helper.insertDebt(debt);
  });

  tearDownAll(() async {
    final testPath = directory.absolute.path;
    expect(testPath.startsWith(Directory.systemTemp.absolute.path), isTrue);
    await db.close();
    await directory.delete(recursive: true);
  });

  for (final isIncrease in [false, true]) {
    test(
      'editing ${isIncrease ? 'credit increase' : 'payment'} syncs history and balance',
      () async {
        final tx = await record(isIncrease: isIncrease);
        await ledger.updateTransaction(edit(tx));

        final saved = (await ledger.getTransactions()).single;
        expect(saved.debtRepaymentId, 'payment');
        expect(saved.amount, 80);
        final history = (await helper.getDebtRepayments(debt.id)).single;
        expect(history.amount, 80);
        expect(history.date, DateTime(2026, 10, 4));
        expect(history.note, 'Updated note');
        expect(history.accountId, saved.accountId);
        expect(history.accountId, 'edited_account');
        expect(history.isIncrease, isIncrease);
        var credit = (await helper.getDebts()).single;
        expect(credit.amount, isIncrease ? 1080 : 1000);
        expect(credit.currentAmount, isIncrease ? 100 : 180);

        // Repeated edits apply only the difference, not the entire new amount.
        await ledger.updateTransaction(edit(saved, amount: 20));
        credit = (await helper.getDebts()).single;
        expect(credit.amount, isIncrease ? 1020 : 1000);
        expect(credit.currentAmount, isIncrease ? 100 : 120);

        await ledger.voidTransaction(tx.id);
        credit = (await helper.getDebts()).single;
        expect(credit.amount, 1000);
        expect(credit.currentAmount, 100);
        expect(await helper.getDebtRepayments(debt.id), isEmpty);
      },
    );
  }

  test('transaction edits refresh credit providers already in use', () async {
    final tx = await record();
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(ledger),
        debtRepositoryProvider.overrideWithValue(SqliteDebtAdapter()),
      ],
    );
    addTearDown(container.dispose);
    final historySubscription = container.listen(
      debtRepaymentsProvider(debt.id),
      (_, _) {},
    );
    addTearDown(historySubscription.close);
    await container.read(transactionProvider.future);
    await container.read(debtsProvider.future);
    expect(
      (await container.read(
        debtRepaymentsProvider(debt.id).future,
      )).single.amount,
      50,
    );

    await container
        .read(transactionProvider.notifier)
        .updateTransaction(edit(tx));

    expect(
      (await container.read(
        debtRepaymentsProvider(debt.id).future,
      )).single.amount,
      80,
    );
    expect(
      container.read(debtsProvider).requireValue.single.currentAmount,
      180,
    );
    expect(
      container.read(transactionProvider).requireValue.single.debtRepaymentId,
      'payment',
    );
  });

  test('failed transaction update rolls back credit changes', () async {
    final tx = await record();
    await db.execute('''
      CREATE TEMP TRIGGER reject_test_edit BEFORE UPDATE ON transactions
      BEGIN SELECT RAISE(ABORT, 'test failure'); END
    ''');
    try {
      await expectLater(ledger.updateTransaction(edit(tx)), throwsA(anything));
      expect((await helper.getDebtRepayments(debt.id)).single.amount, 50);
      expect((await helper.getDebts()).single.currentAmount, 150);
      expect((await ledger.getTransactions()).single.amount, 50);
    } finally {
      await db.execute('DROP TRIGGER reject_test_edit');
    }
  });

  test('ordinary transaction edits leave credit balances alone', () async {
    final tx = edit(await record()).copyWith(id: 'ordinary');
    await ledger.recordTransaction(tx);
    await ledger.updateTransaction(edit(tx, amount: 200));
    expect((await helper.getDebts()).single.currentAmount, 150);
    expect((await helper.getDebtRepayments(debt.id)).single.amount, 50);
  });

  test('in-memory ledger preserves origin links on edits', () async {
    final original = AppTransaction(
      id: 'linked',
      amount: 50,
      date: DateTime(2026, 10, 1),
      type: TransactionType.expense,
      categoryId: 'cat_others',
      accountId: 'default_account',
      debtRepaymentId: 'payment',
      plannedPaymentId: 'planned',
    );
    final memoryLedger = InMemoryLedgerAdapter(initial: [original]);
    await memoryLedger.updateTransaction(edit(original));
    final saved = (await memoryLedger.getTransactions()).single;
    expect(saved.amount, 80);
    expect(saved.debtRepaymentId, 'payment');
    expect(saved.plannedPaymentId, 'planned');
  });
}

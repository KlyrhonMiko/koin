import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/maintenance/database_snapshot.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final date = DateTime.now().subtract(const Duration(days: 2));
  final received = DateTime.now().subtract(const Duration(days: 1));
  AppTransaction purchase({
    double amount = 1200,
    CashbackRule rule = CashbackRule.onePercent,
    DateTime? receivedAt,
  }) => AppTransaction(
    id: 'purchase',
    note: 'Groceries',
    amount: amount,
    date: date,
    type: TransactionType.expense,
    categoryId: 'cat_others',
    accountId: 'maribank',
    cashbackRule: rule,
    cashbackReceivedAt: receivedAt,
  );
  final bank = Account(
    id: 'maribank',
    name: 'MariBank',
    initialBalance: 10000,
    iconCodePoint: KoinIcons.bank.codePoint,
    colorHex: '#008080',
  );

  test('percentage rounds centavos half up; fixed cashback ignores amount', () {
    expect(CashbackRule.onePercent.calculate(1200), 12);
    expect(CashbackRule.onePercent.calculate(100.50), 1.01);
    expect(CashbackRule.onePercent.calculate(100.49), 1);
    expect(CashbackRule.onePercent.calculate(0.50), 0.01);
    expect(CashbackRule.onePercent.calculate(0.49), 0);
    expect(CashbackRule.fixedFive.calculate(300), 5);
    expect(CashbackRule.none.calculate(1200), 0);
    for (final invalid in [0.0, -1.0, double.nan, double.infinity]) {
      expect(CashbackRule.fixedFive.calculate(invalid), 0);
      expect(CashbackRule.onePercent.calculate(invalid), 0);
    }
  });

  test(
    'cashback round-trips, clears receipt, and defaults off for old data',
    () {
      final source = purchase(receivedAt: received);
      final restored = AppTransaction.fromMap(source.toMap());
      expect(restored.cashbackRule, CashbackRule.onePercent);
      expect(restored.cashbackReceivedAt, received);
      expect(restored.cashbackCredit!.cashbackSourceId, source.id);
      expect(
        AppTransaction.fromMap(restored.cashbackCredit!.toMap()).amount,
        12,
      );
      expect(
        restored.copyWith(cashbackReceivedAt: () => null).cashbackCredit!.date,
        date,
      );
      final legacy = source.toMap()
        ..remove('cashbackRule')
        ..remove('cashbackReceivedAt')
        ..remove('cashbackSourceId');
      expect(AppTransaction.fromMap(legacy).expectedCashback, 0);
      expect(source.copyWith(type: TransactionType.income).expectedCashback, 0);
      expect(source.copyWith(transferId: 'transfer').expectedCashback, 0);
      expect(source.copyWith(isDebtTransfer: true).expectedCashback, 0);
    },
  );

  for (final sqlite in [false, true]) {
    group(sqlite ? 'SQLite cashback' : 'In-memory cashback', () {
      late Ledger ledger;
      Directory? directory;
      final helper = DatabaseHelper.instance;
      setUp(() async {
        if (sqlite) {
          sqfliteFfiInit();
          databaseFactory = databaseFactoryFfi;
          directory = await Directory.systemTemp.createTemp('koin_cashback_');
          await databaseFactory.setDatabasesPath(directory!.path);
          await helper.insertAccount(bank);
          await helper.insertAccount(bank.copyWith(id: 'other'));
          ledger = SqliteLedgerAdapter();
        } else {
          ledger = InMemoryLedgerAdapter();
        }
      });
      tearDown(() async {
        if (sqlite) {
          await helper.close();
          await directory!.delete(recursive: true);
        }
      });

      test('selecting cashback credits automatically exactly once', () async {
        final source = purchase();
        await ledger.recordTransaction(source);
        var entries = await ledger.getTransactions();
        var stats = DashboardStats.calculate(
          accounts: [bank],
          transactions: entries,
        );
        expect(stats.accountBalances[bank.id], 8812);
        expect(stats.allTimeIncome, 12);
        expect(stats.allTimeExpense, 1200);
        final confirmed = source;
        await ledger.updateTransaction(confirmed);
        await ledger.updateTransaction(confirmed);
        entries = await ledger.getTransactionFamily(source.id);
        expect(entries, hasLength(2));
        final credit = entries.singleWhere((t) => t.cashbackSourceId != null);
        expect(credit.amount, 12);
        expect(credit.date, date);
        stats = DashboardStats.calculate(
          accounts: [bank],
          transactions: entries,
        );
        expect(stats.accountBalances[bank.id], 8812);
        expect(stats.allTimeExpense, 1200);
        expect(stats.allTimeIncome, 12);
      });

      test(
        'editing recalculates credit, moves accounts, and can remove cashback',
        () async {
          final source = purchase(receivedAt: received);
          await ledger.recordTransaction(source);
          final updated = source.copyWith(amount: 2000, accountId: 'other');
          await ledger.updateTransaction(updated);
          var family = await ledger.getTransactionFamily(source.id);
          expect(
            family.singleWhere((t) => t.cashbackSourceId != null).amount,
            20,
          );
          expect(family.every((t) => t.accountId == 'other'), isTrue);
          await ledger.updateTransaction(
            updated.copyWith(cashbackRule: CashbackRule.fixedFive),
          );
          family = await ledger.getTransactionFamily(source.id);
          expect(
            family.singleWhere((t) => t.cashbackSourceId != null).amount,
            5,
          );
          await ledger.updateTransaction(
            updated.copyWith(cashbackReceivedAt: () => null),
          );
          family = await ledger.getTransactionFamily(source.id);
          expect(family, hasLength(2));
          expect(
            family.singleWhere((t) => t.cashbackSourceId != null).amount,
            20,
          );
          await ledger.updateTransaction(
            updated.copyWith(
              cashbackRule: CashbackRule.none,
              cashbackReceivedAt: () => null,
            ),
          );
          expect(
            (await ledger.getTransactionFamily(source.id))
                .single
                .expectedCashback,
            0,
          );
        },
      );

      test(
        'future cashback follows the transaction date without affecting today',
        () async {
          final source = purchase().copyWith(
            date: DateTime.now().add(const Duration(days: 2)),
          );
          await ledger.recordTransaction(source);
          final entries = await ledger.getTransactionFamily(source.id);
          expect(
            entries.singleWhere((t) => t.cashbackSourceId != null).date,
            source.date,
          );
          final stats = DashboardStats.calculate(
            accounts: [bank],
            transactions: entries,
          );
          expect(stats.accountBalances[bank.id], bank.initialBalance);
          expect(stats.allTimeIncome, 0);
        },
      );

      test(
        'deleting a credit clears its rule; deleting source removes its credit',
        () async {
          final source = purchase(receivedAt: received);
          await ledger.recordTransaction(source);
          await ledger.voidTransaction('cashback:${source.id}');
          final pending = (await ledger.getTransactionFamily(source.id)).single;
          expect(pending.cashbackReceivedAt, isNull);
          expect(pending.cashbackRule, CashbackRule.none);
          await ledger.updateTransaction(source);
          await ledger.voidTransaction(source.id);
          expect(await ledger.getTransactionFamily(source.id), isEmpty);
        },
      );

      test(
        'transfers earn cashback on amount only and retain linked fees',
        () async {
          final source = purchase(
            rule: CashbackRule.fixedFive,
            receivedAt: received,
          ).copyWith(type: TransactionType.transfer, toAccountId: 'other');
          final fee = AppTransaction(
            id: 'fee',
            amount: 10,
            date: date,
            type: TransactionType.expense,
            categoryId: 'cat_others',
            accountId: bank.id,
          );
          await ledger.recordTransfer(
            transferTransaction: source,
            feeTransaction: fee,
          );
          expect(await ledger.getTransactionFamily(source.id), hasLength(3));
          await ledger.updateTransfer(
            source.copyWith(cashbackRule: CashbackRule.onePercent),
            fee,
          );
          final family = await ledger.getTransactionFamily(source.id);
          expect(
            family.singleWhere((t) => t.cashbackSourceId != null).amount,
            12,
          );
          expect(
            family.singleWhere((t) => t.id == 'fee').transferId,
            source.id,
          );
          await ledger.voidTransaction(source.id);
          expect(await ledger.getTransactionFamily(source.id), isEmpty);
        },
      );

      test(
        'invalid receipts roll back; linked credits must be edited at source',
        () async {
          final source = purchase(receivedAt: received);
          await ledger.recordTransaction(source);
          await expectLater(
            ledger.updateTransaction(
              source.copyWith(
                cashbackReceivedAt: () =>
                    date.subtract(const Duration(days: 1)),
              ),
            ),
            throwsA(isA<FinancialValidationException>()),
          );
          await expectLater(
            ledger.updateTransaction(
              source.copyWith(
                cashbackReceivedAt: () =>
                    DateTime.now().add(const Duration(days: 1)),
              ),
            ),
            throwsA(isA<FinancialValidationException>()),
          );
          await expectLater(
            ledger.updateTransaction(
              source.cashbackCredit!.copyWith(amount: 99),
            ),
            throwsA(isA<FinancialValidationException>()),
          );
          expect(
            (await ledger.getTransactionFamily(source.id))
                .singleWhere((t) => t.cashbackSourceId != null)
                .amount,
            12,
          );
        },
      );

      if (sqlite) {
        test('cashback survives backup and reopening the database', () async {
          final source = purchase(receivedAt: received);
          await ledger.recordTransaction(source);
          final backupPath = '${directory!.path}/cashback-backup.db';
          await DatabaseSnapshot.create(await helper.database, backupPath);
          final backup = await openDatabase(backupPath, singleInstance: false);
          try {
            final rows = (await backup.query('transactions'))
                .map(AppTransaction.fromMap)
                .toList();
            expect(
              rows.singleWhere((t) => t.id == source.id).cashbackReceivedAt,
              received,
            );
            expect(
              rows.singleWhere((t) => t.cashbackSourceId == source.id).amount,
              12,
            );
          } finally {
            await backup.close();
          }
          await helper.close();
          expect(await ledger.getTransactionFamily(source.id), hasLength(2));
        });

        test(
          'version 48 upgrades without changing existing transactions',
          () async {
            await ledger.recordTransaction(purchase(rule: CashbackRule.none));
            final db = await helper.database;
            await db.execute('DROP INDEX transaction_cashback_source');
            for (final column in [
              'cashbackRule',
              'cashbackReceivedAt',
              'cashbackSourceId',
            ]) {
              await db.execute('ALTER TABLE transactions DROP COLUMN $column');
            }
            await db.setVersion(48);
            await helper.close();
            final source = (await ledger.getTransactionFamily('purchase'))
                .single;
            expect(source.amount, 1200);
            expect(source.cashbackRule, CashbackRule.none);
            await ledger.updateTransaction(
              source.copyWith(
                cashbackRule: CashbackRule.fixedFive,
                cashbackReceivedAt: () => received,
              ),
            );
            expect(await ledger.getTransactionFamily('purchase'), hasLength(2));
          },
        );

        test('removed cashback cannot fund a larger edited expense', () async {
          final source = purchase(
            amount: 10000,
            rule: CashbackRule.fixedFive,
            receivedAt: received,
          );
          await ledger.recordTransaction(source);
          await expectLater(
            ledger.updateTransaction(
              source.copyWith(
                amount: 10005,
                cashbackRule: CashbackRule.none,
                cashbackReceivedAt: () => null,
              ),
            ),
            throwsA(isA<FinancialValidationException>()),
          );
        });
      }
    });
  }

  test(
    'transaction provider refreshes credits and removes stale linked rows',
    () async {
      final source = purchase();
      final providers = ProviderContainer(
        overrides: [ledgerProvider.overrideWithValue(InMemoryLedgerAdapter())],
      );
      addTearDown(providers.dispose);
      await providers.read(transactionProvider.future);
      final notifier = providers.read(transactionProvider.notifier);
      await notifier.addTransaction(
        source.copyWith(cashbackReceivedAt: () => received),
      );
      expect(providers.read(transactionProvider).value, hasLength(2));
      await notifier.updateTransaction(
        source.copyWith(cashbackRule: CashbackRule.none),
      );
      expect(providers.read(transactionProvider).value, hasLength(1));
      await notifier.updateTransaction(
        source.copyWith(cashbackReceivedAt: () => received),
      );
      await notifier.deleteTransaction('cashback:${source.id}');
      expect(
        providers.read(transactionProvider).value!.single.cashbackRule,
        CashbackRule.none,
      );
      await notifier.updateTransaction(
        source.copyWith(cashbackReceivedAt: () => received),
      );
      await notifier.deleteTransaction(source.id);
      expect(providers.read(transactionProvider).value, isEmpty);
    },
  );
}

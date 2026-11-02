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

  test('account timing and pending status round-trip with legacy defaults', () {
    expect(
      Account.fromMap(
        bank.copyWith(defaultCashbackRule: CashbackRule.onePercent).toMap(),
      ).defaultCashbackRule,
      CashbackRule.onePercent,
    );
    expect(
      Account.fromMap(bank.toMap()..remove('defaultCashbackRule'))
          .defaultCashbackRule,
      CashbackRule.none,
    );
    expect(
      Account.fromMap(bank.copyWith(cashbackDelayed: true).toMap())
          .cashbackDelayed,
      isTrue,
    );
    expect(
      Account.fromMap(bank.toMap()..remove('cashbackDelayed')).cashbackDelayed,
      isFalse,
    );
    final pending = purchase().copyWith(cashbackPending: true);
    final restored = AppTransaction.fromMap(pending.toMap());
    expect(restored.cashbackPending, isTrue);
    expect(restored.expectedCashback, 12);
    expect(restored.cashbackCredit, isNull);
    final legacy = AppTransaction.fromMap(
      purchase().toMap()..remove('cashbackPending'),
    );
    expect(legacy.cashbackPending, isFalse);
    expect(legacy.cashbackCredit!.amount, 12);
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

      test('pending filter includes eligible cashback and excludes received and zero amounts', () async {
        final pending = purchase().copyWith(cashbackPending: true);
        final transfer = pending.copyWith(
          id: 'transfer',
          amount: 500,
          type: TransactionType.transfer,
          toAccountId: 'other',
        );
        final zero = pending.copyWith(id: 'zero', amount: 0.49);
        final rounded = pending.copyWith(id: 'rounded', amount: 0.495);
        final receivedSource = purchase().copyWith(id: 'received');
        for (final source in [
          pending,
          transfer,
          zero,
          rounded,
          receivedSource,
        ]) {
          if (source.type == TransactionType.transfer) {
            await ledger.recordTransfer(transferTransaction: source);
          } else {
            await ledger.recordTransaction(source);
          }
        }
        const filter = TransactionFilter(pendingCashbackOnly: true);
        var page = await ledger.getTransactionPage(
          filter: filter,
          categoryNamesById: const {},
        );
        expect(page.items.map((tx) => tx.id).toSet(), {
          'purchase',
          'transfer',
          'rounded',
        });
        await ledger.updateTransaction(
          pending.copyWith(
            cashbackPending: false,
            cashbackReceivedAt: () => received,
          ),
        );
        page = await ledger.getTransactionPage(
          filter: filter,
          categoryNamesById: const {},
        );
        expect(page.items.map((tx) => tx.id).toSet(), {'transfer', 'rounded'});
        final combined = await ledger.getTransactionPage(
          filter: filter.copyWith(
            type: TransactionType.transfer,
            accountIds: {'other'},
          ),
          categoryNamesById: const {},
        );
        expect(combined.items.single.id, transfer.id);
      });

      test('stale account edits retain a newer remembered cashback choice', () async {
        final AccountRepository repository = sqlite
            ? SqliteAccountAdapter()
            : InMemoryAccountAdapter(initial: [bank]);
        final providers = ProviderContainer(
          overrides: [accountRepositoryProvider.overrideWithValue(repository)],
        );
        addTearDown(providers.dispose);
        await providers.read(accountProvider.future);
        final notifier = providers.read(accountProvider.notifier);
        await notifier.rememberCashbackRule(bank.id, CashbackRule.onePercent);
        await notifier.updateAccount(bank.copyWith(name: 'Updated name'));
        var restored = (await repository.getAccounts()).singleWhere(
          (a) => a.id == bank.id,
        );
        expect(restored.defaultCashbackRule, CashbackRule.onePercent);
        expect(restored.name, 'Updated name');
        expect(
          providers
              .read(accountProvider)
              .value!
              .singleWhere((a) => a.id == bank.id)
              .defaultCashbackRule,
          CashbackRule.onePercent,
        );
        // Another engine can remember a choice without updating this container.
        await repository.setDefaultCashbackRule(
          bank.id,
          CashbackRule.fixedFive,
        );
        await notifier.updateAccount(bank.copyWith(name: 'Edited again'));
        restored = (await repository.getAccounts()).singleWhere(
          (a) => a.id == bank.id,
        );
        expect(restored.defaultCashbackRule, CashbackRule.fixedFive);
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
        'pending cashback affects neither balance nor income until received',
        () async {
          final source = purchase().copyWith(cashbackPending: true);
          await ledger.recordTransaction(source);
          await ledger.recordTransaction(source);
          var entries = await ledger.getTransactionFamily(source.id);
          expect(entries, hasLength(1));
          var stats = DashboardStats.calculate(
            accounts: [bank],
            transactions: entries,
          );
          expect(stats.accountBalances[bank.id], 8800);
          expect(stats.allTimeIncome, 0);
          expect(stats.allTimeExpense, 1200);
          final confirmed = source.copyWith(
            cashbackPending: false,
            cashbackReceivedAt: () => received,
          );
          await ledger.updateTransaction(confirmed);
          await ledger.updateTransaction(confirmed);
          entries = await ledger.getTransactionFamily(source.id);
          expect(entries, hasLength(2));
          final credit = entries.singleWhere(
            (tx) => tx.cashbackSourceId != null,
          );
          expect(credit.date, received);
          expect(credit.amount, 12);
          stats = DashboardStats.calculate(
            accounts: [bank],
            transactions: entries,
          );
          expect(stats.accountBalances[bank.id], 8812);
          expect(stats.allTimeIncome, 12);
          await ledger.updateTransaction(source);
          entries = await ledger.getTransactionFamily(source.id);
          expect(entries.single.cashbackPending, isTrue);
          expect(entries.single.cashbackReceivedAt, isNull);
          stats = DashboardStats.calculate(
            accounts: [bank],
            transactions: entries,
          );
          expect(stats.accountBalances[bank.id], 8800);
          expect(stats.allTimeIncome, 0);
          await ledger.updateTransaction(confirmed);
          entries = await ledger.getTransactionFamily(source.id);
          expect(entries, hasLength(2));
          expect(
            entries.singleWhere((tx) => tx.cashbackSourceId != null).amount,
            12,
          );
        },
      );

      test(
        'pending edits recalculate without creating income and can be removed',
        () async {
          final source = purchase().copyWith(cashbackPending: true);
          await ledger.recordTransaction(source);
          final updated = source.copyWith(amount: 2000, accountId: 'other');
          await ledger.updateTransaction(updated);
          var family = await ledger.getTransactionFamily(source.id);
          expect(family.single.expectedCashback, 20);
          expect(family.single.accountId, 'other');
          await ledger.updateTransaction(
            updated.copyWith(
              cashbackRule: CashbackRule.none,
              cashbackPending: false,
            ),
          );
          family = await ledger.getTransactionFamily(source.id);
          expect(family.single.expectedCashback, 0);
          await ledger.voidTransaction(source.id);
          expect(await ledger.getTransactionFamily(source.id), isEmpty);
        },
      );

      test(
        'pending transfer cashback leaves fees and receiving balance intact',
        () async {
          final source = purchase(rule: CashbackRule.fixedFive).copyWith(
            type: TransactionType.transfer,
            toAccountId: 'other',
            cashbackPending: true,
          );
          final fee = purchase(rule: CashbackRule.none)
              .copyWith(id: 'fee', amount: 10);
          await ledger.recordTransfer(
            transferTransaction: source,
            feeTransaction: fee,
          );
          var family = await ledger.getTransactionFamily(source.id);
          expect(family, hasLength(2));
          final stats = DashboardStats.calculate(
            accounts: [
              bank,
              bank.copyWith(id: 'other', initialBalance: 0),
            ],
            transactions: family,
          );
          expect(stats.accountBalances[bank.id], 8790);
          expect(stats.accountBalances['other'], 1200);
          expect(stats.allTimeIncome, 0);
          await ledger.updateTransfer(
            source.copyWith(
              cashbackPending: false,
              cashbackReceivedAt: () => received,
            ),
            fee,
          );
          family = await ledger.getTransactionFamily(source.id);
          expect(family, hasLength(3));
          expect(
            family.singleWhere((tx) => tx.cashbackSourceId != null).amount,
            5,
          );
          expect(family.singleWhere((tx) => tx.id == 'fee').amount, 10);
        },
      );

      test(
        'pending cashback with a receipt date is rejected atomically',
        () async {
          await expectLater(
            ledger.recordTransaction(
              purchase(receivedAt: received).copyWith(cashbackPending: true),
            ),
            throwsA(isA<FinancialValidationException>()),
          );
          expect(await ledger.getTransactions(), isEmpty);
        },
      );

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
        test('remembered cashback changes only that account and survives reopening', () async {
          final repository = SqliteAccountAdapter();
          await repository.setDefaultCashbackRule(
            bank.id,
            CashbackRule.onePercent,
          );
          await helper.close();
          var accounts = await repository.getAccounts();
          final restored = accounts.singleWhere((a) => a.id == bank.id);
          expect(restored.defaultCashbackRule, CashbackRule.onePercent);
          expect(restored.initialBalance, bank.initialBalance);
          expect(restored.name, bank.name);
          expect(
            accounts.singleWhere((a) => a.id == 'other').defaultCashbackRule,
            CashbackRule.none,
          );
          await repository.setDefaultCashbackRule(bank.id, CashbackRule.none);
          accounts = await repository.getAccounts();
          expect(
            accounts.singleWhere((a) => a.id == bank.id).defaultCashbackRule,
            CashbackRule.none,
          );
        });

        test(
          'version 50 upgrades default cashback without touching credits',
          () async {
            final source = purchase();
            await ledger.recordTransaction(source);
            final db = await helper.database;
            await db.execute(
              'ALTER TABLE accounts DROP COLUMN defaultCashbackRule',
            );
            await db.setVersion(50);
            await helper.close();
            expect(
              (await helper.getAccounts()).every(
                (a) => a.defaultCashbackRule == CashbackRule.none,
              ),
              isTrue,
            );
            final family = await ledger.getTransactionFamily(source.id);
            expect(family, hasLength(2));
            expect(
              family.singleWhere((tx) => tx.cashbackSourceId != null).amount,
              12,
            );
          },
        );

        test('version 49 preserves existing credits and defaults account to instant', () async {
          final source = purchase();
          await ledger.recordTransaction(source);
          final db = await helper.database;
          await db.execute('ALTER TABLE accounts DROP COLUMN cashbackDelayed');
          await db.execute(
            'ALTER TABLE transactions DROP COLUMN cashbackPending',
          );
          await db.setVersion(49);
          await helper.close();
          var family = await ledger.getTransactionFamily(source.id);
          expect(family, hasLength(2));
          final restored = family.singleWhere((tx) => tx.id == source.id);
          expect(restored.cashbackPending, isFalse);
          expect(restored.cashbackReceivedAt, isNull);
          expect(
            (await helper.getAccounts())
                .singleWhere((a) => a.id == bank.id)
                .cashbackDelayed,
            isFalse,
          );
          await ledger.updateTransaction(restored);
          family = await ledger.getTransactionFamily(source.id);
          expect(
            family.singleWhere((tx) => tx.cashbackSourceId != null).date,
            date,
          );
          expect(
            DashboardStats.calculate(
              accounts: [bank],
              transactions: family,
            ).accountBalances[bank.id],
            8812,
          );
        });

        test(
          'pending cashback and account timing survive backup and reopening',
          () async {
            await helper.updateAccount(bank.copyWith(cashbackDelayed: true));
            await SqliteAccountAdapter().setDefaultCashbackRule(
              bank.id,
              CashbackRule.onePercent,
            );
            final source = purchase().copyWith(cashbackPending: true);
            await ledger.recordTransaction(source);
            final backupPath = '${directory!.path}/pending-backup.db';
            await DatabaseSnapshot.create(await helper.database, backupPath);
            final backup = await openDatabase(
              backupPath,
              singleInstance: false,
            );
            try {
              final rows = (await backup.query('transactions'))
                  .map(AppTransaction.fromMap);
              expect(rows.single.cashbackPending, isTrue);
              expect(rows.single.cashbackCredit, isNull);
              final accounts = (await backup.query('accounts'))
                  .map(Account.fromMap);
              expect(
                accounts.singleWhere((a) => a.id == bank.id).cashbackDelayed,
                isTrue,
              );
              expect(
                accounts
                    .singleWhere((a) => a.id == bank.id)
                    .defaultCashbackRule,
                CashbackRule.onePercent,
              );
            } finally {
              await backup.close();
            }
            await helper.close();
            expect(
              (await ledger.getTransactionFamily(source.id))
                  .single
                  .cashbackPending,
              isTrue,
            );
          },
        );

        test('pending cashback cannot fund another expense', () async {
          final source = purchase(
            amount: 10000,
            rule: CashbackRule.fixedFive,
          ).copyWith(cashbackPending: true);
          await ledger.recordTransaction(source);
          await expectLater(
            ledger.recordTransaction(
              purchase(
                amount: 5,
                rule: CashbackRule.none,
              ).copyWith(id: 'extra'),
            ),
            throwsA(isA<FinancialValidationException>()),
          );
        });

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

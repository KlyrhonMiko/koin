import 'dart:io';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _CountingSqliteLedger extends SqliteLedgerAdapter {
  _CountingSqliteLedger() : super(savingsApprovals: SavingsSpendingApprovals());

  int historyReads = 0;
  @override
  Future<List<AppTransaction>> getTransactions() {
    historyReads++;
    return super.getTransactions();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final helper = DatabaseHelper.instance;
  late Directory directory;
  final source = List.generate(
    20000,
    (i) => AppTransaction(
      id: 'history_${i.toString().padLeft(6, '0')}',
      note: i == 13
          ? 'ÉCOLE'
          : i.isEven
          ? 'Coffee at café'
          : 'Salary',
      amount: (i % 100 + 1).toDouble(),
      date: DateTime(2026, 1, 1).add(Duration(seconds: i ~/ 3)),
      type: TransactionType.values[i % 3],
      accountId: i.isEven ? 'default_account' : 'bank_account',
      toAccountId: i % 3 == 2
          ? (i.isEven ? 'bank_account' : 'default_account')
          : null,
      categoryId: i % 3 == 0 ? 'salary' : 'food',
    ),
  );
  const names = {'salary': 'Salary', 'food': 'Food'};
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('koin_paging_');
    await databaseFactory.setDatabasesPath(directory.path);
    final db = await helper.database;
    await db.update('accounts', {'initialBalance': 10000});
    await db.transaction((txn) async {
      for (var offset = 0; offset < source.length; offset += 500) {
        final batch = txn.batch();
        for (final tx in source.skip(offset).take(500)) {
          batch.insert('transactions', tx.toMap());
        }
        await batch.commit(noResult: true);
      }
    });
  });
  tearDownAll(() async {
    await helper.close();
    expect(
      directory.absolute.path.startsWith(Directory.systemTemp.absolute.path),
      true,
    );
    await directory.delete(recursive: true);
  });

  Future<TransactionPage> page(
    TransactionFilter filter, {
    TransactionCursor? after,
    int limit = 100,
  }) => helper.getTransactionPage(
    filter: filter,
    categoryNamesById: names,
    after: after,
    limit: limit,
  );

  test('large history is bounded and daily totals include unloaded rows', () async {
    final watch = Stopwatch()..start();
    final first = await page(const TransactionFilter());
    watch.stop();
    debugPrint(
      '20,000-row SQLite history first page: ${watch.elapsedMilliseconds}ms, ${first.items.length} rows',
    );
    expect(first.items, hasLength(100));
    expect(first.next, isNotNull);
    final expected = TransactionPage.fromTransactions(
      source,
      filter: const TransactionFilter(),
      categoryNamesById: names,
    );
    expect(first.items.map((tx) => tx.id), expected.items.map((tx) => tx.id));
    expect(first.dayTotals, expected.dayTotals);
    final next = await page(const TransactionFilter(), after: first.next);
    final ids = [...first.items, ...next.items].map((tx) => tx.id).toList();
    expect(ids.toSet(), hasLength(200));
  });

  test(
    'keyset pagination preserves combined filters and complete totals',
    () async {
      final filter = TransactionFilter(
        query: 'coffee',
        type: TransactionType.expense,
        accountIds: {'default_account'},
        categoryIds: {'food'},
        minAmount: 50,
        maxAmount: 75,
        dateRange: DateTimeRange(
          start: DateTime(2026, 1, 1),
          end: DateTime(2026, 1, 1),
        ),
      );
      final expected = filter.apply(source, categoryNamesById: names)
        ..sort(TransactionPage.compare);
      final found = <AppTransaction>[];
      TransactionCursor? cursor;
      do {
        final result = await page(filter, after: cursor, limit: 73);
        found.addAll(result.items);
        expect(
          result.dayTotals.values.single,
          -expected.fold<double>(0, (sum, tx) => sum + tx.amount),
        );
        cursor = result.next;
      } while (cursor != null);
      expect(found.map((tx) => tx.id), expected.map((tx) => tx.id));
      expect(found.map((tx) => tx.id).toSet(), hasLength(found.length));
    },
  );

  test(
    'destination account filtering and Unicode search retain existing behavior',
    () async {
      final filter = TransactionFilter(
        accountIds: {'bank_account'},
        type: TransactionType.transfer,
      );
      final expected = filter.apply(source)..sort(TransactionPage.compare);
      final transfers = await page(filter);
      expect(
        transfers.items.map((tx) => tx.id),
        expected.take(100).map((tx) => tx.id),
      );
      final unicode = await page(const TransactionFilter(query: 'école'));
      expect(unicode.items.single.id, source[13].id);
    },
  );

  test(
    'ordinary saves and edits do not reload the complete analytics history',
    () async {
      final ledger = _CountingSqliteLedger();
      final c = ProviderContainer(
        overrides: [ledgerProvider.overrideWithValue(ledger)],
      );
      final sub = c.listen(transactionProvider, (_, _) {});
      try {
        await c.read(transactionProvider.future);
        final tx = AppTransaction(
          id: 'new',
          amount: 10,
          date: DateTime(2026, 10, 1),
          type: TransactionType.expense,
          accountId: 'default_account',
          categoryId: 'salary',
        );
        await c.read(transactionProvider.notifier).addTransaction(tx);
        await c
            .read(transactionProvider.notifier)
            .updateTransaction(tx.copyWith(amount: 20));
        expect(c.read(transactionProvider).value!.first.amount, 20);
        await c.read(transactionProvider.notifier).deleteTransaction(tx.id);
        expect(c.read(transactionProvider).value, hasLength(source.length));
        expect(ledger.historyReads, 1);
      } finally {
        sub.close();
        c.dispose();
      }
    },
  );
}

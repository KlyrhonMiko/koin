import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/categorization/categorization_engine.dart';
import 'package:koin/core/categorization/category_suggester.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/ledger/ledger.dart';
import 'package:koin/core/models/models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Database db;
  late CategorizationEngine engine;
  final helper = DatabaseHelper.instance;
  final ledger = SqliteLedgerAdapter();

  AppTransaction transaction(
    String id, {
    String note = 'Coffee shop',
    String categoryId = 'cat_food',
    DateTime? date,
    TransactionType type = TransactionType.expense,
    String? toAccountId,
  }) => AppTransaction(
    id: id,
    note: note,
    amount: 25,
    date: date ?? DateTime(2026, 1, 1),
    type: type,
    categoryId: categoryId,
    accountId: 'default_account',
    toAccountId: toAccountId,
  );

  Future<CategorizationResult?> suggest(String text, {double amount = -25}) =>
      engine.categorize(
        rawText: text,
        amount: amount,
        date: DateTime(2026, 10, 3),
        currentAccountId: 'default_account',
      );

  Future<int> occurrences(String token) async {
    final rows = await db.query(
      'ml_frequency_dictionary',
      where: 'token = ?',
      whereArgs: [token],
    );
    return rows.fold<int>(
      0,
      (total, row) => total + (row['occurrences'] as num).toInt(),
    );
  }

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('koin_history_test_');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await helper.database;
  });

  setUp(() async {
    await db.delete('transactions');
    await db.delete('categorization_rules');
    await db.delete('ml_frequency_dictionary');
    await db.delete('categorization_feedback');
    await db.delete('app_settings');
    engine = CategorizationEngine();
  });

  tearDownAll(() async {
    await db.close();
    await directory.delete(recursive: true);
  });

  test('repairs the legacy bootstrap flag and reads all old history', () async {
    await db.insert('app_settings', {
      'key': 'is_ml_bootstrapped',
      'value': 'true',
    });
    await ledger.recordTransaction(transaction('oldest', note: 'Old bakery'));
    for (var i = 0; i < 120; i++) {
      await ledger.recordTransaction(
        transaction(
          'recent_$i',
          note: 'Coffee shop',
          date: DateTime(2026, 9, 1),
        ),
      );
    }

    expect((await suggest('Old bakery'))?.destinationId, 'cat_food');
    expect(await occurrences('coffee'), 120);
    expect(await occurrences('bakery'), 1);
  });

  test('learns ledger writes after an empty initial bootstrap', () async {
    await engine.bootstrapFromHistory();
    expect(await suggest('Coffee shop'), isNull);

    await ledger.recordTransaction(transaction('later'));

    expect((await suggest('Coffee shop'))?.destinationId, 'cat_food');
  });

  Future<void> recordMatchingIncome() => ledger.recordTransaction(
    transaction(
      'gcash_income',
      note: 'Allowance',
      categoryId: 'cat_salary',
      type: TransactionType.income,
      date: DateTime(2026, 10, 3, 8, 30),
    ).copyWith(amount: 1000, accountId: 'bank_account'),
  );

  Future<CategorySuggestion?> formSuggestion(
    String text, {
    double amount = 1000,
    TransactionType type = TransactionType.expense,
    String accountId = 'default_account',
  }) => HybridMlSuggesterAdapter(engine: engine).suggest(
    SuggestionContext(
      text: text,
      amount: amount,
      type: type,
      date: DateTime(2026, 10, 3, 9, 50),
      currentAccountId: accountId,
    ),
  );

  test(
    'matching another account income cannot turn arbitrary notes into transfers',
    () async {
      await recordMatchingIncome();
      for (final text in ['test', 'The Love Hypothesis']) {
        expect(await formSuggestion(text), isNull);
      }
    },
  );

  test(
    'burger learns Food from cheese burger despite other categories and matching income',
    () async {
      await recordMatchingIncome();
      await ledger.recordTransaction(
        transaction('food', note: 'Cheese burger'),
      );
      await ledger.recordTransaction(
        transaction('travel', note: 'Bus ticket', categoryId: 'cat_transport'),
      );
      await ledger.recordTransaction(
        transaction(
          'transfer',
          note: 'Savings deposit',
          type: TransactionType.transfer,
          toAccountId: 'bank_account',
        ),
      );

      for (final text in ['burger', 'Grilled burger']) {
        final suggestion = await formSuggestion(text);
        expect(suggestion?.categoryId, 'cat_food');
        expect(suggestion?.type, TransactionType.expense);
        expect(suggestion?.isExactMatch, isFalse);
      }
      expect((await formSuggestion('Cheese burger'))?.isExactMatch, isTrue);
      expect(
        (await formSuggestion('burger', amount: 0))?.categoryId,
        'cat_food',
      );
    },
  );

  test('conflicting word evidence still needs sufficient confidence', () async {
    await ledger.recordTransaction(transaction('food', note: 'Cheese burger'));
    await ledger.recordTransaction(
      transaction('travel', note: 'Bus ticket', categoryId: 'cat_transport'),
    );
    expect(await formSuggestion('burger ticket'), isNull);
  });

  test(
    'one shared word suggests without claiming certainty or auto-applying',
    () async {
      await ledger.recordTransaction(transaction('one', note: 'Cheese burger'));
      final result = await formSuggestion('burger');
      expect(result?.categoryId, 'cat_food');
      expect(result!.confidence, lessThan(0.7));
      expect(result.canAutoApply, isFalse);
      expect((await formSuggestion('Cheese burger'))!.canAutoApply, isFalse);
    },
  );

  test(
    'category evidence combines accounts and preserves the selected account',
    () async {
      for (var i = 0; i < 3; i++) {
        await ledger.recordTransaction(
          transaction(
            'sample_$i',
            note: 'Cheese burger',
          ).copyWith(accountId: i == 0 ? 'default_account' : 'bank_account'),
        );
      }
      final result = await formSuggestion(
        'burger',
        accountId: 'default_account',
      );
      expect(result?.categoryId, 'cat_food');
      expect(result!.canAutoApply, isTrue);
      expect(result.originAccountId, 'default_account');
    },
  );

  test(
    'repeated words in one note do not create independent evidence',
    () async {
      await ledger.recordTransaction(
        transaction('repeat', note: 'burger burger burger'),
      );
      expect((await formSuggestion('burger'))!.canAutoApply, isFalse);
      expect(await occurrences('burger'), 1);
    },
  );

  test(
    'normalization retains Unicode, short names, and merchant digits',
    () async {
      await ledger.recordTransaction(transaction('unicode', note: 'Café 24'));
      expect((await formSuggestion('CAFÉ—24'))?.isExactMatch, isTrue);
      expect(await formSuggestion('Café 25'), isNotNull);
      expect((await formSuggestion('Café 25'))!.isExactMatch, isFalse);
      await ledger.recordTransaction(transaction('short', note: 'SM'));
      expect((await formSuggestion('SM store'))?.categoryId, 'cat_food');
    },
  );

  test('explicit correction wins over old history after rebuilding', () async {
    await ledger.recordTransaction(transaction('old', note: 'Coffee shop'));
    await engine.processFeedback(
      rawText: 'Coffee shop',
      amount: -25,
      originId: 'default_account',
      destinationId: 'cat_transport',
    );
    await ledger.recordTransaction(transaction('unrelated', note: 'Bread'));
    final result = await formSuggestion('Coffee shop');
    expect(result?.categoryId, 'cat_transport');
    expect(result!.canAutoApply, isTrue);
    expect(result.confidence, lessThan(1));
  });

  test(
    'historical transfers cannot change an expense form into a transfer',
    () async {
      await ledger.recordTransaction(
        transaction(
          'move',
          note: 'Savings deposit',
          type: TransactionType.transfer,
          toAccountId: 'bank_account',
        ),
      );
      expect(await formSuggestion('Savings deposit'), isNull);
    },
  );

  test(
    'selected transfers can still pair accounts by real amount and date',
    () async {
      await recordMatchingIncome();
      final suggestion = await formSuggestion(
        'Move funds',
        type: TransactionType.transfer,
      );
      expect(suggestion?.type, TransactionType.transfer);
      expect(suggestion?.originAccountId, 'default_account');
      expect(suggestion?.destinationAccountId, 'bank_account');
      expect(
        await formSuggestion(
          'Move funds',
          type: TransactionType.transfer,
          accountId: '',
        ),
        isNull,
      );

      await ledger.recordTransaction(
        transaction(
          'one_peso',
          note: 'Small allowance',
          categoryId: 'cat_salary',
          type: TransactionType.income,
          date: DateTime(2026, 10, 3),
        ).copyWith(amount: 1, accountId: 'bank_account'),
      );
      expect(
        await formSuggestion(
          'Move funds',
          type: TransactionType.transfer,
          amount: 0,
        ),
        isNull,
      );
    },
  );

  test(
    'edits replace old categories and deleted transactions stop teaching',
    () async {
      await ledger.recordTransaction(transaction('edit'));
      expect((await suggest('Coffee shop'))?.destinationId, 'cat_food');

      await ledger.updateTransaction(
        transaction('edit', categoryId: 'cat_transport'),
      );
      expect((await suggest('Coffee shop'))?.destinationId, 'cat_transport');
      expect(await occurrences('coffee'), 1);

      await ledger.voidTransaction('edit');
      expect(await suggest('Coffee shop'), isNull);
      expect(await occurrences('coffee'), 0);
    },
  );

  test(
    'unchanged and concurrent synchronizations do not inflate learning',
    () async {
      await ledger.recordTransaction(transaction('once'));
      await Future.wait([
        engine.bootstrapFromHistory(),
        CategorizationEngine().bootstrapFromHistory(),
        suggest('Coffee shop'),
      ]);
      final rules = await db.query('categorization_rules');
      await engine.bootstrapFromHistory();
      expect(await occurrences('coffee'), 1);
      expect(await db.query('categorization_rules'), rules);
    },
  );

  test(
    'latest dated history wins exact matches regardless of insertion order',
    () async {
      await ledger.recordTransaction(
        transaction(
          'newer',
          categoryId: 'cat_transport',
          date: DateTime(2026, 9, 1),
        ),
      );
      await ledger.recordTransaction(transaction('older'));
      expect((await suggest('Coffee shop'))?.destinationId, 'cat_transport');
    },
  );

  test('historical transfer tokens use the outgoing sign', () async {
    await ledger.recordTransaction(
      transaction(
        'transfer',
        note: 'Savings deposit',
        type: TransactionType.transfer,
        toAccountId: 'bank_account',
      ),
    );
    final suggestion = await suggest('Monthly savings deposit');
    expect(suggestion?.type, TransactionType.transfer);
    expect(suggestion?.destinationId, 'bank_account');
    final rows = await db.query('ml_frequency_dictionary');
    expect(rows.every((row) => row['sign'] == -1), isTrue);
  });

  test(
    'planned-payment feedback survives history rebuilds without inflation',
    () async {
      await engine.processFeedback(
        rawText: 'Monthly subscription',
        amount: -10,
        originId: 'default_account',
        destinationId: 'cat_entertainment',
      );
      await ledger.recordTransaction(transaction('unrelated'));
      expect(
        (await suggest('Monthly subscription'))?.destinationId,
        'cat_entertainment',
      );
      expect(await occurrences('subscription'), 1);

      await engine.processFeedback(
        rawText: 'Monthly subscription',
        amount: -12,
        originId: 'default_account',
        destinationId: 'cat_food',
      );
      expect(
        (await suggest('Monthly subscription'))?.destinationId,
        'cat_food',
      );
      expect(await occurrences('subscription'), 1);
      expect(await occurrences('coffee'), 1);
    },
  );

  test('backup settings preserve model state and unchanged learning', () async {
    await ledger.recordTransaction(transaction('backup'));
    await engine.bootstrapFromHistory();
    final rules = await db.query('categorization_rules');
    await helper.saveSettingsToDb({'currency_code': 'PHP'});
    await engine.bootstrapFromHistory();
    expect(await db.query('categorization_rules'), rules);
    expect(await occurrences('coffee'), 1);
  });

  test(
    'clearing all data clears both transaction and explicit feedback memory',
    () async {
      await engine.processFeedback(
        rawText: 'Monthly subscription',
        amount: -10,
        originId: 'default_account',
        destinationId: 'cat_food',
      );
      await helper.deleteAllData();
      expect(await db.query('categorization_feedback'), isEmpty);
      expect(await db.query('ml_frequency_dictionary'), isEmpty);
      // Recreate defaults for following tests through the production reset path.
      await helper.resetDatabase();
      db = await helper.database;
    },
  );

  test(
    'restoring a version 32 backup upgrades triggers and retrains history',
    () async {
      await ledger.recordTransaction(
        transaction('restored', note: 'Restored bakery'),
      );
      final triggers = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'trigger' AND name LIKE 'categorization_%'",
      );
      for (final trigger in triggers) {
        await db.execute('DROP TRIGGER ${trigger['name']}');
      }
      await db.insert('app_settings', {
        'key': 'is_ml_bootstrapped',
        'value': 'true',
      });
      await db.setVersion(32);
      final backup = File('${directory.path}/legacy_backup.db');
      await File(await helper.getDatabaseFilePath()).copy(backup.path);

      expect(await helper.restoreDatabase(backup.path), isTrue);
      db = await helper.database;
      expect(await db.getVersion(), 36);
      expect((await suggest('Restored bakery'))?.destinationId, 'cat_food');

      await ledger.recordTransaction(
        transaction('after_restore', note: 'Train ticket'),
      );
      expect((await suggest('Train ticket'))?.destinationId, 'cat_food');
    },
  );

  test(
    'repairs an intermediate version 33 database without deleting history',
    () async {
      await ledger.recordTransaction(
        transaction('repair', note: 'Repair bakery'),
      );
      await db.execute('DROP TABLE categorization_feedback');
      await db.setVersion(33);
      final backup = File('${directory.path}/intermediate_backup.db');
      await File(await helper.getDatabaseFilePath()).copy(backup.path);

      expect(await helper.restoreDatabase(backup.path), isTrue);
      db = await helper.database;
      expect(await db.getVersion(), 36);
      expect(await db.query('categorization_feedback'), isEmpty);
      expect((await suggest('Repair bakery'))?.destinationId, 'cat_food');
      expect((await ledger.getTransactions()).single.id, 'repair');
    },
  );
}

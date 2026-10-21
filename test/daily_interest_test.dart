import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/database_version.dart';
import 'package:koin/core/maintenance/database_snapshot.dart';
import 'package:koin/core/repositories/daily_interest_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  Account bank({double balance = 10000, double rate = 3.65, double tax = 20}) =>
      Account(
        id: 'bank',
        name: 'Savings bank',
        iconCodePoint: 0,
        colorHex: '#00A884',
        initialBalance: balance,
        annualInterestRate: rate,
        interestTaxRate: tax,
        interestStartDate: DateTime(2026, 10, 20),
      );

  test(
    'annual rate is divided by 365, tax reduces interest, currency rounds',
    () {
      expect(DailyInterest.estimate(balance: 10000, annualRate: 3.65), 1);
      expect(
        DailyInterest.estimate(balance: 10000, annualRate: 3.65, taxRate: 20),
        0.8,
      );
      expect(DailyInterest.estimate(balance: 100, annualRate: 3.65), 0.01);
      expect(
        DailyInterest.estimate(
          balance: 10000,
          annualRate: 3.65,
          taxRate: 20,
          decimalDigits: 0,
        ),
        1,
      );
      expect(
        DailyInterest.estimate(balance: 10000, annualRate: 3.65, taxRate: 100),
        0,
      );
      for (final value in [-10.0, 0.0, double.nan, double.infinity]) {
        expect(DailyInterest.estimate(balance: value, annualRate: 3.65), 0);
        expect(DailyInterest.validRates(value, 0), isFalse);
      }
      expect(DailyInterest.validRates(4, -1), isFalse);
      expect(DailyInterest.validRates(4, 101), isFalse);
    },
  );

  test('settings round-trip; legacy and credit accounts do not accrue', () {
    final account = Account.fromMap(bank().toMap());
    expect(account.hasDailyInterest, isTrue);
    expect(account.annualInterestRate, 3.65);
    expect(account.interestTaxRate, 20);
    expect(account.interestStartDate, DateTime(2026, 10, 20));
    expect(account.copyWith(excludeFromTotal: true).hasDailyInterest, isTrue);
    expect(account.copyWith(isCredit: true).hasDailyInterest, isFalse);
    expect(
      account.copyWith(interestStartDate: () => null).hasDailyInterest,
      isFalse,
    );
    final legacy = bank().toMap()
      ..remove('annualInterestRate')
      ..remove('interestTaxRate')
      ..remove('interestStartDate');
    expect(Account.fromMap(legacy).hasDailyInterest, isFalse);
    expect(
      Account.fromMap(legacy).interestFrequency,
      InterestPayoutFrequency.daily,
    );
    final monthly = account.copyWith(
      interestFrequency: InterestPayoutFrequency.monthly,
    );
    expect(monthly.hasInterest, isTrue);
    expect(monthly.hasDailyInterest, isFalse);
    expect(
      Account.fromMap(monthly.toMap()).interestFrequency,
      InterestPayoutFrequency.monthly,
    );
  });

  test('payout estimates respect calendar months and leap years', () {
    expect(
      DailyInterest.estimatePayout(
        balance: 10000,
        annualRate: 3.65,
        taxRate: 20,
        frequency: InterestPayoutFrequency.monthly,
        at: DateTime(2028, 2),
      ),
      23.2,
    );
    expect(
      DailyInterest.estimatePayout(
        balance: 10000,
        annualRate: 3.65,
        taxRate: 20,
        frequency: InterestPayoutFrequency.yearly,
        at: DateTime(2028),
      ),
      292.8,
    );
  });

  group('SQLite interest accrual', () {
    final helper = DatabaseHelper.instance;
    final interest = DailyInterestRepository();
    late Directory directory;
    late Database db;
    setUp(() async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      directory = await Directory.systemTemp.createTemp('koin_interest_');
      await databaseFactory.setDatabasesPath(directory.path);
      db = await helper.database;
      await helper.insertAccount(bank());
    });
    tearDown(() async {
      await helper.close();
      await directory.delete(recursive: true);
    });

    Future<List<AppTransaction>> entries() async =>
        (await helper.getTransactions())
            .where((t) => t.id.startsWith('interest:'))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    Future<void> movement(
      String id,
      double amount,
      DateTime date,
      TransactionType type, {
      String accountId = 'bank',
      String? toAccountId,
    }) => helper.insertTransaction(
      AppTransaction(
        id: id,
        amount: amount,
        date: date,
        type: type,
        categoryId: '',
        accountId: accountId,
        toAccountId: toAccountId,
      ),
    );

    test(
      'records only completed days, catches up, and compounds net amounts',
      () async {
        await helper.updateAccount(bank(balance: 10000, rate: 36.5, tax: 0));
        expect(
          await interest.processDue(now: DateTime(2026, 10, 20, 23, 59)),
          0,
        );
        expect(await interest.processDue(now: DateTime(2026, 10, 23)), 3);
        final posted = await entries();
        expect(posted.map((t) => t.note), everyElement('Daily interest'));
        expect(posted.map((t) => t.amount), [10, 10.01, 10.02]);
        expect(posted.first.date, DateTime(2026, 10, 20, 23, 59, 59, 999));
        expect(
          posted.every(
            (t) =>
                t.categoryId == 'cat_interest' &&
                t.type == TransactionType.income,
          ),
          isTrue,
        );
        expect(
          TransactionRules.balance(bank(), posted, at: DateTime(2026, 10, 23)),
          closeTo(10030.03, 0.00001),
        );
        expect(
          (await helper.getCategories())
              .where((c) => c.id == 'cat_interest')
              .single
              .type,
          TransactionType.income,
        );
        expect(await interest.processDue(now: DateTime(2026, 10, 23, 15)), 0);
        await helper.close();
        expect(await interest.processDue(now: DateTime(2026, 10, 23, 18)), 0);
        expect((await entries()).length, 3);
      },
    );

    test('closing balances include deposits, withdrawals, both transfer directions and fees', () async {
      await movement(
        'deposit',
        1000,
        DateTime(2026, 10, 20, 8),
        TransactionType.income,
      );
      await movement(
        'expense',
        500,
        DateTime(2026, 10, 20, 12),
        TransactionType.expense,
      );
      await movement(
        'outgoing',
        2000,
        DateTime(2026, 10, 20, 13),
        TransactionType.transfer,
        toAccountId: 'default_account',
      );
      await movement(
        'fee',
        10,
        DateTime(2026, 10, 20, 13),
        TransactionType.expense,
      );
      await movement(
        'incoming',
        500,
        DateTime(2026, 10, 20, 14),
        TransactionType.transfer,
        accountId: 'default_account',
        toAccountId: 'bank',
      );
      await movement(
        'future',
        999999,
        DateTime(2026, 10, 22),
        TransactionType.income,
      );
      await interest.processDue(now: DateTime(2026, 10, 21));
      expect((await entries()).single.amount, 0.72); // 8990 × 3.65% / 365 × 80%
    });

    test(
      'zero or negative closing balances advance without phantom income',
      () async {
        await helper.updateAccount(bank(balance: -100));
        await movement(
          'replenish',
          10100,
          DateTime(2026, 10, 21, 12),
          TransactionType.income,
        );
        expect(await interest.processDue(now: DateTime(2026, 10, 22)), 1);
        expect((await entries()).single.date.day, 21);
        expect((await entries()).single.amount, 0.8);
        expect(await interest.processDue(now: DateTime(2026, 10, 22)), 0);
      },
    );

    test('edited/deleted interest stays corrected and account edits preserve progress', () async {
      await interest.processDue(now: DateTime(2026, 10, 22));
      final posted = await entries();
      await helper.updateTransaction(posted.first.copyWith(amount: 2));
      await SqliteLedgerAdapter().voidTransaction(posted.last.id);
      await helper.updateAccount(bank().copyWith(excludeFromTotal: true));
      expect(await interest.processDue(now: DateTime(2026, 10, 22)), 0);
      expect((await entries()).single.amount, 2);
      expect(await interest.processDue(now: DateTime(2026, 10, 23)), 1);
      expect((await entries()).last.amount, 0.8);
    });

    test('disable/re-enable skips disabled days and credit accounts', () async {
      await interest.processDue(now: DateTime(2026, 10, 21));
      await helper.updateAccount(bank(rate: 0));
      expect(await interest.processDue(now: DateTime(2026, 10, 24)), 0);
      await helper.updateAccount(
        bank().copyWith(interestStartDate: () => DateTime(2026, 10, 24)),
      );
      expect(await interest.processDue(now: DateTime(2026, 10, 25)), 1);
      expect((await entries()).map((t) => t.date.day), [20, 24]);
      await helper.updateAccount(bank().copyWith(isCredit: true));
      expect(await interest.processDue(now: DateTime(2026, 10, 26)), 0);
    });

    test('rate changes affect only subsequent completed days', () async {
      await interest.processDue(now: DateTime(2026, 10, 21));
      await helper.updateAccount(bank(rate: 7.3));
      await interest.processDue(now: DateTime(2026, 10, 22));
      expect((await entries()).map((t) => t.amount), [0.8, 1.6]);
    });

    test(
      'failure rolls back income and cursor together; retries are safe',
      () async {
        await db.execute(
          "CREATE TRIGGER fail_interest BEFORE UPDATE OF interestNextDate ON accounts BEGIN SELECT RAISE(ABORT, 'test failure'); END",
        );
        await expectLater(
          interest.processDue(now: DateTime(2026, 10, 22)),
          throwsA(isA<DatabaseException>()),
        );
        expect(await entries(), isEmpty);
        expect(
          (await db.query(
            'accounts',
            where: 'id = ?',
            whereArgs: ['bank'],
          )).single['interestNextDate'],
          isNull,
        );
        await db.execute('DROP TRIGGER fail_interest');
        expect(await interest.processDue(now: DateTime(2026, 10, 22)), 2);
      },
    );

    test('concurrent processing posts one entry per day', () async {
      final counts = await Future.wait([
        interest.processDue(now: DateTime(2026, 10, 22)),
        interest.processDue(now: DateTime(2026, 10, 22)),
      ]);
      expect(counts.reduce((a, b) => a + b), 2);
      expect((await entries()).length, 2);
    });

    test(
      'monthly interest accrues without increasing balance until month-end',
      () async {
        await helper.updateAccount(
          bank().copyWith(interestFrequency: InterestPayoutFrequency.monthly),
        );
        expect(await interest.processDue(now: DateTime(2026, 10, 31)), 0);
        expect(await entries(), isEmpty);
        var row = (await db.query(
          'accounts',
          where: 'id = ?',
          whereArgs: ['bank'],
        )).single;
        expect(row['interestAccrued'], closeTo(8.8, 0.000001));
        await helper.updateAccount(
          (await helper.getAccounts())
              .firstWhere((a) => a.id == 'bank')
              .copyWith(excludeFromTotal: true),
        );
        await helper.close();
        expect(await interest.processDue(now: DateTime(2026, 11, 1)), 1);
        expect((await entries()).single.amount, 9.6);
        expect((await entries()).single.note, 'Monthly interest');
        expect((await entries()).single.date.day, 31);
        expect(await interest.processDue(now: DateTime(2026, 11, 1)), 0);
        expect(await interest.processDue(now: DateTime(2026, 12, 1)), 1);
        expect((await entries()).last.amount, 24.02);
      },
    );

    test('monthly accrual uses each daily balance and rounds once at payout', () async {
      await helper.updateAccount(
        bank().copyWith(interestFrequency: InterestPayoutFrequency.monthly),
      );
      await movement(
        'deposit',
        10000,
        DateTime(2026, 10, 30, 12),
        TransactionType.income,
      );
      await interest.processDue(now: DateTime(2026, 11, 1));
      expect((await entries()).single.amount, 11.2);
      await helper.updateAccount(
        bank(balance: 1, tax: 0).copyWith(
          interestFrequency: InterestPayoutFrequency.monthly,
          interestStartDate: () => DateTime(2026, 11, 1),
        ),
      );
      // A tiny daily amount can still reach a payable amount over a full month.
      await db.delete('transactions');
      await helper.updateAccount(
        bank(balance: 3, tax: 0).copyWith(
          interestFrequency: InterestPayoutFrequency.monthly,
          interestStartDate: () => DateTime(2026, 11, 1),
        ),
      );
      await interest.processDue(now: DateTime(2026, 12, 1));
      expect((await entries()).single.amount, 0.01);
    });

    test(
      'yearly payout includes leap day and never compounds uncredited interest',
      () async {
        await helper.updateAccount(
          bank().copyWith(
            interestFrequency: InterestPayoutFrequency.yearly,
            interestStartDate: () => DateTime(2028, 1, 1),
          ),
        );
        expect(await interest.processDue(now: DateTime(2028, 12, 31)), 0);
        expect(await entries(), isEmpty);
        expect(await interest.processDue(now: DateTime(2029, 1, 1)), 1);
        expect((await entries()).single.amount, 292.8);
        expect((await entries()).single.note, 'Yearly interest');
        expect(
          (await entries()).single.date,
          DateTime(2028, 12, 31, 23, 59, 59, 999),
        );
      },
    );

    test(
      'monthly rate changes preserve accrued interest at the previous rate',
      () async {
        await helper.updateAccount(
          bank().copyWith(interestFrequency: InterestPayoutFrequency.monthly),
        );
        await interest.processDue(now: DateTime(2026, 10, 25));
        await helper.updateAccount(
          bank(rate: 7.3)
              .copyWith(interestFrequency: InterestPayoutFrequency.monthly),
        );
        await interest.processDue(now: DateTime(2026, 11, 1));
        expect((await entries()).single.amount, 15.2);
      },
    );

    test(
      'changing payout frequency carries unpaid interest to the new schedule',
      () async {
        await helper.updateAccount(
          bank().copyWith(interestFrequency: InterestPayoutFrequency.monthly),
        );
        await interest.processDue(now: DateTime(2026, 10, 25));
        await helper.updateAccount(bank());
        await interest.processDue(now: DateTime(2026, 10, 26));
        expect((await entries()).single.amount, 4.8);
        expect(await interest.processDue(now: DateTime(2026, 10, 26)), 0);
      },
    );

    test(
      'monthly pending accrual survives backups and skips disabled days',
      () async {
        final monthly = bank().copyWith(
          interestFrequency: InterestPayoutFrequency.monthly,
        );
        await helper.updateAccount(monthly);
        await interest.processDue(now: DateTime(2026, 10, 25));
        final path = '${directory.path}/pending_backup.db';
        await DatabaseSnapshot.create(db, path);
        final copy = await openDatabase(
          path,
          readOnly: true,
          singleInstance: false,
        );
        final saved = (await copy.query(
          'accounts',
          where: 'id = ?',
          whereArgs: ['bank'],
        )).single;
        expect(saved['interestFrequency'], 'monthly');
        expect(saved['interestAccrued'], closeTo(4, 0.000001));
        await copy.close();
        await helper.updateAccount(
          monthly.copyWith(
            annualInterestRate: 0,
            interestStartDate: () => null,
          ),
        );
        await interest.processDue(now: DateTime(2026, 10, 28));
        await helper.updateAccount(
          monthly.copyWith(interestStartDate: () => DateTime(2026, 10, 28)),
        );
        await interest.processDue(now: DateTime(2026, 11, 1));
        expect((await entries()).single.amount, 7.2);
      },
    );

    test(
      'version 42 migration preserves existing daily payouts and progress',
      () async {
        await interest.processDue(now: DateTime(2026, 10, 22));
        for (final column in ['interestFrequency', 'interestAccrued']) {
          await db.execute('ALTER TABLE accounts DROP COLUMN $column');
        }
        await db.setVersion(42);
        await helper.close();
        db = await helper.database;
        final saved = (await helper.getAccounts()).firstWhere(
          (a) => a.id == 'bank',
        );
        expect(saved.interestFrequency, InterestPayoutFrequency.daily);
        expect(saved.annualInterestRate, 3.65);
        expect(saved.hasInterest, isTrue);
        expect(await interest.processDue(now: DateTime(2026, 10, 22)), 0);
        expect((await entries()).length, 2);
        expect(await interest.processDue(now: DateTime(2026, 10, 23)), 1);
      },
    );

    test('version 41 migration preserves money and backup includes interest progress', () async {
      for (final column in [
        'annualInterestRate',
        'interestTaxRate',
        'interestStartDate',
        'interestNextDate',
      ]) {
        await db.execute('ALTER TABLE accounts DROP COLUMN $column');
      }
      await db.setVersion(41);
      await helper.close();
      db = await helper.database;
      expect(await db.getVersion(), databaseSchemaVersion);
      final migrated = (await helper.getAccounts()).firstWhere(
        (a) => a.id == 'bank',
      );
      expect(migrated.initialBalance, 10000);
      expect(migrated.hasDailyInterest, isFalse);
      await helper.updateAccount(bank());
      await interest.processDue(now: DateTime(2026, 10, 22));
      final path = '${directory.path}/interest_backup.db';
      await DatabaseSnapshot.create(db, path);
      final copy = await openDatabase(
        path,
        readOnly: true,
        singleInstance: false,
      );
      final saved = (await copy.query(
        'accounts',
        where: 'id = ?',
        whereArgs: ['bank'],
      )).single;
      expect(
        saved['interestNextDate'],
        DateTime(2026, 10, 22).toIso8601String(),
      );
      expect(saved['annualInterestRate'], 3.65);
      expect((await copy.query('transactions')).length, 2);
      await copy.close();
    });
  });
}

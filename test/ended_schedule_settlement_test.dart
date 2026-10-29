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

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('koin_ended_schedule_');
    await databaseFactory.setDatabasesPath(directory.path);
    db = await helper.database;
    await db.update(
      'accounts',
      {'initialBalance': 10000},
      where: 'id = ?',
      whereArgs: ['default_account'],
    );
  });

  tearDownAll(() async {
    final root = Directory.systemTemp.absolute.path;
    expect(
      directory.absolute.path.startsWith('$root${Platform.pathSeparator}'),
      isTrue,
    );
    await db.close();
    await directory.delete(recursive: true);
  });

  test(
    'late payment settles an ended occurrence once and deletion restores it',
    () async {
      final payment = PlannedPayment(
        id: 'ended-rent',
        title: 'Rent',
        amount: 1000,
        type: TransactionType.expense,
        categoryId: 'cat_food',
        accountId: 'default_account',
        startDate: DateTime(2026, 1, 26),
        nextDate: DateTime(2026, 10, 26),
        endDate: DateTime(2026, 10, 28),
        frequency: PaymentFrequency.monthly,
      );
      await helper.insertPlannedPayment(payment);
      final tx = await ledger.recordPlannedPaymentOccurrence(
        payment: payment,
        amount: 1000,
        accountId: 'default_account',
        categoryId: 'cat_food',
        date: DateTime(2026, 10, 29),
      );
      expect(tx.date, DateTime(2026, 10, 29));
      final advanced = (await helper.getPlannedPayments()).single;
      expect(advanced.nextDate, DateTime(2026, 11, 26));
      await expectLater(
        ledger.recordPlannedPaymentOccurrence(
          payment: advanced,
          amount: 1000,
          accountId: 'default_account',
          categoryId: 'cat_food',
          date: DateTime(2026, 10, 29),
        ),
        throwsA(isA<FinancialValidationException>()),
      );
      expect((await ledger.getTransactions()).length, 1);
      await ledger.voidTransaction(tx.id);
      final restored = (await helper.getPlannedPayments()).single;
      expect(restored.nextDate, payment.nextDate);
      expect(restored.canProcess(DateTime(2026, 10, 29)), isTrue);
    },
  );
}

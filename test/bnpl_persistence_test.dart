import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/maintenance/database_snapshot.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  final helper = DatabaseHelper.instance;
  late Directory root;
  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    root = await Directory.systemTemp.createTemp('koin_bnpl_');
    await databaseFactory.setDatabasesPath(root.path);
  });
  tearDown(() async {
    await helper.close();
    await root.delete(recursive: true);
  });

  test('version 38 debts migrate without changing existing plans', () async {
    var db = await helper.database;
    final debt = Debt(
      id: 'shop',
      personName: 'Shop',
      amount: 600,
      currentAmount: 100,
      type: DebtType.iOwe,
      startDate: DateTime(2026, 10, 5),
    );
    await helper.saveDebtWithItems(debt, []);
    await db.execute('ALTER TABLE debts DROP COLUMN isPurchaseAccount');
    await db.setVersion(38);
    await helper.close();
    db = await helper.database;
    expect(await db.getVersion(), 43);
    final migrated = (await helper.getDebts()).single;
    expect(migrated.isPurchaseAccount, isFalse);
    expect(migrated.currentAmount, 100);
    expect(migrated.amount, 600);

    final bnpl = migrated.copyWith(
      isPurchaseAccount: true,
      items: [
        DebtItem(
          id: 'item',
          debtId: 'shop',
          name: 'Phone',
          amount: 600,
          totalInstallments: 2,
          firstPaymentDate: DateTime(2026, 10, 5),
        ),
      ],
    );
    await helper.saveDebtWithItems(bnpl, bnpl.items);
    final saved = (await helper.getDebts()).single;
    expect(saved.isPurchaseAccount, isTrue);
    expect(saved.items.single.totalInstallments, 2);
    final snapshot = '${root.path}/bnpl_backup.db';
    await DatabaseSnapshot.create(db, snapshot);
    await DatabaseSnapshot.validate(snapshot);
    final copy = await openDatabase(
      snapshot,
      readOnly: true,
      singleInstance: false,
    );
    expect((await copy.query('debts')).single['isPurchaseAccount'], 1);
    await copy.close();
  });
}

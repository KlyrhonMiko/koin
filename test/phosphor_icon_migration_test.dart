import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/icons.dart';
import 'package:koin/core/migrations/phosphor_icon_migration.dart';
import 'package:koin/core/utils/icon_utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();

  test('visibility keeps the original rounded eye pair', () {
    expect(KoinIcons.eye, Icons.visibility_rounded);
    expect(KoinIcons.eyeSlash, Icons.visibility_off_rounded);
  });

  test('legacy IDs upgrade once without changing data or firing edit triggers', () async {
    final db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    addTearDown(db.close);
    await db.execute('CREATE TABLE accounts (id TEXT, iconCodePoint INTEGER, balance REAL)');
    await db.execute('CREATE TABLE categories (id TEXT, iconCodePoint INTEGER, name TEXT)');
    await db.execute('CREATE TABLE edits (count INTEGER)');
    await db.insert('edits', {'count': 0});
    await db.execute('CREATE TRIGGER count_edit AFTER UPDATE ON categories BEGIN UPDATE edits SET count = count + 1; END');
    await db.insert('accounts', {'id': 'bank', 'iconCodePoint': 0xe069, 'balance': 123.45});
    await db.insert('categories', {'id': 'food', 'iconCodePoint': Icons.restaurant.codePoint, 'name': 'Food'});
    await db.transaction(PhosphorIconMigration.upgrade);
    expect((await db.query('accounts')).single, {'id': 'bank', 'iconCodePoint': KoinIcons.bank.codePoint, 'balance': 123.45});
    expect((await db.query('categories')).single, {'id': 'food', 'iconCodePoint': KoinIcons.forkKnife.codePoint, 'name': 'Food'});
    expect((await db.query('edits')).single['count'], 0);
    await db.transaction(PhosphorIconMigration.upgrade);
    expect((await db.query('categories')).single['iconCodePoint'], KoinIcons.forkKnife.codePoint);
    await db.update('categories', {'name': 'Dining'});
    expect((await db.query('edits')).single['count'], 1);
  });

  test('native catalog resolves saved Phosphor IDs without legacy translation', () {
    expect(IconUtils.getIcon(KoinIcons.wallet.codePoint).codePoint, KoinIcons.wallet.codePoint);
    expect(IconUtils.getIcon(KoinIcons.calculator.codePoint).codePoint, KoinIcons.calculator.codePoint);
    expect(IconUtils.getIcon(-1), KoinIcons.question);
    expect(IconUtils.getIcon(KoinIcons.wallet.codePoint).fontFamily, contains('PhosphorFill'));
    expect(IconUtils.availableIcons.every((icon) => icon.fontPackage == 'phosphor_icons'), isTrue);
  });
}

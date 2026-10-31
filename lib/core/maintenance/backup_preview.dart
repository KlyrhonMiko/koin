import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'database_snapshot.dart';
import 'recovery_store.dart';

/// Validates an imported copy and reads its identity without opening the live DB.
class BackupPreview {
  const BackupPreview({
    required this.accounts,
    required this.transactions,
    required this.currency,
    this.latestTransaction,
  });
  final int accounts;
  final int transactions;
  final String currency;
  final DateTime? latestTransaction;

  static Future<BackupPreview> read(String sourcePath) async {
    final directory = await (await getTemporaryDirectory()).createTemp(
      'koin_preview_',
    );
    Database? db;
    try {
      final path = p.join(directory.path, 'preview.db');
      final bytes = await compute(
        decodeBackup,
        await File(sourcePath).readAsBytes(),
      );
      await File(path).writeAsBytes(bytes, flush: true);
      await DatabaseSnapshot.validate(path);
      db = await openDatabase(path, readOnly: true, singleInstance: false);
      final tables = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type = 'table'",
      )).map((row) => row['name']).toSet();
      final accounts = tables.contains('accounts')
          ? Sqflite.firstIntValue(
                  await db.rawQuery('SELECT COUNT(*) FROM accounts'),
                ) ??
                0
          : 0;
      final transactions =
          Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM transactions'),
          ) ??
          0;
      final latest = (await db.rawQuery(
        'SELECT MAX(date) AS latest FROM transactions',
      )).first['latest'];
      final settings = tables.contains('app_settings')
          ? await db.query(
              'app_settings',
              columns: ['value'],
              where: 'key = ?',
              whereArgs: ['currency_code'],
            )
          : <Map<String, Object?>>[];
      return BackupPreview(
        accounts: accounts,
        transactions: transactions,
        currency: settings.isEmpty
            ? 'USD (legacy backup)'
            : settings.first['value'].toString(),
        latestTransaction: latest == null
            ? null
            : DateTime.tryParse(latest.toString()),
      );
    } finally {
      await db?.close();
      await directory.delete(recursive: true);
    }
  }
}

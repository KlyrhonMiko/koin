import 'dart:io';
import 'package:sqflite/sqflite.dart';

/// Produces a consistent snapshot without copying an open database file.
class DatabaseSnapshot {
  static Future<void> create(Database source, String path) async {
    final version =
        (await source.rawQuery('SELECT sqlite_version() AS v')).first['v']
            as String;
    final parts = version.split('.').map(int.parse).toList();
    if (parts[0] > 3 || (parts[0] == 3 && parts[1] >= 27)) {
      await source.execute('VACUUM INTO ?', [path]);
    } else {
      // Older Android SQLite versions have no VACUUM INTO. Read under one
      // transaction and rebuild into a separate connection instead.
      await copyLegacy(source, path);
    }
    await validate(path);
  }

  static Future<void> copyLegacy(Database source, String path) async {
    final target = await openDatabase(path, singleInstance: false);
    try {
      await source.transaction((reader) async {
        final schema = await reader.rawQuery(
          "SELECT type, name, sql FROM sqlite_master WHERE sql IS NOT NULL "
          "AND name NOT LIKE 'sqlite_%' ORDER BY type = 'table' DESC",
        );
        await target.transaction((writer) async {
          for (final entry in schema.where((e) => e['type'] == 'table')) {
            await writer.execute(entry['sql'] as String);
            final name = (entry['name'] as String).replaceAll('"', '""');
            final rows = await reader.rawQuery('SELECT * FROM "$name"');
            for (var i = 0; i < rows.length; i += 250) {
              final batch = writer.batch();
              for (final row in rows.skip(i).take(250)) {
                batch.insert(entry['name'] as String, row);
              }
              await batch.commit(noResult: true);
            }
          }
          for (final entry in schema.where((e) => e['type'] != 'table')) {
            await writer.execute(entry['sql'] as String);
          }
          final version = Sqflite.firstIntValue(
            await reader.rawQuery('PRAGMA user_version'),
          );
          await writer.execute('PRAGMA user_version = $version');
        });
      });
    } finally {
      await target.close();
    }
  }

  static Future<void> validate(String path) async {
    if (!await File(path).exists()) {
      throw const FormatException('Missing backup');
    }
    final db = await openDatabase(path, readOnly: true, singleInstance: false);
    try {
      final result = await db.rawQuery('PRAGMA integrity_check');
      if (result.length != 1 || result.first.values.single != 'ok') {
        throw const FormatException('Damaged backup');
      }
      final version = await db.getVersion();
      if (version < 1 || version > 37) {
        throw const FormatException('Unsupported backup version');
      }
      final requiredColumns = {
        if (version >= 37) 'savings_logs': ['id', 'transactionId'],
        if (version >= 37)
          'savings_spending_links': ['transactionId', 'spendableAmount'],
        if (version >= 36) 'savings_goals': ['id', 'includeInDashboardBalance'],
        'transactions': ['id', 'title', 'amount', 'date', 'type', 'categoryId'],
        'categories': ['id', 'name', 'iconCodePoint', 'colorHex', 'type'],
        if (version >= 2)
          'accounts': [
            'id',
            'name',
            'iconCodePoint',
            'colorHex',
            'initialBalance',
          ],
      };
      for (final entry in requiredColumns.entries) {
        final columns = (await db.rawQuery(
          'PRAGMA table_info(${entry.key})',
        )).map((row) => row['name']).toSet();
        if (!columns.containsAll(entry.value)) {
          throw const FormatException('Not a Koin backup');
        }
      }
    } finally {
      await db.close();
    }
  }
}

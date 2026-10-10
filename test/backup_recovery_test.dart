import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/savings/savings_goal.dart';
import 'package:koin/core/maintenance/database_snapshot.dart';
import 'package:koin/core/maintenance/external_backup.dart';
import 'package:koin/core/maintenance/maintenance_manager.dart';
import 'package:koin/core/maintenance/recovery_service.dart';
import 'package:koin/core/maintenance/recovery_store.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class RecordingMaintenance extends InMemoryMaintenanceAdapter {
  int calls = 0;
  Uint8List data = Uint8List.fromList([1]);
  Uint8List? restored;
  Completer<void>? gate;
  bool fail = false;
  @override
  Future<BackupBundle?> createBackup() async {
    calls++;
    await gate?.future;
    if (fail) throw const FileSystemException('No space');
    return BackupBundle(fileName: 'test', bytes: data);
  }

  @override
  Future<bool> restoreBackup(String path) async {
    restored = decodeBackup(await File(path).readAsBytes());
    return true;
  }
}

class RecordingExternal extends ExternalBackup {
  BackupDestination? destination;
  int writes = 0;
  bool fail = false;
  @override
  bool get supported => true;
  @override
  Future<BackupDestination?> choose() async => destination;
  @override
  Future<void> write(String destination, RecoveryCopy copy) async {
    writes++;
    if (fail) throw const FileSystemException('USB disconnected');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('koin_backup_test_');
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await root.delete(recursive: true);
  });

  test(
    'compressed copies round-trip, skip unchanged data and retain only three',
    () async {
      final store = RecoveryStore(Directory('${root.path}/recovery'));
      final unrelated = File('${root.path}/recovery/keep.txt');
      await store.directory.create();
      await unrelated.writeAsString('Keep me');
      final interrupted = File(
        '${root.path}/recovery/koin_recovery_1.koin.partial',
      );
      await interrupted.writeAsString('interrupted');
      for (var i = 1; i <= 5; i++) {
        final data = Uint8List.fromList(List.filled(10000, i));
        final copy = await store.save(data, now: DateTime(2026, 10, i));
        expect(copy!.bytes, lessThan(data.length));
        expect(decodeBackup(await File(copy.path).readAsBytes()), data);
      }
      final copies = await store.list();
      expect(copies.map((c) => c.createdAt.day), [5, 4, 3]);
      expect(
        await store.save(Uint8List.fromList(List.filled(10000, 5))),
        isNull,
      );
      expect(await unrelated.readAsString(), 'Keep me');
      expect(await interrupted.exists(), isFalse);
    },
  );

  test('damaged previous copy does not block new backups', () async {
    final store = RecoveryStore(Directory('${root.path}/recovery'));
    final copy = await store.save(Uint8List.fromList([1]));
    await File(copy!.path).writeAsBytes([1, 2, 3]);
    expect(await store.save(Uint8List.fromList([2])), isNotNull);
  });

  test(
    'automatic checks skip unchanged revisions and coalesce concurrent checks',
    () async {
      final maintenance = RecordingMaintenance();
      var token = 'one';
      final service = RecoveryService(
        maintenance: maintenance,
        preferences: await SharedPreferences.getInstance(),
        changeToken: () async => token,
        store: () async => RecoveryStore(Directory('${root.path}/recovery')),
      );
      addTearDown(service.dispose);
      await service.check();
      await service.check();
      expect(maintenance.calls, 1);
      token = 'two';
      maintenance.data = Uint8List.fromList([2]);
      maintenance.gate = Completer<void>();
      final running = service.check();
      await Future<void>.delayed(Duration.zero);
      await service.check();
      maintenance.gate!.complete();
      await running;
      expect(maintenance.calls, 2);
      expect(service.status.value.copies.length, 2);
    },
  );

  test('failed local save keeps prior copy and recovers on retry', () async {
    final maintenance = RecordingMaintenance();
    final service = RecoveryService(
      maintenance: maintenance,
      preferences: await SharedPreferences.getInstance(),
      changeToken: () async => 'one',
      store: () async => RecoveryStore(Directory('${root.path}/recovery')),
    );
    addTearDown(service.dispose);
    await service.check();
    maintenance.fail = true;
    await service.check(force: true);
    expect(service.status.value.localError, isTrue);
    expect(service.status.value.copies.length, 1);
    maintenance.fail = false;
    await service.check();
    expect(service.status.value.localError, isFalse);
  });

  test(
    'folder cancellation preserves setup; external failure does not lose local copy',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final external = RecordingExternal();
      final service = RecoveryService(
        maintenance: RecordingMaintenance(),
        preferences: prefs,
        changeToken: () async => 'one',
        external: external,
        store: () async => RecoveryStore(Directory('${root.path}/recovery')),
      );
      addTearDown(service.dispose);
      expect(await service.setupExternal(), isFalse);
      external.destination = const BackupDestination('usb', 'USB drive');
      external.fail = true;
      expect(await service.setupExternal(), isTrue);
      expect(service.status.value.externalError, isTrue);
      expect(service.status.value.localError, isFalse);
      expect(service.status.value.copies.length, 1);
      external.fail = false;
      await service.check(force: true);
      expect(service.status.value.externalAt, isNotNull);
      expect(service.status.value.externalError, isFalse);
      external.destination = null;
      expect(await service.setupExternal(), isFalse);
      expect(prefs.getString('backup_destination'), 'usb');
      await service.disconnectExternal();
      expect(prefs.getString('backup_destination'), isNull);
      expect(service.status.value.copies.length, 1);
    },
  );

  test(
    'oldest recovery copy can be restored even when pre-restore save prunes it',
    () async {
      final store = RecoveryStore(Directory('${root.path}/recovery'));
      for (var i = 1; i <= 3; i++) {
        await store.save(Uint8List.fromList([i]), now: DateTime(2026, 1, i));
      }
      final oldest = (await store.list()).last;
      final maintenance = RecordingMaintenance()
        ..data = Uint8List.fromList([4]);
      final service = RecoveryService(
        maintenance: maintenance,
        preferences: await SharedPreferences.getInstance(),
        changeToken: () async => 'one',
        store: () async => store,
      );
      addTearDown(service.dispose);
      expect(await service.restore(oldest.path), isTrue);
      expect(maintenance.restored, [1]);
      expect(await File(oldest.path).exists(), isFalse);
      expect((await store.list()).length, 3);
    },
  );

  group('real SQLite snapshots and restores', () {
    final helper = DatabaseHelper.instance;
    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    setUp(() async {
      await databaseFactory.setDatabasesPath(root.path);
    });
    tearDown(() async {
      await helper.close();
    });

    test(
      'version 35 migration preserves goals and backs up dashboard preferences',
      () async {
        var db = await helper.database;
        await helper.insertSavingsGoal(
          SavingsGoal(
            id: 'saved',
            name: 'Saved',
            startDate: DateTime(2026),
            currentAmount: 250,
            isStash: true,
          ),
        );
        await db.execute(
          'ALTER TABLE savings_goals DROP COLUMN includeInDashboardBalance',
        );
        await db.setVersion(35);
        await helper.close();
        db = await helper.database;
        expect(await db.getVersion(), 37);
        final migrated = (await helper.getSavingsGoals()).single;
        expect(migrated.currentAmount, 250);
        expect(migrated.includeInDashboardBalance, true);
        await helper.updateSavingsGoal(
          migrated.copyWith(includeInDashboardBalance: false),
        );
        final snapshot = '${root.path}/dashboard_option.db';
        await DatabaseSnapshot.create(db, snapshot);
        await DatabaseSnapshot.validate(snapshot);
        final copy = await openDatabase(
          snapshot,
          readOnly: true,
          singleInstance: false,
        );
        expect(
          (await copy.query(
            'savings_goals',
          )).single['includeInDashboardBalance'],
          0,
        );
        await copy.close();
      },
    );

    test(
      'snapshot includes WAL data and legacy fallback preserves history triggers',
      () async {
        final db = await helper.database;
        await db.rawQuery('PRAGMA journal_mode=WAL');
        await db.update(
          'accounts',
          {'name': 'Changed cash'},
          where: 'id = ?',
          whereArgs: ['default_account'],
        );
        final snapshot = '${root.path}/snapshot.db';
        await DatabaseSnapshot.create(db, snapshot);
        final restored = await openDatabase(
          snapshot,
          readOnly: true,
          singleInstance: false,
        );
        expect(
          (await restored.query(
            'accounts',
            where: 'id = ?',
            whereArgs: ['default_account'],
          )).first['name'],
          'Changed cash',
        );
        await restored.close();
        final legacy = '${root.path}/legacy.db';
        await DatabaseSnapshot.copyLegacy(db, legacy);
        await DatabaseSnapshot.validate(legacy);
        final rebuilt = await openDatabase(legacy, singleInstance: false);
        expect(await rebuilt.getVersion(), await db.getVersion());
        final triggers = await rebuilt.rawQuery(
          "SELECT name FROM sqlite_master WHERE type = 'trigger'",
        );
        expect(triggers, isNotEmpty);
        await rebuilt.close();
      },
    );

    test(
      'rejects invalid imports before replacing the current database',
      () async {
        final db = await helper.database;
        await db.update(
          'accounts',
          {'name': 'Keep this'},
          where: 'id = ?',
          whereArgs: ['default_account'],
        );
        final bad = File('${root.path}/bad.db');
        await bad.writeAsString('not a SQLite database');
        expect(await helper.restoreDatabase(bad.path), isFalse);
        expect(
          (await (await helper.database).query(
            'accounts',
            where: 'id = ?',
            whereArgs: ['default_account'],
          )).first['name'],
          'Keep this',
        );
      },
    );

    test(
      'compressed exports and original db backups restore data and settings',
      () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('currency_code', 'PHP');
        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);
        final maintenance = container.read(appMaintenanceProvider);
        final db = await helper.database;
        final category = (await db.query('categories')).first['id'];
        await db.insert('transactions', {
          'id': 'backup_transaction',
          'title': 'Lunch',
          'amount': 125.5,
          'date': '2026-10-08T12:00:00',
          'type': 'expense',
          'categoryId': category,
          'accountId': 'default_account',
        });
        final bundle = (await maintenance.createBackup())!;
        final compressed = File('${root.path}/backup.koin');
        await compressed.writeAsBytes(compressBackup(bundle.bytes));
        await prefs.setString('currency_code', 'USD');
        await db.update('transactions', {'amount': 999.0});
        expect(await maintenance.restoreBackup(compressed.path), isTrue);
        expect(prefs.getString('currency_code'), 'PHP');
        expect(
          (await (await helper.database).query(
            'transactions',
          )).single['amount'],
          125.5,
        );
        final raw = File('${root.path}/old.db');
        await raw.writeAsBytes(bundle.bytes);
        expect(await maintenance.restoreBackup(raw.path), isTrue);
        expect(
          (await (await helper.database).query('transactions')).single['title'],
          'Lunch',
        );
      },
    );
  });
}

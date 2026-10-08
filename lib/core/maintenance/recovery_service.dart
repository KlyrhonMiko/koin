import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'external_backup.dart';
import 'maintenance_manager.dart';
import 'recovery_store.dart';

class RecoveryStatus {
  const RecoveryStatus({
    this.copies = const [],
    this.busy = false,
    this.localError = false,
    this.externalError = false,
    this.destinationLabel,
    this.externalAt,
  });
  final List<RecoveryCopy> copies;
  final bool busy;
  final bool localError;
  final bool externalError;
  final String? destinationLabel;
  final DateTime? externalAt;
  int get storageBytes => copies.fold(0, (sum, copy) => sum + copy.bytes);
}

/// Polls a cheap change token while the app is active, and checks on lifecycle
/// transitions. No persistent background worker or network connection is needed.
class RecoveryService with WidgetsBindingObserver {
  RecoveryService({
    required this.maintenance,
    required this.preferences,
    required this.changeToken,
    required this.store,
    ExternalBackup? external,
  }) : external = external ?? ExternalBackup();
  final AppMaintenanceService maintenance;
  final SharedPreferences preferences;
  final Future<String> Function() changeToken;
  final Future<RecoveryStore> Function() store;
  final ExternalBackup external;
  final status = ValueNotifier(const RecoveryStatus());
  Timer? _timer;
  String? _lastToken;
  bool _checking = false;
  bool _disposed = false;
  bool _localError = false;
  bool _externalError = false;
  Future<void> _tail = Future.value();
  DateTime? _externalAttempt;

  Future<T> _exclusive<T>(Future<T> Function() action) {
    final task = _tail.then((_) => action());
    _tail = task.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return task;
  }

  void start() {
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    unawaited(check());
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => unawaited(check()),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      unawaited(check());
    } else {
      _timer?.cancel();
      unawaited(check());
    }
  }

  Future<void> _publish({bool busy = false}) async {
    if (_disposed) return;
    final copies = await (await store()).list();
    if (_disposed) return;
    final savedAt = preferences.getInt('backup_external_at');
    status.value = RecoveryStatus(
      copies: copies,
      busy: busy,
      localError: _localError,
      externalError: _externalError,
      destinationLabel: preferences.getString('backup_destination_label'),
      externalAt: savedAt == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(savedAt),
    );
  }

  Future<void> _saveLocal() async {
    final bundle = await maintenance.createBackup();
    if (bundle == null) throw const FileSystemException('Database unavailable');
    await (await store()).save(bundle.bytes);
    _localError = false;
  }

  Future<void> _saveExternal({bool force = false}) async {
    final destination = preferences.getString('backup_destination');
    if (destination == null) return;
    final copies = await (await store()).list();
    if (copies.isEmpty) return;
    final latest = copies.first;
    if (!force &&
        preferences.getInt('backup_external_at') ==
            latest.createdAt.millisecondsSinceEpoch) {
      return;
    }
    if (!force &&
        _externalAttempt != null &&
        DateTime.now().difference(_externalAttempt!) <
            const Duration(minutes: 1)) {
      return;
    }
    _externalAttempt = DateTime.now();
    try {
      await external.write(destination, latest);
      await preferences.setInt(
        'backup_external_at',
        latest.createdAt.millisecondsSinceEpoch,
      );
      _externalError = false;
    } catch (_) {
      _externalError = true;
    }
  }

  Future<void> check({bool force = false}) async {
    if (_disposed || _checking) return;
    _checking = true;
    try {
      await _exclusive(() async {
        final token = await changeToken();
        if (force || _localError || token != _lastToken) {
          await _publish(busy: true);
          await _saveLocal();
          // Read the token again next time if edits happened during snapshotting.
          _lastToken = token;
        }
        await _saveExternal(force: force);
        await _publish();
      });
    } catch (_) {
      _localError = true;
      try {
        await _publish();
      } catch (_) {
        if (!_disposed) status.value = const RecoveryStatus(localError: true);
      }
    } finally {
      _checking = false;
    }
  }

  Future<bool> setupExternal() async {
    final destination = await external.choose();
    if (destination == null || _disposed) return false;
    return _exclusive(() async {
      await preferences.setString('backup_destination', destination.location);
      await preferences.setString(
        'backup_destination_label',
        destination.label,
      );
      await preferences.remove('backup_external_at');
      await _publish(busy: true);
      try {
        await _saveLocal();
        await _saveExternal(force: true);
      } finally {
        await _publish();
      }
      return true;
    });
  }

  Future<void> disconnectExternal() => _exclusive(() async {
    await preferences.remove('backup_destination');
    await preferences.remove('backup_destination_label');
    await preferences.remove('backup_external_at');
    _externalError = false;
    await _publish();
  });

  Future<bool> restore(String path) => _exclusive(() async {
    await _publish(busy: true);
    final temp = await (await getTemporaryDirectory()).createTemp(
      'koin_selected_restore_',
    );
    try {
      // The selected copy might be pruned when the pre-restore copy is saved.
      // Stage it first so even the oldest retained copy remains restorable.
      final selected = await File(
        path,
      ).copy(p.join(temp.path, 'selected.koin'));
      // Preserve the current state before replacing it. Serialize against all
      // automatic copies so none reads a database while it is being restored.
      await _saveLocal();
      final result = await maintenance.restoreBackup(selected.path);
      _lastToken = null;
      return result;
    } finally {
      await temp.delete(recursive: true);
      await _publish();
    }
  });

  Future<void> runMaintenance(Future<void> Function() action) =>
      _exclusive(() async {
        await _publish(busy: true);
        try {
          await action();
          _lastToken = null;
        } finally {
          await _publish();
        }
      });

  Future<BackupBundle?> exportBackup() => _exclusive(() async {
    await _publish(busy: true);
    try {
      return await maintenance.createBackup();
    } finally {
      await _publish();
    }
  });

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    status.dispose();
  }
}

final recoveryServiceProvider = Provider<RecoveryService>((ref) {
  final prefs = ref.read(sharedPreferencesProvider);
  final service = RecoveryService(
    maintenance: ref.read(appMaintenanceProvider),
    preferences: prefs,
    store: () async => RecoveryStore(
      Directory(
        p.join((await getApplicationSupportDirectory()).path, 'recovery'),
      ),
    ),
    changeToken: () async {
      final db = await DatabaseHelper.instance.database;
      final changes = await db.rawQuery('SELECT total_changes() AS n');
      final version = await db.rawQuery('PRAGMA data_version');
      final settings = {
        for (final key in [
          'currency_code',
          'theme_color',
          'theme_mode',
          'analysis_filter_index',
        ])
          key: prefs.get(key),
      };
      return '${identityHashCode(db)}:$changes:$version:${jsonEncode(settings)}';
    },
  );
  ref.onDispose(service.dispose);
  return service;
});

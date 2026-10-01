import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/database_helper.dart';

import 'package:koin/core/providers/account_provider.dart';
import 'package:koin/core/providers/category_provider.dart';
import 'package:koin/core/providers/debt_provider.dart';
import 'package:koin/core/providers/planned_payment_provider.dart';
import 'package:koin/core/providers/savings_provider.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/core/providers/transaction_provider.dart';

/// Bundle representing a prepared database backup ready for saving.
class BackupBundle {
  final String fileName;
  final Uint8List bytes;

  const BackupBundle({
    required this.fileName,
    required this.bytes,
  });
}

/// Domain Seam: The interface encapsulating application maintenance, backup generation,
/// database restore, data purging, and factory reset cascades.
abstract class AppMaintenanceService {
  Future<BackupBundle?> createBackup();
  Future<bool> restoreBackup(String backupPath);
  Future<void> clearTransactions();
  Future<void> clearAllData();
  Future<void> factoryReset();
}

/// Concrete Production Adapter: Coordinates DatabaseHelper, SharedPreferences,
/// and Riverpod state synchronization.
class SqliteMaintenanceAdapter implements AppMaintenanceService {
  final Ref _ref;
  final DatabaseHelper _dbHelper;

  SqliteMaintenanceAdapter(this._ref, {DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<BackupBundle?> createBackup() async {
    final prefs = _ref.read(sharedPreferencesProvider);
    final settings = <String, String>{
      if (prefs.getString('currency_code') != null)
        'currency_code': prefs.getString('currency_code')!,
      if (prefs.getInt('theme_color') != null)
        'theme_color': prefs.getInt('theme_color')!.toString(),
      if (prefs.getInt('theme_mode') != null)
        'theme_mode': prefs.getInt('theme_mode')!.toString(),
      if (prefs.getInt('analysis_filter_index') != null)
        'analysis_filter_index':
            prefs.getInt('analysis_filter_index')!.toString(),
    };
    await _dbHelper.saveSettingsToDb(settings);

    final dbPath = await _dbHelper.getDatabaseFilePath();
    final file = File(dbPath);
    if (!await file.exists()) return null;

    final dateStr = DateFormat('yyyy_MM_dd').format(DateTime.now());
    final fileName = 'koin_backup_$dateStr';
    final bytes = await file.readAsBytes();

    return BackupBundle(fileName: fileName, bytes: bytes);
  }

  @override
  Future<bool> restoreBackup(String backupPath) async {
    final success = await _dbHelper.restoreDatabase(backupPath);
    if (!success) return false;

    // Restore settings from db to SharedPreferences
    final settingsFromDb = await _dbHelper.loadSettingsFromDb();
    final prefs = _ref.read(sharedPreferencesProvider);
    if (settingsFromDb.containsKey('currency_code')) {
      await prefs.setString('currency_code', settingsFromDb['currency_code']!);
    }
    if (settingsFromDb.containsKey('theme_color') &&
        settingsFromDb['theme_color']!.isNotEmpty) {
      await prefs.setInt(
        'theme_color',
        int.tryParse(settingsFromDb['theme_color']!) ?? 0xFF00D09E,
      );
    }
    if (settingsFromDb.containsKey('theme_mode') &&
        settingsFromDb['theme_mode']!.isNotEmpty) {
      await prefs.setInt(
        'theme_mode',
        int.tryParse(settingsFromDb['theme_mode']!) ?? 0,
      );
    }
    if (settingsFromDb.containsKey('analysis_filter_index') &&
        settingsFromDb['analysis_filter_index']!.isNotEmpty) {
      await prefs.setInt(
        'analysis_filter_index',
        int.tryParse(settingsFromDb['analysis_filter_index']!) ?? 0,
      );
    }

    _invalidateAllDomainProviders();
    return true;
  }

  @override
  Future<void> clearTransactions() async {
    await _dbHelper.deleteAllTransactions();
    _ref.invalidate(transactionProvider);
    _ref.invalidate(accountProvider);
  }

  @override
  Future<void> clearAllData() async {
    await _dbHelper.deleteAllData();
    _invalidateAllDomainProviders();
  }

  @override
  Future<void> factoryReset() async {
    await _dbHelper.resetDatabase();
    await _ref.read(settingsProvider.notifier).resetSettings();
    _invalidateAllDomainProviders();
  }

  void _invalidateAllDomainProviders() {
    _ref.invalidate(settingsProvider);
    _ref.invalidate(transactionProvider);
    _ref.invalidate(accountProvider);
    _ref.invalidate(categoriesProvider);
    _ref.invalidate(savingsGoalsProvider);
    _ref.invalidate(debtsProvider);
    _ref.invalidate(plannedPaymentProvider);
  }
}

/// In-Memory Test Adapter: Provides deterministic maintenance operations for testing.
class InMemoryMaintenanceAdapter implements AppMaintenanceService {
  bool clearedTransactions = false;
  bool clearedAllData = false;
  bool factoryResetDone = false;
  bool restoreSuccess = true;
  BackupBundle? mockBackup;

  @override
  Future<BackupBundle?> createBackup() async {
    return mockBackup ??
        BackupBundle(
          fileName: 'koin_backup_test',
          bytes: Uint8List.fromList([1, 2, 3, 4]),
        );
  }

  @override
  Future<bool> restoreBackup(String backupPath) async {
    return restoreSuccess;
  }

  @override
  Future<void> clearTransactions() async {
    clearedTransactions = true;
  }

  @override
  Future<void> clearAllData() async {
    clearedAllData = true;
  }

  @override
  Future<void> factoryReset() async {
    factoryResetDone = true;
  }
}

/// Riverpod provider exposing the AppMaintenanceService seam.
final appMaintenanceProvider = Provider<AppMaintenanceService>((ref) {
  return SqliteMaintenanceAdapter(ref);
});

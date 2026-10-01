import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/models.dart';

/// Domain Seam: The interface for persisting and retrieving savings goals and logs.
abstract class SavingsRepository {
  Future<List<SavingsGoal>> getSavingsGoals();
  Future<SavingsGoal> insertSavingsGoal(SavingsGoal goal);
  Future<void> updateSavingsGoal(SavingsGoal goal);
  Future<void> deleteSavingsGoal(String id);
  Future<List<SavingsLog>> getSavingsLogs(String goalId);
  Future<void> insertSavingsLog(SavingsLog log);
  Future<void> updateSavingsLog(SavingsLog oldLog, SavingsLog newLog);
  Future<void> deleteSavingsLog(SavingsLog log);
}

/// Concrete SQLite Adapter: delegates to DatabaseHelper.
class SqliteSavingsAdapter implements SavingsRepository {
  final DatabaseHelper _dbHelper;

  SqliteSavingsAdapter({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<SavingsGoal>> getSavingsGoals() => _dbHelper.getSavingsGoals();

  @override
  Future<SavingsGoal> insertSavingsGoal(SavingsGoal goal) =>
      _dbHelper.insertSavingsGoal(goal);

  @override
  Future<void> updateSavingsGoal(SavingsGoal goal) async {
    await _dbHelper.updateSavingsGoal(goal);
  }

  @override
  Future<void> deleteSavingsGoal(String id) async {
    await _dbHelper.deleteSavingsGoal(id);
  }

  @override
  Future<List<SavingsLog>> getSavingsLogs(String goalId) =>
      _dbHelper.getSavingsLogs(goalId);

  @override
  Future<void> insertSavingsLog(SavingsLog log) => _dbHelper.insertSavingsLog(log);

  @override
  Future<void> updateSavingsLog(SavingsLog oldLog, SavingsLog newLog) =>
      _dbHelper.updateSavingsLog(oldLog, newLog);

  @override
  Future<void> deleteSavingsLog(SavingsLog log) => _dbHelper.deleteSavingsLog(log);
}

/// In-Memory Test Adapter: provides deterministic savings persistence for testing.
class InMemorySavingsAdapter implements SavingsRepository {
  final Map<String, SavingsGoal> _goals = {};
  final Map<String, List<SavingsLog>> _logs = {};

  InMemorySavingsAdapter({List<SavingsGoal> initial = const []}) {
    for (final g in initial) {
      _goals[g.id] = g;
    }
  }

  @override
  Future<List<SavingsGoal>> getSavingsGoals() async {
    return List.unmodifiable(_goals.values.toList());
  }

  @override
  Future<SavingsGoal> insertSavingsGoal(SavingsGoal goal) async {
    _goals[goal.id] = goal;
    return goal;
  }

  @override
  Future<void> updateSavingsGoal(SavingsGoal goal) async {
    _goals[goal.id] = goal;
  }

  @override
  Future<void> deleteSavingsGoal(String id) async {
    _goals.remove(id);
    _logs.remove(id);
  }

  @override
  Future<List<SavingsLog>> getSavingsLogs(String goalId) async {
    return List.unmodifiable(_logs[goalId] ?? []);
  }

  @override
  Future<void> insertSavingsLog(SavingsLog log) async {
    _logs.putIfAbsent(log.goalId, () => []).add(log);
    final goal = _goals[log.goalId];
    if (goal != null) {
      _goals[log.goalId] = goal.copyWith(
        currentAmount: goal.currentAmount + log.amount,
      );
    }
  }

  @override
  Future<void> updateSavingsLog(SavingsLog oldLog, SavingsLog newLog) async {
    final list = _logs[newLog.goalId];
    if (list != null) {
      final idx = list.indexWhere((l) => l.id == oldLog.id);
      if (idx != -1) {
        list[idx] = newLog;
      }
    }
    final goal = _goals[newLog.goalId];
    if (goal != null) {
      final diff = newLog.amount - oldLog.amount;
      _goals[newLog.goalId] = goal.copyWith(
        currentAmount: goal.currentAmount + diff,
      );
    }
  }

  @override
  Future<void> deleteSavingsLog(SavingsLog log) async {
    final list = _logs[log.goalId];
    if (list != null) {
      list.removeWhere((l) => l.id == log.id);
    }
    final goal = _goals[log.goalId];
    if (goal != null) {
      _goals[log.goalId] = goal.copyWith(
        currentAmount: goal.currentAmount - log.amount,
      );
    }
  }
}

/// Riverpod provider exposing the SavingsRepository seam.
final savingsRepositoryProvider = Provider<SavingsRepository>((ref) {
  return SqliteSavingsAdapter();
});

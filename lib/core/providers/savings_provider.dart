import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/repositories/savings_repository.dart';
import 'dashboard_provider.dart';

class SavingsGoalsNotifier extends AsyncNotifier<List<SavingsGoal>> {
  SavingsRepository get _repository => ref.read(savingsRepositoryProvider);

  @override
  Future<List<SavingsGoal>> build() async {
    return await _repository.getSavingsGoals();
  }

  Future<void> loadGoals() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _repository.getSavingsGoals();
    });
  }

  Future<void> addGoal(SavingsGoal goal) async {
    await _repository.insertSavingsGoal(goal);
    await loadGoals();
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    await _repository.updateSavingsGoal(goal);
    await loadGoals();
  }

  Future<void> deleteGoal(String id) async {
    await _repository.deleteSavingsGoal(id);
    await loadGoals();
  }

  Future<void> _logWrites = Future.value();

  Future<void> _writeLog(Future<void> Function() write) {
    final result = _logWrites.then((_) => write());
    _logWrites = result.then((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> _validateLog(SavingsLog log, {SavingsLog? oldLog}) async {
    if (!log.amount.isFinite || log.amount == 0) {
      throw const SavingsBalanceException('Enter a valid savings amount');
    }
    final goals = await _repository.getSavingsGoals();
    final goal = goals.where((g) => g.id == log.goalId).firstOrNull;
    if (goal == null) {
      throw const SavingsBalanceException(
        'This savings goal is no longer available',
      );
    }
    if (oldLog != null &&
        (oldLog.id != log.id || oldLog.goalId != log.goalId)) {
      throw const SavingsBalanceException('This savings entry cannot be moved');
    }
    final increase = log.amount - (oldLog?.amount ?? 0);
    if (((goal.currentAmount + increase) * 100).round() < 0) {
      throw const SavingsBalanceException(
        'You cannot release more than the saved amount',
      );
    }
    if (goal.linkedAccountId == null || increase <= 0) return;
    final balance = ref
        .read(dashboardStatsProvider)
        .accountBalances[goal.linkedAccountId];
    if (balance == null) {
      throw const SavingsBalanceException(
        'Account balance is unavailable. Try again',
      );
    }
    final reserved = goals
        .where((g) => g.linkedAccountId == goal.linkedAccountId)
        .fold<double>(0, (sum, g) => sum + g.currentAmount);
    if ((increase * 100).round() > ((balance - reserved) * 100).round()) {
      throw const SavingsBalanceException(
        'Insufficient available balance in the linked account',
      );
    }
  }

  Future<void> addLog(SavingsLog log) => _writeLog(() async {
    await _validateLog(log);
    await _repository.insertSavingsLog(log);
    ref.invalidate(savingsLogsProvider(log.goalId));
    await loadGoals();
  });

  Future<void> updateLog(SavingsLog oldLog, SavingsLog newLog) =>
      _writeLog(() async {
        final logs = await _repository.getSavingsLogs(oldLog.goalId);
        final currentLog = logs.where((l) => l.id == oldLog.id).firstOrNull;
        if (currentLog == null) {
          throw const SavingsBalanceException(
            'This savings entry is no longer available',
          );
        }
        await _validateLog(newLog, oldLog: currentLog);
        await _repository.updateSavingsLog(currentLog, newLog);
        ref.invalidate(savingsLogsProvider(newLog.goalId));
        await loadGoals();
      });

  Future<void> deleteLog(SavingsLog log) => _writeLog(() async {
    final logs = await _repository.getSavingsLogs(log.goalId);
    final current = logs.where((l) => l.id == log.id).firstOrNull;
    if (current == null) return;
    await _validateLog(
      SavingsLog(
        id: current.id,
        goalId: current.goalId,
        amount: -current.amount,
        date: DateTime.now(),
      ),
    );
    await _repository.deleteSavingsLog(current);
    ref.invalidate(savingsLogsProvider(log.goalId));
    await loadGoals();
  });
}

final savingsGoalsProvider =
    AsyncNotifierProvider<SavingsGoalsNotifier, List<SavingsGoal>>(() {
      return SavingsGoalsNotifier();
    });

final computedSavingsGoalsProvider = Provider<AsyncValue<List<SavingsGoal>>>((
  ref,
) {
  return ref.watch(savingsGoalsProvider);
});

final savingsLogsProvider = FutureProvider.family<List<SavingsLog>, String>((
  ref,
  goalId,
) async {
  final repository = ref.read(savingsRepositoryProvider);
  return await repository.getSavingsLogs(goalId);
});

final savingsSummaryProvider = Provider<SavingsSummary>((ref) {
  final goals = ref.watch(computedSavingsGoalsProvider).value ?? [];
  return SavingsSummary.calculate(goals);
});

/// Savings are earmarked within the account, so existing allocations are unavailable.
final savingsAvailableBalanceProvider = Provider.family<double?, String>((
  ref,
  accountId,
) {
  final goals = ref.watch(savingsGoalsProvider).value;
  final balance = ref.watch(dashboardStatsProvider).accountBalances[accountId];
  if (goals == null || balance == null) return null;
  final reserved = goals
      .where((g) => g.linkedAccountId == accountId)
      .fold<double>(0, (sum, g) => sum + g.currentAmount);
  return balance - reserved;
});

class SavingsBalanceException implements Exception {
  final String message;
  const SavingsBalanceException(this.message);
}

/// Only subtract funded reservations from accounts already counted in the total.
/// Account balances and income/expense metrics remain unchanged.
double excludedSavingsFromDashboard(
  DashboardStats stats,
  Iterable<SavingsGoal> goals,
) {
  final reserved = <String, double>{};
  for (final goal in goals) {
    final id = goal.linkedAccountId;
    if (id == null ||
        goal.includeInDashboardBalance ||
        goal.currentAmount <= 0) {
      continue;
    }
    reserved[id] = (reserved[id] ?? 0) + goal.currentAmount;
  }
  return stats.accounts.where((a) => !a.excludeFromTotal).fold<double>(0, (
    sum,
    account,
  ) {
    final balance = (stats.accountBalances[account.id] ?? 0).clamp(
      0,
      double.infinity,
    );
    return sum + (reserved[account.id] ?? 0).clamp(0, balance);
  });
}

final dashboardExcludedSavingsProvider = Provider<double>(
  (ref) => excludedSavingsFromDashboard(
    ref.watch(dashboardStatsProvider),
    ref.watch(savingsGoalsProvider).value ?? [],
  ),
);

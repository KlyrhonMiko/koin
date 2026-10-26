import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/repositories/savings_repository.dart';

import 'dashboard_provider.dart';
import '../ledger/savings_spending_approval.dart';

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

  Future<void> _validateGoal(SavingsGoal goal, List<SavingsGoal> goals) async {
    if (!goal.currentAmount.isFinite ||
        goal.currentAmount < 0 ||
        (!goal.isStash && (!goal.hasTarget || !goal.targetAmount!.isFinite))) {
      throw const SavingsBalanceException('Enter a valid savings amount');
    }
    final plan = goal.savingsPlan;
    if (plan != null && (!plan.amount.isFinite || plan.amount < 0.01)) {
      throw const SavingsBalanceException('Enter a valid contribution amount');
    }
    final old = goals.where((g) => g.id == goal.id).firstOrNull;
    if (goal.linkedAccountId == null ||
        goal.currentAmount == 0 ||
        (old?.linkedAccountId == goal.linkedAccountId &&
            goal.currentAmount <= old!.currentAmount)) {
      return;
    }
    final balance = ref
        .read(dashboardStatsProvider)
        .accountBalances[goal.linkedAccountId];
    final reserved = goals
        .where(
          (g) => g.id != goal.id && g.linkedAccountId == goal.linkedAccountId,
        )
        .fold<double>(0, (sum, g) => sum + g.currentAmount);
    if (balance == null ||
        (goal.currentAmount * 100).round() >
            ((balance - reserved) * 100).round()) {
      throw const SavingsBalanceException(
        'Insufficient available balance in the linked account',
      );
    }
  }

  Future<void> addGoal(SavingsGoal goal) => _writeLog(() async {
    final goals = await _repository.getSavingsGoals();
    await _validateGoal(goal, goals);
    await _repository.insertSavingsGoal(goal);
    await loadGoals();
  });

  Future<void> updateGoal(SavingsGoal goal, {bool preserveBalance = false}) =>
      _writeLog(() async {
        final goals = await _repository.getSavingsGoals();
        final current = goals.where((g) => g.id == goal.id).firstOrNull;
        if (current == null) {
          throw const SavingsBalanceException(
            'This savings goal is no longer available',
          );
        }
        // Editors must not overwrite deposits made since they opened.
        final updated = preserveBalance
            ? goal.copyWith(currentAmount: current.currentAmount)
            : goal;
        await _validateGoal(updated, goals);
        await _repository.updateSavingsGoal(updated);
        await loadGoals();
      });

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

  /// Persist all automatic releases together, retaining savings activity history.
  Future<void> releaseForSpending(
    List<SavingsLog> logs, {
    double? spendingAmount,
  }) => _writeLog(() async {
    for (final log in logs) {
      if (log.amount >= 0) {
        throw const SavingsBalanceException('Enter a valid release amount');
      }
      await _validateLog(log);
    }
    await _repository.insertSavingsLogs(logs, spendingAmount: spendingAmount);
    for (final log in logs) {
      ref.invalidate(savingsLogsProvider(log.goalId));
    }
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
        if (currentLog.transactionId != null) {
          throw const SavingsBalanceException(
            'Automatic releases are read only. Edit the linked transaction instead.',
          );
        }
        await _validateLog(newLog, oldLog: currentLog);
        await _repository.updateSavingsLog(currentLog, newLog);
        ref.invalidate(savingsLogsProvider);
        await loadGoals();
      });

  Future<void> deleteLog(SavingsLog log) => _writeLog(() async {
    final logs = await _repository.getSavingsLogs(log.goalId);
    final current = logs.where((l) => l.id == log.id).firstOrNull;
    if (current == null) return;
    if (current.transactionId != null) {
      throw const SavingsBalanceException(
        'Automatic releases are read only. Delete the linked transaction instead.',
      );
    }
    await _validateLog(
      SavingsLog(
        id: current.id,
        goalId: current.goalId,
        amount: -current.amount,
        date: DateTime.now(),
      ),
    );
    await _repository.deleteSavingsLog(current);
    ref.invalidate(savingsLogsProvider);
    await loadGoals();
  });

  Future<void> rollbackDraftRelease(String transactionId) async {
    // Draft consent never wrote savings. Cancellation must work even when the
    // database is unavailable; migration repairs legacy interrupted releases.
    ref.read(savingsSpendingApprovalsProvider).clear(transactionId);
  }
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

/// Dashboard display balances exclude opted-out savings without changing the ledger.
Map<String, double> dashboardAccountBalances(
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
  return {
    for (final account in stats.accounts)
      account.id:
          (stats.accountBalances[account.id] ?? 0) -
          (reserved[account.id] ?? 0).clamp(
            0,
            (stats.accountBalances[account.id] ?? 0).clamp(0, double.infinity),
          ),
  };
}

final dashboardAccountBalancesProvider = Provider<Map<String, double>>(
  (ref) => dashboardAccountBalances(
    ref.watch(dashboardStatsProvider),
    ref.watch(savingsGoalsProvider).value ?? [],
  ),
);

/// Only subtract funded reservations from accounts already counted in the total.
double excludedSavingsFromDashboard(
  DashboardStats stats,
  Iterable<SavingsGoal> goals,
) {
  final displayedBalances = dashboardAccountBalances(stats, goals);
  return stats.accounts
      .where((a) => !a.excludeFromTotal)
      .fold<double>(
        0,
        (sum, account) =>
            sum +
            (stats.accountBalances[account.id] ?? 0) -
            (displayedBalances[account.id] ?? 0),
      );
}

final dashboardExcludedSavingsProvider = Provider<double>(
  (ref) => excludedSavingsFromDashboard(
    ref.watch(dashboardStatsProvider),
    ref.watch(savingsGoalsProvider).value ?? [],
  ),
);

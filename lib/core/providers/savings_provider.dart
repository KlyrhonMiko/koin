import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/models/savings_log.dart';
import 'package:koin/core/providers/dashboard_provider.dart';

class SavingsGoalsNotifier extends AsyncNotifier<List<SavingsGoal>> {
  @override
  Future<List<SavingsGoal>> build() async {
    return await DatabaseHelper.instance.getSavingsGoals();
  }

  Future<void> loadGoals() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await DatabaseHelper.instance.getSavingsGoals();
    });
  }

  Future<void> addGoal(SavingsGoal goal) async {
    await DatabaseHelper.instance.insertSavingsGoal(goal);
    await loadGoals();
  }

  Future<void> updateGoal(SavingsGoal goal) async {
    await DatabaseHelper.instance.updateSavingsGoal(goal);
    await loadGoals();
  }

  Future<void> deleteGoal(String id) async {
    await DatabaseHelper.instance.deleteSavingsGoal(id);
    await loadGoals();
  }

  Future<void> addLog(SavingsLog log) async {
    await DatabaseHelper.instance.insertSavingsLog(log);
    ref.invalidate(savingsLogsProvider(log.goalId));
    await loadGoals();
  }

  Future<void> updateLog(SavingsLog oldLog, SavingsLog newLog) async {
    await DatabaseHelper.instance.updateSavingsLog(oldLog, newLog);
    ref.invalidate(savingsLogsProvider(newLog.goalId));
    await loadGoals();
  }

  Future<void> deleteLog(SavingsLog log) async {
    await DatabaseHelper.instance.deleteSavingsLog(log);
    ref.invalidate(savingsLogsProvider(log.goalId));
    await loadGoals();
  }
}

final savingsGoalsProvider =
    AsyncNotifierProvider<SavingsGoalsNotifier, List<SavingsGoal>>(() {
      return SavingsGoalsNotifier();
    });

final computedSavingsGoalsProvider = Provider<AsyncValue<List<SavingsGoal>>>((
  ref,
) {
  final asyncGoals = ref.watch(savingsGoalsProvider);
  final stats = ref.watch(dashboardStatsProvider);

  return asyncGoals.whenData((goals) {
    return goals.map((goal) {
      if (goal.linkedAccountId != null) {
        final balance = stats.accountBalances[goal.linkedAccountId!];
        if (balance != null) {
          return goal.copyWith(currentAmount: balance);
        }
      }
      return goal;
    }).toList();
  });
});

final savingsLogsProvider = FutureProvider.family<List<SavingsLog>, String>((
  ref,
  goalId,
) async {
  return await DatabaseHelper.instance.getSavingsLogs(goalId);
});

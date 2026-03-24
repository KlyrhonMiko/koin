import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/savings_goal.dart';
import 'package:koin/core/models/savings_log.dart';

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
    await loadGoals();
  }
}

final savingsGoalsProvider = AsyncNotifierProvider<SavingsGoalsNotifier, List<SavingsGoal>>(() {
  return SavingsGoalsNotifier();
});

final savingsLogsProvider = FutureProvider.family<List<SavingsLog>, String>((ref, goalId) async {
  return await DatabaseHelper.instance.getSavingsLogs(goalId);
});

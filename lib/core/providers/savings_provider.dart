import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/repositories/savings_repository.dart';

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

  Future<void> addLog(SavingsLog log) async {
    await _repository.insertSavingsLog(log);
    ref.invalidate(savingsLogsProvider(log.goalId));
    await loadGoals();
  }

  Future<void> updateLog(SavingsLog oldLog, SavingsLog newLog) async {
    await _repository.updateSavingsLog(oldLog, newLog);
    ref.invalidate(savingsLogsProvider(newLog.goalId));
    await loadGoals();
  }

  Future<void> deleteLog(SavingsLog log) async {
    await _repository.deleteSavingsLog(log);
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


import 'savings_goal.dart';

/// Immutable domain value object encapsulating aggregated savings goal metrics.
class SavingsSummary {
  final double totalSaved;
  final double totalTarget;
  final double overallProgress;
  final int overallPercent;
  final int totalGoalsCount;
  final int activeGoalsCount;
  final int stashesCount;
  final int completedGoalsCount;

  const SavingsSummary({
    required this.totalSaved,
    required this.totalTarget,
    required this.overallProgress,
    required this.overallPercent,
    required this.totalGoalsCount,
    required this.activeGoalsCount,
    required this.stashesCount,
    required this.completedGoalsCount,
  });

  factory SavingsSummary.empty() => const SavingsSummary(
        totalSaved: 0.0,
        totalTarget: 0.0,
        overallProgress: 0.0,
        overallPercent: 0,
        totalGoalsCount: 0,
        activeGoalsCount: 0,
        stashesCount: 0,
        completedGoalsCount: 0,
      );

  factory SavingsSummary.calculate(List<SavingsGoal> goals) {
    double saved = 0.0;
    double target = 0.0;
    int active = 0;
    int stashes = 0;
    int completed = 0;

    for (final goal in goals) {
      saved += goal.currentAmount;
      if (goal.targetAmount != null && goal.targetAmount! > 0) {
        target += goal.targetAmount!;
      }

      if (goal.isStash) {
        stashes++;
      } else if (goal.isCompleted) {
        completed++;
      } else {
        active++;
      }
    }

    final progress = target > 0 ? (saved / target).clamp(0.0, 1.0) : 0.0;

    return SavingsSummary(
      totalSaved: saved,
      totalTarget: target,
      overallProgress: progress,
      overallPercent: (progress * 100).toInt(),
      totalGoalsCount: goals.length,
      activeGoalsCount: active,
      stashesCount: stashes,
      completedGoalsCount: completed,
    );
  }

  bool get hasGoals => totalGoalsCount > 0;
  bool get hasActiveGoals => activeGoalsCount > 0;
}

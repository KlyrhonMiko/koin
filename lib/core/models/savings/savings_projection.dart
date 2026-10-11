import 'dart:math';
import 'savings_goal.dart';
import 'savings_log.dart';
import 'savings_plan.dart';

/// Calendar-based estimates only. Never changes balances or records deposits.
class SavingsProjection {
  final SavingsGoal goal;
  final DateTime today;
  final List<SavingsLog> logs;

  SavingsProjection({
    required this.goal,
    required DateTime today,
    Iterable<SavingsLog> logs = const [],
  }) : today = SavingsPlan.day(today),
       logs = logs.toList();

  SavingsPlan get plan => goal.savingsPlan!;
  SavingsPlanProgress get next => plan.progress(logs, today);
  DateTime get nextDate =>
      next.nextDate.isBefore(today) ? today : next.nextDate;
  int get firstIndex => plan.periodAt(next.nextDate);

  double additionalBy(DateTime date) {
    if (goal.isCompleted || SavingsPlan.day(date).isBefore(nextDate)) return 0;
    final count = plan.periodAt(date) - firstIndex + 1;
    if (count <= 0) return 0;
    final additional = next.amountDue + (count - 1) * plan.amount;
    return goal.hasTarget ? min(additional, goal.remainingAmount!) : additional;
  }

  double totalBy(DateTime date) => goal.currentAmount + additionalBy(date);

  DateTime? get completionDate {
    if (!goal.hasTarget) return null;
    if (goal.isCompleted) return today;
    final remainingCents = (goal.remainingAmount! * 100).round();
    final firstCents = (next.amountDue * 100).round();
    final amountCents = (plan.amount * 100).round();
    if (amountCents <= 0) return null;
    final extra = max(0, ((remainingCents - firstCents) / amountCents).ceil());
    // Avoid unsupported dates for extreme amounts/targets.
    final maxIndex = plan.periodAt(DateTime(9999, 12, 31));
    if (firstIndex + extra > maxIndex) {
      return null;
    }
    return extra == 0 ? nextDate : plan.occurrence(firstIndex + extra);
  }

  /// Contribution needed at this frequency to meet a deadline, rounded up
  /// to a cent. Includes credit already contributed in the current period.
  double? requiredBy(DateTime deadline) {
    if (!goal.hasTarget || goal.isCompleted) return null;
    final end = SavingsPlan.day(deadline);
    if (end.isBefore(today)) return null;
    final currentIndex = max(0, plan.periodAt(today));
    final count = plan.periodAt(end) - currentIndex + 1;
    if (count <= 0) return null;
    final credit = logs
        .where(
          (log) =>
              log.amount > 0 &&
              !SavingsPlan.day(log.date).isAfter(today) &&
              plan.periodAt(log.date) == currentIndex,
        )
        .fold<double>(0, (sum, log) => sum + log.amount);
    var amount = (goal.remainingAmount! + credit) / count;
    if (amount <= credit && count > 1) {
      amount = goal.remainingAmount! / (count - 1);
    }
    return (amount * 100).ceil() / 100;
  }
}

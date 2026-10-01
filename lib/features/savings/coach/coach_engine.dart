import 'dart:math';
import 'package:koin/core/models/models.dart';

enum CoachStatus {
  completed,
  overdue,
  tooEarly,
  atRisk,
  ahead,
  onTrack,
  behind,
}

class CoachSimulationResult {
  final DateTime newDeadline;
  final double weeklyPace;
  final DateTime? projectedFinish; // null if never
  final int? daysLate; // positive = late, negative = early. null = never
  final double weeklyAmountRequired;
  final CoachStatus status;
  final double extraSavedPerWeek;
  final int deadlineShiftWeeks;
  final double? targetAmountOverride;

  CoachSimulationResult({
    required this.newDeadline,
    required this.weeklyPace,
    required this.projectedFinish,
    required this.daysLate,
    required this.weeklyAmountRequired,
    required this.status,
    required this.extraSavedPerWeek,
    required this.deadlineShiftWeeks,
    this.targetAmountOverride,
  });
}

/// Deep Domain Module: Simulates savings goal timelines, deadline shifts,
/// required weekly contributions, and goal completion projections.
class CoachEngine {
  final SavingsGoal goal;
  final DateTime today;

  CoachEngine({required this.goal, DateTime? today})
    : today = _dateOnly(today ?? DateTime.now());

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  DateTime get targetDeadline =>
      goal.endDate != null ? _dateOnly(goal.endDate!) : today.add(const Duration(days: 30));

  double get remainingAmount =>
      max(0.0, (goal.targetAmount ?? 0.0) - goal.currentAmount);

  CoachSimulationResult simulate({
    double extraSavedPerWeek = 0.0,
    int deadlineShiftWeeks = 0,
  }) {
    final newDeadline = targetDeadline.add(
      Duration(days: deadlineShiftWeeks * 7),
    );
    final pace = max(0.0, goal.currentWeeklyPace(today) + extraSavedPerWeek);

    DateTime? projectedFinish;
    int? daysLate;

    if (remainingAmount <= 0) {
      projectedFinish = today;
      daysLate = projectedFinish.difference(newDeadline).inDays;
    } else if (pace <= 0) {
      projectedFinish = null;
    } else {
      final weeksToFinish = remainingAmount / pace;
      final daysToFinish = (weeksToFinish * 7).round();
      if (daysToFinish > 36500) {
        projectedFinish = null;
      } else {
        projectedFinish = today.add(Duration(days: daysToFinish));
      }
    }

    if (projectedFinish != null) {
      daysLate = projectedFinish.difference(newDeadline).inDays;
    }

    final daysLeft = newDeadline.difference(today).inDays;
    final weeksLeft = daysLeft / 7.0;
    double weeklyAmountRequired = 0;
    if (weeksLeft > 0) {
      weeklyAmountRequired = remainingAmount / weeksLeft;
    } else {
      weeklyAmountRequired = remainingAmount;
    }

    // Classify status
    CoachStatus status;
    final goalTotalDays = max(1, newDeadline.difference(_dateOnly(goal.startDate)).inDays);

    if (remainingAmount <= 0) {
      status = CoachStatus.completed;
    } else if (today.isAfter(newDeadline)) {
      status = CoachStatus.overdue;
    } else if (goal.elapsedDays(today) < 7) {
      status = CoachStatus.tooEarly;
    } else if (projectedFinish == null) {
      status = CoachStatus.atRisk;
    } else {
      final toleranceDays = max(3.0, goalTotalDays * 0.03).round();
      final behindThreshold = max(3.0, goalTotalDays * 0.25).round();

      if (daysLate! < -toleranceDays) {
        status = CoachStatus.ahead;
      } else if (daysLate <= toleranceDays) {
        status = CoachStatus.onTrack;
      } else if (daysLate <= behindThreshold) {
        status = CoachStatus.behind;
      } else {
        status = CoachStatus.atRisk;
      }
    }

    return CoachSimulationResult(
      newDeadline: newDeadline,
      weeklyPace: pace,
      projectedFinish: projectedFinish,
      daysLate: daysLate,
      weeklyAmountRequired: weeklyAmountRequired,
      status: status,
      extraSavedPerWeek: extraSavedPerWeek,
      deadlineShiftWeeks: deadlineShiftWeeks,
    );
  }

  double _roundToFriendly(double val) {
    if (val <= 0) return 0;
    final magnitude = pow(10, (log(val) / ln10).floor());
    final normalized = val / magnitude;
    double friendly;
    if (normalized <= 1) {
      friendly = 1;
    } else if (normalized <= 1.5) {
      friendly = 1.5;
    } else if (normalized <= 2) {
      friendly = 2;
    } else if (normalized <= 2.5) {
      friendly = 2.5;
    } else if (normalized <= 3) {
      friendly = 3;
    } else if (normalized <= 4) {
      friendly = 4;
    } else if (normalized <= 5) {
      friendly = 5;
    } else if (normalized <= 6) {
      friendly = 6;
    } else if (normalized <= 8) {
      friendly = 8;
    } else {
      friendly = 10;
    }
    return friendly * magnitude;
  }

  List<double> generatePresets(double sliderMax) {
    // finish on time, 2 weeks early, 1 month early
    final targetsDaysEarly = [0, 14, 30];
    final currentPace = goal.currentWeeklyPace(today);

    List<double> presets = [];
    for (int daysEarly in targetsDaysEarly) {
      final availableDays = targetDeadline.difference(today).inDays - daysEarly;
      if (availableDays <= 0) continue;
      final availableWeeks = availableDays / 7.0;
      final extraNeeded = (remainingAmount / availableWeeks) - currentPace;
      if (extraNeeded <= 0) continue;

      final friendly = _roundToFriendly(extraNeeded);
      if (friendly > sliderMax) continue;
      if (!presets.contains(friendly)) {
        presets.add(friendly);
      }
    }
    return presets.reversed.toList();
  }

  double calculateSliderMax() {
    if (today.isAfter(targetDeadline)) {
      return _roundToFriendly(remainingAmount / 4.0);
    }
    final daysLeft = targetDeadline.difference(today).inDays;
    final weeksLeft = daysLeft / 7.0;
    final requiredWeekly = weeksLeft > 0
        ? remainingAmount / weeksLeft
        : remainingAmount;
    final currentPace = goal.currentWeeklyPace(today);
    final larger = max(requiredWeekly, currentPace);
    return _roundToFriendly(larger * 1.5);
  }
}

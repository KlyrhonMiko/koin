import 'dart:math';
import 'package:koin/core/models/models.dart';

enum CoachStatus { completed, overdue, tooEarly, atRisk, ahead, onTrack, behind }

class CoachGoal {
  final String id;
  final String name;
  final double target;
  final double current;
  final DateTime startDate;
  final DateTime endDate;

  CoachGoal({
    required this.id,
    required this.name,
    required this.target,
    required this.current,
    required this.startDate,
    required this.endDate,
  });

  static DateTime dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  factory CoachGoal.fromSavingsGoal(SavingsGoal goal) {
    if (goal.isStash || goal.targetAmount == null || goal.endDate == null) {
      throw Exception("Stash goals cannot use the coach feature");
    }
    return CoachGoal(
      id: goal.id,
      name: goal.name,
      target: goal.targetAmount!,
      current: goal.currentAmount,
      startDate: dateOnly(goal.startDate),
      endDate: dateOnly(goal.endDate!),
    );
  }

  double get remaining => max(0.0, target - current);
  
  int elapsedDays(DateTime today) {
    return max(0, dateOnly(today).difference(startDate).inDays);
  }

  int totalDays() {
    return max(1, endDate.difference(startDate).inDays);
  }

  double expectedAmountToday(DateTime today) {
    final eDays = elapsedDays(today);
    final tDays = totalDays();
    if (eDays >= tDays) return target;
    return target * (eDays / tDays);
  }

  double gap(DateTime today) {
    final expected = expectedAmountToday(today);
    return max(0.0, expected - current);
  }

  double currentWeeklyPace(DateTime today) {
    final eDays = elapsedDays(today);
    if (eDays < 7) {
      final tWeeks = totalDays() / 7;
      if (tWeeks == 0) return target;
      return target / tWeeks;
    }
    final eWeeks = eDays / 7.0;
    return current / eWeeks;
  }
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

class CoachEngine {
  final CoachGoal goal;
  final DateTime today;

  CoachEngine({required this.goal, DateTime? today}) 
      : today = CoachGoal.dateOnly(today ?? DateTime.now());

  CoachSimulationResult simulate({double extraSavedPerWeek = 0.0, int deadlineShiftWeeks = 0}) {
    final newDeadline = goal.endDate.add(Duration(days: deadlineShiftWeeks * 7));
    final pace = max(0.0, goal.currentWeeklyPace(today) + extraSavedPerWeek);
    
    DateTime? projectedFinish;
    int? daysLate;

    if (goal.remaining <= 0) {
      projectedFinish = today;
      daysLate = projectedFinish.difference(newDeadline).inDays;
    } else if (pace <= 0) {
      projectedFinish = null; 
    } else {
      final weeksToFinish = goal.remaining / pace;
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
      weeklyAmountRequired = goal.remaining / weeksLeft;
    } else {
      weeklyAmountRequired = goal.remaining; 
    }

    // Classify status
    CoachStatus status;
    final goalTotalDays = max(1, newDeadline.difference(goal.startDate).inDays);
    
    if (goal.remaining <= 0) {
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
    if (normalized <= 1) { friendly = 1; }
    else if (normalized <= 1.5) { friendly = 1.5; }
    else if (normalized <= 2) { friendly = 2; }
    else if (normalized <= 2.5) { friendly = 2.5; }
    else if (normalized <= 3) { friendly = 3; }
    else if (normalized <= 4) { friendly = 4; }
    else if (normalized <= 5) { friendly = 5; }
    else if (normalized <= 6) { friendly = 6; }
    else if (normalized <= 8) { friendly = 8; }
    else { friendly = 10; }
    return friendly * magnitude;
  }

  List<double> generatePresets(double sliderMax) {
    // finish on time, 2 weeks early, 1 month early
    final targetsDaysEarly = [0, 14, 30];
    final currentPace = goal.currentWeeklyPace(today);
    
    List<double> presets = [];
    for (int daysEarly in targetsDaysEarly) {
      final availableDays = goal.endDate.difference(today).inDays - daysEarly;
      if (availableDays <= 0) continue;
      final availableWeeks = availableDays / 7.0;
      final extraNeeded = (goal.remaining / availableWeeks) - currentPace;
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
    if (today.isAfter(goal.endDate)) {
      return _roundToFriendly(goal.remaining / 4.0);
    }
    final daysLeft = goal.endDate.difference(today).inDays;
    final weeksLeft = daysLeft / 7.0;
    final requiredWeekly = weeksLeft > 0 ? goal.remaining / weeksLeft : goal.remaining;
    final currentPace = goal.currentWeeklyPace(today);
    final larger = max(requiredWeekly, currentPace);
    return _roundToFriendly(larger * 1.5);
  }
}

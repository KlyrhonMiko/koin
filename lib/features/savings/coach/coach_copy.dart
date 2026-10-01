import 'package:intl/intl.dart';
import 'package:koin/features/savings/coach/coach_engine.dart';

class CoachCopy {
  static int _stableHash(String id, int week) {
    int h = 0;
    final str = '${id}_$week';
    for (int i = 0; i < str.length; i++) {
      h = (31 * h + str.codeUnitAt(i)) % 100000;
    }
    return h;
  }

  static String formatDuration(int days) {
    if (days == 0) return "today";
    final absDays = days.abs();
    if (absDays < 7) {
      return "$absDays day${absDays == 1 ? '' : 's'}";
    } else if (absDays < 30) {
      final weeks = (absDays / 7).round();
      return "about $weeks week${weeks == 1 ? '' : 's'}";
    } else if (absDays < 365) {
      final months = (absDays / 30).round();
      return "about $months month${months == 1 ? '' : 's'}";
    } else {
      final years = (absDays / 365).round();
      return "about $years year${years == 1 ? '' : 's'}";
    }
  }

  static String getHeadline(
    CoachSimulationResult baseline,
    String goalId,
    NumberFormat currencyFormat,
  ) {
    final now = DateTime.now();
    // Week of year approximation
    final dayOfYear = int.parse(DateFormat("D").format(now));
    final week = (dayOfYear / 7).ceil();
    final phrasingIndex = _stableHash(goalId, week) % 2;

    final lateDuration = baseline.daysLate != null && baseline.daysLate! > 0
        ? formatDuration(baseline.daysLate!)
        : "";

    // To fix it, you need to save remaining / weeksLeft
    final extraNeeded = baseline.weeklyAmountRequired > baseline.weeklyPace
        ? baseline.weeklyAmountRequired - baseline.weeklyPace
        : 0.0;
    final extraFmt = currencyFormat.format(extraNeeded);

    switch (baseline.status) {
      case CoachStatus.completed:
        return phrasingIndex == 0
            ? "You did it! Goal achieved."
            : "Congratulations! You reached your goal.";
      case CoachStatus.overdue:
        return phrasingIndex == 0
            ? "The deadline has passed."
            : "You missed the target date.";
      case CoachStatus.tooEarly:
        return phrasingIndex == 0
            ? "Too early to tell. Keep going!"
            : "Just getting started. Let's build momentum.";
      case CoachStatus.ahead:
        return phrasingIndex == 0
            ? "You're ahead of schedule! Great job."
            : "Cruising! You're beating your target date.";
      case CoachStatus.onTrack:
        return phrasingIndex == 0
            ? "Right on track. Keep up the pace."
            : "Looking good. You're set to finish on time.";
      case CoachStatus.behind:
        return phrasingIndex == 0
            ? "You're running $lateDuration late. Adding $extraFmt/wk puts you back on track."
            : "Falling behind by $lateDuration. Can you bump up your savings by $extraFmt/wk?";
      case CoachStatus.atRisk:
        if (baseline.projectedFinish == null) {
          return phrasingIndex == 0
              ? "Your goal is at risk. You need to start saving $extraFmt/wk to hit it."
              : "Danger zone. Saving $extraFmt/wk will get you there on time.";
        } else {
          return phrasingIndex == 0
              ? "You're at risk, tracking $lateDuration late. Adding $extraFmt/wk will fix it."
              : "Warning: $lateDuration behind schedule. You need an extra $extraFmt/wk.";
        }
    }
  }

  static String getScenarioSentence(
    CoachSimulationResult baseline,
    CoachSimulationResult sim,
    NumberFormat currencyFormat,
  ) {
    if (baseline.status == CoachStatus.completed) {
      return "Goal is already completed!";
    }

    final List<String> parts = [];

    // Part 1: How the finish date moved + daily cost
    final originalFinish = baseline.projectedFinish;
    final newFinish = sim.projectedFinish;

    if (sim.extraSavedPerWeek > 0 || sim.deadlineShiftWeeks != 0) {
      if (originalFinish != null && newFinish != null) {
        final diffDays = originalFinish.difference(newFinish).inDays;
        if (diffDays != 0) {
          final fmtOrig = DateFormat("MMM d").format(originalFinish);
          final fmtNew = DateFormat("MMM d").format(newFinish);
          final direction = diffDays > 0 ? "sooner" : "later";
          final extraDailyFmt = currencyFormat.format(
            sim.extraSavedPerWeek / 7,
          );

          if (sim.extraSavedPerWeek > 0) {
            parts.add(
              "You'd finish on $fmtNew instead of $fmtOrig (${formatDuration(diffDays)} $direction) for about $extraDailyFmt extra a day.",
            );
          } else {
            parts.add(
              "You'd finish on $fmtNew instead of $fmtOrig (${formatDuration(diffDays)} $direction).",
            );
          }
        }
      } else if (originalFinish == null && newFinish != null) {
        final fmtNew = DateFormat("MMM d").format(newFinish);
        parts.add("You'll finally be able to finish by $fmtNew!");
      }
    }

    // Part 2: Total weekly amount needed
    if (sim.deadlineShiftWeeks != 0) {
      final totalWk = currencyFormat.format(sim.weeklyAmountRequired);
      parts.add("With the new deadline, you need $totalWk per week overall.");
    }

    // Part 3: Verdict
    if (sim.status == CoachStatus.ahead) {
      parts.add("You'd be safely ahead of schedule.");
    } else if (sim.status == CoachStatus.onTrack) {
      parts.add("You'd be right on track.");
    } else if (sim.status == CoachStatus.behind ||
        sim.status == CoachStatus.atRisk) {
      final extraNeeded = sim.weeklyAmountRequired - sim.weeklyPace;
      if (extraNeeded > 0) {
        parts.add(
          "You'd still be late. You need another ${currencyFormat.format(extraNeeded)}/wk to fix it.",
        );
      } else {
        parts.add("You'd still be late.");
      }
    }

    if (parts.isEmpty) {
      return "Change the plan to see how it affects your goal.";
    }

    return parts.join(" ");
  }
}

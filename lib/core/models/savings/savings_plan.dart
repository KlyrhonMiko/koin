import 'dart:math';
import 'savings_log.dart';

enum SavingsFrequency {
  weekly('Weekly'),
  fortnightly('Every 2 weeks'),
  monthly('Monthly');

  final String label;
  const SavingsFrequency(this.label);
}

/// A manual contribution routine; it never writes deposits automatically.
class SavingsPlan {
  final double amount;
  final SavingsFrequency frequency;
  final DateTime startDate;

  const SavingsPlan({
    required this.amount,
    required this.frequency,
    required this.startDate,
  });

  static DateTime day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static SavingsPlan? fromMap(Map<String, dynamic> map) {
    final amount = (map['contributionAmount'] as num?)?.toDouble();
    final frequency = SavingsFrequency.values
        .where((f) => f.name == map['contributionFrequency'])
        .firstOrNull;
    final date = DateTime.tryParse(
      map['contributionStartDate'] as String? ?? '',
    );
    if (amount == null ||
        !amount.isFinite ||
        amount <= 0 ||
        frequency == null ||
        date == null) {
      return null;
    }
    return SavingsPlan(amount: amount, frequency: frequency, startDate: date);
  }

  DateTime occurrence(int index) {
    final start = day(startDate);
    if (frequency != SavingsFrequency.monthly) {
      return DateTime(
        start.year,
        start.month,
        start.day + index * (frequency == SavingsFrequency.weekly ? 7 : 14),
      );
    }
    final month = DateTime(start.year, start.month + index);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, min(start.day, lastDay));
  }

  int periodAt(DateTime date) {
    final today = day(date);
    if (today.isBefore(day(startDate))) return -1;
    if (frequency != SavingsFrequency.monthly) {
      // UTC calendar days avoid daylight-saving duration rounding.
      final days = DateTime.utc(today.year, today.month, today.day)
          .difference(
            DateTime.utc(startDate.year, startDate.month, startDate.day),
          )
          .inDays;
      return days ~/ (frequency == SavingsFrequency.weekly ? 7 : 14);
    }
    var index =
        (today.year - startDate.year) * 12 + today.month - startDate.month;
    if (today.isBefore(occurrence(index))) index--;
    return index;
  }

  SavingsPlanProgress progress(Iterable<SavingsLog> logs, DateTime today) {
    final current = periodAt(today);
    final deposits = <int, double>{};
    for (final log in logs) {
      if (log.amount <= 0 || day(log.date).isAfter(day(today))) continue;
      final period = periodAt(log.date);
      if (period >= 0 && period <= current) {
        deposits[period] = (deposits[period] ?? 0) + log.amount;
      }
    }
    final completed = deposits.values
        .where((sum) => (sum * 100).round() >= (amount * 100).round())
        .length;
    final currentSaved = deposits[current] ?? 0;
    final fulfilled = (currentSaved * 100).round() >= (amount * 100).round();
    final dueIndex = current < 0 ? 0 : (fulfilled ? current + 1 : current);
    return SavingsPlanProgress(
      nextDate: occurrence(dueIndex),
      amountDue: fulfilled || current < 0
          ? amount
          : max(0, amount - currentSaved),
      completedPeriods: completed,
      elapsedPeriods: max(0, current + 1),
      isDue: current >= 0 && !fulfilled,
    );
  }
}

class SavingsPlanProgress {
  final DateTime nextDate;
  final double amountDue;
  final int completedPeriods;
  final int elapsedPeriods;
  final bool isDue;

  const SavingsPlanProgress({
    required this.nextDate,
    required this.amountDue,
    required this.completedPeriods,
    required this.elapsedPeriods,
    required this.isDue,
  });
}

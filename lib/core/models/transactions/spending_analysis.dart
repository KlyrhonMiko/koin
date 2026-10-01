import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/models/transactions/transaction.dart';

/// Supported time periods for financial spending analysis.
enum AnalysisPeriod {
  week,
  month,
  year;

  static AnalysisPeriod fromIndex(int index) {
    switch (index) {
      case 0:
        return AnalysisPeriod.week;
      case 1:
        return AnalysisPeriod.month;
      case 2:
        return AnalysisPeriod.year;
      default:
        return AnalysisPeriod.month;
    }
  }

  /// Calculates the inclusive [DateTimeRange] for this period given [baseDate].
  DateTimeRange dateRange(DateTime baseDate) {
    switch (this) {
      case AnalysisPeriod.week:
        final startOfWeek = baseDate.subtract(
          Duration(days: baseDate.weekday - 1),
        );
        final start = DateTime(
          startOfWeek.year,
          startOfWeek.month,
          startOfWeek.day,
        );
        final end = DateTime(
          start.year,
          start.month,
          start.day + 6,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: end);

      case AnalysisPeriod.month:
        final start = DateTime(baseDate.year, baseDate.month, 1);
        final end = DateTime(
          baseDate.year,
          baseDate.month + 1,
          0,
          23,
          59,
          59,
          999,
        );
        return DateTimeRange(start: start, end: end);

      case AnalysisPeriod.year:
        final start = DateTime(baseDate.year, 1, 1);
        final end = DateTime(baseDate.year, 12, 31, 23, 59, 59, 999);
        return DateTimeRange(start: start, end: end);
    }
  }

  /// Calculates the comparison [DateTimeRange] immediately preceding [baseDate].
  DateTimeRange previousDateRange(DateTime baseDate) {
    switch (this) {
      case AnalysisPeriod.week:
        final prevBase = baseDate.subtract(const Duration(days: 7));
        return dateRange(prevBase);

      case AnalysisPeriod.month:
        final prevBase = DateTime(baseDate.year, baseDate.month - 1, 1);
        return dateRange(prevBase);

      case AnalysisPeriod.year:
        final prevBase = DateTime(baseDate.year - 1, 1, 1);
        return dateRange(prevBase);
    }
  }

  /// Formatted localized label for the period header.
  String formatPeriod(DateTime baseDate) {
    switch (this) {
      case AnalysisPeriod.week:
        final range = dateRange(baseDate);
        final startLabel = DateFormat('MMM d').format(range.start);
        final endLabel = DateFormat('MMM d').format(range.end);
        return '$startLabel - $endLabel';

      case AnalysisPeriod.month:
        return DateFormat('MMMM yyyy').format(baseDate);

      case AnalysisPeriod.year:
        return DateFormat('yyyy').format(baseDate);
    }
  }

  /// Returns whether [baseDate] falls within the current real-world timeframe.
  bool isCurrentPeriod(DateTime baseDate, [DateTime? now]) {
    final refNow = now ?? DateTime.now();
    final range = dateRange(baseDate);
    return !refNow.isBefore(range.start) && !refNow.isAfter(range.end);
  }

  /// Shift [baseDate] forward by 1 step.
  DateTime nextPeriod(DateTime baseDate) {
    switch (this) {
      case AnalysisPeriod.week:
        return baseDate.add(const Duration(days: 7));
      case AnalysisPeriod.month:
        return DateTime(baseDate.year, baseDate.month + 1, baseDate.day);
      case AnalysisPeriod.year:
        return DateTime(baseDate.year + 1, baseDate.month, baseDate.day);
    }
  }

  /// Shift [baseDate] backward by 1 step.
  DateTime previousPeriod(DateTime baseDate) {
    switch (this) {
      case AnalysisPeriod.week:
        return baseDate.subtract(const Duration(days: 7));
      case AnalysisPeriod.month:
        return DateTime(baseDate.year, baseDate.month - 1, baseDate.day);
      case AnalysisPeriod.year:
        return DateTime(baseDate.year - 1, baseDate.month, baseDate.day);
    }
  }
}

/// Itemized breakdown of spending allocated to a single category.
class CategorySpendingItem {
  final String categoryId;
  final double amount;
  final double percentage;

  const CategorySpendingItem({
    required this.categoryId,
    required this.amount,
    required this.percentage,
  });
}

/// Deep Domain Module: Encapsulates financial time-series spending analysis,
/// date window partitioning, period-over-period trend comparisons, and category allocations.
class SpendingAnalysis {
  final AnalysisPeriod period;
  final DateTime baseDate;
  final DateTimeRange currentDateRange;
  final DateTimeRange previousDateRange;
  final double totalExpense;
  final double? previousExpense;
  final double trendPercentage;
  final bool isIncrease;
  final List<AppTransaction> filteredTransactions;
  final Map<String, double> categorySpendingMap;
  final List<CategorySpendingItem> categoryBreakdown;

  const SpendingAnalysis({
    required this.period,
    required this.baseDate,
    required this.currentDateRange,
    required this.previousDateRange,
    required this.totalExpense,
    required this.previousExpense,
    required this.trendPercentage,
    required this.isIncrease,
    required this.filteredTransactions,
    required this.categorySpendingMap,
    required this.categoryBreakdown,
  });

  /// Factory calculator that computes spending analytics from raw transaction history.
  factory SpendingAnalysis.calculate({
    required List<AppTransaction> transactions,
    required DateTime baseDate,
    required AnalysisPeriod period,
  }) {
    final currentRange = period.dateRange(baseDate);
    final prevRange = period.previousDateRange(baseDate);

    final expenseTransactions = transactions.where(
      (t) => t.type == TransactionType.expense,
    );

    // Current period transactions
    final currentExpenses = expenseTransactions.where((t) {
      return !t.date.isBefore(currentRange.start) &&
          !t.date.isAfter(currentRange.end);
    }).toList();

    // Previous period transactions
    final prevExpenses = expenseTransactions.where((t) {
      return !t.date.isBefore(prevRange.start) && !t.date.isAfter(prevRange.end);
    }).toList();

    final currentTotal = currentExpenses.fold<double>(
      0.0,
      (sum, t) => sum + t.amount,
    );
    final prevTotal = prevExpenses.fold<double>(
      0.0,
      (sum, t) => sum + t.amount,
    );

    double trendPercent = 0.0;
    bool isTrendIncrease = false;
    if (prevTotal > 0) {
      final diff = currentTotal - prevTotal;
      trendPercent = (diff / prevTotal * 100).abs();
      isTrendIncrease = diff > 0;
    }

    // Category allocation
    final Map<String, double> catMap = {};
    for (final tx in currentExpenses) {
      catMap[tx.categoryId] = (catMap[tx.categoryId] ?? 0.0) + tx.amount;
    }

    final sortedEntries = catMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final breakdown = sortedEntries.map((e) {
      final percent = currentTotal > 0 ? (e.value / currentTotal) * 100.0 : 0.0;
      return CategorySpendingItem(
        categoryId: e.key,
        amount: e.value,
        percentage: percent,
      );
    }).toList();

    return SpendingAnalysis(
      period: period,
      baseDate: baseDate,
      currentDateRange: currentRange,
      previousDateRange: prevRange,
      totalExpense: currentTotal,
      previousExpense: prevTotal > 0 ? prevTotal : null,
      trendPercentage: trendPercent,
      isIncrease: isTrendIncrease,
      filteredTransactions: currentExpenses,
      categorySpendingMap: catMap,
      categoryBreakdown: breakdown,
    );
  }
}

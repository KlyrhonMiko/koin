import 'package:koin/core/models/models.dart';

/// Builds aligned monthly samples without treating partial months as complete.
class ForecastHistory {
  final List<double> inflows;
  final List<double> outflows;

  const ForecastHistory({required this.inflows, required this.outflows});

  factory ForecastHistory.fromTransactions({
    required List<AppTransaction> transactions,
    required Set<String> includedAccountIds,
    required DateTime referenceDate,
    int maxMonths = 12,
  }) {
    final observed = transactions.where(
      (tx) =>
          includedAccountIds.contains(tx.accountId) &&
          !tx.date.isAfter(referenceDate),
    );
    if (observed.isEmpty) {
      return const ForecastHistory(inflows: [], outflows: []);
    }
    final first = observed
        .map((tx) => tx.date)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final currentMonth = DateTime(referenceDate.year, referenceDate.month);
    // The first recorded month may contain only a few days of activity.
    var start = DateTime(first.year, first.month + (first.day == 1 ? 0 : 1));
    final earliest = DateTime(
      currentMonth.year,
      currentMonth.month - maxMonths,
    );
    if (start.isBefore(earliest)) start = earliest;
    final inflows = <double>[];
    final outflows = <double>[];
    final incomeByMonth = <DateTime, double>{};
    final expenseByMonth = <DateTime, double>{};
    for (final tx in observed) {
      // Both directions of a debt repayment belong to the scheduled layer.
      if (tx.plannedPaymentId != null || tx.debtRepaymentId != null) continue;
      final month = DateTime(tx.date.year, tx.date.month);
      if (tx.type == TransactionType.income) {
        incomeByMonth[month] = (incomeByMonth[month] ?? 0) + tx.amount;
      } else if (tx.type == TransactionType.expense) {
        expenseByMonth[month] = (expenseByMonth[month] ?? 0) + tx.amount;
      }
    }
    for (
      var month = start;
      month.isBefore(currentMonth);
      month = DateTime(month.year, month.month + 1)
    ) {
      inflows.add(incomeByMonth[month] ?? 0);
      outflows.add(expenseByMonth[month] ?? 0);
    }
    // Cold start: estimate a run rate only after a week of observed activity.
    // Established forecasts never ingest the unfinished current month.
    if (inflows.isEmpty) {
      final firstDay = DateTime(first.year, first.month, first.day);
      final today = DateTime(
        referenceDate.year,
        referenceDate.month,
        referenceDate.day,
      );
      final observedEnd = firstDay.isBefore(currentMonth)
          ? currentMonth
          : today;
      final elapsed = observedEnd.difference(firstDay).inDays;
      if (elapsed < 7) {
        return const ForecastHistory(inflows: [], outflows: []);
      }
      final daysInMonth = DateTime(firstDay.year, firstDay.month + 1, 0).day;
      // Use complete observed days; today's transactions are still incomplete.
      double income = 0;
      double expense = 0;
      for (final tx in observed) {
        if (!tx.date.isBefore(observedEnd) ||
            tx.plannedPaymentId != null ||
            tx.debtRepaymentId != null) {
          continue;
        }
        if (tx.type == TransactionType.income) income += tx.amount;
        if (tx.type == TransactionType.expense) expense += tx.amount;
      }
      inflows.add(income * daysInMonth / elapsed);
      outflows.add(expense * daysInMonth / elapsed);
    }
    return ForecastHistory(inflows: inflows, outflows: outflows);
  }
}

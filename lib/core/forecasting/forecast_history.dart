import 'package:koin/core/models/models.dart';

/// Builds aligned monthly samples without treating partial months as complete.
class ForecastHistory {
  final List<double> inflows;
  final List<double> outflows;

  /// Complete observed days used for a cold-start run rate, not a full month.
  final int? observedDays;

  const ForecastHistory({
    required this.inflows,
    required this.outflows,
    this.observedDays,
  });

  factory ForecastHistory.fromTransactions({
    required List<AppTransaction> transactions,
    required Set<String> includedAccountIds,
    required DateTime referenceDate,
    List<PlannedPayment> plannedPayments = const [],
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
    final flexibleIds = plannedPayments
        .where((payment) => payment.frequency == PaymentFrequency.flexible)
        .map((payment) => payment.id)
        .toSet();
    bool isVariable(AppTransaction tx) =>
        tx.debtRepaymentId == null &&
        (tx.plannedPaymentId == null ||
            flexibleIds.contains(tx.plannedPaymentId));
    final incomeByMonth = <DateTime, double>{};
    final expenseByMonth = <DateTime, double>{};
    for (final tx in observed) {
      // Both directions of a debt repayment belong to the scheduled layer.
      // Flexible schedules have no recurring amount to replace their history.
      if (!isVariable(tx)) continue;
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
      // Until a complete calendar month exists, keep learning from every
      // complete day across month boundaries instead of freezing on week one.
      final observedEnd = today;
      final elapsed = observedEnd.difference(firstDay).inDays;
      if (elapsed < 7) {
        return const ForecastHistory(inflows: [], outflows: []);
      }
      final daysInMonth = DateTime(today.year, today.month + 1, 0).day;
      // Use complete observed days; today's transactions are still incomplete.
      double income = 0;
      double expense = 0;
      for (final tx in observed) {
        if (!tx.date.isBefore(observedEnd) || !isVariable(tx)) {
          continue;
        }
        if (tx.type == TransactionType.income) income += tx.amount;
        if (tx.type == TransactionType.expense) expense += tx.amount;
      }
      inflows.add(income * daysInMonth / elapsed);
      outflows.add(expense * daysInMonth / elapsed);
      return ForecastHistory(
        inflows: inflows,
        outflows: outflows,
        observedDays: elapsed,
      );
    }
    return ForecastHistory(inflows: inflows, outflows: outflows);
  }

  /// A flexible schedule keeps its original date after manual processing.
  /// Once a receipt/payment covers that date it must not be forecast again.
  static List<PlannedPayment> outstandingPayments({
    required List<PlannedPayment> payments,
    required List<AppTransaction> transactions,
    required DateTime referenceDate,
  }) {
    final latestProcessed = <String, DateTime>{};
    for (final tx in transactions) {
      final id = tx.plannedPaymentId;
      if (id == null || tx.date.isAfter(referenceDate)) continue;
      final previous = latestProcessed[id];
      if (previous == null || tx.date.isAfter(previous)) {
        latestProcessed[id] = tx.date;
      }
    }
    return payments.where((payment) {
      if (payment.frequency != PaymentFrequency.flexible) return true;
      final processed = latestProcessed[payment.id];
      final dueDay = DateTime(
        payment.nextDate.year,
        payment.nextDate.month,
        payment.nextDate.day,
      );
      return processed == null || processed.isBefore(dueDay);
    }).toList();
  }
}

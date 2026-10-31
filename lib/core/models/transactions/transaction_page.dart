import 'transaction.dart';
import 'transaction_filter.dart';

class TransactionCursor {
  const TransactionCursor(this.date, this.id, {required this.amount});
  final DateTime date;
  final String id;
  final double amount;
}

class TransactionPage {
  const TransactionPage({
    required this.items,
    required this.dayTotals,
    this.next,
  });
  final List<AppTransaction> items;
  final Map<String, double> dayTotals;
  final TransactionCursor? next;

  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static int compare(AppTransaction a, AppTransaction b) {
    return TransactionSortOrder.newestFirst.compare(a, b);
  }

  /// Fallback for in-memory adapters. SQLite overrides with a bounded query.
  static TransactionPage fromTransactions(
    Iterable<AppTransaction> source, {
    required TransactionFilter filter,
    required Map<String, String> categoryNamesById,
    TransactionCursor? after,
    int limit = 100,
  }) {
    RangeError.checkValueInInterval(limit, 1, 500, 'limit');
    final filtered = filter.apply(source, categoryNamesById: categoryNamesById);
    if (!filter.isAmountSort) filtered.sort(compare);
    final totals = <String, double>{};
    for (final tx in filtered) {
      final key = dayKey(tx.date);
      totals[key] =
          (totals[key] ?? 0) +
          (tx.isDebtTransfer
              ? 0
              : switch (tx.type) {
                  TransactionType.income => tx.amount,
                  TransactionType.expense => -tx.amount,
                  TransactionType.transfer => 0,
                });
    }
    final remaining = filtered.where((tx) {
      if (after == null) return true;
      if (filter.isAmountSort && tx.amount != after.amount) {
        return filter.sortOrder == TransactionSortOrder.amountAscending
            ? tx.amount > after.amount
            : tx.amount < after.amount;
      }
      return tx.date.isBefore(after.date) ||
          (tx.date.isAtSameMomentAs(after.date) &&
              tx.id.compareTo(after.id) < 0);
    });
    final page = remaining.take(limit + 1).toList();
    final items = page.take(limit).toList();
    return TransactionPage(
      items: items,
      dayTotals: {
        for (final tx in items) dayKey(tx.date): totals[dayKey(tx.date)]!,
      },
      next: page.length > limit
          ? TransactionCursor(
              items.last.date,
              items.last.id,
              amount: items.last.amount,
            )
          : null,
    );
  }
}

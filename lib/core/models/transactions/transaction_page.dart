import 'transaction.dart';
import 'transaction_filter.dart';

class TransactionCursor {
  const TransactionCursor(this.date, this.id);
  final DateTime date;
  final String id;
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
    final date = b.date.compareTo(a.date);
    return date == 0 ? b.id.compareTo(a.id) : date;
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
    final filtered = filter.apply(source, categoryNamesById: categoryNamesById)
      ..sort(compare);
    final totals = <String, double>{};
    for (final tx in filtered) {
      final key = dayKey(tx.date);
      totals[key] =
          (totals[key] ?? 0) +
          switch (tx.type) {
            TransactionType.income => tx.amount,
            TransactionType.expense => -tx.amount,
            TransactionType.transfer => 0,
          };
    }
    final remaining = filtered.where(
      (tx) =>
          after == null ||
          tx.date.isBefore(after.date) ||
          (tx.date.isAtSameMomentAs(after.date) &&
              tx.id.compareTo(after.id) < 0),
    );
    final page = remaining.take(limit + 1).toList();
    final items = page.take(limit).toList();
    return TransactionPage(
      items: items,
      dayTotals: {
        for (final tx in items) dayKey(tx.date): totals[dayKey(tx.date)]!,
      },
      next: page.length > limit
          ? TransactionCursor(items.last.date, items.last.id)
          : null,
    );
  }
}

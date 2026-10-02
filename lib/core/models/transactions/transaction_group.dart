import 'package:intl/intl.dart';
import 'package:koin/core/models/transactions/transaction.dart';

/// Immutable domain model representing a chronological group of transactions for a specific calendar day.
/// Encapsulates daily net balance calculations, transaction ordering, and date labeling.
class TransactionGroup {
  final String dateKey;
  final DateTime date;
  final List<AppTransaction> transactions;
  final double dailyTotal;

  /// Net balance for the group (alias for [dailyTotal]).
  double get netBalance => dailyTotal;

  const TransactionGroup({
    required this.dateKey,
    required this.date,
    required this.transactions,
    required this.dailyTotal,
  });

  /// Groups a collection of [transactions] by calendar day into chronological [TransactionGroup]s.
  /// Computes net daily total (positive for income, negative for expenses, 0 for neutral transfers).
  static List<TransactionGroup> groupTransactions(
    Iterable<AppTransaction> transactions, {
    DateFormat? dateFormat,
  }) {
    final formatter = dateFormat ?? DateFormat.yMMMd();
    final groupedMap = <String, List<AppTransaction>>{};
    final dateMap = <String, DateTime>{};

    for (final tx in transactions) {
      final key = formatter.format(tx.date);
      groupedMap.putIfAbsent(key, () => []).add(tx);
      dateMap.putIfAbsent(key, () => DateTime(tx.date.year, tx.date.month, tx.date.day));
    }

    final groups = <TransactionGroup>[];

    for (final entry in groupedMap.entries) {
      final key = entry.key;
      final txList = entry.value;

      double netTotal = 0.0;
      for (final tx in txList) {
        if (tx.type == TransactionType.income) {
          netTotal += tx.amount;
        } else if (tx.type == TransactionType.expense) {
          netTotal -= tx.amount;
        }
      }

      groups.add(
        TransactionGroup(
          dateKey: key,
          date: dateMap[key] ?? txList.first.date,
          transactions: txList,
          dailyTotal: netTotal,
        ),
      );
    }

    // Sort by date descending (most recent first)
    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }
}

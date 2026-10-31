import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ledger/ledger.dart';
import '../models/models.dart';
import 'category_provider.dart';
import 'transaction_provider.dart';

class TransactionHistory {
  const TransactionHistory({
    required this.items,
    required this.dayTotals,
    this.next,
    this.loadingMore = false,
    this.loadMoreError = false,
  });
  final List<AppTransaction> items;
  final Map<String, double> dayTotals;
  final TransactionCursor? next;
  final bool loadingMore;
  final bool loadMoreError;
}

class TransactionHistoryNotifier extends AsyncNotifier<TransactionHistory> {
  int _revision = 0;
  @override
  Future<TransactionHistory> build() async {
    _revision++;
    ref.watch(transactionProvider);
    final filter = ref.watch(effectiveTransactionFilterProvider);
    final categories = await ref.watch(categoriesProvider.future);
    final page = await ref
        .watch(ledgerProvider)
        .getTransactionPage(
          filter: filter,
          categoryNamesById: {for (final c in categories) c.id: c.name},
        );
    return TransactionHistory(
      items: page.items,
      dayTotals: page.dayTotals,
      next: page.next,
    );
  }

  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.next == null || current.loadingMore) return;
    final revision = _revision;
    state = AsyncData(
      TransactionHistory(
        items: current.items,
        dayTotals: current.dayTotals,
        next: current.next,
        loadingMore: true,
      ),
    );
    try {
      final categories = await ref.read(categoriesProvider.future);
      final filter = ref.read(effectiveTransactionFilterProvider);
      final page = await ref
          .read(ledgerProvider)
          .getTransactionPage(
            filter: filter,
            after: current.next,
            categoryNamesById: {for (final c in categories) c.id: c.name},
          );
      if (!ref.mounted || revision != _revision) return;
      final items = {
        for (final tx in [...current.items, ...page.items]) tx.id: tx,
      }.values.toList()..sort(filter.sortOrder.compare);
      state = AsyncData(
        TransactionHistory(
          items: items,
          dayTotals: {...current.dayTotals, ...page.dayTotals},
          next: page.next,
        ),
      );
    } catch (_) {
      if (ref.mounted && revision == _revision) {
        state = AsyncData(
          TransactionHistory(
            items: current.items,
            dayTotals: current.dayTotals,
            next: current.next,
            loadMoreError: true,
          ),
        );
      }
    }
  }
}

final transactionHistoryProvider =
    AsyncNotifierProvider<TransactionHistoryNotifier, TransactionHistory>(
      TransactionHistoryNotifier.new,
    );

final pagedTransactionRowsProvider = Provider((ref) {
  final amountSorted = ref
      .watch(effectiveTransactionFilterProvider)
      .isAmountSort;
  return ref.watch(transactionHistoryProvider).whenData((history) {
    if (amountSorted) {
      return [
        for (final tx in history.items)
          (
            group: TransactionGroup(
              dateKey: TransactionPage.dayKey(tx.date),
              date: tx.date,
              transactions: [tx],
              dailyTotal: 0,
            ),
            index: 0,
          ),
      ];
    }
    return [
      for (final group in TransactionGroup.groupTransactions(
        history.items,
      )) ...[
        (
          group: TransactionGroup(
            dateKey: group.dateKey,
            date: group.date,
            transactions: group.transactions,
            dailyTotal:
                history.dayTotals[TransactionPage.dayKey(group.date)] ??
                group.dailyTotal,
          ),
          index: -1,
        ),
        for (var i = 0; i < group.transactions.length; i++)
          (group: group, index: i),
      ],
    ];
  });
});

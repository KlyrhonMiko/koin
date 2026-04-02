import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/transaction.dart';
import 'package:koin/core/models/transaction_filter.dart';
import 'package:koin/core/providers/category_provider.dart';

class TransactionNotifier extends AsyncNotifier<List<AppTransaction>> {
  @override
  Future<List<AppTransaction>> build() async {
    return await DatabaseHelper.instance.getTransactions();
  }

  Future<void> loadTransactions() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await DatabaseHelper.instance.getTransactions();
    });
  }

  Future<void> addTransaction(AppTransaction transaction) async {
    await DatabaseHelper.instance.insertTransaction(transaction);
    await loadTransactions();
  }

  Future<void> updateTransaction(AppTransaction transaction) async {
    await DatabaseHelper.instance.updateTransaction(transaction);
    await loadTransactions();
  }

  Future<void> deleteTransaction(String id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    await loadTransactions();
  }
}

final transactionProvider =
    AsyncNotifierProvider<TransactionNotifier, List<AppTransaction>>(() {
      return TransactionNotifier();
    });

class TransactionFilterNotifier extends Notifier<TransactionFilter> {
  @override
  TransactionFilter build() => const TransactionFilter();

  void updateFilter(TransactionFilter filter) => state = filter;
  void setQuery(String query) => state = state.copyWith(query: query);
  void clearFilters() => state = const TransactionFilter();
}

final transactionFilterProvider =
    NotifierProvider<TransactionFilterNotifier, TransactionFilter>(() {
      return TransactionFilterNotifier();
    });

final filteredTransactionsProvider = Provider<AsyncValue<List<AppTransaction>>>(
  (ref) {
    final transactionsAsync = ref.watch(transactionProvider);
    final filter = ref.watch(transactionFilterProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];

    return transactionsAsync.whenData((transactions) {
      if (filter.isEmpty) return transactions;

      return transactions.where((tx) {
        // Query filter (note or category name)
        if (filter.query.isNotEmpty) {
          final query = filter.query.toLowerCase();
          final categoryName =
              categories
                  .where((c) => c.id == tx.categoryId)
                  .map((c) => c.name.toLowerCase())
                  .firstOrNull ??
              '';
          final matchesNote = tx.note.toLowerCase().contains(query);
          final matchesCategory = categoryName.contains(query);
          if (!matchesNote && !matchesCategory) return false;
        }

        // Date range filter
        if (filter.dateRange != null) {
          if (tx.date.isBefore(filter.dateRange!.start) ||
              tx.date.isAfter(
                filter.dateRange!.end.add(const Duration(days: 1)),
              )) {
            return false;
          }
        }

        // Category filter
        if (filter.categoryIds.isNotEmpty &&
            !filter.categoryIds.contains(tx.categoryId)) {
          return false;
        }

        // Account filter
        if (filter.accountIds.isNotEmpty &&
            !filter.accountIds.contains(tx.accountId)) {
          return false;
        }

        // Amount filter
        if (filter.minAmount != null && tx.amount < filter.minAmount!) {
          return false;
        }
        if (filter.maxAmount != null && tx.amount > filter.maxAmount!) {
          return false;
        }

        // Type filter
        if (filter.type != null && tx.type != filter.type) {
          return false;
        }

        return true;
      }).toList();
    });
  },
);

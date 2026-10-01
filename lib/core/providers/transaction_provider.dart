import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/ledger/ledger.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/providers/category_provider.dart';

import 'package:koin/core/providers/planned_payment_provider.dart';
import 'package:koin/core/providers/debt_provider.dart';

class TransactionNotifier extends AsyncNotifier<List<AppTransaction>> {
  Ledger get _ledger => ref.read(ledgerProvider);

  @override
  Future<List<AppTransaction>> build() async {
    return await _ledger.getTransactions();
  }

  Future<void> loadTransactions({bool showLoading = true}) async {
    if (showLoading) state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _ledger.getTransactions();
    });
  }

  Future<void> addTransaction(AppTransaction transaction) async {
    await _ledger.recordTransaction(transaction);
    await loadTransactions(showLoading: false);
  }

  Future<TransferResult> addTransfer({
    required AppTransaction transferTransaction,
    AppTransaction? feeTransaction,
  }) async {
    final result = await _ledger.recordTransfer(
      transferTransaction: transferTransaction,
      feeTransaction: feeTransaction,
    );
    await loadTransactions(showLoading: false);
    return result;
  }

  Future<void> updateTransaction(AppTransaction transaction) async {
    await _ledger.updateTransaction(transaction);
    await loadTransactions(showLoading: false);
  }

  Future<void> deleteTransaction(String id) async {
    final result = await _ledger.voidTransaction(id);
    await loadTransactions(showLoading: false);

    if (result.hadPlannedPaymentRollback) {
      // Force reload of planned payments if a rollback occurred
      await ref.read(plannedPaymentProvider.notifier).loadPlannedPayments();
    } else {
      // Still invalidate just in case
      ref.invalidate(plannedPaymentProvider);
    }

    if (result.hadDebtRollback) {
      // Force reload of debt data
      ref.invalidate(debtRepaymentsProvider(result.affectedDebtId!));
      await ref.read(debtsProvider.notifier).loadDebts();
    } else {
      // Still invalidate just in case
      ref.invalidate(debtsProvider);
    }
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

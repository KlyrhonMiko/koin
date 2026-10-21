import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/ledger/ledger.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/providers/category_provider.dart';

import 'package:koin/core/providers/planned_payment_provider.dart';
import 'package:koin/core/providers/debt_provider.dart';

import 'savings_provider.dart';

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
    ref.invalidate(savingsGoalsProvider);
    ref.invalidate(savingsLogsProvider);
    await loadTransactions(showLoading: false);
    final updated = state.value
        ?.where((tx) => tx.id == transaction.id)
        .firstOrNull;
    if (updated?.debtRepaymentId != null) {
      ref.invalidate(debtRepaymentsProvider);
      await ref.read(debtsProvider.notifier).loadDebts();
    }
  }

  Future<void> updateTransfer(
    AppTransaction transaction,
    AppTransaction? fee,
  ) async {
    await _ledger.updateTransfer(transaction, fee);
    ref.invalidate(savingsGoalsProvider);
    ref.invalidate(savingsLogsProvider);
    await loadTransactions(showLoading: false);
  }

  Future<void> deleteTransaction(String id) async {
    final result = await _ledger.voidTransaction(id);
    ref.invalidate(savingsGoalsProvider);
    ref.invalidate(savingsLogsProvider);
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

class EffectiveTransactionFilter extends Notifier<TransactionFilter> {
  Timer? _timer;
  @override
  TransactionFilter build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(transactionFilterProvider, (previous, next) {
      _timer?.cancel();
      if (next.query.isEmpty || next.query == state.query) {
        state = next;
      } else {
        // Typed text stays immediate in the input; expensive filtering waits
        // for a pause. Other filter criteria still take effect immediately.
        if (!next.hasSameCriteria(state)) {
          state = next.copyWith(query: state.query);
        }
        _timer = Timer(const Duration(milliseconds: 200), () => state = next);
      }
    });
    return ref.read(transactionFilterProvider);
  }
}

final effectiveTransactionFilterProvider =
    NotifierProvider<EffectiveTransactionFilter, TransactionFilter>(
      EffectiveTransactionFilter.new,
    );

final filteredTransactionsProvider = Provider<AsyncValue<List<AppTransaction>>>(
  (ref) {
    final transactionsAsync = ref.watch(transactionProvider);
    final filter = ref.watch(effectiveTransactionFilterProvider);
    final categories = ref.watch(categoriesProvider).value ?? [];

    return transactionsAsync.whenData((transactions) {
      if (filter.isEmpty) return transactions;
      final categoryNamesById = {for (final c in categories) c.id: c.name};
      return filter.apply(transactions, categoryNamesById: categoryNamesById);
    });
  },
);

/// Cache grouping and row descriptors independently of theme/privacy rebuilds.
final transactionRowsProvider = Provider(
  (ref) => ref
      .watch(filteredTransactionsProvider)
      .whenData(
        (transactions) => [
          for (final group in TransactionGroup.groupTransactions(
            transactions,
          )) ...[
            (group: group, index: -1),
            for (var i = 0; i < group.transactions.length; i++)
              (group: group, index: i),
          ],
        ],
      ),
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/ledger/ledger.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/repositories/debt_repository.dart';
import 'package:koin/core/providers/transaction_provider.dart';

class DebtsNotifier extends AsyncNotifier<List<Debt>> {
  DebtRepository get _repository => ref.read(debtRepositoryProvider);

  @override
  Future<List<Debt>> build() async {
    try {
      return await _repository.getDebts();
    } catch (e, st) {
      // ignore: avoid_print
      print('[debtsProvider] Error loading debts: $e\n$st');
      rethrow;
    }
  }

  Future<void> loadDebts() async {
    state = await AsyncValue.guard(() async {
      return await _repository.getDebts();
    });
  }

  Future<void> addDebt(Debt debt) async {
    await _repository.insertDebt(debt);
    await loadDebts();
  }

  Future<void> updateDebt(Debt debt) async {
    await _repository.updateDebt(debt);
    await loadDebts();
  }

  Future<void> deleteDebt(String id) async {
    await _repository.deleteDebt(id);
    await loadDebts();
  }

  Future<void> addDebtItem(DebtItem item) async {
    await _repository.insertDebtItem(item);
    await loadDebts();
  }

  Future<void> updateDebtItem(DebtItem oldItem, DebtItem newItem) async {
    await _repository.updateDebtItem(oldItem, newItem);
    await loadDebts();
  }

  Future<void> deleteDebtItem(DebtItem item) async {
    await _repository.deleteDebtItem(item);
    await loadDebts();
  }

  /// Atomically processes a debt repayment or credit increase through the Ledger seam,
  /// updating the debt balance, storing repayment history, and recording
  /// the associated financial transaction if an account was linked.
  Future<AppTransaction?> processRepayment({
    required Debt debt,
    required DebtRepayment repayment,
    required String? categoryId,
  }) async {
    final ledger = ref.read(ledgerProvider);
    final tx = await ledger.recordDebtRepayment(
      debt: debt,
      repayment: repayment,
      categoryId: categoryId,
    );
    ref.invalidate(debtRepaymentsProvider(repayment.debtId));
    ref.invalidate(transactionProvider);
    await loadDebts();
    return tx;
  }

  Future<void> addRepayment(DebtRepayment repayment) async {
    await _repository.insertDebtRepayment(repayment);
    ref.invalidate(debtRepaymentsProvider(repayment.debtId));
    await loadDebts();
  }

  Future<void> deleteRepayment(DebtRepayment repayment) async {
    final ledger = ref.read(ledgerProvider);
    await ledger.voidDebtRepayment(repayment);
    ref.invalidate(debtRepaymentsProvider(repayment.debtId));
    ref.invalidate(transactionProvider);
    await loadDebts();
  }

  Future<void> reorderDebts(int oldIndex, int newIndex) async {
    final currentDebts = List<Debt>.from(state.value ?? []);

    final item = currentDebts.removeAt(oldIndex);
    currentDebts.insert(newIndex, item);

    final updatedDebts = currentDebts.asMap().entries.map((e) {
      return e.value.copyWith(sortOrder: e.key);
    }).toList();

    state = AsyncValue.data(updatedDebts);
    await _repository.updateDebtPositions(updatedDebts);
  }
}

final debtsProvider = AsyncNotifierProvider<DebtsNotifier, List<Debt>>(() {
  return DebtsNotifier();
});

final debtRepaymentsProvider =
    FutureProvider.family<List<DebtRepayment>, String>((ref, debtId) async {
      final repository = ref.read(debtRepositoryProvider);
      return await repository.getDebtRepayments(debtId);
    });

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/debt.dart';
import 'package:koin/core/models/debt_repayment.dart';
import 'package:koin/core/providers/transaction_provider.dart';

class DebtsNotifier extends AsyncNotifier<List<Debt>> {
  @override
  Future<List<Debt>> build() async {
    try {
      return await DatabaseHelper.instance.getDebts();
    } catch (e, st) {
      // ignore: avoid_print
      print('[debtsProvider] Error loading debts: $e\n$st');
      rethrow;
    }
  }

  Future<void> loadDebts() async {
    // Don't set loading state here — it causes a persistent spinner if an
    // error occurs. AsyncValue.guard will set error state properly.
    state = await AsyncValue.guard(() async {
      return await DatabaseHelper.instance.getDebts();
    });
  }

  Future<void> addDebt(Debt debt) async {
    await DatabaseHelper.instance.insertDebt(debt);
    await loadDebts();
  }

  Future<void> updateDebt(Debt debt) async {
    await DatabaseHelper.instance.updateDebt(debt);
    await loadDebts();
  }

  Future<void> deleteDebt(String id) async {
    await DatabaseHelper.instance.deleteDebt(id);
    await loadDebts();
  }

  Future<void> addRepayment(DebtRepayment repayment) async {
    await DatabaseHelper.instance.insertDebtRepayment(repayment);
    ref.invalidate(debtRepaymentsProvider(repayment.debtId));
    await loadDebts();
  }

  Future<void> deleteRepayment(DebtRepayment repayment) async {
    await DatabaseHelper.instance.deleteDebtRepayment(repayment);
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
    await DatabaseHelper.instance.updateDebtPositions(updatedDebts);
  }
}

final debtsProvider = AsyncNotifierProvider<DebtsNotifier, List<Debt>>(() {
  return DebtsNotifier();
});

final debtRepaymentsProvider =
    FutureProvider.family<List<DebtRepayment>, String>((ref, debtId) async {
      return await DatabaseHelper.instance.getDebtRepayments(debtId);
    });

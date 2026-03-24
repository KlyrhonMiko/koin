import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/transaction.dart';

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

  Future<void> deleteTransaction(String id) async {
    await DatabaseHelper.instance.deleteTransaction(id);
    await loadTransactions();
  }
}

final transactionProvider = AsyncNotifierProvider<TransactionNotifier, List<AppTransaction>>(() {
  return TransactionNotifier();
});

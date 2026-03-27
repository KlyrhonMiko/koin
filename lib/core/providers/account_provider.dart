import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/account.dart';
import 'dart:developer' as dev;

class AccountNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() async {
    return await DatabaseHelper.instance.getAccounts();
  }

  Future<void> loadAccounts() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await DatabaseHelper.instance.getAccounts();
    });
  }

  Future<void> addAccount(Account account) async {
    final currentAccounts = state.value ?? [];
    final accountWithPosition = account.copyWith(position: currentAccounts.length);
    await DatabaseHelper.instance.insertAccount(accountWithPosition);
    await loadAccounts();
  }

  Future<void> updateAccount(Account account) async {
    await DatabaseHelper.instance.updateAccount(account);
    await loadAccounts();
  }

  Future<void> deleteAccount(String id) async {
    await DatabaseHelper.instance.deleteAccount(id);
    await loadAccounts();
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    final accounts = state.value;
    if (accounts == null) return;

    final items = List<Account>.from(accounts);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);

    // Update positions in memory first for immediate UI feedback
    final updatedItems = <Account>[];
    for (int i = 0; i < items.length; i++) {
      updatedItems.add(items[i].copyWith(position: i));
    }
    state = AsyncValue.data(updatedItems);

    // Update database efficiently with batch
    try {
      await DatabaseHelper.instance.updateAccountPositions(updatedItems);
    } catch (e, stackTrace) {
      dev.log('Error updating account positions', error: e, stackTrace: stackTrace);
    }
  }
}

final accountProvider = AsyncNotifierProvider<AccountNotifier, List<Account>>(() {
  return AccountNotifier();
});

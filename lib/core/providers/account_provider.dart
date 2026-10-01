import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/repositories/account_repository.dart';
import 'dart:developer' as dev;

class AccountNotifier extends AsyncNotifier<List<Account>> {
  AccountRepository get _repository => ref.read(accountRepositoryProvider);

  @override
  Future<List<Account>> build() async {
    return await _repository.getAccounts();
  }

  Future<void> loadAccounts() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      return await _repository.getAccounts();
    });
  }

  Future<void> addAccount(Account account) async {
    final currentAccounts = state.value ?? [];
    final accountWithPosition = account.copyWith(
      position: currentAccounts.length,
    );

    // Save previous state for rollback
    final previousState = state;

    // Optimistic update
    state = AsyncValue.data([...currentAccounts, accountWithPosition]);

    try {
      await _repository.insertAccount(accountWithPosition);
    } catch (e, st) {
      state = previousState;
      dev.log('Error adding account', error: e, stackTrace: st);
    }
  }

  Future<void> updateAccount(Account account) async {
    if (!state.hasValue) return;

    final previousState = state;
    final currentAccounts = state.value!;

    // Optimistic update
    state = AsyncValue.data(
      currentAccounts.map((a) => a.id == account.id ? account : a).toList(),
    );

    try {
      await _repository.updateAccount(account);
    } catch (e, st) {
      state = previousState;
      dev.log('Error updating account', error: e, stackTrace: st);
    }
  }

  Future<void> deleteAccount(String id) async {
    await _repository.deleteAccount(id);
    await loadAccounts();
  }

  Future<void> reorderAccounts(int oldIndex, int newIndex) async {
    final accounts = state.value;
    if (accounts == null) return;

    final items = List<Account>.from(accounts);

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
      await _repository.updateAccountPositions(updatedItems);
    } catch (e, stackTrace) {
      dev.log(
        'Error updating account positions',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }
}

final accountProvider = AsyncNotifierProvider<AccountNotifier, List<Account>>(
  () {
    return AccountNotifier();
  },
);

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/account.dart';

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
    await DatabaseHelper.instance.insertAccount(account);
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
}

final accountProvider = AsyncNotifierProvider<AccountNotifier, List<Account>>(() {
  return AccountNotifier();
});

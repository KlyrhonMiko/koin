import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/models.dart';

/// Domain Seam: The interface for persisting and retrieving accounts.
abstract class AccountRepository {
  Future<List<Account>> getAccounts();
  Future<Account> insertAccount(Account account);
  Future<void> updateAccount(Account account);
  Future<void> deleteAccount(String id);
  Future<void> updateAccountPositions(List<Account> accounts);
}

/// Concrete SQLite Adapter: delegates to DatabaseHelper.
class SqliteAccountAdapter implements AccountRepository {
  final DatabaseHelper _dbHelper;

  SqliteAccountAdapter({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Account>> getAccounts() => _dbHelper.getAccounts();

  @override
  Future<Account> insertAccount(Account account) => _dbHelper.insertAccount(account);

  @override
  Future<void> updateAccount(Account account) async {
    await _dbHelper.updateAccount(account);
  }

  @override
  Future<void> deleteAccount(String id) async {
    await _dbHelper.deleteAccount(id);
  }

  @override
  Future<void> updateAccountPositions(List<Account> accounts) =>
      _dbHelper.updateAccountPositions(accounts);
}

/// In-Memory Test Adapter: provides deterministic account persistence for testing.
class InMemoryAccountAdapter implements AccountRepository {
  final List<Account> _accounts = [];

  InMemoryAccountAdapter({List<Account> initial = const []}) {
    _accounts.addAll(initial);
    _sort();
  }

  void _sort() {
    _accounts.sort((a, b) => a.position.compareTo(b.position));
  }

  @override
  Future<List<Account>> getAccounts() async {
    _sort();
    return List.unmodifiable(_accounts);
  }

  @override
  Future<Account> insertAccount(Account account) async {
    _accounts.removeWhere((a) => a.id == account.id);
    _accounts.add(account);
    _sort();
    return account;
  }

  @override
  Future<void> updateAccount(Account account) async {
    final idx = _accounts.indexWhere((a) => a.id == account.id);
    if (idx != -1) {
      _accounts[idx] = account;
      _sort();
    }
  }

  @override
  Future<void> deleteAccount(String id) async {
    _accounts.removeWhere((a) => a.id == id);
  }

  @override
  Future<void> updateAccountPositions(List<Account> accounts) async {
    for (final updated in accounts) {
      final idx = _accounts.indexWhere((a) => a.id == updated.id);
      if (idx != -1) {
        _accounts[idx] = _accounts[idx].copyWith(position: updated.position);
      }
    }
    _sort();
  }
}

/// Riverpod provider exposing the AccountRepository seam.
final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return SqliteAccountAdapter();
});

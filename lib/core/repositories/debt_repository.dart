import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/models.dart';

/// Domain Seam: The interface for persisting and retrieving debts, sub-items, and repayments.
abstract class DebtRepository {
  Future<List<Debt>> getDebts();
  Future<Debt> insertDebt(Debt debt);
  Future<void> updateDebt(Debt debt);
  Future<void> deleteDebt(String id);
  Future<DebtItem> insertDebtItem(DebtItem item);
  Future<void> updateDebtItem(DebtItem oldItem, DebtItem newItem);
  Future<void> deleteDebtItem(DebtItem item);
  Future<List<DebtRepayment>> getDebtRepayments(String debtId);
  Future<void> insertDebtRepayment(DebtRepayment repayment);
  Future<void> updateDebtPositions(List<Debt> debts);
}

/// Concrete SQLite Adapter: delegates to DatabaseHelper.
class SqliteDebtAdapter implements DebtRepository {
  final DatabaseHelper _dbHelper;

  SqliteDebtAdapter({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<Debt>> getDebts() => _dbHelper.getDebts();

  @override
  Future<Debt> insertDebt(Debt debt) => _dbHelper.insertDebt(debt);

  @override
  Future<void> updateDebt(Debt debt) async {
    await _dbHelper.updateDebt(debt);
  }

  @override
  Future<void> deleteDebt(String id) async {
    await _dbHelper.deleteDebt(id);
  }

  @override
  Future<DebtItem> insertDebtItem(DebtItem item) => _dbHelper.insertDebtItem(item);

  @override
  Future<void> updateDebtItem(DebtItem oldItem, DebtItem newItem) =>
      _dbHelper.updateDebtItem(oldItem, newItem);

  @override
  Future<void> deleteDebtItem(DebtItem item) async {
    await _dbHelper.deleteDebtItem(item);
  }

  @override
  Future<List<DebtRepayment>> getDebtRepayments(String debtId) =>
      _dbHelper.getDebtRepayments(debtId);

  @override
  Future<void> insertDebtRepayment(DebtRepayment repayment) =>
      _dbHelper.insertDebtRepayment(repayment);

  @override
  Future<void> updateDebtPositions(List<Debt> debts) =>
      _dbHelper.updateDebtPositions(debts);
}

/// In-Memory Test Adapter: provides deterministic debt persistence for testing.
class InMemoryDebtAdapter implements DebtRepository {
  final Map<String, Debt> _debts = {};
  final Map<String, List<DebtItem>> _items = {};
  final Map<String, List<DebtRepayment>> _repayments = {};

  InMemoryDebtAdapter({List<Debt> initial = const []}) {
    for (final d in initial) {
      _debts[d.id] = d;
      _items[d.id] = List.from(d.items);
    }
  }

  @override
  Future<List<Debt>> getDebts() async {
    final list = _debts.values.map((d) {
      return d.copyWith(items: _items[d.id] ?? []);
    }).toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return list;
  }

  @override
  Future<Debt> insertDebt(Debt debt) async {
    _debts[debt.id] = debt;
    _items[debt.id] = List.from(debt.items);
    return debt;
  }

  @override
  Future<void> updateDebt(Debt debt) async {
    _debts[debt.id] = debt;
  }

  @override
  Future<void> deleteDebt(String id) async {
    _debts.remove(id);
    _items.remove(id);
    _repayments.remove(id);
  }

  @override
  Future<DebtItem> insertDebtItem(DebtItem item) async {
    _items.putIfAbsent(item.debtId, () => []).add(item);
    return item;
  }

  @override
  Future<void> updateDebtItem(DebtItem oldItem, DebtItem newItem) async {
    final list = _items[newItem.debtId];
    if (list != null) {
      final idx = list.indexWhere((i) => i.id == oldItem.id);
      if (idx != -1) {
        list[idx] = newItem;
      }
    }
  }

  @override
  Future<void> deleteDebtItem(DebtItem item) async {
    final list = _items[item.debtId];
    if (list != null) {
      list.removeWhere((i) => i.id == item.id);
    }
  }

  @override
  Future<List<DebtRepayment>> getDebtRepayments(String debtId) async {
    final list = _repayments[debtId] ?? [];
    return List.unmodifiable(list);
  }

  @override
  Future<void> insertDebtRepayment(DebtRepayment repayment) async {
    _repayments.putIfAbsent(repayment.debtId, () => []).add(repayment);
    // Mutate in-memory debt balance to mirror DB cascade
    final debt = _debts[repayment.debtId];
    if (debt != null) {
      if (repayment.isIncrease) {
        _debts[repayment.debtId] = debt.copyWith(
          amount: debt.amount + repayment.amount,
        );
      } else {
        _debts[repayment.debtId] = debt.copyWith(
          currentAmount: debt.currentAmount + repayment.amount,
        );
      }
    }
  }

  @override
  Future<void> updateDebtPositions(List<Debt> debts) async {
    for (final d in debts) {
      final existing = _debts[d.id];
      if (existing != null) {
        _debts[d.id] = existing.copyWith(sortOrder: d.sortOrder);
      }
    }
  }
}

/// Riverpod provider exposing the DebtRepository seam.
final debtRepositoryProvider = Provider<DebtRepository>((ref) {
  return SqliteDebtAdapter();
});

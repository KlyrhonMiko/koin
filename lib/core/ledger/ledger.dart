import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/models.dart';

/// Represents the outcome of voiding/deleting a transaction,
/// recording any cascading domain side effects that occurred.
class TransactionVoidResult {
  final String transactionId;
  final String? affectedPlannedPaymentId;
  final String? affectedDebtId;

  const TransactionVoidResult({
    required this.transactionId,
    this.affectedPlannedPaymentId,
    this.affectedDebtId,
  });

  bool get hadPlannedPaymentRollback => affectedPlannedPaymentId != null;
  bool get hadDebtRollback => affectedDebtId != null;
}

/// Domain Seam: The interface through which transactions are recorded, queried, and voided.
/// Hides raw SQL persistence and encapsulates transaction cascade rules.
abstract class Ledger {
  Future<List<AppTransaction>> getTransactions();

  Future<AppTransaction> recordTransaction(AppTransaction transaction);

  Future<void> updateTransaction(AppTransaction transaction);

  Future<TransactionVoidResult> voidTransaction(String id);

  /// Atomically records a planned payment occurrence, advances the schedule to nextDate,
  /// and persists the corresponding financial transaction.
  Future<AppTransaction> recordPlannedPaymentOccurrence({
    required PlannedPayment payment,
    required double amount,
    required String accountId,
    required String categoryId,
    DateTime? date,
  });

  /// Atomically records a debt repayment/increase, mutates the debt balance,
  /// and writes the corresponding financial transaction if an account was specified.
  Future<AppTransaction?> recordDebtRepayment({
    required Debt debt,
    required DebtRepayment repayment,
    required String? categoryId,
  });
}

/// Production Adapter: Uses DatabaseHelper and SQLite under an atomic transaction.
class SqliteLedgerAdapter implements Ledger {
  final DatabaseHelper _dbHelper;

  SqliteLedgerAdapter({DatabaseHelper? dbHelper})
      : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<AppTransaction>> getTransactions() async {
    return await _dbHelper.getTransactions();
  }

  @override
  Future<AppTransaction> recordTransaction(AppTransaction transaction) async {
    return await _dbHelper.insertTransaction(transaction);
  }

  @override
  Future<void> updateTransaction(AppTransaction transaction) async {
    await _dbHelper.updateTransaction(transaction);
  }

  @override
  Future<TransactionVoidResult> voidTransaction(String id) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final maps = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [id],
      );

      String? rolledBackPlannedPaymentId;
      String? affectedDebtId;

      if (maps.isNotEmpty) {
        final transaction = AppTransaction.fromMap(maps.first);

        // 1. Roll back planned payment schedule if linked
        if (transaction.plannedPaymentId != null) {
          final ppMaps = await txn.query(
            'planned_payments',
            where: 'id = ?',
            whereArgs: [transaction.plannedPaymentId],
          );

          if (ppMaps.isNotEmpty) {
            final payment = PlannedPayment.fromMap(ppMaps.first);
            final prevDate = payment.computePreviousDate();

            await txn.update(
              'planned_payments',
              {'nextDate': prevDate.toIso8601String()},
              where: 'id = ?',
              whereArgs: [payment.id],
            );
            rolledBackPlannedPaymentId = payment.id;
          }
        }

        // 2. Roll back debt repayment and balance if linked
        if (transaction.debtRepaymentId != null) {
          final repaymentMaps = await txn.query(
            'debt_repayments',
            where: 'id = ?',
            whereArgs: [transaction.debtRepaymentId],
          );

          if (repaymentMaps.isNotEmpty) {
            final repayment = DebtRepayment.fromMap(repaymentMaps.first);
            affectedDebtId = repayment.debtId;

            await txn.delete(
              'debt_repayments',
              where: 'id = ?',
              whereArgs: [repayment.id],
            );

            await txn.execute(
              'UPDATE debts SET currentAmount = currentAmount - ? WHERE id = ?',
              [repayment.amount, repayment.debtId],
            );
          }
        }
      }

      // 3. Delete the transaction record
      await txn.delete('transactions', where: 'id = ?', whereArgs: [id]);

      return TransactionVoidResult(
        transactionId: id,
        affectedPlannedPaymentId: rolledBackPlannedPaymentId,
        affectedDebtId: affectedDebtId,
      );
    });
  }

  @override
  Future<AppTransaction> recordPlannedPaymentOccurrence({
    required PlannedPayment payment,
    required double amount,
    required String accountId,
    required String categoryId,
    DateTime? date,
  }) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final nextDate = payment.computeNextDate();
      final updatedPayment = payment.copyWith(nextDate: nextDate);
      await txn.update(
        'planned_payments',
        updatedPayment.toMap(),
        where: 'id = ?',
        whereArgs: [payment.id],
      );

      final transaction = AppTransaction(
        id: const Uuid().v4(),
        note: payment.title,
        amount: amount,
        type: payment.type,
        date: date ?? DateTime.now(),
        categoryId: categoryId,
        accountId: accountId,
        plannedPaymentId: payment.id,
      );

      await txn.insert('transactions', transaction.toMap());
      return transaction;
    });
  }

  @override
  Future<AppTransaction?> recordDebtRepayment({
    required Debt debt,
    required DebtRepayment repayment,
    required String? categoryId,
  }) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await txn.insert('debt_repayments', repayment.toMap());

      if (repayment.isIncrease) {
        await txn.execute(
          'UPDATE debts SET amount = amount + ? WHERE id = ?',
          [repayment.amount, repayment.debtId],
        );
      } else {
        await txn.execute(
          'UPDATE debts SET currentAmount = currentAmount + ? WHERE id = ?',
          [repayment.amount, repayment.debtId],
        );
      }

      if (repayment.accountId != null && repayment.accountId!.isNotEmpty) {
        final isExpense = repayment.isIncrease
            ? debt.type == DebtType.owedToMe
            : debt.type == DebtType.iOwe;

        final transaction = AppTransaction(
          id: const Uuid().v4(),
          amount: repayment.amount,
          date: repayment.date,
          type: isExpense ? TransactionType.expense : TransactionType.income,
          categoryId: categoryId ?? (isExpense ? 'cat_others' : 'cat_others_inc'),
          accountId: repayment.accountId!,
          note: repayment.isIncrease
              ? 'Debt increase: ${debt.personName}'
              : (debt.type == DebtType.owedToMe
                  ? 'Debt payment: ${debt.personName}'
                  : 'Debt settlement: ${debt.personName}'),
          debtRepaymentId: repayment.id,
        );

        await txn.insert('transactions', transaction.toMap());
        return transaction;
      }
      return null;
    });
  }
}

/// In-Memory Test Adapter: Provides deterministic in-memory ledger operations for testing.
class InMemoryLedgerAdapter implements Ledger {
  final Map<String, AppTransaction> _store = {};
  final List<TransactionVoidResult> voidLog = [];

  InMemoryLedgerAdapter({List<AppTransaction> initial = const []}) {
    for (final tx in initial) {
      _store[tx.id] = tx;
    }
  }

  @override
  Future<List<AppTransaction>> getTransactions() async {
    final list = _store.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  @override
  Future<AppTransaction> recordTransaction(AppTransaction transaction) async {
    _store[transaction.id] = transaction;
    return transaction;
  }

  @override
  Future<void> updateTransaction(AppTransaction transaction) async {
    _store[transaction.id] = transaction;
  }

  @override
  Future<TransactionVoidResult> voidTransaction(String id) async {
    final tx = _store.remove(id);
    final result = TransactionVoidResult(
      transactionId: id,
      affectedPlannedPaymentId: tx?.plannedPaymentId,
      affectedDebtId: tx?.debtRepaymentId,
    );
    voidLog.add(result);
    return result;
  }

  @override
  Future<AppTransaction> recordPlannedPaymentOccurrence({
    required PlannedPayment payment,
    required double amount,
    required String accountId,
    required String categoryId,
    DateTime? date,
  }) async {
    final tx = AppTransaction(
      id: const Uuid().v4(),
      note: payment.title,
      amount: amount,
      type: payment.type,
      date: date ?? DateTime.now(),
      categoryId: categoryId,
      accountId: accountId,
      plannedPaymentId: payment.id,
    );
    _store[tx.id] = tx;
    return tx;
  }

  @override
  Future<AppTransaction?> recordDebtRepayment({
    required Debt debt,
    required DebtRepayment repayment,
    required String? categoryId,
  }) async {
    if (repayment.accountId != null && repayment.accountId!.isNotEmpty) {
      final isExpense = repayment.isIncrease
          ? debt.type == DebtType.owedToMe
          : debt.type == DebtType.iOwe;
      final tx = AppTransaction(
        id: const Uuid().v4(),
        amount: repayment.amount,
        date: repayment.date,
        type: isExpense ? TransactionType.expense : TransactionType.income,
        categoryId: categoryId ?? (isExpense ? 'cat_others' : 'cat_others_inc'),
        accountId: repayment.accountId!,
        note: repayment.isIncrease
            ? 'Debt increase: ${debt.personName}'
            : 'Debt settlement: ${debt.personName}',
        debtRepaymentId: repayment.id,
      );
      _store[tx.id] = tx;
      return tx;
    }
    return null;
  }
}

/// Riverpod provider exposing the Ledger seam to notifiers
final ledgerProvider = Provider<Ledger>((ref) {
  return SqliteLedgerAdapter();
});

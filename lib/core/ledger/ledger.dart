import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:koin/core/database_helper.dart';
import 'package:koin/core/models/models.dart';
import 'package:sqflite/sqflite.dart';

import 'transaction_rules.dart';
import 'savings_spending_approval.dart';

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

/// Represents the outcome of recording a transfer transaction,
/// including any associated fee transaction recorded atomically alongside it.
class TransferResult {
  final AppTransaction transferTransaction;
  final AppTransaction? feeTransaction;

  const TransferResult({
    required this.transferTransaction,
    this.feeTransaction,
  });

  bool get hasFee => feeTransaction != null;
}

/// Domain Seam: The interface through which transactions are recorded, queried, and voided.
/// Hides raw SQL persistence and encapsulates transaction cascade rules.
abstract class Ledger {
  Future<List<AppTransaction>> getTransactions();

  Future<TransactionPage> getTransactionPage({
    required TransactionFilter filter,
    required Map<String, String> categoryNamesById,
    TransactionCursor? after,
    int limit = 100,
  }) async => TransactionPage.fromTransactions(
    await getTransactions(),
    filter: filter,
    categoryNamesById: categoryNamesById,
    after: after,
    limit: limit,
  );

  Future<List<AppTransaction>> getTransactionFamily(String id) async =>
      (await getTransactions())
          .where((tx) => tx.id == id || tx.transferId == id)
          .toList();

  Future<AppTransaction> recordTransaction(AppTransaction transaction);

  Future<void> updateTransaction(AppTransaction transaction);

  Future<void> updateTransfer(AppTransaction transaction, AppTransaction? fee);

  Future<TransactionVoidResult> voidTransaction(String id);

  /// Atomically records a planned payment occurrence, advances the schedule to nextDate,
  /// and persists the corresponding financial transaction.
  Future<AppTransaction> recordPlannedPaymentOccurrence({
    required PlannedPayment payment,
    required double amount,
    required String accountId,
    required String categoryId,
    String? transactionId,
    DateTime? date,
    bool protectSavings = false,
  });

  /// Atomically records a debt repayment/increase, mutates the debt balance,
  /// and writes the corresponding financial transaction if an account was specified.
  Future<AppTransaction?> recordDebtRepayment({
    required Debt debt,
    required DebtRepayment repayment,
    required String? categoryId,
    String? transactionId,
  });

  /// Atomically records a transfer transaction between accounts, optionally creating a linked fee transaction.
  Future<TransferResult> recordTransfer({
    required AppTransaction transferTransaction,
    AppTransaction? feeTransaction,
  });

  /// Atomically voids a debt repayment or credit increase, reverting the debt balance mutation
  /// and deleting any associated financial transaction recorded in the ledger.
  Future<void> voidDebtRepayment(DebtRepayment repayment);
}

/// Production Adapter: Uses DatabaseHelper and SQLite under an atomic transaction.
class SqliteLedgerAdapter extends Ledger {
  String _scheduleKey(PlannedPayment payment) => jsonEncode([
    payment.startDate.toIso8601String(),
    payment.frequency.name,
    payment.recurrenceDay,
  ]);
  final DatabaseHelper _dbHelper;
  final SavingsSpendingApprovals? savingsApprovals;

  SqliteLedgerAdapter({DatabaseHelper? dbHelper, this.savingsApprovals})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  @override
  Future<List<AppTransaction>> getTransactions() async {
    return await _dbHelper.getTransactions();
  }

  @override
  Future<TransactionPage> getTransactionPage({
    required TransactionFilter filter,
    required Map<String, String> categoryNamesById,
    TransactionCursor? after,
    int limit = 100,
  }) => _dbHelper.getTransactionPage(
    filter: filter,
    categoryNamesById: categoryNamesById,
    after: after,
    limit: limit,
  );

  @override
  Future<List<AppTransaction>> getTransactionFamily(String id) async {
    final db = await _dbHelper.database;
    return (await db.query(
      'transactions',
      where: 'id = ? OR transferId = ?',
      whereArgs: [id, id],
    )).map(AppTransaction.fromMap).toList();
  }

  @override
  Future<AppTransaction> recordTransaction(AppTransaction transaction) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'transactions',
        where: 'id = ?',
        whereArgs: [transaction.id],
      );
      if (existing.isNotEmpty) return AppTransaction.fromMap(existing.single);
      await _validateMoney(
        txn,
        transaction.accountId,
        transaction.amount,
        transaction.type != TransactionType.income,
      );
      if (transaction.type != TransactionType.income) {
        await _releaseApprovedSavings(
          txn,
          transaction.id,
          transaction.accountId,
          transaction.amount,
        );
      }
      await txn.insert('transactions', transaction.toMap());
      return transaction;
    });
  }

  @override
  Future<void> updateTransaction(AppTransaction transaction) async {
    await _dbHelper.updateTransaction(
      transaction,
      validate: (txn) async {
        await _validateMoney(
          txn,
          transaction.accountId,
          transaction.amount,
          transaction.type != TransactionType.income,
          excluding: transaction.id,
        );
        if (transaction.type != TransactionType.income) {
          await _releaseApprovedSavings(
            txn,
            transaction.id,
            transaction.accountId,
            transaction.amount,
            excluding: transaction.id,
          );
        }
      },
    );
  }

  @override
  Future<void> updateTransfer(
    AppTransaction transaction,
    AppTransaction? fee,
  ) async {
    await _dbHelper.updateTransfer(
      transaction,
      fee,
      validate: (txn) async {
        await _validateMoney(
          txn,
          transaction.accountId,
          transaction.amount + (fee?.amount ?? 0),
          transaction.type != TransactionType.income,
          excluding: transaction.id,
        );
        if (transaction.type == TransactionType.transfer) {
          await _validateDestination(txn, transaction);
        }
        if (transaction.type != TransactionType.income) {
          await _releaseApprovedSavings(
            txn,
            transaction.id,
            transaction.accountId,
            transaction.amount + (fee?.amount ?? 0),
            excluding: transaction.id,
          );
        }
      },
    );
  }

  Future<void> _validateMoney(
    DatabaseExecutor db,
    String accountId,
    double amount,
    bool expense, {
    String? excluding,
    bool protectSavings = false,
  }) async {
    final accounts = (await db.query(
      'accounts',
      where: 'id = ?',
      whereArgs: [accountId],
    )).map(Account.fromMap).toList();
    final now = DateTime.now().toIso8601String();
    final totals = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(
        CASE WHEN accountId = ? THEN CASE WHEN type = 'income' THEN amount ELSE -amount END ELSE 0 END
        + CASE WHEN type = 'transfer' AND toAccountId = ? THEN amount ELSE 0 END
      ), 0) AS delta FROM transactions
      WHERE (accountId = ? OR toAccountId = ?) AND julianday(date) <= julianday(?)
      ${excluding == null ? '' : 'AND id != ? AND (transferId IS NULL OR transferId != ?)'}
    ''',
      [
        accountId,
        accountId,
        accountId,
        accountId,
        now,
        if (excluding != null) ...[excluding, excluding],
      ],
    );
    final delta = (totals.single['delta'] as num).toDouble();
    final adjusted = accounts
        .map((a) => a.copyWith(initialBalance: a.initialBalance + delta))
        .toList();
    TransactionRules.account(
      accountId: accountId,
      value: amount,
      isExpense: expense,
      accounts: adjusted,
      transactions: const [],
    );
    final account = accounts.firstWhere((a) => a.id == accountId);
    if (protectSavings && expense && !account.isCredit) {
      final goals = (await db.query(
        'savings_goals',
        where: 'linkedAccountId = ?',
        whereArgs: [accountId],
      )).map(SavingsGoal.fromMap);
      final reserved = goals
          .where((g) => g.linkedAccountId == accountId)
          .fold<double>(0, (sum, g) => sum + g.currentAmount);
      if (TransactionRules.exceedsBalance(
        amount,
        account.initialBalance + delta - reserved,
      )) {
        throw const FinancialValidationException(
          'Open this payment to review the savings needed.',
        );
      }
    }
  }

  Future<void> _validateDestination(
    DatabaseExecutor db,
    AppTransaction transaction,
  ) async {
    if (transaction.toAccountId == null ||
        transaction.toAccountId == transaction.accountId ||
        (await db.query(
          'accounts',
          where: 'id = ?',
          whereArgs: [transaction.toAccountId],
        )).isEmpty) {
      throw const FinancialValidationException(
        'Choose two different available accounts',
      );
    }
  }

  Future<void> _releaseApprovedSavings(
    DatabaseExecutor db,
    String id,
    String accountId,
    double debit, {
    String? excluding,
  }) async {
    final approval = savingsApprovals?[id];
    if (savingsApprovals == null) return;
    // Existing linked edits are reconciled by _syncSavingsRelease in this same
    // transaction, including restoration of their earlier releases.
    if ((await db.query(
      'savings_spending_links',
      where: 'transactionId = ?',
      whereArgs: [id],
    )).isNotEmpty) {
      return;
    }
    if (approval != null &&
        (approval.accountId != accountId ||
            approval.debitCents != (debit * 100).round())) {
      throw const FinancialValidationException(
        'Review the savings needed again',
      );
    }
    await _dbHelper.releaseSavingsForTransaction(
      db,
      transactionId: id,
      accountId: accountId,
      debit: debit,
      approvedGoalCents: approval?.goalCents ?? const {},
      excluding: excluding,
    );
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

          if (ppMaps.isNotEmpty &&
              !PlannedPayment.fromMap(ppMaps.first).isAutoProcess) {
            final payment = PlannedPayment.fromMap(ppMaps.first);
            final occurrences = await txn.query(
              'planned_payment_occurrences',
              where: 'transactionId = ?',
              whereArgs: [id],
            );
            // Reopen only the latest occurrence of the unchanged schedule.
            // Legacy entries have no reliable occurrence identity: deleting
            // those preserves the current schedule instead of guessing a date.
            if (occurrences.isNotEmpty) {
              final occurrence = occurrences.single;
              if (occurrence['paymentId'] == payment.id &&
                  occurrence['nextDate'] ==
                      payment.nextDate.toIso8601String() &&
                  occurrence['scheduleKey'] == _scheduleKey(payment)) {
                await txn.update(
                  'planned_payments',
                  {'nextDate': occurrence['dueDate']},
                  where: 'id = ?',
                  whereArgs: [payment.id],
                );
                rolledBackPlannedPaymentId = payment.id;
              }
            }
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
            await _dbHelper.validateDebtRepaymentRemoval(txn, repayment);
            affectedDebtId = repayment.debtId;

            await txn.delete(
              'debt_repayments',
              where: 'id = ?',
              whereArgs: [repayment.id],
            );

            await txn.execute(
              repayment.isIncrease
                  ? 'UPDATE debts SET amount = amount - ? WHERE id = ?'
                  : 'UPDATE debts SET currentAmount = currentAmount - ? WHERE id = ?',
              [repayment.amount, repayment.debtId],
            );
          }
        }
      }

      // 3. Delete the transaction record
      await txn.delete(
        'transactions',
        where: 'transferId = ?',
        whereArgs: [id],
      );
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
    String? transactionId,
    DateTime? date,
    bool protectSavings = false,
  }) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      final existing = transactionId == null
          ? <Map<String, Object?>>[]
          : await txn.query(
              'transactions',
              where: 'id = ?',
              whereArgs: [transactionId],
            );
      if (existing.isNotEmpty) return AppTransaction.fromMap(existing.single);
      final schedules = await txn.query(
        'planned_payments',
        where: 'id = ?',
        whereArgs: [payment.id],
      );
      if (schedules.isEmpty) {
        throw const FinancialValidationException(
          'This schedule is no longer available',
        );
      }
      final current = PlannedPayment.fromMap(schedules.single);
      if (current.nextDate != payment.nextDate) {
        throw const FinancialValidationException(
          'This payment was already processed. Refresh and try again.',
        );
      }
      if (!current.isEligible(date)) {
        throw const FinancialValidationException(
          'This schedule is not available on this date',
        );
      }
      await _validateMoney(
        txn,
        accountId,
        amount,
        current.type == TransactionType.expense,
        protectSavings: protectSavings,
      );
      final categories = await txn.query(
        'categories',
        where: 'id = ? AND type = ?',
        whereArgs: [categoryId, current.type.name],
      );
      if (categories.isEmpty) {
        throw const FinancialValidationException(
          'Choose an available category',
        );
      }
      final nextDate = current.computeNextDate();
      final updatedPayment = current.copyWith(nextDate: nextDate);
      await txn.update(
        'planned_payments',
        updatedPayment.toMap(),
        where: 'id = ?',
        whereArgs: [payment.id],
      );

      final transaction = AppTransaction(
        id: transactionId ?? const Uuid().v4(),
        note: current.title,
        amount: amount,
        type: current.type,
        date: date ?? DateTime.now(),
        categoryId: categoryId,
        accountId: accountId,
        plannedPaymentId: payment.id,
      );

      if (current.type == TransactionType.expense) {
        await _releaseApprovedSavings(txn, transaction.id, accountId, amount);
      }
      await txn.insert('transactions', transaction.toMap());
      await txn.insert('planned_payment_occurrences', {
        'transactionId': transaction.id,
        'paymentId': current.id,
        'dueDate': current.nextDate.toIso8601String(),
        'nextDate': nextDate.toIso8601String(),
        'scheduleKey': _scheduleKey(current),
      });
      return transaction;
    });
  }

  @override
  Future<AppTransaction?> recordDebtRepayment({
    required Debt debt,
    required DebtRepayment repayment,
    required String? categoryId,
    String? transactionId,
  }) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      TransactionRules.amount(repayment.amount);
      final saved = await txn.query(
        'debt_repayments',
        where: 'id = ?',
        whereArgs: [repayment.id],
      );
      if (saved.isNotEmpty) {
        final transactions = await txn.query(
          'transactions',
          where: 'debtRepaymentId = ?',
          whereArgs: [repayment.id],
        );
        return transactions.isEmpty
            ? null
            : AppTransaction.fromMap(transactions.single);
      }
      final debtRows = await txn.query(
        'debts',
        where: 'id = ?',
        whereArgs: [debt.id],
      );
      if (debtRows.isEmpty) {
        throw const FinancialValidationException(
          'This debt is no longer available',
        );
      }
      final currentDebt = Debt.fromMap(debtRows.single);
      if (!repayment.isIncrease &&
          (repayment.amount * 100).round() >
              (currentDebt.remainingAmount * 100).round()) {
        throw const FinancialValidationException(
          'You cannot pay more than the remaining debt',
        );
      }
      final expense = TransactionRules.debtIsExpense(
        currentDebt,
        isIncrease: repayment.isIncrease,
      );
      if (!repayment.isIncrease && repayment.accountId == null) {
        throw const FinancialValidationException(
          'Choose an account for this payment',
        );
      }
      if (repayment.accountId != null) {
        await _validateMoney(
          txn,
          repayment.accountId!,
          repayment.amount,
          expense,
        );
      }
      await txn.insert('debt_repayments', repayment.toMap());

      if (repayment.isIncrease) {
        await txn.execute('UPDATE debts SET amount = amount + ? WHERE id = ?', [
          repayment.amount,
          repayment.debtId,
        ]);
      } else {
        await txn.execute(
          'UPDATE debts SET currentAmount = currentAmount + ? WHERE id = ?',
          [repayment.amount, repayment.debtId],
        );
      }

      if (repayment.accountId != null && repayment.accountId!.isNotEmpty) {
        final isExpense = expense;

        final transaction = AppTransaction(
          id: transactionId ?? const Uuid().v4(),
          amount: repayment.amount,
          date: repayment.date,
          type: isExpense ? TransactionType.expense : TransactionType.income,
          categoryId:
              categoryId ?? (isExpense ? 'cat_others' : 'cat_others_inc'),
          accountId: repayment.accountId!,
          note: repayment.isIncrease
              ? 'Debt increase: ${debt.personName}'
              : (debt.type == DebtType.owedToMe
                    ? 'Payment from ${debt.personName}'
                    : 'Payment to ${debt.personName}'),
          debtRepaymentId: repayment.id,
          isDebtTransfer: currentDebt.type == DebtType.owedToMe,
        );

        if (isExpense) {
          await _releaseApprovedSavings(
            txn,
            transaction.id,
            repayment.accountId!,
            repayment.amount,
          );
        }
        await txn.insert('transactions', transaction.toMap());
        return transaction;
      }
      return null;
    });
  }

  @override
  Future<TransferResult> recordTransfer({
    required AppTransaction transferTransaction,
    AppTransaction? feeTransaction,
  }) async {
    final db = await _dbHelper.database;
    return await db.transaction((txn) async {
      await _validateMoney(
        txn,
        transferTransaction.accountId,
        transferTransaction.amount + (feeTransaction?.amount ?? 0),
        true,
      );
      await _validateDestination(txn, transferTransaction);
      await _releaseApprovedSavings(
        txn,
        transferTransaction.id,
        transferTransaction.accountId,
        transferTransaction.amount + (feeTransaction?.amount ?? 0),
      );
      await txn.insert('transactions', transferTransaction.toMap());
      if (feeTransaction != null) {
        await txn.insert(
          'transactions',
          feeTransaction.copyWith(transferId: transferTransaction.id).toMap(),
        );
      }
      return TransferResult(
        transferTransaction: transferTransaction,
        feeTransaction: feeTransaction,
      );
    });
  }

  @override
  Future<void> voidDebtRepayment(DebtRepayment repayment) async {
    final db = await _dbHelper.database;
    final transactions = await db.query(
      'transactions',
      columns: ['id'],
      where: 'debtRepaymentId = ?',
      whereArgs: [repayment.id],
    );
    if (transactions.isNotEmpty) {
      await voidTransaction(transactions.single['id'] as String);
    } else {
      await _dbHelper.deleteDebtRepayment(repayment);
    }
  }
}

/// In-Memory Test Adapter: Provides deterministic in-memory ledger operations for testing.
class InMemoryLedgerAdapter extends Ledger {
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
    final previous = _store[transaction.id];
    if (previous == null) return;
    _store[transaction.id] = transaction.copyWith(
      plannedPaymentId: previous.plannedPaymentId,
      debtRepaymentId: previous.debtRepaymentId,
      transferId: previous.transferId,
      isDebtTransfer: previous.isDebtTransfer,
    );
  }

  @override
  Future<void> updateTransfer(
    AppTransaction transaction,
    AppTransaction? fee,
  ) async {
    await updateTransaction(transaction);
    _store.removeWhere((_, tx) => tx.transferId == transaction.id);
    if (fee != null) _store[fee.id] = fee.copyWith(transferId: transaction.id);
  }

  @override
  Future<TransactionVoidResult> voidTransaction(String id) async {
    final tx = _store.remove(id);
    _store.removeWhere((_, tx) => tx.transferId == id);
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
    String? transactionId,
    DateTime? date,
    bool protectSavings = false,
  }) async {
    final tx = AppTransaction(
      id: transactionId ?? const Uuid().v4(),
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
    String? transactionId,
  }) async {
    if (repayment.accountId != null && repayment.accountId!.isNotEmpty) {
      final isExpense = repayment.isIncrease
          ? debt.type == DebtType.owedToMe
          : debt.type == DebtType.iOwe;
      final tx = AppTransaction(
        id: transactionId ?? const Uuid().v4(),
        amount: repayment.amount,
        date: repayment.date,
        type: isExpense ? TransactionType.expense : TransactionType.income,
        categoryId: categoryId ?? (isExpense ? 'cat_others' : 'cat_others_inc'),
        accountId: repayment.accountId!,
        note: repayment.isIncrease
            ? 'Debt increase: ${debt.personName}'
            : (debt.type == DebtType.owedToMe
                  ? 'Payment from ${debt.personName}'
                  : 'Payment to ${debt.personName}'),
        debtRepaymentId: repayment.id,
        isDebtTransfer: debt.type == DebtType.owedToMe,
      );
      _store[tx.id] = tx;
      return tx;
    }
    return null;
  }

  @override
  Future<TransferResult> recordTransfer({
    required AppTransaction transferTransaction,
    AppTransaction? feeTransaction,
  }) async {
    _store[transferTransaction.id] = transferTransaction;
    if (feeTransaction != null) {
      _store[feeTransaction.id] = feeTransaction.copyWith(
        transferId: transferTransaction.id,
      );
    }
    return TransferResult(
      transferTransaction: transferTransaction,
      feeTransaction: feeTransaction,
    );
  }

  @override
  Future<void> voidDebtRepayment(DebtRepayment repayment) async {
    _store.removeWhere((_, tx) => tx.debtRepaymentId == repayment.id);
  }
}

/// Riverpod provider exposing the Ledger seam to notifiers
final ledgerProvider = Provider<Ledger>((ref) {
  return SqliteLedgerAdapter(
    savingsApprovals: ref.read(savingsSpendingApprovalsProvider),
  );
});

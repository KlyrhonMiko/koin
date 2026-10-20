import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';

import '../database_helper.dart';
import '../models/models.dart';

/// Accrues completed days and posts at the chosen calendar payout boundary.
/// Cursor and uncredited accrual stay outside Account.toMap so account edits
/// cannot overwrite automatic processing progress.
class DailyInterestRepository {
  DailyInterestRepository({DatabaseHelper? dbHelper})
    : _dbHelper = dbHelper ?? DatabaseHelper.instance;

  final DatabaseHelper _dbHelper;

  Future<int> processDue({required DateTime now, int decimalDigits = 2}) async {
    final db = await _dbHelper.database;
    return db.transaction((txn) async {
      var count = 0;
      final today = DailyInterest.day(now);
      final rows = await txn.query('accounts', where: 'annualInterestRate > 0');
      for (final row in rows) {
        final account = Account.fromMap(row);
        if (!account.hasInterest) continue;
        final start = DailyInterest.day(account.interestStartDate!);
        var date = DateTime.tryParse(row['interestNextDate'] as String? ?? '');
        date = date == null || date.isBefore(start)
            ? start
            : DailyInterest.day(date);
        if (!date.isBefore(today)) continue;

        final transactions =
            (await txn.query(
                'transactions',
                where: 'accountId = ? OR toAccountId = ?',
                whereArgs: [account.id, account.id],
              )).map(AppTransaction.fromMap).toList()
              ..sort((a, b) => a.date.compareTo(b.date));
        final existingIds = transactions.map((t) => t.id).toSet();
        var balance = account.initialBalance;
        var accrued = (row['interestAccrued'] as num?)?.toDouble() ?? 0;
        var index = 0;
        while (date!.isBefore(today)) {
          final next = DailyInterest.nextDay(date);
          // All same-day movements, including transfer fees and incoming
          // transfers, affect the closing balance. Future transactions do not.
          while (index < transactions.length &&
              transactions[index].date.isBefore(next)) {
            final entry = transactions[index++];
            if (entry.accountId == account.id) {
              balance += entry.type == TransactionType.income
                  ? entry.amount
                  : -entry.amount;
            }
            if (entry.type == TransactionType.transfer &&
                entry.toAccountId == account.id) {
              balance += entry.amount;
            }
          }
          final id = DailyInterest.transactionId(account.id, date);
          accrued += DailyInterest.rawDailyInterest(
            balance: balance,
            annualRate: account.annualInterestRate,
            taxRate: account.interestTaxRate,
          );
          final payout = account.interestFrequency.paysOn(date);
          final amount = payout
              ? DailyInterest.round(accrued, decimalDigits: decimalDigits)
              : 0.0;
          if (amount > 0 && !existingIds.contains(id)) {
            await txn.insert(
              'categories',
              TransactionCategory(
                id: 'cat_interest',
                name: 'Interest',
                iconCodePoint: Icons.savings_rounded.codePoint,
                colorHex: '#00A884',
                type: TransactionType.income,
              ).toMap(),
              conflictAlgorithm: ConflictAlgorithm.ignore,
            );
            await txn.insert(
              'transactions',
              AppTransaction(
                id: id,
                note: '${account.interestFrequency.label} interest (estimated)',
                amount: amount,
                date: next.subtract(const Duration(milliseconds: 1)),
                type: TransactionType.income,
                categoryId: 'cat_interest',
                accountId: account.id,
              ).toMap(),
            );
            balance += amount;
            count++;
          }
          if (payout) accrued = 0;
          date = next;
        }
        await txn.update(
          'accounts',
          {
            'interestNextDate': date.toIso8601String(),
            'interestAccrued': accrued,
          },
          where: 'id = ?',
          whereArgs: [account.id],
        );
      }
      return count;
    });
  }
}

final dailyInterestRepositoryProvider = Provider<DailyInterestRepository>(
  (ref) => DailyInterestRepository(),
);

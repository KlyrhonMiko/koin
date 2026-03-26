import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/models/transaction.dart';

void main() {
  group('AppTransaction Model Tests', () {
    test('should create transaction with empty note by default', () {
      final tx = AppTransaction(
        id: '1',
        amount: 100.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        categoryId: 'cat_1',
        accountId: 'acc_1',
      );

      expect(tx.note, '');
    });

    test('should map note to title in toMap for DB compatibility', () {
      final tx = AppTransaction(
        id: '1',
        note: 'Test Note',
        amount: 100.0,
        date: DateTime.now(),
        type: TransactionType.expense,
        categoryId: 'cat_1',
        accountId: 'acc_1',
      );

      final map = tx.toMap();
      expect(map['title'], 'Test Note');
    });

    test('should map title from map to note in fromMap', () {
      final now = DateTime.now();
      final map = {
        'id': '1',
        'title': 'DB Title',
        'amount': 100.0,
        'date': now.toIso8601String(),
        'type': 'expense',
        'categoryId': 'cat_1',
        'accountId': 'acc_1',
      };

      final tx = AppTransaction.fromMap(map);
      expect(tx.note, 'DB Title');
    });

    test('should handle missing title in fromMap with empty string', () {
      final now = DateTime.now();
      final map = {
        'id': '1',
        'amount': 100.0,
        'date': now.toIso8601String(),
        'type': 'expense',
        'categoryId': 'cat_1',
        'accountId': 'acc_1',
      };

      final tx = AppTransaction.fromMap(map);
      expect(tx.note, '');
    });
  });
}

import '../models/transactions/transaction.dart';
import 'transaction_rules.dart';

abstract final class CashbackRules {
  static void validate(AppTransaction transaction) {
    if (transaction.cashbackRule != CashbackRule.none &&
        !transaction.canEarnCashback) {
      throw const FinancialValidationException(
        'Cashback applies to expenses and transfers only',
      );
    }
    final received = transaction.cashbackReceivedAt;
    if (transaction.cashbackPending &&
        (!transaction.canEarnCashback ||
            transaction.cashbackRule == CashbackRule.none ||
            received != null)) {
      throw const FinancialValidationException(
        'Pending cashback needs a cashback rule and cannot have a receipt date',
      );
    }
    if (received == null) return;
    final now = DateTime.now();
    final purchaseDay = DateTime(
      transaction.date.year,
      transaction.date.month,
      transaction.date.day,
    );
    if (transaction.expectedCashback <= 0 ||
        received.isBefore(purchaseDay) ||
        received.isAfter(now) ||
        transaction.date.isAfter(now)) {
      throw const FinancialValidationException(
        'Choose a cashback receipt date between the transaction date and today',
      );
    }
  }
}

import '../models/models.dart';

class FinancialValidationException implements Exception {
  const FinancialValidationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One authority for money direction, validity, and available account funds.
abstract final class TransactionRules {
  /// Compare the same rounded cents in previews and persisted validation.
  static bool exceedsBalance(double value, double available) =>
      !value.isFinite ||
      !available.isFinite ||
      (value * 100).round() > (available * 100).round();

  static void amount(double value) {
    if (!value.isFinite || value <= 0) {
      throw const FinancialValidationException(
        'Enter an amount greater than zero',
      );
    }
  }

  static bool debtIsExpense(Debt debt, {required bool isIncrease}) =>
      isIncrease ? debt.type == DebtType.owedToMe : debt.type == DebtType.iOwe;

  static double balance(
    Account account,
    Iterable<AppTransaction> transactions, {
    DateTime? at,
  }) {
    final now = at ?? DateTime.now();
    var result = account.initialBalance;
    for (final tx in transactions) {
      if (tx.date.isAfter(now)) continue;
      if (tx.accountId == account.id) {
        result += tx.type == TransactionType.income ? tx.amount : -tx.amount;
      }
      if (tx.type == TransactionType.transfer && tx.toAccountId == account.id) {
        result += tx.amount;
      }
    }
    return result;
  }

  static void account({
    required String accountId,
    required double value,
    required bool isExpense,
    required List<Account> accounts,
    required Iterable<AppTransaction> transactions,
    DateTime? at,
  }) {
    amount(value);
    final selected = accounts.where((a) => a.id == accountId).firstOrNull;
    if (selected == null) {
      throw const FinancialValidationException('Choose an available account');
    }
    if (isExpense &&
        !selected.isCredit &&
        exceedsBalance(value, balance(selected, transactions, at: at))) {
      throw FinancialValidationException(
        'Insufficient balance in ${selected.name}',
      );
    }
  }
}

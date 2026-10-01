import 'package:uuid/uuid.dart';
import 'package:koin/core/models/accounts/account.dart';
import 'package:koin/core/models/transactions/transaction.dart';

/// Validation failure result for transfer draft.
enum TransferDraftValidationError {
  missingRequiredFields,
  sameAccount,
  invalidAmount,
  feeExceedsAmount,
}

/// Deep Domain Module: Encapsulates transfer fee computation, validation rules,
/// and financial transaction fabrication for atomic transfers between accounts.
class TransferDraft {
  final String sourceAccountId;
  final String destinationAccountId;
  final double rawAmount;
  final double enteredFee;
  final bool isFeePercentage;
  final String note;
  final DateTime date;

  const TransferDraft({
    required this.sourceAccountId,
    required this.destinationAccountId,
    required this.rawAmount,
    this.enteredFee = 0.0,
    this.isFeePercentage = false,
    this.note = '',
    required this.date,
  });

  /// Validates the transfer draft against domain integrity rules.
  TransferDraftValidationError? validate() {
    if (sourceAccountId.isEmpty || destinationAccountId.isEmpty) {
      return TransferDraftValidationError.missingRequiredFields;
    }
    if (sourceAccountId == destinationAccountId) {
      return TransferDraftValidationError.sameAccount;
    }
    if (rawAmount <= 0) {
      return TransferDraftValidationError.invalidAmount;
    }
    if (calculateFeeAmount() >= rawAmount) {
      return TransferDraftValidationError.feeExceedsAmount;
    }
    return null;
  }

  /// Calculates the resolved fee amount given the optional source account fee rules.
  double calculateFeeAmount([Account? sourceAccount]) {
    if (enteredFee <= 0) return 0.0;
    if (sourceAccount != null) {
      return sourceAccount.calculateTransferFee(
        rawAmount,
        enteredFee,
        isFeePercentage,
      );
    }
    if (isFeePercentage) {
      return rawAmount * (enteredFee / 100.0);
    }
    return enteredFee;
  }

  /// Calculates the net transfer amount after deducting the fee.
  double calculateNetAmount([Account? sourceAccount]) {
    final fee = calculateFeeAmount(sourceAccount);
    return rawAmount - fee;
  }

  /// Builds the transfer transaction and optional fee transaction.
  ({AppTransaction transferTransaction, AppTransaction? feeTransaction})
      buildTransactions({
    String? existingId,
    Account? sourceAccount,
  }) {
    final feeAmount = calculateFeeAmount(sourceAccount);
    final netAmount = rawAmount - feeAmount;

    final transferTx = AppTransaction(
      id: existingId ?? const Uuid().v4(),
      note: note,
      amount: netAmount,
      date: date,
      type: TransactionType.transfer,
      categoryId: 'cat_others',
      accountId: sourceAccountId,
      toAccountId: destinationAccountId,
    );

    AppTransaction? feeTx;
    if (feeAmount > 0) {
      feeTx = AppTransaction(
        id: const Uuid().v4(),
        note: note.isNotEmpty ? 'Transfer Fee: $note' : 'Transfer Fee',
        amount: feeAmount,
        date: date,
        type: TransactionType.expense,
        categoryId: 'cat_others',
        accountId: sourceAccountId,
      );
    }

    return (transferTransaction: transferTx, feeTransaction: feeTx);
  }
}

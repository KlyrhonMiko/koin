enum TransactionType { income, expense, transfer }

enum CashbackRule {
  none,
  onePercent,
  fixedFive;

  double calculate(double amount) {
    if (!amount.isFinite || amount <= 0) return 0;
    return switch (this) {
      none => 0,
      // Round the percentage to centavos, including amounts below one peso.
      onePercent => (((amount * 100).round() + 50) ~/ 100) / 100,
      fixedFive => 5,
    };
  }
}

class AppTransaction {
  final String id;
  final String note;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final String? toAccountId;
  final String? plannedPaymentId;
  final String? debtRepaymentId;
  final String? transferId;
  final CashbackRule cashbackRule;
  final DateTime? cashbackReceivedAt;
  final String? cashbackSourceId;

  bool get canEarnCashback =>
      type != TransactionType.income &&
      !isDebtTransfer &&
      transferId == null &&
      cashbackSourceId == null;

  double get expectedCashback =>
      canEarnCashback ? cashbackRule.calculate(amount) : 0;

  /// Selecting cashback records a linked income entry with the transaction.
  AppTransaction? get cashbackCredit => expectedCashback > 0
      ? AppTransaction(
          id: 'cashback:$id',
          note: note.isEmpty ? 'Cashback' : 'Cashback: $note',
          amount: expectedCashback,
          // Preserve receipt dates from older records; new credits use the expense date.
          date: cashbackReceivedAt ?? date,
          type: TransactionType.income,
          categoryId: 'cat_cashback',
          accountId: accountId,
          cashbackSourceId: id,
        )
      : null;

  /// Loan principal changes cash without counting as income or spending.
  final bool isDebtTransfer;

  bool get countsAsIncome => type == TransactionType.income && !isDebtTransfer;
  bool get countsAsExpense =>
      type == TransactionType.expense && !isDebtTransfer;

  AppTransaction({
    required this.id,
    this.note = '',
    required this.amount,
    required this.date,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
    this.plannedPaymentId,
    this.debtRepaymentId,
    this.transferId,
    this.cashbackRule = CashbackRule.none,
    this.cashbackReceivedAt,
    this.cashbackSourceId,
    this.isDebtTransfer = false,
  });

  AppTransaction copyWith({
    String? id,
    String? note,
    double? amount,
    DateTime? date,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    String? toAccountId,
    String? plannedPaymentId,
    String? debtRepaymentId,
    String? transferId,
    CashbackRule? cashbackRule,
    DateTime? Function()? cashbackReceivedAt,
    String? cashbackSourceId,
    bool? isDebtTransfer,
  }) {
    return AppTransaction(
      id: id ?? this.id,
      note: note ?? this.note,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      toAccountId: toAccountId ?? this.toAccountId,
      plannedPaymentId: plannedPaymentId ?? this.plannedPaymentId,
      debtRepaymentId: debtRepaymentId ?? this.debtRepaymentId,
      transferId: transferId ?? this.transferId,
      cashbackRule: cashbackRule ?? this.cashbackRule,
      cashbackReceivedAt: cashbackReceivedAt != null
          ? cashbackReceivedAt()
          : this.cashbackReceivedAt,
      cashbackSourceId: cashbackSourceId ?? this.cashbackSourceId,
      isDebtTransfer: isDebtTransfer ?? this.isDebtTransfer,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': note, // Keeping 'title' for DB compatibility
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
      'categoryId': categoryId,
      'accountId': accountId,
      'toAccountId': toAccountId,
      'plannedPaymentId': plannedPaymentId,
      'debtRepaymentId': debtRepaymentId,
      'transferId': transferId,
      'cashbackRule': cashbackRule.name,
      'cashbackReceivedAt': cashbackReceivedAt?.toIso8601String(),
      'cashbackSourceId': cashbackSourceId,
      'isDebtTransfer': isDebtTransfer ? 1 : 0,
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
    return AppTransaction(
      id: map['id'],
      note: map['title'] ?? '', // Mapping 'title' from DB to 'note'
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      type: TransactionType.values.byName(map['type']),
      categoryId: map['categoryId'] ?? '',
      accountId: map['accountId'] ?? '',
      toAccountId: map['toAccountId'],
      plannedPaymentId: map['plannedPaymentId'],
      debtRepaymentId: map['debtRepaymentId'],
      transferId: map['transferId'],
      cashbackRule: CashbackRule.values.byName(map['cashbackRule'] ?? 'none'),
      cashbackReceivedAt: map['cashbackReceivedAt'] == null
          ? null
          : DateTime.parse(map['cashbackReceivedAt']),
      cashbackSourceId: map['cashbackSourceId'],
      isDebtTransfer: map['isDebtTransfer'] == 1,
    );
  }
}

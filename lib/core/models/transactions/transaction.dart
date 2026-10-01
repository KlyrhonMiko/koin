enum TransactionType { income, expense, transfer }

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
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
    return AppTransaction(
      id: map['id'],
      note: map['title'] ?? '', // Mapping 'title' from DB to 'note'
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      type: TransactionType.values.byName(map['type']),
      categoryId: map['categoryId'],
      accountId: map['accountId'] ?? 'default_account',
      toAccountId: map['toAccountId'],
      plannedPaymentId: map['plannedPaymentId'],
      debtRepaymentId: map['debtRepaymentId'],
    );
  }
}

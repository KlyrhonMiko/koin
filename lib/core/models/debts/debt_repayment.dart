class DebtRepayment {
  final String id;
  final String debtId;
  final double amount;
  final DateTime date;
  final String? note;
  final String? accountId; // Which account handled this transaction
  final bool isIncrease;

  DebtRepayment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.date,
    this.note,
    this.accountId,
    this.isIncrease = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debtId': debtId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'accountId': accountId,
      'isIncrease': isIncrease ? 1 : 0,
    };
  }

  factory DebtRepayment.fromMap(Map<String, dynamic> map) {
    return DebtRepayment(
      id: map['id'],
      debtId: map['debtId'],
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date']),
      note: map['note'],
      accountId: map['accountId'],
      isIncrease: map['isIncrease'] == 1,
    );
  }
}

class SavingsLog {
  final String id;
  final String goalId;
  final double amount;
  final DateTime date;
  final String? note;

  SavingsLog({
    required this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'goalId': goalId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
    };
  }

  factory SavingsLog.fromMap(Map<String, dynamic> map) {
    return SavingsLog(
      id: map['id'],
      goalId: map['goalId'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      note: map['note'],
    );
  }
}

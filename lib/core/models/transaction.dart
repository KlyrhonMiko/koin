enum TransactionType { income, expense, transfer }

class AppTransaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final String? toAccountId;

  AppTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.type,
    required this.categoryId,
    required this.accountId,
    this.toAccountId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'type': type.name,
      'categoryId': categoryId,
      'accountId': accountId,
      'toAccountId': toAccountId,
    };
  }

  factory AppTransaction.fromMap(Map<String, dynamic> map) {
    return AppTransaction(
      id: map['id'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      type: TransactionType.values.byName(map['type']),
      categoryId: map['categoryId'],
      accountId: map['accountId'] ?? 'default_account',
      toAccountId: map['toAccountId'],
    );
  }
}

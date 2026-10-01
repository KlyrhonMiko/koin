class DebtItem {
  final String id;
  final String debtId;
  final String name;
  final double amount;
  final int totalInstallments;
  final DateTime firstPaymentDate;
  final String? categoryId;

  DebtItem({
    required this.id,
    required this.debtId,
    required this.name,
    required this.amount,
    required this.totalInstallments,
    required this.firstPaymentDate,
    this.categoryId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'debtId': debtId,
      'name': name,
      'amount': amount,
      'totalInstallments': totalInstallments,
      'firstPaymentDate': firstPaymentDate.toIso8601String(),
      'categoryId': categoryId,
    };
  }

  factory DebtItem.fromMap(Map<String, dynamic> map) {
    return DebtItem(
      id: map['id'],
      debtId: map['debtId'],
      name: map['name'],
      amount: (map['amount'] as num).toDouble(),
      totalInstallments: map['totalInstallments'],
      firstPaymentDate: DateTime.parse(map['firstPaymentDate']),
      categoryId: map['categoryId'],
    );
  }

  DebtItem copyWith({
    String? id,
    String? debtId,
    String? name,
    double? amount,
    int? totalInstallments,
    DateTime? firstPaymentDate,
    String? categoryId,
  }) {
    return DebtItem(
      id: id ?? this.id,
      debtId: debtId ?? this.debtId,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      firstPaymentDate: firstPaymentDate ?? this.firstPaymentDate,
      categoryId: categoryId ?? this.categoryId,
    );
  }

  double get perInstallmentAmount =>
      totalInstallments > 0 ? amount / totalInstallments : amount;
}

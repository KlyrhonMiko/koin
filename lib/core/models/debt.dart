enum InstallmentFrequency { weekly, biweekly, monthly, yearly }

enum DebtType { owedToMe, iOwe }

class Debt {
  final String id;
  final String personName;
  final String? description;
  final double amount;
  final DebtType type;
  final DateTime startDate;
  final DateTime? dueDate;
  final int totalInstallments;
  final InstallmentFrequency frequency;
  final String? accountId; // If initially funded/received from an account
  final String? categoryId; // Connected category for transactions
  final double currentAmount; // Derived from repayments and initial amount
  final int sortOrder; // Added for custom reordering

  Debt({
    required this.id,
    required this.personName,
    this.description,
    required this.amount,
    required this.type,
    required this.startDate,
    this.dueDate,
    this.totalInstallments = 0,
    this.frequency = InstallmentFrequency.monthly,
    this.accountId,
    this.categoryId,
    this.currentAmount = 0.0,
    this.sortOrder = 0,
  });

  Debt copyWith({
    String? id,
    String? personName,
    String? description,
    double? amount,
    DebtType? type,
    DateTime? startDate,
    DateTime? dueDate,
    int? totalInstallments,
    InstallmentFrequency? frequency,
    String? accountId,
    String? categoryId,
    double? currentAmount,
    int? sortOrder,
  }) {
    return Debt(
      id: id ?? this.id,
      personName: personName ?? this.personName,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      startDate: startDate ?? this.startDate,
      dueDate: dueDate ?? this.dueDate,
      totalInstallments: totalInstallments ?? this.totalInstallments,
      frequency: frequency ?? this.frequency,
      accountId: accountId ?? this.accountId,
      categoryId: categoryId ?? this.categoryId,
      currentAmount: currentAmount ?? this.currentAmount,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'personName': personName,
      'description': description,
      'amount': amount,
      'type': type.name,
      'startDate': startDate.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'totalInstallments': totalInstallments,
      'frequency': frequency.name,
      'accountId': accountId,
      'categoryId': categoryId,
      'currentAmount': currentAmount,
      'sortOrder': sortOrder,
    };
  }

  factory Debt.fromMap(Map<String, dynamic> map) {
    return Debt(
      id: map['id'],
      personName: map['personName'],
      description: map['description'],
      amount: (map['amount'] as num).toDouble(),
      type: DebtType.values.byName(map['type']),
      startDate: DateTime.parse(map['startDate']),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      totalInstallments: map['totalInstallments'] ?? 0,
      frequency: map['frequency'] != null
          ? InstallmentFrequency.values.byName(map['frequency'])
          : InstallmentFrequency.monthly,
      accountId: map['accountId'],
      categoryId: map['categoryId'],
      currentAmount: map['currentAmount'] != null
          ? (map['currentAmount'] as num).toDouble()
          : 0.0,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }
}

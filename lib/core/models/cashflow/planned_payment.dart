import 'package:koin/core/models/models.dart';

enum PaymentFrequency {
  flexible,
  daily,
  weekly,
  biWeekly,
  monthly,
  quarterly,
  yearly,
}

class PlannedPayment {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String categoryId;
  final String accountId;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime nextDate;
  final PaymentFrequency frequency;
  final String? notes;
  final bool isAutoProcess;

  PlannedPayment({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.accountId,
    required this.startDate,
    this.endDate,
    required this.nextDate,
    required this.frequency,
    this.notes,
    this.isAutoProcess = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'categoryId': categoryId,
      'accountId': accountId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'nextDate': nextDate.toIso8601String(),
      'frequency': frequency.name,
      'notes': notes,
      'isAutoProcess': isAutoProcess ? 1 : 0,
    };
  }

  factory PlannedPayment.fromMap(Map<String, dynamic> map) {
    return PlannedPayment(
      id: map['id'],
      title: map['title'],
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.byName(map['type']),
      categoryId: map['categoryId'],
      accountId: map['accountId'],
      startDate: DateTime.parse(map['startDate']),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      nextDate: DateTime.parse(map['nextDate']),
      frequency: PaymentFrequency.values.byName(map['frequency']),
      notes: map['notes'],
      isAutoProcess: map['isAutoProcess'] == 1,
    );
  }

  /// Calculates the previous due date when an auto-processed or linked transaction is rolled back.
  DateTime computePreviousDate() {
    DateTime prevDate = nextDate;
    switch (frequency) {
      case PaymentFrequency.daily:
        return prevDate.subtract(const Duration(days: 1));
      case PaymentFrequency.weekly:
        return prevDate.subtract(const Duration(days: 7));
      case PaymentFrequency.biWeekly:
        return prevDate.subtract(const Duration(days: 14));
      case PaymentFrequency.monthly:
        return DateTime(prevDate.year, prevDate.month - 1, prevDate.day);
      case PaymentFrequency.quarterly:
        return DateTime(prevDate.year, prevDate.month - 3, prevDate.day);
      case PaymentFrequency.yearly:
        return DateTime(prevDate.year - 1, prevDate.month, prevDate.day);
      case PaymentFrequency.flexible:
        return prevDate;
    }
  }

  /// Calculates the forward due date based on recurrence frequency.
  DateTime computeNextDate([DateTime? fromDate]) {
    final base = fromDate ?? nextDate;
    switch (frequency) {
      case PaymentFrequency.daily:
        return base.add(const Duration(days: 1));
      case PaymentFrequency.weekly:
        return base.add(const Duration(days: 7));
      case PaymentFrequency.biWeekly:
        return base.add(const Duration(days: 14));
      case PaymentFrequency.monthly:
        return DateTime(base.year, base.month + 1, base.day);
      case PaymentFrequency.quarterly:
        return DateTime(base.year, base.month + 3, base.day);
      case PaymentFrequency.yearly:
        return DateTime(base.year + 1, base.month, base.day);
      case PaymentFrequency.flexible:
        return base;
    }
  }

  PlannedPayment copyWith({
    String? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? categoryId,
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? nextDate,
    PaymentFrequency? frequency,
    String? notes,
    bool? isAutoProcess,
  }) {
    return PlannedPayment(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      nextDate: nextDate ?? this.nextDate,
      frequency: frequency ?? this.frequency,
      notes: notes ?? this.notes,
      isAutoProcess: isAutoProcess ?? this.isAutoProcess,
    );
  }
}

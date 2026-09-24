import 'package:koin/core/models/transaction.dart';

enum PaymentFrequency { flexible, daily, weekly, biWeekly, monthly, quarterly, yearly }

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
}

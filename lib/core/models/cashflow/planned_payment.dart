import 'package:koin/core/models/models.dart';
import 'package:intl/intl.dart';

enum PaymentFrequency {
  flexible,
  daily,
  weekly,
  biWeekly,
  monthly,
  quarterly,
  yearly;

  String get label => switch (this) {
    flexible => 'Flexible',
    daily => 'Daily',
    weekly => 'Weekly',
    biWeekly => 'Every two weeks',
    monthly => 'Monthly',
    quarterly => 'Quarterly',
    yearly => 'Yearly',
  };
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
  final int recurrenceDay;

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
    int? recurrenceDay,
  }) : recurrenceDay = recurrenceDay ?? nextDate.day;

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
      'recurrenceDay': recurrenceDay,
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
      recurrenceDay: map['recurrenceDay'] as int? ?? _legacyAnchor(map),
    );
  }

  /// Calculates the previous due date when an auto-processed or linked transaction is rolled back.
  DateTime _calendarShift(DateTime date, int months) {
    final month = DateTime(date.year, date.month + months);
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, recurrenceDay.clamp(1, lastDay));
  }

  static int _legacyAnchor(Map<String, dynamic> map) {
    final next = DateTime.parse(map['nextDate']);
    final start = DateTime.parse(map['startDate']);
    final last = DateTime(next.year, next.month + 1, 0).day;
    return next.day == last && start.day > next.day ? start.day : next.day;
  }

  bool isEligible([DateTime? at]) {
    final reference = at ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = endDate == null
        ? null
        : DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !today.isBefore(start) && (end == null || !today.isAfter(end));
  }

  String availabilityLabel([DateTime? at]) {
    final reference = at ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (today.isBefore(start)) {
      return 'Available from ${DateFormat.yMMMd().format(start)}';
    }
    if (!isEligible(reference) && canProcess(reference)) {
      return 'Overdue · ${DateFormat.yMMMd().format(nextDate)}';
    }
    if (!isEligible(reference)) {
      return 'Ended ${DateFormat.yMMMd().format(endDate!)}';
    }
    return frequency == PaymentFrequency.flexible
        ? 'Available anytime'
        : DateFormat.yMMMd().format(nextDate);
  }

  /// Ending recurrence does not settle an unpaid occurrence already due.
  bool canProcess([DateTime? at]) {
    final reference = at ?? DateTime.now();
    return isEligible(reference) ||
        (frequency != PaymentFrequency.flexible &&
            isEligible(nextDate) &&
            daysUntilNext(reference) <= 0);
  }

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
        return _calendarShift(prevDate, -1);
      case PaymentFrequency.quarterly:
        return _calendarShift(prevDate, -3);
      case PaymentFrequency.yearly:
        return _calendarShift(prevDate, -12);
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
        return _calendarShift(base, 1);
      case PaymentFrequency.quarterly:
        return _calendarShift(base, 3);
      case PaymentFrequency.yearly:
        return _calendarShift(base, 12);
      case PaymentFrequency.flexible:
        return base;
    }
  }

  /// Returns the number of days until the payment's next due date relative to [now].
  int daysUntilNext([DateTime? now]) {
    final ref = now ?? DateTime.now();
    return DateTime(
      nextDate.year,
      nextDate.month,
      nextDate.day,
    ).difference(DateTime(ref.year, ref.month, ref.day)).inDays;
  }

  /// Whether this recurring commitment is overdue relative to [now].
  bool isOverdue([DateTime? now]) =>
      frequency != PaymentFrequency.flexible && daysUntilNext(now) < 0;

  /// Whether this recurring commitment is due today relative to [now].
  bool isDueToday([DateTime? now]) =>
      frequency != PaymentFrequency.flexible && daysUntilNext(now) == 0;

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
    int? recurrenceDay,
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
      recurrenceDay: recurrenceDay ?? this.recurrenceDay,
    );
  }
}

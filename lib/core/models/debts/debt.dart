import 'debt_item.dart';

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
  final List<DebtItem> items;

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
    this.items = const [],
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
    List<DebtItem>? items,
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
      items: items ?? this.items,
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

  double get remainingAmount => (amount - currentAmount).clamp(0.0, amount);

  double get progress =>
      amount <= 0.0 ? 1.0 : (currentAmount / amount).clamp(0.0, 1.0);

  bool get isSettled => progress >= 1.0;

  double get totalItemizedAmount =>
      items.fold(0.0, (sum, item) => sum + item.amount);

  double get perInstallmentAmount =>
      totalInstallments > 0 ? amount / totalInstallments : amount;

  int get paidInstallmentsCount => perInstallmentAmount > 0
      ? (currentAmount / perInstallmentAmount).floor()
      : 0;

  int get remainingInstallmentsCount =>
      (totalInstallments - paidInstallmentsCount).clamp(0, totalInstallments);

  DateTime _advanceDate(
    DateTime date,
    InstallmentFrequency frequency,
    DateTime originalDate,
  ) {
    switch (frequency) {
      case InstallmentFrequency.weekly:
        return date.add(const Duration(days: 7));
      case InstallmentFrequency.biweekly:
        return date.add(const Duration(days: 14));
      case InstallmentFrequency.monthly:
        int newYear = date.year;
        int newMonth = date.month + 1;
        if (newMonth > 12) {
          newYear += (newMonth - 1) ~/ 12;
          newMonth = ((newMonth - 1) % 12) + 1;
        }
        final daysInNewMonth = DateTime(newYear, newMonth + 1, 0).day;
        final newDay = originalDate.day > daysInNewMonth
            ? daysInNewMonth
            : originalDate.day;
        return DateTime(newYear, newMonth, newDay);
      case InstallmentFrequency.yearly:
        final isLeapDay = originalDate.month == 2 && originalDate.day == 29;
        final targetYear = date.year + 1;
        final isTargetLeapYear =
            (targetYear % 4 == 0 && targetYear % 100 != 0) ||
            (targetYear % 400 == 0);
        final newDay = (isLeapDay && !isTargetLeapYear) ? 28 : originalDate.day;
        return DateTime(targetYear, originalDate.month, newDay);
    }
  }

  Map<DateTime, double> get _installmentSchedule {
    final Map<DateTime, double> groups = {};
    for (var item in items) {
      if (item.totalInstallments > 0) {
        final installmentAmount = item.amount / item.totalInstallments;
        DateTime nextDate = item.firstPaymentDate;
        for (int i = 0; i < item.totalInstallments; i++) {
          final dateKey = DateTime(nextDate.year, nextDate.month, nextDate.day);
          groups[dateKey] = (groups[dateKey] ?? 0.0) + installmentAmount;
          nextDate = _advanceDate(nextDate, frequency, item.firstPaymentDate);
        }
      } else {
        final dateKey = DateTime(
          item.firstPaymentDate.year,
          item.firstPaymentDate.month,
          item.firstPaymentDate.day,
        );
        groups[dateKey] = (groups[dateKey] ?? 0.0) + item.amount;
      }
    }
    return groups;
  }

  double get upcomingPaymentAmount {
    if (items.isNotEmpty) {
      final schedule = _installmentSchedule;
      final sortedDates = schedule.keys.toList()..sort();
      double remainingPaid = currentAmount;

      for (var date in sortedDates) {
        final amount = schedule[date]!;
        if (remainingPaid >= amount) {
          remainingPaid -= amount;
        } else {
          return amount - remainingPaid;
        }
      }
      return 0.0;
    }

    if (totalInstallments > 0) {
      final perInstallment = amount / totalInstallments;
      final unpaidCurrent = remainingAmount % perInstallment;
      if (unpaidCurrent > 0) return unpaidCurrent;
      return remainingAmount < perInstallment
          ? remainingAmount
          : perInstallment;
    }
    return remainingAmount;
  }

  DateTime get nextDueDate {
    if (dueDate != null) return dueDate!;
    if (items.isNotEmpty) {
      final schedule = _installmentSchedule;
      final sortedDates = schedule.keys.toList()..sort();
      double remainingPaid = currentAmount;

      for (var date in sortedDates) {
        final amount = schedule[date]!;
        if (remainingPaid >= amount) {
          remainingPaid -= amount;
        } else {
          return date;
        }
      }
      if (sortedDates.isNotEmpty) return sortedDates.last;
      return startDate;
    }

    if (totalInstallments <= 0) return startDate;

    final singleInstallment = amount / totalInstallments;
    final installmentsPaid = singleInstallment > 0
        ? (currentAmount / singleInstallment).floor()
        : 0;

    DateTime next = startDate;
    for (int i = 0; i < installmentsPaid; i++) {
      next = _advanceDate(next, frequency, startDate);
    }
    return next;
  }

  /// Resolves the effective next due date, preferring explicitly assigned [dueDate]
  /// or installment-derived [nextDueDate] when installments are configured.
  DateTime? get resolvedDueDate =>
      dueDate ?? (totalInstallments > 0 ? nextDueDate : null);

  /// Number of days until the debt obligation is due relative to [now].
  int? daysUntilDue([DateTime? now]) {
    final due = resolvedDueDate;
    if (due == null) return null;
    final ref = now ?? DateTime.now();
    return DateTime(
      due.year,
      due.month,
      due.day,
    ).difference(DateTime(ref.year, ref.month, ref.day)).inDays;
  }

  /// Whether this unsettled debt has passed its due date relative to [now].
  bool isOverdue([DateTime? now]) {
    if (isSettled) return false;
    final diff = daysUntilDue(now);
    return diff != null && diff < 0;
  }
}

import 'debt_item.dart';
import 'installment_amounts.dart';

class DebtInstallment {
  const DebtInstallment({
    required this.date,
    required this.amount,
    this.itemId,
  });
  final DateTime date;
  final double amount;
  final String? itemId;
}

enum InstallmentFrequency {
  weekly,
  biweekly,
  monthly,
  yearly;

  String get label => switch (this) {
    weekly => 'Weekly',
    biweekly => 'Every two weeks',
    monthly => 'Monthly',
    yearly => 'Yearly',
  };
}

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
  final bool isPurchaseAccount;

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
    this.isPurchaseAccount = false,
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
    bool? isPurchaseAccount,
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
      isPurchaseAccount: isPurchaseAccount ?? this.isPurchaseAccount,
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
      'isPurchaseAccount': isPurchaseAccount ? 1 : 0,
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
      isPurchaseAccount: map['isPurchaseAccount'] == 1,
    );
  }

  double get remainingAmount => (amount - currentAmount).clamp(0.0, amount);

  double get progress =>
      amount <= 0.0 ? 1.0 : (currentAmount / amount).clamp(0.0, 1.0);

  bool get isSettled => progress >= 1.0;

  double get totalItemizedAmount =>
      items.fold(0.0, (sum, item) => sum + item.amount);

  bool get isMonthlyPurchaseAccount =>
      isPurchaseAccount && frequency == InstallmentFrequency.monthly;

  /// Keep the provider's due day even when a short month clamps it.
  DateTime monthlyBillDate(int year, int month) => DateTime(
    year,
    month,
    startDate.day.clamp(1, DateTime(year, month + 1, 0).day),
  );

  DateTime get nextPurchaseBillDate {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var next = monthlyBillDate(now.year, now.month);
    if (next.isBefore(today)) next = monthlyBillDate(now.year, now.month + 1);
    return next;
  }

  double get perInstallmentAmount =>
      InstallmentAmounts.at(amount, totalInstallments, 0);

  int get paidInstallmentsCount => paidInstallments();

  int paidInstallments({int decimalDigits = 2}) {
    if (totalInstallments <= 0) return 0;
    final paid = InstallmentAmounts.units(currentAmount, decimalDigits);
    final total = InstallmentAmounts.units(amount, decimalDigits);
    if (paid >= total) return totalInstallments;
    final base = total ~/ totalInstallments;
    return base == 0
        ? totalInstallments - 1
        : (paid ~/ base).clamp(0, totalInstallments - 1);
  }

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

  List<DebtInstallment> installmentSchedule({int decimalDigits = 2}) {
    final result = <DebtInstallment>[];
    if (items.isEmpty) {
      var date = startDate;
      final count = totalInstallments > 0 ? totalInstallments : 1;
      for (var i = 0; i < count; i++) {
        result.add(
          DebtInstallment(
            date: date,
            amount: InstallmentAmounts.at(
              amount,
              count,
              i,
              digits: decimalDigits,
            ),
          ),
        );
        date = _advanceDate(date, frequency, startDate);
      }
    } else {
      for (final item in items) {
        var date = item.firstPaymentDate;
        final count = item.totalInstallments > 0 ? item.totalInstallments : 1;
        for (var i = 0; i < count; i++) {
          result.add(
            DebtInstallment(
              date: date,
              itemId: item.id,
              amount: item.installmentAmountAt(i, decimalDigits: decimalDigits),
            ),
          );
          date = isMonthlyPurchaseAccount
              ? monthlyBillDate(date.year, date.month + 1)
              : _advanceDate(date, frequency, item.firstPaymentDate);
        }
      }
    }
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  Map<DateTime, double> remainingSchedule({int decimalDigits = 2}) {
    final Map<DateTime, double> groups = {};
    final scale = InstallmentAmounts.units(1, decimalDigits);
    var paid = InstallmentAmounts.units(currentAmount, decimalDigits);
    DateTime? overriddenDate;
    for (final event in installmentSchedule(decimalDigits: decimalDigits)) {
      final units = InstallmentAmounts.units(event.amount, decimalDigits);
      if (paid >= units) {
        paid -= units;
        continue;
      }
      final date = items.isEmpty && dueDate != null
          ? overriddenDate ?? dueDate!
          : event.date;
      final key = DateTime(date.year, date.month, date.day);
      groups[key] = (groups[key] ?? 0) + (units - paid) / scale;
      paid = 0;
      if (items.isEmpty && dueDate != null) {
        overriddenDate = _advanceDate(date, frequency, dueDate!);
      }
    }
    return groups;
  }

  double get upcomingPaymentAmount => upcomingPayment();

  double upcomingPayment({int decimalDigits = 2}) {
    final remaining = remainingSchedule(decimalDigits: decimalDigits);
    return remaining.isEmpty ? 0 : remaining.values.first;
  }

  DateTime get nextDueDate => nextPaymentDate();

  DateTime nextPaymentDate({int decimalDigits = 2}) {
    final remaining = remainingSchedule(decimalDigits: decimalDigits);
    if (remaining.isNotEmpty) return remaining.keys.first;
    final full = installmentSchedule(decimalDigits: decimalDigits);
    return dueDate ?? (full.isEmpty ? startDate : full.last.date);
  }

  /// Resolves the effective next due date, preferring explicitly assigned [dueDate]
  /// or installment-derived [nextDueDate] when installments are configured.
  DateTime? get resolvedDueDate =>
      dueDate ??
      (totalInstallments > 0 || items.isNotEmpty ? nextDueDate : null);

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

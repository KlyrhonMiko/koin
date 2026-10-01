import 'package:koin/core/models/models.dart';

enum UpcomingEntryKind { plannedPayment, debtInstallment }

/// Unified domain representation of an upcoming financial commitment,
/// whether originating from a recurring cashflow schedule or a debt installment.
class UpcomingEntry {
  final String id;
  final String title;
  final String? subtitle;
  final double amount;
  final DateTime dueDate;
  final bool isExpense;
  final bool isAutoProcess;
  final String? categoryId;
  final String? accountId;
  final UpcomingEntryKind kind;
  final PlannedPayment? plannedPayment;
  final Debt? debt;

  const UpcomingEntry({
    required this.id,
    required this.title,
    this.subtitle,
    required this.amount,
    required this.dueDate,
    required this.isExpense,
    this.isAutoProcess = false,
    this.categoryId,
    this.accountId,
    required this.kind,
    this.plannedPayment,
    this.debt,
  });

  bool get isDebt => kind == UpcomingEntryKind.debtInstallment;
  bool get isPayment => kind == UpcomingEntryKind.plannedPayment;

  int daysUntilDue([DateTime? now]) {
    final ref = now ?? DateTime.now();
    return DateTime(dueDate.year, dueDate.month, dueDate.day)
        .difference(DateTime(ref.year, ref.month, ref.day))
        .inDays;
  }

  bool isOverdue([DateTime? now]) => daysUntilDue(now) < 0;

  String formattedDueStatus([DateTime? now]) {
    final diff = daysUntilDue(now);
    if (diff < 0) return '${-diff}d overdue';
    if (diff == 0) return 'Due today';
    if (diff == 1) return 'Due tomorrow';
    if (diff <= 7) return 'Due in ${diff}d';
    return '${diff}d left';
  }
}

/// Unified timeline aggregation across all upcoming financial obligations.
class UpcomingTimeline {
  final List<UpcomingEntry> entries;

  const UpcomingTimeline(this.entries);

  factory UpcomingTimeline.empty() => const UpcomingTimeline([]);

  factory UpcomingTimeline.calculate({
    required List<PlannedPayment> payments,
    required List<Debt> debts,
    DateTime? now,
  }) {
    final List<UpcomingEntry> all = [];

    for (final p in payments) {
      all.add(
        UpcomingEntry(
          id: p.id,
          title: p.title,
          subtitle: p.frequency.name.toUpperCase(),
          amount: p.amount,
          dueDate: p.nextDate,
          isExpense: p.type == TransactionType.expense,
          isAutoProcess: p.isAutoProcess,
          categoryId: p.categoryId,
          accountId: p.accountId,
          kind: UpcomingEntryKind.plannedPayment,
          plannedPayment: p,
        ),
      );
    }

    for (final d in debts) {
      if (d.totalInstallments > 0 && !d.isSettled) {
        all.add(
          UpcomingEntry(
            id: d.id,
            title: d.personName,
            subtitle: d.description ?? 'Installment',
            amount: d.upcomingPaymentAmount,
            dueDate: d.nextDueDate,
            isExpense: d.type == DebtType.iOwe,
            isAutoProcess: false,
            categoryId: d.categoryId,
            accountId: d.accountId,
            kind: UpcomingEntryKind.debtInstallment,
            debt: d,
          ),
        );
      }
    }

    all.sort((a, b) => a.dueDate.compareTo(b.dueDate));

    return UpcomingTimeline(all);
  }

  bool get isEmpty => entries.isEmpty;
  bool get isNotEmpty => entries.isNotEmpty;
  int get length => entries.length;

  List<UpcomingEntry> take(int count) => entries.take(count).toList();

  List<UpcomingEntry> get overdueEntries =>
      entries.where((e) => e.isOverdue()).toList();

  double get totalExpenseDue => entries
      .where((e) => e.isExpense)
      .fold(0.0, (sum, e) => sum + e.amount);

  double get totalIncomeDue => entries
      .where((e) => !e.isExpense)
      .fold(0.0, (sum, e) => sum + e.amount);
}

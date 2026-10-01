import 'debt.dart';

/// Immutable domain value object encapsulating aggregated debt metrics across a portfolio.
class DebtSummary {
  final double netBalance;
  final double totalOwedToMe;
  final double totalIOwe;
  final double totalRepaid;
  final double totalOriginalPrincipal;
  final int activeCount;
  final int settledCount;
  final int overdueCount;

  const DebtSummary({
    required this.netBalance,
    required this.totalOwedToMe,
    required this.totalIOwe,
    required this.totalRepaid,
    required this.totalOriginalPrincipal,
    required this.activeCount,
    required this.settledCount,
    required this.overdueCount,
  });

  factory DebtSummary.empty() => const DebtSummary(
        netBalance: 0.0,
        totalOwedToMe: 0.0,
        totalIOwe: 0.0,
        totalRepaid: 0.0,
        totalOriginalPrincipal: 0.0,
        activeCount: 0,
        settledCount: 0,
        overdueCount: 0,
      );

  factory DebtSummary.calculate(List<Debt> debts, {DateTime? now}) {
    final referenceDate = now ?? DateTime.now();
    double net = 0.0;
    double owedToMe = 0.0;
    double iOwe = 0.0;
    double repaid = 0.0;
    double principal = 0.0;
    int active = 0;
    int settled = 0;
    int overdue = 0;

    for (final debt in debts) {
      final remaining = debt.remainingAmount;
      repaid += debt.currentAmount;
      principal += debt.amount;

      if (debt.isSettled) {
        settled++;
      } else {
        active++;
        if (debt.isOverdue(referenceDate)) {
          overdue++;
        }
      }

      if (debt.type == DebtType.owedToMe) {
        owedToMe += remaining;
        net += remaining;
      } else {
        iOwe += remaining;
        net -= remaining;
      }
    }

    return DebtSummary(
      netBalance: net,
      totalOwedToMe: owedToMe,
      totalIOwe: iOwe,
      totalRepaid: repaid,
      totalOriginalPrincipal: principal,
      activeCount: active,
      settledCount: settled,
      overdueCount: overdue,
    );
  }

  bool get isNegative => netBalance < 0;
  bool get hasActiveDebts => activeCount > 0;
  bool get hasOverdue => overdueCount > 0;
}

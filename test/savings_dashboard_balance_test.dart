import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  final account = Account(
    id: 'mari',
    name: 'MariBank',
    iconCodePoint: Icons.wallet.codePoint,
    colorHex: '#00C9A0',
    initialBalance: 263,
  );
  final goal = SavingsGoal(
    id: 'goal',
    name: 'End of Year',
    startDate: DateTime(2026),
    currentAmount: 250,
    isStash: true,
    linkedAccountId: 'mari',
  );
  test(
    'dashboard excludes only opted-out savings without changing account balances',
    () {
      final stats = DashboardStats.calculate(
        accounts: [account],
        transactions: [],
      );
      expect(excludedSavingsFromDashboard(stats, [goal]), 0);
      final excluded = goal.copyWith(includeInDashboardBalance: false);
      expect(
        stats.currentBalance - excludedSavingsFromDashboard(stats, [excluded]),
        13,
      );
      expect(stats.accountBalances['mari'], 263);
      expect(stats.currentBalance, 263);
      expect(
        excludedSavingsFromDashboard(stats, [
          excluded.copyWith(currentAmount: 200),
        ]),
        200,
      );
    },
  );
  test(
    'excluded accounts are never subtracted twice and overallocated savings are capped',
    () {
      final excluded = goal.copyWith(includeInDashboardBalance: false);
      final hidden = DashboardStats.calculate(
        accounts: [account.copyWith(excludeFromTotal: true)],
        transactions: [],
      );
      expect(excludedSavingsFromDashboard(hidden, [excluded]), 0);
      final stats = DashboardStats.calculate(
        accounts: [account],
        transactions: [],
      );
      expect(
        excludedSavingsFromDashboard(stats, [
          excluded.copyWith(currentAmount: 300),
        ]),
        263,
      );
      expect(
        excludedSavingsFromDashboard(stats, [
          SavingsGoal(
            id: 'unlinked',
            name: 'Cash savings',
            startDate: DateTime(2026),
            currentAmount: 100,
            isStash: true,
            includeInDashboardBalance: false,
          ),
        ]),
        0,
      );
    },
  );
  test('dashboard option round-trips and legacy goals stay included', () {
    final excluded = goal.copyWith(includeInDashboardBalance: false);
    expect(
      SavingsGoal.fromMap(excluded.toMap()).includeInDashboardBalance,
      false,
    );
    expect(
      excluded.copyWith(currentAmount: 200).includeInDashboardBalance,
      false,
    );
    final legacy = goal.toMap()..remove('includeInDashboardBalance');
    expect(SavingsGoal.fromMap(legacy).includeInDashboardBalance, true);
  });
}

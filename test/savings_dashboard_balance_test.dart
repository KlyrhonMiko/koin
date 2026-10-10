import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    'dashboard account cards react to savings visibility and releases',
    () async {
      final stats = DashboardStats.calculate(
        accounts: [account],
        transactions: [],
      );
      final container = ProviderContainer(
        overrides: [
          dashboardStatsProvider.overrideWithValue(stats),
          savingsRepositoryProvider.overrideWithValue(
            InMemorySavingsAdapter(initial: [goal]),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(savingsGoalsProvider.future);
      expect(container.read(dashboardAccountBalancesProvider)['mari'], 263);
      final excluded = goal.copyWith(includeInDashboardBalance: false);
      await container.read(savingsGoalsProvider.notifier).updateGoal(excluded);
      expect(container.read(dashboardAccountBalancesProvider)['mari'], 13);
      expect(container.read(dashboardExcludedSavingsProvider), 250);
      await container
          .read(savingsGoalsProvider.notifier)
          .updateGoal(excluded.copyWith(currentAmount: 200));
      expect(container.read(dashboardAccountBalancesProvider)['mari'], 63);
      await container.read(savingsGoalsProvider.notifier).updateGoal(goal);
      expect(container.read(dashboardAccountBalancesProvider)['mari'], 263);
      expect(stats.accountBalances['mari'], 263);
    },
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
      expect(dashboardAccountBalances(stats, [goal])['mari'], 263);
      expect(dashboardAccountBalances(stats, [excluded])['mari'], 13);
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
      expect(dashboardAccountBalances(hidden, [excluded])['mari'], 13);
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
        dashboardAccountBalances(stats, [
          excluded.copyWith(currentAmount: 300),
        ])['mari'],
        0,
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

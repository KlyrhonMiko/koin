import 'package:koin/core/models/savings/savings_projection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  final start = DateTime(2026, 1, 31);
  SavingsGoal goal({
    String id = 'goal',
    double saved = 0,
    String? account,
    bool emergency = false,
  }) => SavingsGoal(
    id: id,
    name: id,
    startDate: start,
    targetAmount: 1000,
    currentAmount: saved,
    linkedAccountId: account,
    isEmergencyFund: emergency,
  );
  SavingsLog log(String id, double amount, DateTime date) =>
      SavingsLog(id: id, goalId: 'goal', amount: amount, date: date);

  test(
    'routine suggestions use the chosen schedule instead of historical saving pace',
    () {
      final today = DateTime(2026, 2, 28);
      final scheduled = goal(saved: 500).copyWith(
        targetAmount: 2000,
        endDate: DateTime(2026, 5, 31),
        savingsPlan: SavingsPlan(
          amount: 40,
          frequency: SavingsFrequency.fortnightly,
          startDate: start,
        ),
      );
      final projection = SavingsProjection(goal: scheduled, today: today);
      expect(projection.totalBy(DateTime(2026, 3, 28)), 620);
      final increased = SavingsProjection(
        goal: scheduled.copyWith(
          savingsPlan: SavingsPlan(
            amount: 50,
            frequency: SavingsFrequency.fortnightly,
            startDate: start,
          ),
        ),
        today: today,
      );
      expect(increased.totalBy(DateTime(2026, 3, 28)), 650);
    },
  );

  test(
    'monthly occurrences preserve the month-end anchor including leap years',
    () {
      final plan = SavingsPlan(
        amount: 100,
        frequency: SavingsFrequency.monthly,
        startDate: start,
      );
      expect(plan.occurrence(1), DateTime(2026, 2, 28));
      expect(plan.occurrence(2), DateTime(2026, 3, 31));
      expect(plan.occurrence(25), DateTime(2028, 2, 29));
      expect(plan.periodAt(DateTime(2026, 3, 30)), 1);
      expect(plan.periodAt(DateTime(2026, 3, 31)), 2);
    },
  );

  test(
    'partial contributions count, releases do not erase saving consistency',
    () {
      final plan = SavingsPlan(
        amount: 100,
        frequency: SavingsFrequency.weekly,
        startDate: DateTime(2026, 1, 1),
      );
      final logs = [
        log('a', 40, DateTime(2026, 1, 1)),
        log('b', 60, DateTime(2026, 1, 2)),
        log('c', -20, DateTime(2026, 1, 3)),
        log('d', 25, DateTime(2026, 1, 8)),
      ];
      final progress = plan.progress(logs, DateTime(2026, 1, 10));
      expect(progress.amountDue, 75);
      expect(progress.nextDate, DateTime(2026, 1, 8));
      expect(progress.completedPeriods, 1);
      expect(progress.elapsedPeriods, 2);
      expect(progress.isDue, true);
    },
  );

  test(
    'fulfilled periods advance; future and pre-plan deposits are excluded',
    () {
      final plan = SavingsPlan(
        amount: 100,
        frequency: SavingsFrequency.fortnightly,
        startDate: DateTime(2026, 1, 1),
      );
      final logs = [
        log('old', 100, DateTime(2025, 12, 31)),
        log('now', 100, DateTime(2026, 1, 1)),
        log('future', 100, DateTime(2026, 1, 20)),
      ];
      final progress = plan.progress(logs, DateTime(2026, 1, 1));
      expect(progress.nextDate, DateTime(2026, 1, 15));
      expect(progress.isDue, false);
      expect(progress.completedPeriods, 1);
      expect(plan.progress([], DateTime(2025, 12, 1)).elapsedPeriods, 0);
    },
  );

  test(
    'legacy emergency records become Savings without losing account or routine data',
    () {
      final plan = SavingsPlan(
        amount: 250,
        frequency: SavingsFrequency.weekly,
        startDate: start,
      );
      final legacy =
          goal(id: 'legacy', saved: 725, account: 'bank', emergency: true)
              .copyWith(
                name: 'Rainy days',
                notes: 'My reserve',
                includeInDashboardBalance: false,
                savingsPlan: plan,
              )
              .toMap()
            ..['isEmergencyFund'] = 1
            ..['isStash'] = 0;
      final restored = SavingsGoal.fromMap(legacy);
      expect(restored.isStash, true);
      expect(restored.isEmergencyFund, false);
      expect(restored.id, 'legacy');
      expect(restored.name, 'Rainy days');
      expect(restored.currentAmount, 725);
      expect(restored.linkedAccountId, 'bank');
      expect(restored.notes, 'My reserve');
      expect(restored.includeInDashboardBalance, false);
      expect(restored.savingsPlan!.amount, 250);
      expect(restored.toMap()['isEmergencyFund'], 0);
      expect(restored.copyWith(targetAmount: 1500).targetAmount, 1500);
    },
  );

  test(
    'legacy emergency savings retain targetless status and routine through storage',
    () {
      final original = goal(emergency: true).copyWith(
        savingsPlan: SavingsPlan(
          amount: 500,
          frequency: SavingsFrequency.weekly,
          startDate: start,
        ),
      );
      final restored = SavingsGoal.fromMap(original.toMap());
      expect(restored.isStash, true);
      expect(restored.isEmergencyFund, false);
      expect(restored.targetAmount, isNull);
      expect(restored.endDate, isNull);
      expect(restored.savingsPlan!.amount, 500);
      expect(restored.savingsPlan!.frequency, SavingsFrequency.weekly);
      expect(restored.copyWith(clearSavingsPlan: true).savingsPlan, isNull);
      expect(SavingsGoal.fromMap(goal().toMap()).endDate, isNull);
      expect(SavingsPlan.fromMap({}), isNull);
    },
  );

  test(
    'emergency funds and overfunded goals cannot inflate goal completion',
    () {
      final summary = SavingsSummary.calculate([
        goal(saved: 400),
        goal(id: 'done', saved: 1400),
        goal(id: 'emergency', saved: 5000, emergency: true),
      ]);
      expect(summary.totalSaved, 6800);
      expect(summary.emergencySaved, 0);
      expect(summary.stashesCount, 1);
      expect(summary.totalTarget, 2000);
      expect(summary.overallProgress, 0.7);
      expect(summary.goalRemaining, 600);
      expect(goal(saved: 1400).weeklyNeeded, isNull);
    },
  );

  test(
    'shared accounts enforce combined reservations and reject moving funds to a full account',
    () async {
      final accounts = [
        for (final id in ['a', 'b'])
          Account(
            id: id,
            name: id,
            iconCodePoint: KoinIcons.wallet.codePoint,
            colorHex: '#00C9A0',
            initialBalance: 1000,
          ),
      ];
      final repository = InMemorySavingsAdapter(
        initial: [
          goal(account: 'a'),
          goal(id: 'emergency', account: 'a', emergency: true),
          goal(id: 'full', account: 'b', saved: 1000),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          savingsRepositoryProvider.overrideWithValue(repository),
          dashboardStatsProvider.overrideWithValue(
            DashboardStats.calculate(accounts: accounts, transactions: []),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(savingsGoalsProvider.future);
      final notifier = container.read(savingsGoalsProvider.notifier);
      await notifier.addLog(log('a', 700, DateTime.now()));
      await notifier.addLog(
        SavingsLog(
          id: 'b',
          goalId: 'emergency',
          amount: 200,
          date: DateTime.now(),
        ),
      );
      expect(container.read(savingsAvailableBalanceProvider('a')), 100);
      await expectLater(
        notifier.addLog(
          SavingsLog(
            id: 'excess',
            goalId: 'emergency',
            amount: 101,
            date: DateTime.now(),
          ),
        ),
        throwsA(isA<SavingsBalanceException>()),
      );
      final current = (await repository.getSavingsGoals()).firstWhere(
        (g) => g.id == 'goal',
      );
      await expectLater(
        notifier.updateGoal(current.copyWith(linkedAccountId: 'b')),
        throwsA(isA<SavingsBalanceException>()),
      );
      await notifier.updateGoal(
        goal(account: 'a').copyWith(name: 'Edited'),
        preserveBalance: true,
      );
      expect(
        (await repository.getSavingsGoals())
            .firstWhere((g) => g.id == 'goal')
            .currentAmount,
        700,
      );
    },
  );
}

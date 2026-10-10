import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/widgets/savings_log_sheet.dart';

void main() {
  final goal = SavingsGoal(
    id: 'goal',
    name: 'End of Year',
    startDate: DateTime(2026),
    linkedAccountId: 'mari',
    isStash: true,
  );
  SavingsLog log(String id, double amount) =>
      SavingsLog(id: id, goalId: goal.id, amount: amount, date: DateTime(2026));
  DashboardStats stats(double balance) => DashboardStats(
    totalIncome: 0,
    totalExpense: 0,
    currentBalance: balance,
    accounts: [],
    accountBalances: {'mari': balance},
    categorySpending: {},
  );
  late InMemorySavingsAdapter repository;
  late ProviderContainer container;
  double balance = 263;
  setUp(() async {
    balance = 263;
    repository = InMemorySavingsAdapter(initial: [goal]);
    container = ProviderContainer(
      overrides: [
        savingsRepositoryProvider.overrideWithValue(repository),
        dashboardStatsProvider.overrideWith((ref) => stats(balance)),
      ],
    );
    await container.read(savingsGoalsProvider.future);
  });
  tearDown(() => container.dispose());

  test('200 then 100 cannot allocate 300 from an account with 263', () async {
    final notifier = container.read(savingsGoalsProvider.notifier);
    await notifier.addLog(log('first', 200));
    expect(container.read(savingsAvailableBalanceProvider('mari')), 63);
    await expectLater(
      notifier.addLog(log('second', 100)),
      throwsA(isA<SavingsBalanceException>()),
    );
    expect((await repository.getSavingsGoals()).single.currentAmount, 200);
    expect((await repository.getSavingsLogs(goal.id)).length, 1);
    await notifier.addLog(log('boundary', 63));
    expect((await repository.getSavingsGoals()).single.currentAmount, 263);
  });

  test(
    'editing credits the old deposit but rejects an overfunded total',
    () async {
      final notifier = container.read(savingsGoalsProvider.notifier);
      final original = log('first', 250);
      await notifier.addLog(original);
      await expectLater(
        notifier.updateLog(original, log('first', 300)),
        throwsA(isA<SavingsBalanceException>()),
      );
      await notifier.updateLog(original, log('first', 263));
      expect((await repository.getSavingsGoals()).single.currentAmount, 263);
      await notifier.updateLog(original, log('first', 200));
      expect((await repository.getSavingsGoals()).single.currentAmount, 200);
    },
  );

  test('simultaneous deposits are checked in sequence', () async {
    final notifier = container.read(savingsGoalsProvider.notifier);
    final first = notifier.addLog(log('first', 200));
    final second = notifier.addLog(log('second', 100));
    await expectLater(second, throwsA(isA<SavingsBalanceException>()));
    await first;
    expect((await repository.getSavingsGoals()).single.currentAmount, 200);
  });

  test('save rechecks a changed account balance', () async {
    final notifier = container.read(savingsGoalsProvider.notifier);
    await notifier.addLog(log('first', 50));
    balance = 100;
    container.invalidate(dashboardStatsProvider);
    await expectLater(
      notifier.addLog(log('second', 80)),
      throwsA(isA<SavingsBalanceException>()),
    );
    expect((await repository.getSavingsGoals()).single.currentAmount, 50);
  });

  test('existing overallocated savings can be reduced', () async {
    final original = log('first', 300);
    await repository.insertSavingsLog(original);
    await container
        .read(savingsGoalsProvider.notifier)
        .updateLog(original, log('first', 250));
    expect((await repository.getSavingsGoals()).single.currentAmount, 250);
  });

  test(
    'explicit release restores spendable funds and preserves history',
    () async {
      final notifier = container.read(savingsGoalsProvider.notifier);
      await notifier.addLog(log('deposit', 250));
      await notifier.addLog(log('release', -50));
      expect((await repository.getSavingsGoals()).single.currentAmount, 200);
      expect(container.read(savingsAvailableBalanceProvider('mari')), 63);
      expect((await repository.getSavingsLogs(goal.id)).map((l) => l.amount), [
        250,
        -50,
      ]);
      await expectLater(
        notifier.addLog(log('too-much', -201)),
        throwsA(isA<SavingsBalanceException>()),
      );
      await expectLater(
        notifier.deleteLog(log('deposit', 250)),
        throwsA(isA<SavingsBalanceException>()),
      );
    },
  );

  testWidgets(
    'reserved funds warn but record anyway never changes allocations',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
      final prefs = await SharedPreferences.getInstance();
      await repository.insertSavingsLog(log('deposit', 250));
      bool? accepted;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            savingsRepositoryProvider.overrideWithValue(repository),
            dashboardStatsProvider.overrideWithValue(stats(263)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () async {
                    accepted = await confirmSavingsSpending(
                      context: context,
                      ref: ref,
                      accountId: 'mari',
                      amount: 50,
                    );
                  },
                  child: const Text('Record expense'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record expense'));
      await tester.pumpAndSettle();
      expect(find.text('This uses reserved savings'), findsOneWidget);
      expect(find.textContaining('13.00'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(accepted, false);
      await tester.tap(find.text('Record expense'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record anyway'));
      await tester.pumpAndSettle();
      expect(accepted, true);
      expect((await repository.getSavingsGoals()).single.currentAmount, 250);
      expect((await repository.getSavingsLogs(goal.id)).length, 1);
    },
  );

  testWidgets(
    'release asks for confirmation and saves a negative activity amount',
    (tester) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
      final prefs = await SharedPreferences.getInstance();
      await repository.insertSavingsLog(log('deposit', 250));
      double? saved;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            savingsRepositoryProvider.overrideWithValue(repository),
            dashboardStatsProvider.overrideWithValue(stats(263)),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: SavingsLogSheet(
                goal: goal,
                release: true,
                onSave: (amount) async {
                  saved = amount;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      tester.widget<NumPad>(find.byType(NumPad)).onValueChanged('50', '50');
      await tester.pump();
      tester.widget<NumPad>(find.byType(NumPad)).onDone();
      await tester.pumpAndSettle();
      expect(saved, isNull);
      expect(find.textContaining('200.00 remains'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
      tester.widget<NumPad>(find.byType(NumPad)).onDone();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Release savings'));
      await tester.pumpAndSettle();
      expect(saved, -50);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sheet shows only remaining funds and blocks saving an excess', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    final prefs = await SharedPreferences.getInstance();
    await repository.insertSavingsLog(log('first', 250));
    var saved = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savingsRepositoryProvider.overrideWithValue(repository),
          dashboardStatsProvider.overrideWithValue(stats(263)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SavingsLogSheet(
              goal: goal,
              linkedAccount: Account(
                id: 'mari',
                name: 'MariBank',
                iconCodePoint: Icons.wallet.codePoint,
                colorHex: '#00C9A0',
              ),
              linkedBalance: 263,
              onSave: (_) async {
                saved = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('13.00'), findsOneWidget);
    tester.widget<NumPad>(find.byType(NumPad)).onValueChanged('50', '50');
    await tester.pump();
    expect(
      find.textContaining('Insufficient available balance'),
      findsOneWidget,
    );
    tester.widget<NumPad>(find.byType(NumPad)).onDone();
    await tester.pumpAndSettle();
    expect(saved, isFalse);
    expect(find.byType(SavingsLogSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

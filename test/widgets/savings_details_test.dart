import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/savings_details_screen.dart';
import 'package:koin/features/savings/savings_list_screen.dart';
import 'package:koin/features/savings/widgets/savings_log_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    prefs = await SharedPreferences.getInstance();
  });

  Future<InMemorySavingsAdapter> showSavings(
    WidgetTester tester,
    SavingsGoal goal, {
    bool list = false,
    List<SavingsLog> logs = const [],
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = InMemorySavingsAdapter(initial: [goal]);
    for (final log in logs) {
      await repository.insertSavingsLog(log);
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savingsRepositoryProvider.overrideWithValue(repository),
          accountRepositoryProvider.overrideWithValue(InMemoryAccountAdapter()),
          dashboardStatsProvider.overrideWithValue(DashboardStats.empty()),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00C9A0), true),
          home: list
              ? const Scaffold(body: SavingsTab(showEntranceAnimations: false))
              : SavingsDetailsScreen(goal: goal),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  testWidgets('automatic release explains read-only status and blocks edit and swipe', (
    tester,
  ) async {
    final goal = SavingsGoal(
      id: 'goal',
      name: 'End of Year',
      currentAmount: 500,
      startDate: DateTime(2026),
      isStash: true,
    );
    final repository = await showSavings(
      tester,
      goal,
      logs: [
        SavingsLog(
          id: 'automatic',
          goalId: 'goal',
          amount: -437,
          date: DateTime(2026, 10, 10),
          transactionId: 'expense',
        ),
        SavingsLog(
          id: 'manual',
          goalId: 'goal',
          amount: 20,
          date: DateTime(2026),
        ),
      ],
    );
    final indicator = find.text('Auto release · Read only');
    void expectConnectedTimeline() {
      final firstDot = tester.getRect(
        find.byKey(const ValueKey('timeline-dot-automatic')),
      );
      final secondDot = tester.getRect(
        find.byKey(const ValueKey('timeline-dot-manual')),
      );
      final below = tester.getRect(
        find.byKey(const ValueKey('timeline-below-automatic')),
      );
      final above = tester.getRect(
        find.byKey(const ValueKey('timeline-above-manual')),
      );
      expect(below.top, closeTo(firstDot.center.dy, 0.01));
      expect(below.bottom, closeTo(above.top, 0.01));
      expect(above.bottom, closeTo(secondDot.center.dy, 0.01));
      expect(below.center.dx, closeTo(firstDot.center.dx, 0.01));
      expect(above.center.dx, closeTo(secondDot.center.dx, 0.01));
      final firstCard = tester.getRect(find.byKey(const Key('automatic')));
      final secondCard = tester.getRect(find.byKey(const Key('manual')).first);
      expect(secondCard.top - firstCard.bottom, closeTo(12, 0.01));
    }

    await tester.ensureVisible(indicator);
    await tester.pumpAndSettle();
    expectConnectedTimeline();
    expect(indicator, findsOneWidget);
    expect(
      find.text(
        'Managed by its transaction. Edit or delete that transaction to update this release.',
      ),
      findsNothing,
    );
    await tester.longPress(indicator);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Managed by its transaction. Edit or delete that transaction to update this release.',
      ),
      findsNothing,
    );
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    await tester.tap(indicator);
    await tester.pumpAndSettle();
    expectConnectedTimeline();
    expect(
      find.text(
        'Managed by its transaction. Edit or delete that transaction to update this release.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const Key('automatic')),
        matching: find.byType(Tooltip),
      ),
      findsNothing,
    );
    await tester.tap(indicator);
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Managed by its transaction. Edit or delete that transaction to update this release.',
      ),
      findsNothing,
    );
    expect(find.byType(SavingsLogSheet), findsNothing);
    await tester.drag(
      find.byKey(const Key('automatic')).first,
      const Offset(-200, 0),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete Entry?'), findsNothing);
    expect((await repository.getSavingsLogs('goal')).length, 2);
    expect((await repository.getSavingsGoals()).single.currentAmount, 83);
    await tester.ensureVisible(find.byKey(const Key('manual')).first);
    await tester.tap(find.byKey(const Key('manual')).first);
    await tester.pumpAndSettle();
    expect(find.byType(SavingsLogSheet), findsOneWidget);
    expect(
      tester.widget<SavingsLogSheet>(find.byType(SavingsLogSheet)).log?.id,
      'manual',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Targetless stash has a compact card and no progress ring', (
    tester,
  ) async {
    final stash = SavingsGoal(
      id: 'stash',
      name: 'Spare change',
      startDate: DateTime(2026, 10, 10),
      isStash: true,
    );
    final repository = await showSavings(tester, stash);
    expect(find.text('Stash'), findsNothing);
    expect(find.text('100%'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    final emptyArea = tester.getRect(find.byType(KoinActivityEmptyState));
    final emptyContent = tester.getRect(
      find.byKey(const ValueKey('activity_empty_content')),
    );
    expect(emptyContent.center.dy, closeTo(emptyArea.center.dy, 1));
    expect(find.text('Target'), findsNothing);
    expect(tester.getSize(find.byType(KoinSummaryCard)).height, lessThan(130));
    expect(find.byType(FloatingActionButton), findsNothing);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Release'), findsOneWidget);
    expect(find.text('Coach'), findsOneWidget);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(find.text('Edit'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete goal'));
    await tester.pumpAndSettle();
    expect(find.text('Delete Goal?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect((await repository.getSavingsGoals()).single.id, stash.id);
    expect(tester.takeException(), isNull);

    await showSavings(tester, stash, list: true);
    expect(find.text('Stash'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stash with a target shows its actual progress', (tester) async {
    await showSavings(
      tester,
      SavingsGoal(
        id: 'targeted-stash',
        name: 'Savings',
        targetAmount: 1000,
        currentAmount: 250,
        startDate: DateTime(2026, 10, 10),
        isStash: true,
      ),
    );
    expect(find.text('25%'), findsOneWidget);
    expect(find.text('Target'), findsOneWidget);
    await tester.tap(find.byTooltip('Release savings'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SavingsLogSheet>(find.byType(SavingsLogSheet)).release,
      true,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Edit updates the existing goal and subsequent savings sheet', (
    tester,
  ) async {
    final goal = SavingsGoal(
      id: 'goal',
      name: 'Travel',
      targetAmount: 1000,
      currentAmount: 150,
      startDate: DateTime(2026, 10, 10),
      endDate: DateTime(2027, 1, 1),
    );
    final repository = await showSavings(tester, goal);
    await tester.tap(find.byTooltip('Edit goal'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('goal_name')))
          .controller!
          .text,
      'Travel',
    );
    await tester.enterText(find.byKey(const Key('goal_name')), 'Japan trip');
    await tester.enterText(find.byKey(const Key('goal_amount')), '2000');
    await tester.tap(find.text('Update Goal'));
    await tester.pumpAndSettle();
    final saved = (await repository.getSavingsGoals()).single;
    expect(saved.id, goal.id);
    expect(saved.currentAmount, 150);
    expect(saved.targetAmount, 2000);
    expect(find.text('Japan trip'), findsOneWidget);
    await tester.tap(find.byTooltip('Add Savings'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SavingsLogSheet>(find.byType(SavingsLogSheet))
          .goal
          .targetAmount,
      2000,
    );
    expect(tester.takeException(), isNull);
  });
}

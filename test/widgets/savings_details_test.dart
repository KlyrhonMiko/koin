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
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = InMemorySavingsAdapter(initial: [goal]);
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

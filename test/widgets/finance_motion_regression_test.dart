import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/budgets/budgets_screen.dart';
import 'package:koin/features/portfolio/portfolio_screen.dart';
import 'package:koin/features/savings/savings_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AnimationTracker.clear();
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
  });

  Future<ProviderContainer> providers({
    List<TransactionCategory> categories = const [],
    List<SavingsGoal> goals = const [],
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
        accountRepositoryProvider.overrideWithValue(InMemoryAccountAdapter()),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(initial: categories),
        ),
        savingsRepositoryProvider.overrideWithValue(
          InMemorySavingsAdapter(initial: goals),
        ),
        debtRepositoryProvider.overrideWithValue(InMemoryDebtAdapter()),
        plannedPaymentRepositoryProvider.overrideWithValue(
          InMemoryPlannedPaymentAdapter(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(categoriesProvider.future);
    await container.read(accountProvider.future);
    await container.read(savingsGoalsProvider.future);
    await container.read(transactionProvider.future);
    return container;
  }

  Widget app(ProviderContainer container, Widget child) =>
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.getTheme(Colors.teal, false),
          home: Scaffold(body: child),
        ),
      );

  testWidgets('Manage settles with its neighbors even with many categories', (
    tester,
  ) async {
    final container = await providers(
      categories: List.generate(
        20,
        (index) => TransactionCategory(
          id: 'category-$index',
          name: 'Category $index',
          iconCodePoint: Icons.category.codePoint,
          colorHex: '#009688',
          type: TransactionType.expense,
        ),
      ),
    );
    await tester.pumpWidget(app(container, const BudgetsScreen()));
    for (var frame = 0; frame < 25; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    final manage = find.text('Manage');
    expect(manage, findsOneWidget);
    final fades = find.ancestor(
      of: manage,
      matching: find.byType(FadeTransition),
    );
    for (final fade in tester.widgetList<FadeTransition>(fades)) {
      expect(fade.opacity.value, 1);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Portfolio jumps keep the destination title throughout', (
    tester,
  ) async {
    final container = await providers();
    await tester.pumpWidget(app(container, const PortfolioScreen()));
    await tester.pumpAndSettle();

    container.read(portfolioTabProvider.notifier).setIndex(4);
    await tester.pump();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 30));
      final heading = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.style?.fontSize == KoinTypography.summaryAmount,
        ),
      );
      expect(heading.data, 'Incomes');
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('seen Savings rows remount at their current progress', (
    tester,
  ) async {
    final container = await providers(
      goals: List.generate(
        30,
        (index) => SavingsGoal(
          id: 'goal-$index',
          name: 'Goal $index',
          targetAmount: 1000,
          currentAmount: 500,
          startDate: DateTime(2026),
        ),
      ),
    );
    await tester.pumpWidget(
      app(container, const SavingsTab(showEntranceAnimations: true)),
    );
    final first = find.byKey(const ValueKey('savings-item-card-goal-0'));
    final firstProgress = find.descendant(
      of: first,
      matching: find.byType(LinearProgressIndicator),
    );
    expect(tester.widget<LinearProgressIndicator>(firstProgress).value, 0);
    await tester.pumpAndSettle();
    final firstElement = tester.element(first);

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(2500);
    await tester.pumpAndSettle();
    expect(first, findsNothing);
    scrollable.position.jumpTo(0);
    await tester.pump();

    expect(first, findsOneWidget);
    expect(tester.element(first), isNot(same(firstElement)));
    expect(tester.widget<LinearProgressIndicator>(firstProgress).value, 0.5);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('progress updates retarget from the displayed fill', (
    tester,
  ) async {
    var value = 0.5;
    late StateSetter redraw;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            redraw = setState;
            return KoinProgressBar(
              initialValue: value,
              value: value,
              color: Colors.teal,
            );
          },
        ),
      ),
    );
    double fill() => tester
        .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
        .value!;
    expect(fill(), 0.5);
    redraw(() => value = 0.9);
    await tester.pump();
    expect(fill(), 0.5);
    await tester.pump(const Duration(milliseconds: 80));
    final interrupted = fill();
    expect(interrupted, inExclusiveRange(0.5, 0.9));
    redraw(() => value = 0.2);
    await tester.pump();
    expect(fill(), interrupted);
    await tester.pumpAndSettle();
    expect(fill(), 0.2);
  });
}

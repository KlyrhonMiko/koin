import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/cashflow/add_edit_cashflow_screen.dart';
import 'package:koin/features/categories/category_manager_screen.dart';
import 'package:koin/features/savings/savings_details_screen.dart';
import 'package:koin/features/transactions/transactions_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences preferences;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    preferences = await SharedPreferences.getInstance();
  });
  setUp(AnimationTracker.clear);

  Future<void> showPage(
    WidgetTester tester,
    Widget page, {
    bool? reducedMotion,
    List<AppTransaction> transactions = const [],
    SavingsRepository? savings,
  }) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          accountRepositoryProvider.overrideWithValue(InMemoryAccountAdapter()),
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryAdapter(),
          ),
          categorySuggesterProvider.overrideWithValue(
            TestStubSuggesterAdapter(),
          ),
          savingsRepositoryProvider.overrideWithValue(
            savings ?? InMemorySavingsAdapter(),
          ),
          dashboardStatsProvider.overrideWithValue(DashboardStats.empty()),
          filteredTransactionsProvider.overrideWithValue(
            AsyncData(transactions),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(Colors.teal, false),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(disableAnimations: reducedMotion),
            child: child!,
          ),
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  void expectVisible(WidgetTester tester, Finder content) {
    final fades = find.ancestor(
      of: content,
      matching: find.byType(FadeTransition),
    );
    for (final fade in tester.widgetList<FadeTransition>(fades)) {
      expect(fade.opacity.value, 1);
    }
  }

  testWidgets(
    'late category rows reveal promptly and do not replay on return',
    (tester) async {
      final categories = List.generate(
        80,
        (index) => TransactionCategory(
          id: 'category-$index',
          name: 'Category ${index.toString().padLeft(3, '0')}',
          iconCodePoint: KoinIcons.squaresFour.codePoint,
          colorHex: '#00C9A0',
          type: TransactionType.expense,
        ),
      );
      await showPage(
        tester,
        CategoryList(
          categories: categories,
          type: TransactionType.expense,
          currency: Currency.supportedCurrencies.last,
        ),
      );
      // Mount distant rows after the old 800ms entrance window has elapsed.
      await tester.pump(const Duration(seconds: 1));
      final scroll = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scroll.position.jumpTo(3500);
      await tester.pump();
      await tester.pump(KoinMotion.entrance);
      final rows = find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data?.startsWith('Category ') ?? false),
      );
      expect(rows, findsWidgets);
      for (final row in rows.evaluate()) {
        expectVisible(tester, find.byWidget(row.widget));
      }
      final label = (rows.first.evaluate().single.widget as Text).data!;
      scroll.position.jumpTo(0);
      await tester.pumpAndSettle();
      scroll.position.jumpTo(3500);
      await tester.pump();
      expectVisible(tester, find.text(label));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('transaction rows have one entrance instead of a nested fade', (
    tester,
  ) async {
    await showPage(
      tester,
      const TransactionsListScreen(),
      transactions: [
        AppTransaction(
          id: 'single-entrance',
          note: 'Lunch motion probe',
          amount: 50,
          date: DateTime(2026, 10, 20),
          type: TransactionType.expense,
          categoryId: 'food',
          accountId: 'cash',
        ),
      ],
    );
    final fades = find.ancestor(
      of: find.text('Lunch motion probe'),
      matching: find.descendant(
        of: find.byType(TransactionsListScreen),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fades, findsOneWidget);
    expectVisible(tester, find.text('Lunch motion probe'));
    expect(tester.takeException(), isNull);
  });

  for (final reduced in [false, true]) {
    testWidgets('cashflow end date resizes with reduced motion $reduced', (
      tester,
    ) async {
      await showPage(
        tester,
        const AddEditCashflowScreen(),
        reducedMotion: reduced ? true : null,
      );
      final section = find.byKey(const ValueKey('cashflow-end-date'));
      await tester.ensureVisible(find.text('Add end date'));
      await tester.pumpAndSettle();
      final collapsed = tester.getSize(section).height;
      await tester.tap(find.text('Add end date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final duringExpansion = tester.getSize(section).height;
      await tester.pumpAndSettle();
      final expanded = tester.getSize(section).height;
      expect(expanded, greaterThan(collapsed));
      if (reduced) {
        expect(duringExpansion, expanded);
      } else {
        expect(duringExpansion, greaterThan(collapsed));
        expect(duringExpansion, lessThan(expanded));
      }
      await tester.tap(find.byTooltip('Remove end date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final duringCollapse = tester.getSize(section).height;
      await tester.pumpAndSettle();
      expect(tester.getSize(section).height, collapsed);
      if (reduced) {
        expect(duringCollapse, collapsed);
      } else {
        expect(duringCollapse, greaterThan(collapsed));
        expect(duringCollapse, lessThan(expanded));
      }
      expect(find.text('Add end date'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'savings release explanation resizes with reduced motion $reduced',
      (tester) async {
        final goal = SavingsGoal(
          id: 'release-motion',
          name: 'Reserve',
          currentAmount: 100,
          startDate: DateTime(2026),
          isStash: true,
        );
        final savings = InMemorySavingsAdapter(initial: [goal]);
        await savings.insertSavingsLog(
          SavingsLog(
            id: 'automatic',
            goalId: goal.id,
            amount: -10,
            date: DateTime(2026, 10, 20),
            transactionId: 'expense',
          ),
        );
        await showPage(
          tester,
          SavingsDetailsScreen(goal: goal),
          savings: savings,
          reducedMotion: reduced ? true : null,
        );
        final toggle = find.text('Auto release · Read only');
        final explanation = find.byKey(
          const ValueKey('savings-release-explanation-automatic'),
        );
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        expect(tester.getSize(explanation).height, 0);
        await tester.tap(toggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final expanding = tester.getSize(explanation).height;
        await tester.pumpAndSettle();
        final expanded = tester.getSize(explanation).height;
        expect(expanded, greaterThan(0));
        if (reduced) {
          expect(expanding, expanded);
        } else {
          expect(expanding, inExclusiveRange(0, expanded));
        }
        // Reverse twice before collapse finishes and confirm the final intent wins.
        await tester.tap(toggle);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.getSize(explanation).height, expanded);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(tester.getSize(explanation).height, 0);
        if (!reduced) {
          addTearDown(
            tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
          );
          await tester.tap(toggle);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 40));
          tester.platformDispatcher.accessibilityFeaturesTestValue =
              const FakeAccessibilityFeatures(disableAnimations: true);
          await tester.pump();
          expect(tester.getSize(explanation).height, expanded);
          await tester.pumpAndSettle();
          // The preference change preserves the user's expanded choice.
          expect(tester.getSize(explanation).height, expanded);
          await tester.tap(toggle);
          await tester.pump();
          expect(tester.getSize(explanation).height, 0);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

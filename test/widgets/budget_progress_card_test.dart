import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/dashboard/widgets/budget_progress_card.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  const currency = Currency(code: 'PHP', symbol: '₱', name: 'Philippine Peso');
  TransactionCategory category(String id, {double? percent}) =>
      TransactionCategory(
        id: id,
        name: id,
        iconCodePoint: Icons.shopping_bag_rounded.codePoint,
        colorHex: '#5B7D64',
        type: TransactionType.expense,
        budget: percent == null ? 1000 : null,
        budgetPercent: percent,
        isPercentBudget: percent != null,
      );

  Future<void> pumpCard(
    WidgetTester tester,
    BudgetOverview overview, {
    double width = 390,
    double scale = 1,
    bool dark = false,
    VoidCallback? onManage,
  }) async {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(const Color(0xFF5B7D64), dark),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: BudgetProgressCard(
                overview: overview,
                currency: currency,
                onManage: onManage ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Prioritizes overspending and limits the preview to three budgets',
    (tester) async {
      final overview = BudgetOverview.calculate(
        categories: [
          category('Groceries'),
          category('Travel'),
          category('Dining'),
          category('Shopping'),
        ],
        categorySpending: {
          'Groceries': 250,
          'Travel': 1100,
          'Dining': 900,
          'Shopping': 100,
        },
        totalIncome: 5000,
      );
      var managed = false;
      await pumpCard(tester, overview, onManage: () => managed = true);

      expect(find.text('₱100 over'), findsOneWidget);
      expect(find.text('₱100 left'), findsOneWidget);
      expect(find.text('Shopping'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Travel')).dy,
        lessThan(tester.getTopLeft(find.text('Dining')).dy),
      );
      expect(
        tester.getTopLeft(find.text('Dining')).dy,
        lessThan(tester.getTopLeft(find.text('Groceries')).dy),
      );
      await tester.tap(find.text('View all 4 budgets'));
      expect(managed, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    testWidgets(
      'Fits narrow screens and large text in ${dark ? 'dark' : 'light'} mode',
      (tester) async {
        final overview = BudgetOverview.calculate(
          categories: [category('A long household and grocery category name')],
          categorySpending: {
            'A long household and grocery category name': 1234567.89,
          },
          totalIncome: 5000,
        );
        await pumpCard(tester, overview, width: 320, scale: 1.6, dark: dark);
        expect(find.textContaining('over'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Empty overview offers budget setup', (tester) async {
    final overview = BudgetOverview.calculate(
      categories: [],
      categorySpending: {},
      totalIncome: 0,
    );
    var managed = false;
    await pumpCard(
      tester,
      overview,
      width: 320,
      scale: 1.6,
      onManage: () => managed = true,
    );
    expect(find.text('No budgets yet'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Set budgets'));
    expect(managed, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Income-based budgets explain a zero allocation', (tester) async {
    final overview = BudgetOverview.calculate(
      categories: [category('Groceries', percent: 20)],
      categorySpending: {},
      totalIncome: 0,
    );
    await pumpCard(tester, overview);

    expect(find.text('Awaiting income'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/budgets/budgets_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUpAll(() async {
    final outfit = FontLoader('Outfit');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      outfit.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await outfit.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader('packages/phosphor_icons/PhosphorFill')..addFont(
          rootBundle.load(
            'packages/phosphor_icons/lib/fonts/Phosphor-Fill.ttf',
          ),
        ))
        .load();
    await (FontLoader('packages/phosphor_icons/PhosphorRegular')..addFont(
          rootBundle.load('packages/phosphor_icons/lib/fonts/Phosphor.ttf'),
        ))
        .load();
    final fallbackPath = Platform.environment['KOIN_PREVIEW_FALLBACK_FONT'];
    if (fallbackPath != null) {
      await (FontLoader('Roboto')..addFont(
            File(fallbackPath).readAsBytes().then(ByteData.sublistView),
          ))
          .load();
    }
  });

  Future<ProviderContainer> launch(
    WidgetTester tester, {
    bool dark = true,
    double scale = 1,
    double width = 390,
    double height = 900,
    double spent = 815,
    bool withDrinks = false,
    bool manyCategories = false,
  }) async {
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(
            initial: [
              if (withDrinks) ...[
                AppTransaction(
                  id: 'income',
                  amount: 20000,
                  date: now,
                  type: TransactionType.income,
                  categoryId: 'salary',
                  accountId: 'cash',
                ),
                AppTransaction(
                  id: 'drinks',
                  amount: 1000,
                  date: now,
                  type: TransactionType.expense,
                  categoryId: 'drinks',
                  accountId: 'bank',
                ),
              ],
              AppTransaction(
                id: 'spent',
                amount: spent,
                date: now,
                type: TransactionType.expense,
                categoryId: 'food',
                accountId: 'cash',
              ),
              AppTransaction(
                id: 'previous',
                amount: 100,
                date: DateTime(now.year, now.month - 1, 12),
                type: TransactionType.expense,
                categoryId: 'food',
                accountId: 'cash',
              ),
            ],
          ),
        ),
        accountRepositoryProvider.overrideWithValue(InMemoryAccountAdapter()),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(
            initial: [
              TransactionCategory(
                id: 'food',
                name: 'Food',
                iconCodePoint: KoinIcons.forkKnife.codePoint,
                colorHex: '#FF9800',
                type: TransactionType.expense,
                budget: withDrinks ? null : 912.5,
                budgetPercent: withDrinks ? 25 : null,
                isPercentBudget: withDrinks,
              ),
              if (withDrinks)
                TransactionCategory(
                  id: 'drinks',
                  name: 'Drinks',
                  iconCodePoint: KoinIcons.forkKnife.codePoint,
                  colorHex: '#009688',
                  type: TransactionType.expense,
                ),
              TransactionCategory(
                id: 'transport',
                name: 'Transport',
                iconCodePoint: Icons.directions_bus.codePoint,
                colorHex: '#2196F3',
                type: TransactionType.expense,
              ),
              if (manyCategories)
                for (final name in [
                  'Groceries',
                  'Shopping',
                  'Bills',
                  'Health',
                  'Entertainment',
                ])
                  TransactionCategory(
                    id: name.toLowerCase(),
                    name: name,
                    iconCodePoint: KoinIcons.wallet.codePoint,
                    colorHex: '#009688',
                    type: TransactionType.expense,
                  ),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: RepaintBoundary(
          key: const Key('budget-flow-preview'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.getTheme(const Color(0xFF00C9A0), dark).copyWith(
              textTheme: AppTheme.getTheme(
                const Color(0xFF00C9A0),
                dark,
              ).textTheme.apply(fontFamilyFallback: ['Roboto']),
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const Scaffold(
              body: RepaintBoundary(
                key: Key('budget-preview'),
                child: BudgetsScreen(),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> captureFlow(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('budget-flow-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/budget-flow-preview').create(recursive: true);
      await File('build/budget-flow-preview/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'month navigation updates spending and returns to current month',
    (tester) async {
      await launch(tester);
      expect(find.textContaining('spent · 89% used'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Next month',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.textContaining('spent · 11% used'), findsOneWidget);
      final now = DateTime.now();
      await tester.tap(
        find.text(
          DateFormat('MMMM yyyy').format(DateTime(now.year, now.month - 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('spent · 89% used'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('summary privacy follows the shared preference', (tester) async {
    final container = await launch(tester);
    await tester.tap(find.byTooltip('Hide budget'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).hideBalance, isTrue);
    expect(find.text('Budget usage hidden'), findsOneWidget);
    expect(find.text('****'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(KoinSummaryCard),
        matching: find.byType(AnimatedCounter),
      ),
      findsNothing,
    );
    await tester.tap(find.byTooltip('Show budget'));
    await tester.pumpAndSettle();
    expect(find.textContaining('spent · 89% used'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedCounter>(
            find.descendant(
              of: find.byType(KoinSummaryCard),
              matching: find.byType(AnimatedCounter),
            ),
          )
          .value,
      97.5,
    );
  });

  testWidgets('over-budget totals remain clear on narrow large-text screens', (
    tester,
  ) async {
    await launch(tester, width: 320, scale: 1.6, dark: false, spent: 1000);
    expect(find.textContaining('spent · 110% used'), findsOneWidget);
    expect(find.text('Over Budget'), findsOneWidget);
    expect(
      tester
          .widget<AnimatedCounter>(
            find.descendant(
              of: find.byType(KoinSummaryCard),
              matching: find.byType(AnimatedCounter),
            ),
          )
          .value,
      87.5,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('budget redesign preview', (tester) async {
    await launch(tester);
    expect(tester.takeException(), isNull);
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('budget-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File('build/budget-redesign.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets('Add budget starts with equal category choices then one limit', (
    tester,
  ) async {
    final container = await launch(tester, withDrinks: true);
    await tester.ensureVisible(find.text('Add budget'));
    await tester.tap(find.text('Add budget'));
    await tester.pumpAndSettle();
    expect(find.text('Choose categories'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    final continueButton = tester.widget<KoinPrimaryButton>(
      find.byType(KoinPrimaryButton),
    );
    expect(continueButton.enabled, isFalse);
    await tester.tap(find.byKey(const ValueKey('budget_category_food')));
    await tester.enterText(find.byType(TextField), 'Drinks');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('budget_category_drinks')));
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await captureFlow(tester, 'choose-categories');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Food + Drinks'), findsOneWidget);
    await tester.tap(find.text('% of Income'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.tap(find.text('5'));
    await tester.ensureVisible(find.text('Save'));
    await tester.pumpAndSettle();
    await captureFlow(tester, 'set-limit');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Update existing budgets?'), findsOneWidget);
    expect(find.textContaining('25% of income'), findsWidgets);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    expect(
      container.read(monthlyBudgetOverviewProvider(month)).totalSpent,
      815,
    );
    expect(find.text('Food + Drinks'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move & save'));
    await tester.pumpAndSettle();
    final overview = container.read(monthlyBudgetOverviewProvider(month));
    expect(overview.totalBudget, 5000);
    expect(overview.totalSpent, 1815);
    expect(overview.budgetedCategories, hasLength(1));
    expect(tester.takeException(), isNull);
    await captureFlow(tester, 'saved-budget');
  });

  testWidgets('staggered category chips preselect a category in the new flow', (
    tester,
  ) async {
    final container = await launch(
      tester,
      manyCategories: true,
      withDrinks: true,
    );
    expect(find.text('Not budgeted yet'), findsOneWidget);
    expect(find.text('Add budget'), findsOneWidget);
    await captureFlow(tester, 'category-shortcuts');
    await tester.ensureVisible(find.text('Transport'));
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    expect(find.text('Choose categories'), findsOneWidget);
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('budget_category_transport')),
          )
          .value,
      isTrue,
    );
    expect(
      tester
          .widget<CheckboxListTile>(
            find.byKey(const ValueKey('budget_category_food')),
          )
          .value,
      isFalse,
    );
    expect(find.text('Save'), findsNothing);
    await tester.tap(find.byTooltip('Cancel category selection'));
    await tester.pumpAndSettle();
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    expect(
      container.read(monthlyBudgetOverviewProvider(month)).budgetedCategories,
      hasLength(1),
    );
    expect(tester.takeException(), isNull);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'category picker fits narrow enlarged text in ${dark ? 'dark' : 'light'}',
      (tester) async {
        await launch(
          tester,
          withDrinks: true,
          width: 320,
          scale: 1.5,
          dark: dark,
        );
        await tester.ensureVisible(find.text('Add budget'));
        await tester.tap(find.text('Add budget'));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('budget_category_food')));
        await tester.tap(find.byKey(const ValueKey('budget_category_drinks')));
        expect(tester.takeException(), isNull);
        await tester.pumpAndSettle();
        await captureFlow(
          tester,
          'picker-${dark ? 'dark' : 'light'}-large-text',
        );
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Food + Drinks'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'category search stays usable in a short window with the keyboard',
    (tester) async {
      await launch(
        tester,
        withDrinks: true,
        width: 320,
        height: 640,
        scale: 1.5,
      );
      await tester.ensureVisible(find.text('Add budget'));
      await tester.tap(find.text('Add budget'));
      await tester.pumpAndSettle();
      await tester.showKeyboard(find.byType(TextField));
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextField), 'Drinks');
      await tester.pumpAndSettle();
      final drinks = find.byKey(const ValueKey('budget_category_drinks'));
      await tester.ensureVisible(drinks);
      await tester.tap(drinks);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(drinks).value, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('sharing through the editor updates one combined budget row', (
    tester,
  ) async {
    final container = await launch(tester, withDrinks: true);
    final now = DateTime.now();
    final month = DateTime(now.year, now.month);
    expect(
      container.read(monthlyBudgetOverviewProvider(month)).totalSpent,
      815,
    );
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categories'));
    await tester.pumpAndSettle();
    final drinks = find.byKey(const ValueKey('budget_category_drinks'));
    await tester.ensureVisible(drinks);
    await tester.tap(drinks);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply categories'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final overview = container.read(monthlyBudgetOverviewProvider(month));
    expect(overview.totalBudget, 5000);
    expect(overview.totalSpent, 1815);
    expect(overview.budgetedCategories, hasLength(1));
    expect(overview.unbudgetedCategories.any((c) => c.id == 'drinks'), isFalse);
    expect(find.text('Food + Drinks'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('budget-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/shared-budget-preview').create(recursive: true);
      await File('build/shared-budget-preview/budgets.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });
}

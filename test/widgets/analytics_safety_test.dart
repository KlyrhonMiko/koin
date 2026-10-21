import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/analysis/analysis_screen.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DelayedSuggester extends TestStubSuggesterAdapter {
  Completer<CategorySuggestion?>? pending;
  @override
  Future<CategorySuggestion?> suggest(SuggestionContext context) =>
      pending?.future ?? super.suggest(context);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late DelayedSuggester suggester;
  final boundaryKey = GlobalKey();
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
    final outfit = FontLoader('Outfit');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ]) {
      outfit.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await outfit.load();
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final loader = FontLoader('KoinTest')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await loader.load();
    }
  });
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'analysis_filter_index': 1});
    final prefs = await SharedPreferences.getInstance();
    suggester = DelayedSuggester();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        categorySuggesterProvider.overrideWithValue(suggester),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(
            initial: [
              AppTransaction(
                id: 'expense',
                amount: 20,
                date: DateTime.now(),
                accountId: 'cash',
                categoryId: 'food',
                type: TransactionType.expense,
              ),
            ],
          ),
        ),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(
            initial: [
              Account(
                id: 'cash',
                name: 'Cash',
                initialBalance: 5000,
                iconCodePoint: KoinIcons.money.codePoint,
                colorHex: '#008080',
              ),
              Account(
                id: 'bank',
                name: 'Bank',
                initialBalance: 2000,
                iconCodePoint: KoinIcons.bank.codePoint,
                colorHex: '#008080',
              ),
            ],
          ),
        ),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(
            initial: [
              TransactionCategory(
                id: 'food',
                name: 'Food',
                type: TransactionType.expense,
                iconCodePoint: KoinIcons.forkKnife.codePoint,
                colorHex: '#008080',
              ),
              TransactionCategory(
                id: 'transport',
                name: 'Transport',
                type: TransactionType.expense,
                iconCodePoint: Icons.directions_bus.codePoint,
                colorHex: '#008080',
              ),
            ],
          ),
        ),
        forecastProvider(1).overrideWith(
          (ref) async => ForecastData(
            forecastedInflow: 1000,
            forecastedOutflow: 500,
            currentBaseline: 100,
            predictedNetBalance: 600,
            isWarning: true,
            firstShortfallDate: DateTime(2026, 10, 12),
            lowerNetBalance: 300,
            upperNetBalance: 900,
            historyMonths: 12,
          ),
        ),
      ],
    );
  });
  tearDown(() => container.dispose());

  Future<void> launch(
    WidgetTester tester,
    Widget screen, {
    double scale = 1,
    double width = 390,
    bool dark = false,
    bool reducedMotion = false,
  }) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: 'Outfit',
            scaffoldBackgroundColor: AppTheme.getTheme(
              Colors.teal,
              dark,
            ).scaffoldBackgroundColor,
            colorScheme: AppTheme.getTheme(
              const Color(0xFF00D09E),
              dark,
            ).colorScheme,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: reducedMotion,
            ),
            child: RepaintBoundary(key: boundaryKey, child: child!),
          ),
          home: screen,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder noteField() => find.byWidgetPredicate(
    (widget) =>
        widget is TextField && widget.decoration?.hintText == 'Add a note...',
  );

  SelectionTile categoryTile(WidgetTester tester) =>
      tester.widget<SelectionTile>(
        find.byWidgetPredicate(
          (widget) => widget is SelectionTile && widget.label == 'Category',
        ),
      );

  Future<void> capture(WidgetTester tester, String name) async {
    if (Platform.environment['KOIN_CAPTURE_ANALYTICS'] != '1') return;
    await tester.pump();
    final boundary =
        boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await Directory('build/analytics-review').create(recursive: true);
      await File('build/analytics-review/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
    });
  }

  for (final reduced in [false, true]) {
    testWidgets(
      'chart view switch stays steady and handles rapid taps (reduced=$reduced)',
      (tester) async {
        await launch(
          tester,
          const AnalysisScreen(),
          dark: true,
          reducedMotion: reduced,
        );
        final switcher = find.byKey(const ValueKey('spending-chart-switcher'));
        await tester.ensureVisible(switcher);
        await tester.pumpAndSettle();
        final initialRect = tester.getRect(switcher);
        await tester.tap(find.text('Categories'));
        await tester.pump();
        final pie = tester.widget<PieChart>(find.byType(PieChart));
        expect(
          tester
              .getSize(find.byKey(const ValueKey('category-chart-card')))
              .height,
          240,
        );
        expect(pie.data.sections.single.value, 20);
        expect(pie.data.sections.single.radius, 18);
        expect(tester.getRect(switcher), initialRect);
        if (reduced) {
          expect(
            tester.widget<AnimatedSwitcher>(switcher).duration,
            Duration.zero,
          );
          await tester.pump();
          expect(find.byType(BarChart), findsNothing);
        } else {
          await tester.pump(const Duration(milliseconds: 60));
          final enteringFade = tester.widget<FadeTransition>(
            find
                .ancestor(
                  of: find.byKey(const ValueKey(true)),
                  matching: find.byType(FadeTransition),
                )
                .first,
          );
          expect(enteringFade.opacity.value, 0);
          expect(
            tester
                .widgetList<IgnorePointer>(
                  find.descendant(
                    of: switcher,
                    matching: find.byType(IgnorePointer),
                  ),
                )
                .any((widget) => widget.ignoring),
            isTrue,
          );
        }
        await tester.tap(find.text('Trend'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.text('Categories'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 240));
        await tester.pumpAndSettle();
        expect(find.byType(PieChart), findsOneWidget);
        expect(find.byType(BarChart), findsNothing);
        expect(tester.getRect(switcher), initialRect);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
        if (!reduced) await capture(tester, 'categories-fade-through');
      },
    );
  }
  for (final layout in [
    (width: 390.0, scale: 1.0, dark: true),
    (width: 320.0, scale: 1.0, dark: false),
    (width: 320.0, scale: 2.0, dark: true),
  ]) {
    testWidgets('modern categories graph keeps all spending and fits $layout', (
      tester,
    ) async {
      final specs = [
        (id: 'groceries', name: 'Groceries', amount: 120.0, color: '#F59E0B'),
        (id: 'food', name: 'Food', amount: 80.0, color: '#00D09E'),
        (id: 'transport', name: 'Transport', amount: 80.0, color: '#3B82F6'),
        (id: 'shopping', name: 'Shopping', amount: 40.0, color: '#A78BFA'),
        (id: 'utilities', name: 'Utilities', amount: 20.0, color: '#FB7185'),
        (
          id: 'subscriptions',
          name: 'Subscriptions',
          amount: 1.0,
          color: '#38BDF8',
        ),
      ];
      for (final spec in specs) {
        await container
            .read(categoryRepositoryProvider)
            .insertCategory(
              TransactionCategory(
                id: spec.id,
                name: spec.name,
                type: TransactionType.expense,
                iconCodePoint: KoinIcons.squaresFour.codePoint,
                colorHex: spec.color,
              ),
            );
        await container
            .read(ledgerProvider)
            .recordTransaction(
              AppTransaction(
                id: 'chart-${spec.id}',
                amount: spec.amount,
                date: DateTime.now(),
                accountId: 'cash',
                categoryId: spec.id,
                type: TransactionType.expense,
              ),
            );
      }
      await launch(
        tester,
        const AnalysisScreen(),
        width: layout.width,
        scale: layout.scale,
        dark: layout.dark,
      );
      await tester.ensureVisible(find.text('Categories'));
      await tester.tap(find.text('Categories'));
      await tester.pumpAndSettle();
      final pie = tester.widget<PieChart>(find.byType(PieChart));
      expect(
        tester
            .getSize(find.byKey(const ValueKey('category-chart-card')))
            .height,
        240,
      );
      expect(pie.data.sections, hasLength(4));
      expect(
        pie.data.sections.fold<double>(
          0,
          (sum, section) => sum + section.value,
        ),
        361,
      );
      expect(pie.data.sections.last.value, 61);
      expect(
        pie.data.sections.every((section) => section.radius == 18),
        isTrue,
      );
      final legend = find.byKey(const ValueKey('category-legend-3'));
      await tester.ensureVisible(find.byKey(const ValueKey('category-donut')));
      await tester.pumpAndSettle();
      await capture(
        tester,
        'modern-categories-${layout.width}-${layout.scale}',
      );
      await tester.ensureVisible(legend);
      await tester.tap(legend);
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('category-donut')),
          matching: find.text('Other'),
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<PieChart>(find.byType(PieChart))
            .data
            .sections
            .every((section) => section.radius == 18),
        isTrue,
      );
      await tester.tap(legend);
      await tester.pumpAndSettle();
      expect(find.text('Total'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('weak evidence requires accepting the suggested category', (
    tester,
  ) async {
    suggester.stubbedSuggestion = const CategorySuggestion(
      categoryId: 'food',
      originAccountId: 'bank',
      type: TransactionType.expense,
      confidence: 0.33,
      canAutoApply: false,
    );
    await launch(tester, const AddTransactionScreen());
    await tester.enterText(noteField(), 'burger');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(categoryTile(tester).selectedName, isNull);
    final useSuggestion = find.text('Use suggested category: Food');
    expect(useSuggestion, findsOneWidget);
    await capture(tester, 'category-suggestion');
    await tester.ensureVisible(useSuggestion);
    await tester.tap(useSuggestion);
    await tester.pumpAndSettle();
    expect(categoryTile(tester).selectedName, 'Food');
    suggester.stubbedSuggestion = const CategorySuggestion(
      categoryId: 'transport',
      type: TransactionType.expense,
      confidence: 0.95,
    );
    await tester.enterText(noteField(), 'bus ticket');
    await tester.pumpAndSettle();
    expect(categoryTile(tester).selectedName, 'Food');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'strong category suggestion preserves account and transaction type',
    (tester) async {
      await launch(tester, const AddTransactionScreen());
      await tester.ensureVisible(find.text('Select account'));
      await tester.tap(find.text('Select account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      suggester.stubbedSuggestion = const CategorySuggestion(
        categoryId: 'food',
        originAccountId: 'bank',
        type: TransactionType.expense,
        confidence: 0.95,
      );
      await tester.enterText(noteField(), 'lunch');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(categoryTile(tester).selectedName, 'Food');
      expect(find.textContaining('Cash •'), findsOneWidget);
      suggester.stubbedSuggestion = const CategorySuggestion(
        type: TransactionType.transfer,
        originAccountId: 'bank',
        destinationAccountId: 'cash',
        confidence: 0.95,
      );
      await tester.enterText(noteField(), 'deposit');
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();
      expect(find.text('Category'), findsOneWidget);
      expect(find.textContaining('Cash •'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('clearing the note discards an in-flight suggestion', (
    tester,
  ) async {
    suggester.pending = Completer<CategorySuggestion?>();
    await launch(tester, const AddTransactionScreen());
    await tester.enterText(noteField(), 'coffee');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.enterText(noteField(), '');
    suggester.pending!.complete(
      const CategorySuggestion(
        categoryId: 'food',
        type: TransactionType.expense,
        confidence: 0.95,
      ),
    );
    await tester.pumpAndSettle();
    expect(categoryTile(tester).selectedName, isNull);
  });

  testWidgets('manual picker choice wins over an in-flight suggestion', (
    tester,
  ) async {
    suggester.pending = Completer<CategorySuggestion?>();
    await launch(tester, const AddTransactionScreen());
    await tester.enterText(noteField(), 'coffee');
    await tester.pump(const Duration(milliseconds: 600));
    final category = find.byWidgetPredicate(
      (widget) => widget is SelectionTile && widget.label == 'Category',
    );
    await tester.ensureVisible(category);
    await tester.tap(category);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    suggester.pending!.complete(
      const CategorySuggestion(
        categoryId: 'food',
        type: TransactionType.expense,
        confidence: 0.95,
      ),
    );
    await tester.pumpAndSettle();
    expect(categoryTile(tester).selectedName, 'Transport');
  });

  testWidgets(
    'uncategorized Analysis drilldown keeps the original category ID',
    (tester) async {
      await container
          .read(ledgerProvider)
          .recordTransaction(
            AppTransaction(
              id: 'uncategorized',
              amount: 75,
              date: DateTime.now(),
              accountId: 'cash',
              categoryId: '',
              type: TransactionType.expense,
            ),
          );
      await launch(tester, const AnalysisScreen());
      await tester.scrollUntilVisible(
        find.text('Top Categories'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      final drilldown = find.ancestor(
        of: find.text('Uncategorized'),
        matching: find.byType(PressableScale),
      );
      expect(drilldown, findsOneWidget);
      await tester.ensureVisible(drilldown);
      await tester.tap(drilldown);
      await tester.pumpAndSettle();
      expect(container.read(transactionFilterProvider).categoryIds, {''});
      expect(container.read(activityTabProvider), 1);
      expect(
        container
            .read(filteredTransactionsProvider)
            .requireValue
            .map((tx) => tx.id),
        ['uncategorized'],
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets('forecast keeps details optional at text scale $scale', (
      tester,
    ) async {
      await launch(tester, const AnalysisScreen(), scale: scale);
      expect(find.text('Spending Trend'), findsOneWidget);
      if (scale == 1) {
        expect(
          tester.getTopLeft(find.text('Spending Trend')).dy,
          lessThan(844),
        );
        await capture(tester, 'analysis-compact-forecast');
      }
      await tester.scrollUntilVisible(
        find.text('Details'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      expect(find.byIcon(KoinIcons.warning), findsOneWidget);
      expect(find.text('Possible balance range'), findsNothing);
      expect(find.text('Expected income'), findsNothing);
      expect(find.text(r'$600.00'), findsOneWidget);
      await capture(tester, 'forecast-scale-$scale');
      await tester.ensureVisible(find.text('Details'));
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      expect(find.text('Possible balance range'), findsNothing);
      expect(find.text('Expected income'), findsOneWidget);
      expect(
        find.textContaining('Your balance may run short on Oct 12'),
        findsOneWidget,
      );
      if (scale == 1) await capture(tester, 'forecast-details');
      await tester.ensureVisible(find.text('How this is estimated'));
      await tester.tap(find.text('How this is estimated'));
      await tester.pumpAndSettle();
      expect(find.text('Possible balance range'), findsOneWidget);
      await tester.ensureVisible(find.text('Possible balance range'));
      if (scale == 1) await capture(tester, 'forecast-explanation');
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('Possible balance range'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('detached period control keeps the spending card full width', (
    tester,
  ) async {
    final now = DateTime.now();
    await container
        .read(ledgerProvider)
        .updateTransaction(
          AppTransaction(
            id: 'expense',
            amount: 300,
            date: now,
            accountId: 'cash',
            categoryId: 'food',
            type: TransactionType.expense,
          ),
        );
    await container
        .read(ledgerProvider)
        .recordTransaction(
          AppTransaction(
            id: 'previous-expense',
            amount: 2650,
            date: DateTime(now.year, now.month - 1, 1),
            accountId: 'cash',
            categoryId: 'food',
            type: TransactionType.expense,
          ),
        );
    for (final width in [390.0, 320.0]) {
      await launch(tester, const AnalysisScreen(), width: width, dark: true);
      final card = find.byType(KoinSummaryCard);
      final cardRect = tester.getRect(card);
      expect(cardRect.width, width - 2 * KoinSpacing.screenInset);
      expect(
        find.descendant(of: card, matching: find.text('Wk')),
        findsNothing,
      );
      expect(
        tester.getRect(find.text('Yr')).right,
        lessThanOrEqualTo(cardRect.right),
      );
      final labelRect = tester.getRect(find.text('Total Spent'));
      if (width == 390) {
        final amount = find.descendant(
          of: card,
          matching: find.text(r'$300.00'),
        );
        final amountRect = tester.getRect(amount);
        expect(amountRect.left - cardRect.left, closeTo(24, 1));
        expect(amountRect.top - labelRect.bottom, lessThanOrEqualTo(16));
        final comparison = find.text('88.7% less than previous month');
        expect(comparison, findsOneWidget);
        expect(
          tester.getTopLeft(comparison).dy,
          greaterThan(
            tester
                .getBottomLeft(
                  find.descendant(of: card, matching: find.text(r'$300.00')),
                )
                .dy,
          ),
        );
        expect(
          tester
              .getTopLeft(
                find.text(AnalysisPeriod.fromIndex(1).formatPeriod(now)),
              )
              .dy,
          greaterThan(cardRect.bottom),
        );
        expect(cardRect.height, lessThan(175));
      }
      await capture(tester, 'detached-selector-dark-$width');
      expect(tester.takeException(), isNull);
    }
    await tester.tap(find.text('Wk'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).analysisFilterIndex, 0);
    tester.view.physicalSize = const Size(377, 844);
    await tester.pumpAndSettle();
    final weekLabel = find.byWidgetPredicate(
      (widget) => widget is Text && (widget.data?.contains('–') ?? false),
    );
    expect(weekLabel, findsOneWidget);
    expect(tester.getSize(weekLabel).height, lessThanOrEqualTo(21));
    await capture(tester, 'spending-toolbar-week');
    await tester.tap(find.text('Mo'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).analysisFilterIndex, 1);
    await tester.tap(find.byTooltip('Hide spending'));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(KoinSummaryCard),
        matching: find.text(r'$300.00'),
      ),
      findsNothing,
    );
    expect(find.text('****'), findsOneWidget);
    expect(container.read(settingsProvider).hideBalance, isTrue);
    await tester.tap(find.byTooltip('Show spending'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).hideBalance, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large spending totals stay inside the summary at all text sizes',
    (tester) async {
      for (final amount in [987654.32, 9876543210.12]) {
        await container
            .read(ledgerProvider)
            .updateTransaction(
              AppTransaction(
                id: 'expense',
                amount: amount,
                date: DateTime.now(),
                accountId: 'cash',
                categoryId: 'food',
                type: TransactionType.expense,
              ),
            );
        await container.read(transactionProvider.notifier).loadTransactions();
        for (final width in [390.0, 320.0]) {
          for (final scale in [1.0, 2.0]) {
            await launch(
              tester,
              const AnalysisScreen(),
              width: width,
              scale: scale,
              dark: true,
            );
            final card = find.byType(KoinSummaryCard);
            final cardRect = tester.getRect(card);
            final amountText = find.descendant(
              of: card,
              matching: find.text(
                container
                    .read(settingsProvider)
                    .currency
                    .formatter
                    .format(amount),
              ),
            );
            expect(amountText, findsOneWidget);
            final amountRect = tester.getRect(amountText);
            expect(amountRect.left, greaterThanOrEqualTo(cardRect.left + 23));
            expect(
              amountRect.right,
              lessThanOrEqualTo(cardRect.right - 23),
            );
            expect(amountRect.bottom, lessThan(cardRect.bottom));
            expect(tester.takeException(), isNull);
            if (width == 390 && scale == 1) {
              await capture(tester, 'large-total-$amount');
            }
          }
        }
      }
    },
  );
}

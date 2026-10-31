import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/bar_chart/bar_chart_renderer.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/providers/effective_transaction_clock_provider.dart';
import 'package:koin/features/analysis/widgets/spending_transactions_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;
  final base = DateTime(2026, 10, 15);
  AppTransaction expense(
    String id,
    double amount,
    DateTime date, {
    TransactionType type = TransactionType.expense,
    bool loan = false,
  }) => AppTransaction(
    id: id,
    note: id,
    amount: amount,
    date: date,
    type: type,
    accountId: 'cash',
    categoryId: 'food',
    isDebtTransfer: loan,
  );
  final records = [
    expense('Lunch', 20, DateTime(2026, 10, 13, 8)),
    expense('Coffee', 5, DateTime(2026, 10, 13, 23, 59, 59, 999, 999)),
    expense('Previous day', 10, DateTime(2026, 10, 12)),
    expense('Next day', 30, DateTime(2026, 10, 14)),
    expense('First of month', 4, DateTime(2026, 10, 1)),
    expense('Last of month', 3, DateTime(2026, 10, 31, 23, 59, 59, 999, 999)),
    expense('Previous month', 100, DateTime(2026, 9, 30, 23, 59)),
    expense('Next month', 80, DateTime(2026, 11, 1)),
    expense('Future expense', 900, DateTime(2026, 11, 2)),
    expense('Loan principal', 500, DateTime(2026, 10, 13), loan: true),
    expense(
      'Income',
      500,
      DateTime(2026, 10, 13),
      type: TransactionType.income,
    ),
    expense(
      'Transfer',
      500,
      DateTime(2026, 10, 13),
      type: TransactionType.transfer,
    ),
  ];
  setUpAll(() async {
    final loader = FontLoader('Outfit');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      loader.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await loader.load();
  });
  tearDown(() => container.dispose());

  Future<void> launch(
    WidgetTester tester, {
    int filter = 0,
    double scale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({'currency_code': 'USD'});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        effectiveTransactionClockProvider.overrideWithValue(
          DateTime(2026, 11, 1, 12),
        ),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(initial: records),
        ),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(
            initial: [
              Account(
                id: 'cash',
                name: 'Cash',
                iconCodePoint: KoinIcons.wallet.codePoint,
                colorHex: '#00D09E',
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
            ],
          ),
        ),
      ],
    );
    await container.read(transactionProvider.future);
    await container.read(accountProvider.future);
    await container.read(categoriesProvider.future);
    container
        .read(transactionFilterProvider.notifier)
        .updateFilter(
          const TransactionFilter(
            type: TransactionType.income,
            sortOrder: TransactionSortOrder.amountDescending,
          ),
        );
    tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final analysis = SpendingAnalysis.calculate(
      transactions: records,
      baseDate: base,
      period: AnalysisPeriod.fromIndex(filter),
      asOf: DateTime(2026, 11, 1, 12),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), scale != 1),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  SpendingTrendChart(
                    expenses: analysis.filteredTransactions,
                    currency: container.read(settingsProvider).currency,
                    filterIndex: filter,
                    baseDate: base,
                    onPeriodSelected: (range) =>
                        SpendingTransactionsSheet.show(context, range),
                  ),
                  SpendingAmountsButton(
                    expenses: analysis.filteredTransactions,
                    currency: container.read(settingsProvider).currency,
                    filterIndex: filter,
                    baseDate: base,
                    onPeriodSelected: (range) =>
                        SpendingTransactionsSheet.show(context, range),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder total() => find.byKey(const ValueKey('spending-detail-total'));
  Future<void> selectAmount(
    WidgetTester tester,
    DateTime date, {
    bool month = false,
  }) async {
    await tester.tap(find.text('View amounts'));
    await tester.pumpAndSettle();
    final row = find.text(
      month ? DateFormat.yMMM().format(date) : DateFormat.yMMMEd().format(date),
    );
    await tester.scrollUntilVisible(
      row,
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  test(
    'analysis includes the full final calendar day of every graph period',
    () {
      container = ProviderContainer();
      for (final period in AnalysisPeriod.values) {
        final range = period.dateRange(base);
        final lastInstant = DateTime(
          range.end.year,
          range.end.month,
          range.end.day + 1,
        ).subtract(const Duration(microseconds: 1));
        final analysis = SpendingAnalysis.calculate(
          transactions: [expense('boundary', 7, lastInstant)],
          baseDate: base,
          period: period,
          asOf: lastInstant.add(const Duration(days: 1)),
        );
        expect(analysis.totalExpense, 7);
      }
    },
  );

  testWidgets(
    'last daily bar and its details include the final instant of the month',
    (tester) async {
      await launch(tester, filter: 1);
      expect(
        tester
            .widget<BarChart>(find.byType(BarChart))
            .data
            .barGroups
            .last
            .barRods
            .single
            .toY,
        3,
      );
      await selectAmount(tester, DateTime(2026, 10, 31));
      expect(tester.widget<Text>(total()).data, r'$3.00');
      expect(find.text('Last of month'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'daily details reconcile with the bar and update after edits without changing filters',
    (tester) async {
      await launch(tester);
      final filter = container.read(transactionFilterProvider);
      await selectAmount(tester, DateTime(2026, 10, 13));
      expect(find.text('October 13, 2026'), findsOneWidget);
      expect(tester.widget<Text>(total()).data, r'$25.00');
      expect(find.text('Spent · 2 transactions'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(
        tester
            .widgetList<TransactionTile>(find.byType(TransactionTile))
            .every((row) => !row.showDate),
        isTrue,
      );
      expect(container.read(transactionFilterProvider), same(filter));
      await container
          .read(transactionProvider.notifier)
          .acceptRecordedTransactions([
            records.first.copyWith(amount: 27),
          ], familyId: 'Lunch');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(total()).data, r'$32.00');
      await container
          .read(transactionProvider.notifier)
          .acceptRecordedTransactions([
            records.first.copyWith(date: DateTime(2026, 10, 14)),
          ], familyId: 'Lunch');
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(total()).data, r'$5.00');
      expect(find.text('Lunch'), findsNothing);
      await tester.tap(find.byTooltip('Close spending details'));
      await tester.pumpAndSettle();
      expect(find.text('Spending amounts'), findsNothing);
      expect(find.byType(SpendingTrendChart).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'year bar opens its calendar month and preserves the graph when closed',
    (tester) async {
      await launch(tester, filter: 2);
      final data = tester.widget<BarChart>(find.byType(BarChart)).data;
      expect(data.barGroups[9].barRods.single.toY, 72);
      final plot = tester.getRect(find.byType(BarChartLeaf));
      await tester.tapAt(
        Offset(plot.left + 9.5 * plot.width / 12, plot.bottom - 5),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SpendingTransactionsSheet), findsOneWidget);
      expect(find.text('October 2026'), findsOneWidget);
      expect(tester.widget<Text>(total()).data, r'$72.00');
      expect(find.text('Spent · 6 transactions'), findsOneWidget);
      expect(
        tester
            .widgetList<TransactionTile>(find.byType(TransactionTile))
            .every((row) => row.showDate),
        isTrue,
      );
      await tester.tap(find.byTooltip('Close spending details'));
      await tester.pumpAndSettle();
      expect(find.byType(SpendingTransactionsSheet), findsNothing);
      expect(
        tester
            .widget<SpendingTrendChart>(find.byType(SpendingTrendChart))
            .filterIndex,
        2,
      );
      expect(
        container.read(transactionFilterProvider).sortOrder,
        TransactionSortOrder.amountDescending,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty dates remain accessible at large text and future spending stays excluded',
    (tester) async {
      await launch(tester, filter: 1, scale: 2);
      await selectAmount(tester, DateTime(2026, 10, 15));
      expect(find.text('No spending on this day'), findsOneWidget);
      expect(tester.widget<Text>(total()).data, r'$0.00');
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Close spending details'));
      await tester.pumpAndSettle();
      // Open a current month directly to cover recorded future entries as well.
      final context = tester.element(find.byType(SpendingAmountsButton));
      SpendingTransactionsSheet.show(
        context,
        DateTimeRange(
          start: DateTime(2026, 11),
          end: DateTime(2026, 12).subtract(const Duration(microseconds: 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(total()).data, r'$80.00');
      expect(find.text('Future expense'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

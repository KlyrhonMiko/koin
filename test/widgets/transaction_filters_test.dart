import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/providers/transaction_history_provider.dart';
import 'package:koin/features/transactions/transactions_list_screen.dart';
import 'package:koin/features/transactions/widgets/filter_bottom_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;
  setUpAll(() async {
    final loader = FontLoader('Outfit');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ]) {
      loader.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await loader.load();
  });
  Future<void> prepare() async {
    SharedPreferences.setMockInitialValues({'currency_code': 'USD'});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(
            initial: [
              for (var i = 0; i < 151; i++)
                AppTransaction(
                  id: 'tx-$i',
                  amount: (i % 17 + 1).toDouble(),
                  date: DateTime(2026, 10, i % 28 + 1, i % 24),
                  type: TransactionType.expense,
                  accountId: 'cash',
                  categoryId: 'food',
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
    await container.read(accountProvider.future);
    await container.read(categoriesProvider.future);
    await container.read(transactionProvider.future);
    await container.read(transactionHistoryProvider.future);
  }

  tearDown(() => container.dispose());

  Future<void> launch(
    WidgetTester tester, {
    double scale = 1,
    double width = 390,
    bool dark = true,
  }) async {
    await prepare();
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(body: TransactionsListScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openFilters(WidgetTester tester) async {
    await tester.tap(
      find.byWidgetPredicate(
        (widget) =>
            widget is PressableScale &&
            widget.semanticLabel == 'Filter transactions',
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'sort draft applies globally, survives loading more, and reset restores date groups',
    (tester) async {
      await launch(tester, width: 1220 / 3.25);
      await openFilters(tester);
      expect(
        tester.getTopLeft(find.text('Filters')).dx,
        KoinSpacing.screenInset,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('transaction-sort-options')))
            .height,
        48,
      );
      await tester.tap(find.text('Lowest amount'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('transaction-sort-options')))
            .height,
        48,
      );
      expect(
        container.read(transactionFilterProvider).sortOrder,
        TransactionSortOrder.newestFirst,
      );
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(
        container.read(transactionFilterProvider).sortOrder,
        TransactionSortOrder.amountAscending,
      );
      expect(find.text('Amount: low to high'), findsOneWidget);
      var history = container.read(transactionHistoryProvider).requireValue;
      expect(history.items.length, 100);
      expect(history.items.first.amount, 1);
      expect(
        container
            .read(pagedTransactionRowsProvider)
            .requireValue
            .every((row) => row.index == 0),
        isTrue,
      );
      expect(
        tester
            .widgetList<TransactionTile>(find.byType(TransactionTile))
            .every((tile) => tile.showDate),
        isTrue,
      );
      await container.read(transactionHistoryProvider.notifier).loadMore();
      await tester.pumpAndSettle();
      history = container.read(transactionHistoryProvider).requireValue;
      expect(history.items.length, 151);
      expect(history.items.map((tx) => tx.id).toSet().length, 151);
      final amounts = history.items.map((tx) => tx.amount).toList();
      expect(amounts, [...amounts]..sort());
      await openFilters(tester);
      await tester.tap(find.text('Highest amount'));
      await tester.pumpAndSettle();
      expect(
        tester
            .getSize(find.byKey(const ValueKey('transaction-sort-options')))
            .height,
        48,
      );
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(
        container
            .read(transactionHistoryProvider)
            .requireValue
            .items
            .first
            .amount,
        17,
      );
      await openFilters(tester);
      await tester.tap(find.text('Reset All'));
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(container.read(transactionFilterProvider).isEmpty, isTrue);
      expect(
        container
            .read(pagedTransactionRowsProvider)
            .requireValue
            .any((row) => row.index == -1),
        isTrue,
      );
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'last amount filter reaches Apply without excess clearance at scale $scale',
      (tester) async {
        await launch(tester, scale: scale, width: 320, dark: scale == 2);
        await openFilters(tester);
        await tester.tap(find.text('Lowest amount'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final sheet = find.byType(FilterBottomSheet);
        final list = find.descendant(
          of: sheet,
          matching: find.byType(ListView),
        );
        await tester.drag(list, const Offset(0, -3000));
        await tester.pumpAndSettle();
        final maxField = find.byWidgetPredicate(
          (widget) =>
              widget is TextField && widget.decoration?.labelText == 'Max',
        );
        final fieldBottom = tester.getBottomLeft(maxField).dy;
        final buttonTop = tester
            .getTopLeft(find.widgetWithText(KoinPrimaryButton, 'Apply Filters'))
            .dy;
        expect(buttonTop - fieldBottom, inInclusiveRange(20, 45));
        expect(tester.takeException(), isNull);
      },
    );
  }
}

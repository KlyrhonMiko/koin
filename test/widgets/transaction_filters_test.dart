import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
  final boundaryKey = GlobalKey();
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
    if (const bool.fromEnvironment('CAPTURE_FILTERS')) {
      for (final entry in {
        'packages/phosphor_icons/PhosphorRegular':
            'packages/phosphor_icons/lib/fonts/Phosphor.ttf',
        'packages/phosphor_icons/PhosphorFill':
            'packages/phosphor_icons/lib/fonts/Phosphor-Fill.ttf',
      }.entries) {
        await (FontLoader(
          entry.key,
        )..addFont(rootBundle.load(entry.value))).load();
      }
    }
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
                  cashbackRule: i < 125
                      ? CashbackRule.fixedFive
                      : CashbackRule.none,
                  cashbackPending: i < 125,
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
          builder: (context, child) => RepaintBoundary(
            key: boundaryKey,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
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

  for (final dark in [false, true]) {
    testWidgets(
      'pending cashback filter fits ${dark ? 'dark large text' : 'light'}',
      (tester) async {
        await launch(
          tester,
          dark: dark,
          scale: dark ? 2 : 1,
          width: dark ? 320 : 390,
        );
        await openFilters(tester);
        final chip = find.byKey(const ValueKey('pending-cashback-filter'));
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(tester.widget<KoinSelectableOption>(chip).selected, isTrue);
        expect(tester.getSize(chip).height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('CAPTURE_FILTERS')) {
          await tester.runAsync(() async {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await Directory('build/filter-preview').create(recursive: true);
            await File(
              'build/filter-preview/pending-${dark ? 'dark-large' : 'light'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.tap(find.text('Apply Filters'));
        await tester.pumpAndSettle();
        expect(
          container.read(transactionFilterProvider).pendingCashbackOnly,
          isTrue,
        );
      },
    );
  }

  testWidgets(
    'pending cashback filter applies, paginates, refreshes and resets',
    (tester) async {
      await launch(tester);
      await openFilters(tester);
      await tester.tap(find.byKey(const ValueKey('pending-cashback-filter')));
      await tester.pumpAndSettle();
      expect(
        container.read(transactionFilterProvider).pendingCashbackOnly,
        isFalse,
      );
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(
        container.read(transactionFilterProvider).pendingCashbackOnly,
        isTrue,
      );
      expect(find.text('Pending cashback'), findsOneWidget);
      var history = container.read(transactionHistoryProvider).requireValue;
      expect(history.items, hasLength(100));
      expect(history.items.every((tx) => tx.cashbackPending), isTrue);
      await container.read(transactionHistoryProvider.notifier).loadMore();
      await tester.pumpAndSettle();
      history = container.read(transactionHistoryProvider).requireValue;
      expect(history.items, hasLength(125));
      final received = history.items.first;
      await container
          .read(transactionProvider.notifier)
          .updateTransaction(
            received.copyWith(
              cashbackPending: false,
              cashbackReceivedAt: () => DateTime.now(),
            ),
          );
      await tester.pumpAndSettle();
      await container.read(transactionHistoryProvider.notifier).loadMore();
      history = container.read(transactionHistoryProvider).requireValue;
      expect(history.items, hasLength(124));
      expect(history.items.any((tx) => tx.id == received.id), isFalse);
      await openFilters(tester);
      await tester.tap(find.text('Reset All'));
      await tester.tap(find.text('Apply Filters'));
      await tester.pumpAndSettle();
      expect(container.read(transactionFilterProvider).isEmpty, isTrue);
    },
  );

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

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/accounts/account_form_screen.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/features/transactions/widgets/cashback_control.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (const bool.fromEnvironment('CAPTURE_CASHBACK')) {
      final font = FontLoader(KoinTypography.fontFamily);
      for (final weight in [
        'Regular',
        'Medium',
        'SemiBold',
        'Bold',
        'ExtraBold',
        'Black',
      ]) {
        font.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
      }
      await font.load();
    }
  });
  final date = DateTime.now().subtract(const Duration(days: 2));
  final account = Account(
    id: 'maribank',
    name: 'MariBank',
    initialBalance: 10000,
    iconCodePoint: KoinIcons.bank.codePoint,
    colorHex: '#008080',
  );
  final category = TransactionCategory(
    id: 'groceries',
    name: 'Groceries',
    type: TransactionType.expense,
    iconCodePoint: KoinIcons.money.codePoint,
    colorHex: '#008080',
  );
  AppTransaction purchase({CashbackRule rule = CashbackRule.none}) =>
      AppTransaction(
        id: 'purchase',
        amount: 1200,
        date: date,
        type: TransactionType.expense,
        categoryId: category.id,
        accountId: account.id,
        cashbackRule: rule,
      );
  late ProviderContainer providers;
  Future<void> setup(List<AppTransaction> initial) async {
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    providers = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(initial: [account]),
        ),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(initial: [category]),
        ),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(initial: initial),
        ),
        savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
        categorySuggesterProvider.overrideWithValue(TestStubSuggesterAdapter()),
      ],
    );
    addTearDown(providers.dispose);
    await providers.read(accountProvider.future);
    await providers.read(categoriesProvider.future);
    await providers.read(transactionProvider.future);
    await providers.read(savingsGoalsProvider.future);
  }

  Future<void> launch(
    WidgetTester tester,
    Widget screen, {
    bool dark = false,
    Size size = const Size(420, 1000),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providers,
        child: MaterialApp(
          theme: AppTheme.getTheme(Colors.teal, dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => screen),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('editor calculates cashback and saves receipt as linked income', (
    tester,
  ) async {
    final source = purchase();
    await setup([source]);
    await launch(tester, AddTransactionScreen(editingTransaction: source));
    expect(
      find.byKey(const ValueKey('cashback_button')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('cashback_button')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('1%'));
    expect(find.text('Cashback · ₱12.00'), findsOneWidget);
    expect(find.text('Cashback received'), findsNothing);
    await tapVisible(tester, find.text('Done'));
    tester.widget<NumPad>(find.byType(NumPad)).onDone();
    await tester.pumpAndSettle();
    final entries = providers.read(transactionProvider).value!;
    expect(entries, hasLength(2));
    expect(entries.singleWhere((t) => t.cashbackSourceId != null).amount, 12);
    expect(
      providers.read(dashboardStatsProvider).accountBalances[account.id],
      8812,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cashback label and rule stay inline without a badge', (
    tester,
  ) async {
    final source = purchase(rule: CashbackRule.onePercent);
    await setup([source, source.cashbackCredit!]);
    await launch(
      tester,
      AddTransactionScreen(editingTransaction: source),
      size: const Size(390, 844),
    );
    final shortcut = find.byKey(const ValueKey('cashback_button'));
    final label = find.descendant(
      of: shortcut,
      matching: find.text('Cashback'),
    );
    final rule = find.descendant(of: shortcut, matching: find.text('1%'));
    expect(tester.getCenter(label).dy, closeTo(tester.getCenter(rule).dy, 1));
    expect(
      find.descendant(of: shortcut, matching: find.byType(Container)),
      findsNothing,
    );
    expect(shortcut.hitTestable(), findsOneWidget);
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(find.text('Cashback received'), findsNothing);
    expect(find.text('Cashback · ₱12.00'), findsOneWidget);
    await tapVisible(tester, find.text('₱5 fixed'));
    await tapVisible(tester, find.text('Done'));
    await tester.tap(find.byKey(const ValueKey('cashback_button')));
    await tester.pumpAndSettle();
    expect(find.text('Cashback · ₱5.00'), findsOneWidget);
  });

  for (final variant in [
    (size: const Size(390, 844), scale: 1.0),
    (size: const Size(320, 568), scale: 1.8),
    (size: const Size(800, 400), scale: 1.0),
  ]) {
    testWidgets(
      'cashback remains accessible at ${variant.size}, scale ${variant.scale}',
      (tester) async {
        final source = purchase();
        await setup([source]);
        await launch(
          tester,
          AddTransactionScreen(editingTransaction: source),
          size: variant.size,
          scale: variant.scale,
        );
        final shortcut = find.byKey(const ValueKey('cashback_button'));
        if (variant.scale > 1.5) {
          await tester.ensureVisible(shortcut);
          await tester.pumpAndSettle();
        }
        expect(shortcut.hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(shortcut);
        await tester.pumpAndSettle();
        expect(find.text('1%').hitTestable(), findsOneWidget);
        await tester.tap(find.text('1%'));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(shortcut.hitTestable(), findsOneWidget);
        expect(find.text('1%'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('cashback shares the account row and leaves category visible', (
    tester,
  ) async {
    final source = purchase();
    await setup([source]);
    await launch(
      tester,
      AddTransactionScreen(editingTransaction: source),
      size: const Size(390, 844),
    );
    final shortcut = find.byKey(const ValueKey('cashback_button'));
    final accountTile = find.ancestor(
      of: shortcut,
      matching: find.byType(SelectionTile),
    );
    expect(tester.getSize(accountTile).height, 72);
    expect(
      tester.getRect(accountTile).contains(tester.getCenter(shortcut)),
      isTrue,
    );
    expect(
      find.widgetWithText(SelectionTile, 'Groceries').hitTestable(),
      findsOneWidget,
    );
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(find.text('Calculated from ₱1,200.00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('amount and savings message stay centered inside the header', (
    tester,
  ) async {
    final source = purchase().copyWith(amount: 9500);
    await setup([source]);
    await providers
        .read(savingsRepositoryProvider)
        .insertSavingsGoal(
          SavingsGoal(
            id: 'reserve',
            name: 'Reserve',
            currentAmount: 1000,
            isStash: true,
            linkedAccountId: account.id,
            startDate: date,
          ),
        );
    providers.invalidate(savingsGoalsProvider);
    await providers.read(savingsGoalsProvider.future);
    await launch(
      tester,
      AddTransactionScreen(editingTransaction: source),
      size: const Size(390, 844),
    );
    final amount = find.text('9500');
    final currency = find.text('PHP');
    final savings = find.textContaining('from savings');
    final fields = find.byKey(const ValueKey('transaction-fields-section'));
    expect(savings, findsOneWidget);
    expect(tester.getCenter(currency).dx, closeTo(195, 1));
    expect(tester.getCenter(savings).dx, closeTo(195, 20));
    expect(
      tester.getBottomRight(currency).dy,
      lessThan(tester.getTopLeft(amount).dy),
    );
    expect(
      tester.getBottomRight(savings).dy,
      lessThan(tester.getTopLeft(fields).dy),
    );
    final topGap =
        tester.getTopLeft(currency).dy -
        tester.getBottomRight(find.byType(TransactionTypeSelector)).dy;
    final bottomGap =
        tester.getTopLeft(fields).dy - tester.getBottomRight(savings).dy;
    expect(bottomGap, closeTo(topGap, 8));
    expect(
      find.widgetWithText(SelectionTile, 'Groceries').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'cashback credit opens its source; account shows total and monthly cashback',
    (tester) async {
      final pending = purchase(rule: CashbackRule.fixedFive);
      final received = purchase(rule: CashbackRule.onePercent)
          .copyWith(id: 'received', cashbackReceivedAt: () => DateTime.now());
      await setup([
        pending,
        pending.cashbackCredit!,
        received,
        received.cashbackCredit!,
      ]);
      await launch(tester, AccountFormScreen(account: account));
      await tester.ensureVisible(find.text('Total cashback'));
      await tester.pumpAndSettle();
      expect(find.text('₱17.00'), findsNWidgets(2));
      expect(find.text('This month'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: providers,
          child: MaterialApp(
            theme: AppTheme.getTheme(Colors.teal, false),
            home: Scaffold(
              body: TransactionTile(
                transaction: received.cashbackCredit!,
                currency: Currency.defaultCurrency,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Cashback'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AddTransactionScreen>(find.byType(AddTransactionScreen))
            .editingTransaction!
            .id,
        received.id,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final dark in [false, true]) {
    for (final largeText in [false, true]) {
      testWidgets(
        'cashback fields fit ${dark ? 'dark' : 'light'} at ${largeText ? 'large' : 'normal'} text',
        (tester) async {
          tester.view.physicalSize = Size(largeText ? 320 : 420, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var rule = CashbackRule.onePercent;
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.getTheme(Colors.teal, dark),
              home: RepaintBoundary(
                key: boundaryKey,
                child: MediaQuery(
                  data: MediaQueryData(
                    textScaler: TextScaler.linear(largeText ? 2 : 1),
                  ),
                  child: Scaffold(
                    body: SafeArea(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: StatefulBuilder(
                          builder: (context, setState) => CashbackControl(
                            amount: 1200,
                            currency: Currency.defaultCurrency,
                            rule: rule,
                            onRuleChanged: (value) =>
                                setState(() => rule = value),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('cashback_button')));
          await tester.pumpAndSettle();
          expect(find.text('Cashback · ₱12.00'), findsOneWidget);
          await tapVisible(tester, find.text('₱5 fixed'));
          expect(find.text('Cashback · ₱5.00'), findsOneWidget);
          expect(find.text('Cashback received'), findsNothing);
          expect(tester.takeException(), isNull);
          await tapVisible(tester, find.text('Done'));
          expect(
            find.byKey(const ValueKey('cashback_button')).hitTestable(),
            findsOneWidget,
          );
          if (!largeText && const bool.fromEnvironment('CAPTURE_CASHBACK')) {
            await tester.runAsync(() async {
              final boundary =
                  boundaryKey.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory('build/cashback-preview').create(recursive: true);
              await File(
                'build/cashback-preview/${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        },
      );
    }
  }
}

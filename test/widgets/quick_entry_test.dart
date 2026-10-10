import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/main_layout.dart';
import 'package:koin/features/transactions/quick_entry_app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late ProviderContainer providers;
  late List<MethodCall> windowCalls;
  late _QuickEntrySuggester suggester;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  setUp(() {
    suggester = _QuickEntrySuggester();
    windowCalls = [];
    messenger.setMockMethodCallHandler(quickWindowChannel, (call) async {
      windowCalls.add(call);
      return null;
    });
    providers = ProviderContainer(
      overrides: [
        categorySuggesterProvider.overrideWithValue(suggester),
        sharedPreferencesProvider.overrideWithValue(prefs),
        savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
        ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(
            initial: [
              Account(
                id: 'cash',
                name: 'Cash',
                iconCodePoint: Icons.payments.codePoint,
                colorHex: '#008080',
                initialBalance: 5000,
              ),
              Account(
                id: 'bank',
                name: 'Bank',
                iconCodePoint: Icons.account_balance.codePoint,
                colorHex: '#008080',
              ),
            ],
          ),
        ),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(
            initial: [
              TransactionCategory(
                id: 'allowance',
                name: 'Allowance',
                iconCodePoint: Icons.payments.codePoint,
                colorHex: '#008080',
                type: TransactionType.income,
              ),
              TransactionCategory(
                id: 'food',
                name: 'Food',
                iconCodePoint: Icons.restaurant.codePoint,
                colorHex: '#008080',
                type: TransactionType.expense,
              ),
            ],
          ),
        ),
        plannedPaymentRepositoryProvider.overrideWithValue(
          InMemoryPlannedPaymentAdapter(
            initial: [
              PlannedPayment(
                id: 'saved-allowance',
                title: 'Flexible allowance',
                amount: 500,
                type: TransactionType.income,
                categoryId: 'allowance',
                accountId: 'cash',
                startDate: DateTime(2026, 1, 1),
                nextDate: DateTime(2099, 1, 1),
                frequency: PaymentFrequency.flexible,
              ),
              PlannedPayment(
                id: 'bill',
                title: 'Phone bill',
                amount: 100,
                type: TransactionType.expense,
                categoryId: 'food',
                accountId: 'cash',
                startDate: DateTime(2026, 1, 1),
                nextDate: DateTime(2099, 1, 1),
                frequency: PaymentFrequency.monthly,
              ),
            ],
          ),
        ),
      ],
    );
  });
  tearDown(() {
    providers.dispose();
    messenger.setMockMethodCallHandler(quickWindowChannel, null);
  });
  Future<void> launch(
    WidgetTester tester, {
    bool dark = false,
    double height = 680,
    double width = 360,
    bool settle = true,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await prefs.setInt(
      'theme_mode',
      dark ? ThemeMode.dark.index : ThemeMode.light.index,
    );
    providers.invalidate(settingsProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providers,
        child: const QuickEntryApp(),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, String text) async {
    final exact = find.text(text);
    final finder = exact.evaluate().isNotEmpty
        ? exact
        : find.textContaining('$text • ');
    await tester.ensureVisible(finder.last);
    await tester.tap(finder.last);
    await tester.pumpAndSettle();
  }

  Future<void> amount(WidgetTester tester, String digits) async {
    await tap(tester, 'C');
    for (final digit in digits.split('')) {
      await tap(tester, digit);
    }
    await tap(tester, 'Next');
  }

  Future<void> pickAccount(
    WidgetTester tester,
    String placeholder,
    String account,
  ) async {
    await tap(tester, placeholder);
    expect(find.byType(AnimatedCounter), findsNothing);
    await tap(tester, account);
  }

  for (final reduceMotion in [false, true]) {
    testWidgets('window enters and exits smoothly, reduced=$reduceMotion', (
      tester,
    ) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: reduceMotion);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await launch(tester, settle: false);
      final handle = find.byKey(const ValueKey('quick-entry-drag-area'));
      final initialY = tester.getTopLeft(handle).dy;
      if (reduceMotion) {
        expect(initialY, closeTo(0, 1));
      } else {
        expect(initialY, greaterThan(20));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      if (!reduceMotion) {
        expect(tester.getTopLeft(handle).dy, lessThan(initialY));
        expect(tester.getTopLeft(handle).dy, greaterThan(0));
      }
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(handle).dy, closeTo(0, 1));
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pump();
      expect(windowCalls.where((c) => c.method == 'close'), isEmpty);
      // Back during the exit must not issue a second close request.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(windowCalls.where((c) => c.method == 'close'), hasLength(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'standalone selector never builds the main app and cancel saves nothing',
    (tester) async {
      await launch(tester, height: 360);
      expect(find.byType(MainLayout), findsNothing);
      expect(find.text('Claim income'), findsOneWidget);
      expect(find.text('Add transaction'), findsOneWidget);
      expect(find.text('Open app'), findsOneWidget);
      expect(
        (windowCalls.last.arguments as Map)['height'],
        closeTo(
          tester.getBottomRight(find.widgetWithText(ListTile, 'Open app')).dy +
              16,
          1,
        ),
      );
      await tester.tap(find.byTooltip('Cancel'));
      await tester.pumpAndSettle();
      expect(windowCalls.where((c) => c.method == 'close'), hasLength(1));
      expect(await providers.read(transactionProvider.future), isEmpty);
    },
  );
  testWidgets('Open app requests the full app without saving a transaction', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, 'Open app');
    expect(windowCalls.where((c) => c.method == 'openApp'), hasLength(1));
    expect(find.byType(MainLayout), findsNothing);
    expect(await providers.read(transactionProvider.future), isEmpty);
  });
  for (final dark in [false, true]) {
    testWidgets(
      'flexible claim saves once on Next and shows success, dark=$dark',
      (tester) async {
        await launch(tester, dark: dark);
        await tap(tester, 'Claim income');
        expect((windowCalls.last.arguments as Map)['height'], lessThan(220));
        expect(find.text('Phone bill'), findsNothing);
        await tap(tester, 'Flexible allowance');
        expect(find.text('Cash'), findsOneWidget);
        expect(find.text('Category'), findsOneWidget);
        if (!dark) {
          tester.view.physicalSize = Size(
            360,
            ((windowCalls.last.arguments as Map)['height'] as num).toDouble(),
          );
          await tester.pumpAndSettle();
          expect(
            tester.getBottomRight(find.byType(NumPad)).dy,
            closeTo(tester.view.physicalSize.height, 1),
          );
        }
        await tap(tester, 'C');
        for (final digit in '750'.split('')) {
          await tap(tester, digit);
        }
        expect(await providers.read(transactionProvider.future), isEmpty);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
        await tap(tester, 'Flexible allowance');
        expect(find.text('Cash'), findsOneWidget);
        expect(find.text('750'), findsOneWidget);
        final next = tester.widget<NumPad>(find.byType(NumPad)).onDone;
        next();
        next();
        await tester.pumpAndSettle();
        expect(find.text('Confirm income claim'), findsNothing);
        expect(find.text('Confirm & save'), findsNothing);
        final entries = await providers.read(transactionProvider.future);
        expect(entries, hasLength(1));
        expect(entries.single.amount, 750);
        expect(entries.single.plannedPaymentId, 'saved-allowance');
        expect(entries.single.accountId, 'cash');
        expect(windowCalls.where((c) => c.method == 'close'), isEmpty);
        expect(find.text('Income claimed'), findsOneWidget);
        expect(
          tester
              .widget<FilledButton>(find.widgetWithText(FilledButton, 'Close'))
              .focusNode!
              .hasFocus,
          isTrue,
        );
        expect(
          tester
              .widgetList<Semantics>(find.byType(Semantics))
              .any((widget) => widget.properties.liveRegion == true),
          isTrue,
        );
        expect((windowCalls.last.arguments as Map)['height'], lessThan(260));
        await tap(tester, 'Close');
        expect(windowCalls.where((c) => c.method == 'close'), hasLength(1));
        final schedules = await providers.read(plannedPaymentProvider.future);
        expect(schedules, hasLength(2));
        expect(
          schedules.firstWhere((p) => p.id == 'saved-allowance').frequency,
          PaymentFrequency.flexible,
        );
      },
    );
  }
  testWidgets('account selector separates spendable funds from savings', (
    tester,
  ) async {
    final accounts = await providers.read(accountProvider.future);
    await providers
        .read(accountProvider.notifier)
        .updateAccount(
          accounts
              .firstWhere((a) => a.id == 'cash')
              .copyWith(initialBalance: 263),
        );
    await providers.read(savingsGoalsProvider.future);
    await providers
        .read(savingsGoalsProvider.notifier)
        .addGoal(
          SavingsGoal(
            id: 'reserved',
            name: 'End of Year',
            startDate: DateTime(2026),
            linkedAccountId: 'cash',
            currentAmount: 200,
            isStash: true,
          ),
        );
    await launch(tester);
    await tap(tester, 'Add transaction');
    await tap(tester, 'Expense');
    await tap(tester, 'Select account');
    final cashCard = find.byWidgetPredicate(
      (widget) => widget is AccountItem && widget.account.id == 'cash',
    );
    expect(tester.widget<AccountItem>(cashCard).balance, 63);
    final symbol = providers.read(settingsProvider).currency.symbol;
    expect(find.text('${symbol}200 in savings'), findsOneWidget);
    await tap(tester, 'Cash');
    final label = find.text('Spendable · ${symbol}200 in savings');
    expect(label, findsOneWidget);
    expect(find.text('Cash • ${symbol}63'), findsOneWidget);
    expect(find.text('Cash • ${symbol}263'), findsNothing);
    final compactHeight = tester
        .getSize(find.ancestor(of: label, matching: find.byType(SelectionTile)))
        .height;
    final goal = (await providers.read(savingsGoalsProvider.future)).single;
    await providers
        .read(savingsGoalsProvider.notifier)
        .updateGoal(goal.copyWith(includeInDashboardBalance: false));
    await tester.pumpAndSettle();
    expect(find.text('Spendable'), findsOneWidget);
    expect(find.text('Cash • ${symbol}63'), findsOneWidget);
    expect(label, findsNothing);
    await providers
        .read(savingsGoalsProvider.notifier)
        .updateGoal(goal.copyWith(currentAmount: 0));
    await tester.pumpAndSettle();
    final normalHeight = tester
        .getSize(
          find.ancestor(
            of: find.text('Account'),
            matching: find.byType(SelectionTile),
          ),
        )
        .height;
    expect(compactHeight, closeTo(normalHeight, 1));
    await providers.read(savingsGoalsProvider.notifier).updateGoal(goal);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providers,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => showAccountPickerSheet(
                  context: context,
                  ref: ref,
                  selectedAccountId: 'cash',
                  useSpendableBalance: true,
                ),
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tap(tester, 'Open picker');
    expect(tester.widget<AccountItem>(cashCard).balance, 63);
    expect(find.text('${symbol}200 in savings'), findsOneWidget);
    await providers
        .read(savingsGoalsProvider.notifier)
        .updateGoal(goal.copyWith(includeInDashboardBalance: false));
    await tester.pumpAndSettle();
    expect(find.text('${symbol}200 in savings'), findsNothing);
    expect(tester.widget<AccountItem>(cashCard).balance, 63);
    await providers
        .read(savingsGoalsProvider.notifier)
        .updateGoal(goal.copyWith(currentAmount: 100));
    await tester.pumpAndSettle();
    expect(tester.widget<AccountItem>(cashCard).balance, 163);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'custom expense starts with amount and saves directly from details',
    (tester) async {
      await launch(tester);
      await tap(tester, 'Add transaction');
      await tap(tester, 'Expense');
      expect(find.byType(NumPad), findsOneWidget);
      await pickAccount(tester, 'Select account', 'Cash');
      await amount(tester, '125');
      expect(find.byType(DateSelectorTile), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Lunch');
      await tap(tester, 'Select category');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Expense details'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Lunch',
      );
      await tap(tester, 'Select category');
      await tap(tester, 'Food');
      await tap(tester, 'Edit');
      expect(find.textContaining('Cash • '), findsOneWidget);
      expect(find.textContaining('Available:'), findsNothing);
      await tap(tester, 'Next');
      expect(find.text('Food'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Lunch',
      );
      expect(find.text('Confirm transaction'), findsNothing);
      expect(await providers.read(transactionProvider.future), isEmpty);
      final save = tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Save transaction'),
          )
          .onPressed!;
      save();
      save();
      await tester.pumpAndSettle();
      final entries = await providers.read(transactionProvider.future);
      expect(entries, hasLength(1));
      expect(entries.single.note, 'Lunch');
      expect(entries.single.amount, 125);
      expect(entries.single.categoryId, 'food');
      expect(entries.single.plannedPaymentId, isNull);
    },
  );
  testWidgets(
    'Next shows a content-sized savings sheet before expense details',
    (tester) async {
      await providers
          .read(savingsRepositoryProvider)
          .insertSavingsGoal(
            SavingsGoal(
              id: 'reserved',
              name: 'End of Year',
              currentAmount: 4900,
              startDate: DateTime(2026),
              linkedAccountId: 'cash',
            ),
          );
      await launch(tester, dark: true, height: 440);
      await tap(tester, 'Add transaction');
      await tap(tester, 'Expense');
      await pickAccount(tester, 'Select account', 'Cash');
      await amount(tester, '125');
      final expenseHeight =
          (windowCalls.last.arguments as Map)['height'] as int;
      expect(find.text('Use savings for this?'), findsOneWidget);
      final sheetHeight = (windowCalls.last.arguments as Map)['height'] as int;
      expect(sheetHeight, greaterThanOrEqualTo(expenseHeight));
      // Simulate Android applying the requested window size.
      tester.view.physicalSize = Size(360, sheetHeight.toDouble());
      await tester.pumpAndSettle();
      final sheetScrollable = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(sheetScrollable).position.maxScrollExtent,
        0,
      );
      expect(find.text('Expense amount'), findsOneWidget);
      expect(find.text('Expense details'), findsNothing);
      final underlyingOpacity = find.ancestor(
        of: find.byKey(const ValueKey('quick-entry-drag-area')),
        matching: find.byType(Opacity),
      );
      expect(tester.widget<Opacity>(underlyingOpacity).opacity, 1);
      final barrier = tester.widget<ModalBarrier>(
        find.byType(ModalBarrier).last,
      );
      expect(barrier.color, isNull);
      final sheet = find.byType(BottomSheet);
      final top = tester.getTopLeft(sheet);
      final gesture = await tester.startGesture(
        Offset(top.dx + tester.getSize(sheet).width / 2, top.dy + 24),
      );
      await gesture.moveBy(const Offset(0, 30));
      await tester.pump();
      expect(tester.widget<Opacity>(underlyingOpacity).opacity, 1);
      await gesture.up();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.widget<Opacity>(underlyingOpacity).opacity, 1);
      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(underlyingOpacity).opacity, 1);
      expect(await providers.read(transactionProvider.future), isEmpty);
      expect(
        (await providers.read(savingsRepositoryProvider).getSavingsGoals())
            .single
            .currentAmount,
        4900,
      );
      await tap(tester, 'Next');
      expect(find.text('Use savings for this?'), findsOneWidget);
      await tap(tester, 'Release & continue');
      expect(find.text('Expense details'), findsOneWidget);
      expect(
        (await providers.read(savingsRepositoryProvider).getSavingsGoals())
            .single
            .currentAmount,
        4875,
      );
      expect(await providers.read(transactionProvider.future), isEmpty);
      await tap(tester, 'Select category');
      await tap(tester, 'Food');
      await tap(tester, 'Save transaction');
      expect(find.byType(BottomSheet), findsNothing);
      expect(await providers.read(transactionProvider.future), hasLength(1));
    },
  );

  testWidgets('swiping the handle closes without saving; short drags return', (
    tester,
  ) async {
    await launch(tester);
    final handle = find.byKey(const ValueKey('quick-entry-drag-area'));
    await tester.drag(handle, const Offset(0, 25));
    await tester.pumpAndSettle();
    expect(windowCalls.where((c) => c.method == 'close'), isEmpty);
    await tester.drag(handle, const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(windowCalls.where((c) => c.method == 'close'), hasLength(1));
    expect(await providers.read(transactionProvider.future), isEmpty);
  });
  testWidgets('re-grabbing a returning sheet preserves its visible offset', (
    tester,
  ) async {
    await launch(tester);
    final handle = find.byKey(const ValueKey('quick-entry-drag-area'));
    await tester.drag(handle, const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 16));
    final before = tester.getTopLeft(handle).dy;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(tester.getTopLeft(handle).dy, greaterThanOrEqualTo(before - 1));
    await gesture.moveBy(const Offset(0, -30));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(handle).dy, closeTo(0, 1));
    expect(windowCalls.where((c) => c.method == 'close'), isEmpty);
  });
  for (final landscape in [false, true]) {
    testWidgets(
      'large text keeps picker header available, landscape=$landscape',
      (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = landscape
            ? 1.5
            : 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        for (var index = 0; index < 16; index++) {
          await providers
              .read(categoryRepositoryProvider)
              .insertCategory(
                TransactionCategory(
                  id: 'extra-$index',
                  name: 'Category $index',
                  iconCodePoint: Icons.restaurant.codePoint,
                  colorHex: '#008080',
                  type: TransactionType.expense,
                ),
              );
        }
        await launch(
          tester,
          width: landscape ? 680 : 360,
          height: landscape ? 360 : 680,
        );
        await tap(tester, 'Add transaction');
        await tap(tester, 'Expense');
        expect(find.byType(NumPad), findsOneWidget);
        await pickAccount(tester, 'Select account', 'Cash');
        await amount(tester, '125');
        await tap(tester, 'Select category');
        final before = tester.getTopLeft(find.byTooltip('Cancel'));
        await tester.ensureVisible(find.text('Category 15'));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byTooltip('Cancel')), before);
        await tap(tester, 'Category 15');
        expect(find.text('Expense details'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('a fast upward return never moves above the window edge', (
    tester,
  ) async {
    await launch(tester);
    final handle = find.byKey(const ValueKey('quick-entry-drag-area'));
    await tester.drag(handle, const Offset(0, 40));
    await tester.pump(const Duration(milliseconds: 16));
    await tester.fling(handle, const Offset(0, -30), 2000);
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.getTopLeft(handle).dy, greaterThanOrEqualTo(0));
    }
    await tester.pumpAndSettle();
    expect(windowCalls.where((c) => c.method == 'close'), isEmpty);
  });
  testWidgets('keypad has named accessible buttons and errors announce', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await launch(tester);
    await tap(tester, 'Add transaction');
    await tap(tester, 'Income');
    expect(find.byType(NumPad), findsOneWidget);
    expect(find.bySemanticsLabel('Delete last digit'), findsOneWidget);
    expect(find.bySemanticsLabel('Next'), findsOneWidget);
    await tap(tester, 'Next');
    final error = find.ancestor(
      of: find.text('Enter an amount greater than zero'),
      matching: find.byType(Semantics),
    );
    expect(
      tester
          .widgetList<Semantics>(error)
          .any((widget) => widget.properties.liveRegion == true),
      isTrue,
    );
    expect(
      tester.getBottomRight(find.text('Enter an amount greater than zero')).dy,
      lessThan(tester.getTopLeft(find.text('Select account')).dy),
    );
    await tap(tester, '1');
    expect(find.text('Enter an amount greater than zero'), findsNothing);
    semantics.dispose();
  });
  testWidgets('reduced motion returns the sheet immediately', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await launch(tester);
    final handle = find.byKey(const ValueKey('quick-entry-drag-area'));
    await tester.drag(handle, const Offset(0, 40));
    await tester.pump();
    expect(tester.getTopLeft(handle).dy, closeTo(0, 1));
    expect(windowCalls.where((c) => c.method == 'close'), isEmpty);
  });
  testWidgets('transfer receives full amount and records the fee atomically', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, 'Add transaction');
    await tap(tester, 'Transfer');
    expect(find.byType(NumPad), findsOneWidget);
    await pickAccount(tester, 'Select account', 'Cash');
    await amount(tester, '500');
    await pickAccount(tester, 'Select receiving account', 'Bank');
    await tester.enterText(find.byType(TextField).last, '20');
    expect(find.text('Amount received'), findsOneWidget);
    expect(find.text('Total deducted'), findsOneWidget);
    expect(await providers.read(transactionProvider.future), isEmpty);
    await tap(tester, 'Save transaction');
    final entries = await providers.read(transactionProvider.future);
    expect(entries, hasLength(2));
    final transfer = entries.firstWhere(
      (t) => t.type == TransactionType.transfer,
    );
    expect(transfer.amount, 500);
    expect(transfer.accountId, 'cash');
    expect(transfer.toAccountId, 'bank');
    expect(
      entries.firstWhere((t) => t.type == TransactionType.expense).amount,
      20,
    );
  });
  testWidgets('transfer balance check includes the sending account fee', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, 'Add transaction');
    await tap(tester, 'Transfer');
    await pickAccount(tester, 'Select account', 'Cash');
    await amount(tester, '500');
    await pickAccount(tester, 'Select receiving account', 'Bank');
    await tester.enterText(find.byType(TextField).last, '20');
    final repository = providers.read(accountRepositoryProvider);
    final cash = (await repository.getAccounts()).firstWhere(
      (a) => a.id == 'cash',
    );
    await repository.updateAccount(cash.copyWith(initialBalance: 500));
    await tap(tester, 'Save transaction');
    expect(find.text('Insufficient balance in Cash'), findsOneWidget);
    expect(await providers.read(transactionProvider.future), isEmpty);
  });
  testWidgets('empty income list and invalid amounts cannot record anything', (
    tester,
  ) async {
    await providers
        .read(plannedPaymentRepositoryProvider)
        .deletePlannedPayment('saved-allowance');
    await launch(tester);
    await tap(tester, 'Claim income');
    expect(
      find.textContaining('No saved recurring income yet'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tap(tester, 'Add transaction');
    await tap(tester, 'Income');
    expect(find.byType(NumPad), findsOneWidget);
    await tap(tester, 'Next');
    expect(find.text('Enter an amount greater than zero'), findsOneWidget);
    expect(await providers.read(transactionProvider.future), isEmpty);
  });
  testWidgets(
    'changing accounts preserves amount and refreshes available balance',
    (tester) async {
      await launch(tester);
      await tap(tester, 'Add transaction');
      await tap(tester, 'Expense');
      expect(find.byType(NumPad), findsOneWidget);
      await pickAccount(tester, 'Select account', 'Cash');
      await tap(tester, '1');
      await tap(tester, '2');
      await tap(tester, '5');
      final accountSummary =
          'Cash • ${providers.read(settingsProvider).currency.symbol}5,000';
      expect(find.text(accountSummary), findsOneWidget);
      expect(find.textContaining('Available:'), findsNothing);
      expect(
        tester.getTopLeft(find.text('125')).dy,
        lessThan(tester.getTopLeft(find.text(accountSummary)).dy),
      );
      final expression = tester
          .widget<NumPad>(find.byType(NumPad))
          .initialValue;
      await pickAccount(tester, 'Cash', 'Bank');
      expect(
        tester.widget<NumPad>(find.byType(NumPad)).initialValue,
        expression,
      );
      expect(find.text('Amount exceeds available balance'), findsOneWidget);
      await tap(tester, 'Next');
      expect(find.text('Insufficient balance in Bank'), findsOneWidget);
      await tap(tester, 'Bank');
      await tap(tester, 'Cash');
      expect(find.text('Amount exceeds available balance'), findsNothing);
      await tap(tester, 'Next');
      expect(find.text('Expense details'), findsOneWidget);
      expect(find.text('Select account'), findsNothing);
      await tap(tester, 'Edit');
      expect(
        tester.widget<NumPad>(find.byType(NumPad)).initialValue,
        expression,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Add transaction'), findsOneWidget);
      expect(await providers.read(transactionProvider.future), isEmpty);
    },
  );

  testWidgets('insufficient balance stays on amount entry without saving', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, 'Add transaction');
    await tap(tester, 'Expense');
    expect(find.byType(NumPad), findsOneWidget);
    await pickAccount(tester, 'Select account', 'Cash');
    expect(find.textContaining('Cash • '), findsOneWidget);
    expect(find.textContaining('Available:'), findsNothing);
    await amount(tester, '6000');
    expect(find.text('Insufficient balance in Cash'), findsOneWidget);
    expect(find.text('Amount exceeds available balance'), findsOneWidget);
    expect(find.byType(NumPad), findsOneWidget);
    expect(await providers.read(transactionProvider.future), isEmpty);
    expect(windowCalls.where((c) => c.method == 'close'), isEmpty);
  });

  testWidgets(
    'note suggests a category without changing the selected account',
    (tester) async {
      suggester.stubbedSuggestion = const CategorySuggestion(
        categoryId: 'food',
        originAccountId: 'bank',
        type: TransactionType.expense,
        confidence: 0.95,
      );
      await launch(tester);
      await tap(tester, 'Add transaction');
      await tap(tester, 'Expense');
      await pickAccount(tester, 'Select account', 'Cash');
      await amount(tester, '125');
      await tester.enterText(find.byType(TextField), 'Lunch');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(find.text('Food'), findsOneWidget);
      expect(find.textContaining('Suggested from note'), findsOneWidget);
      expect(find.text('Account: Cash'), findsOneWidget);
      expect(suggester.requests.single.signedAmount, -125);
      expect(suggester.requests.single.currentAccountId, 'cash');
      await tap(tester, 'Save transaction');
      final entries = await providers.read(transactionProvider.future);
      expect(entries.single.categoryId, 'food');
      expect(entries.single.accountId, 'cash');
    },
  );

  testWidgets('clearing a note ignores an in-flight suggestion', (
    tester,
  ) async {
    final prediction = Completer<CategorySuggestion?>();
    suggester.pending = prediction;
    await launch(tester);
    await tap(tester, 'Add transaction');
    await tap(tester, 'Expense');
    await pickAccount(tester, 'Select account', 'Cash');
    await amount(tester, '125');
    await tester.enterText(find.byType(TextField), 'Lunch');
    await tester.pump(const Duration(milliseconds: 350));
    expect(suggester.requests, hasLength(1));
    await tester.enterText(find.byType(TextField), '');
    prediction.complete(
      const CategorySuggestion(
        categoryId: 'food',
        type: TransactionType.expense,
        confidence: 0.95,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select category'), findsOneWidget);
    expect(find.textContaining('Suggested from note'), findsNothing);
    await tap(tester, 'Save transaction');
    expect(find.text('Choose a category'), findsOneWidget);
    expect(await providers.read(transactionProvider.future), isEmpty);
  });

  testWidgets('manual category wins over delayed and subsequent suggestions', (
    tester,
  ) async {
    await providers
        .read(categoryRepositoryProvider)
        .insertCategory(
          TransactionCategory(
            id: 'other',
            name: 'Other',
            iconCodePoint: Icons.category.codePoint,
            colorHex: '#008080',
            type: TransactionType.expense,
          ),
        );
    final prediction = Completer<CategorySuggestion?>();
    suggester.pending = prediction;
    await launch(tester);
    await tap(tester, 'Add transaction');
    await tap(tester, 'Expense');
    await pickAccount(tester, 'Select account', 'Cash');
    await amount(tester, '125');
    await tester.enterText(find.byType(TextField), 'Lunch');
    await tester.pump(const Duration(milliseconds: 350));
    await tap(tester, 'Select category');
    await tap(tester, 'Other');
    prediction.complete(
      const CategorySuggestion(
        categoryId: 'food',
        type: TransactionType.expense,
        confidence: 0.95,
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Burger');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(suggester.requests, hasLength(1));
    expect(find.text('Other'), findsOneWidget);
    expect(find.textContaining('Suggested from note'), findsNothing);
    await tap(tester, 'Save transaction');
    expect(
      (await providers.read(transactionProvider.future)).single.categoryId,
      'other',
    );
  });

  testWidgets('saving rechecks debit balance after amount entry', (
    tester,
  ) async {
    await launch(tester);
    await tap(tester, 'Add transaction');
    await tap(tester, 'Expense');
    await pickAccount(tester, 'Select account', 'Cash');
    await amount(tester, '125');
    await tap(tester, 'Select category');
    await tap(tester, 'Food');
    final repository = providers.read(accountRepositoryProvider);
    final cash = (await repository.getAccounts()).firstWhere(
      (a) => a.id == 'cash',
    );
    await repository.updateAccount(cash.copyWith(initialBalance: 100));
    await tap(tester, 'Save transaction');
    expect(find.text('Insufficient balance in Cash'), findsOneWidget);
    expect(find.text('Expense details'), findsOneWidget);
    expect(await providers.read(transactionProvider.future), isEmpty);
  });
}

class _QuickEntrySuggester extends TestStubSuggesterAdapter {
  final requests = <SuggestionContext>[];
  Completer<CategorySuggestion?>? pending;

  @override
  Future<CategorySuggestion?> suggest(SuggestionContext context) {
    requests.add(context);
    return pending?.future ?? super.suggest(context);
  }
}

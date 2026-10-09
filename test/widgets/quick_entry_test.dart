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
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  setUp(() {
    windowCalls = [];
    messenger.setMockMethodCallHandler(quickWindowChannel, (call) async {
      windowCalls.add(call);
      return null;
    });
    providers = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
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
    final finder = find.text(text);
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
  testWidgets(
    'custom expense uses amount, details and confirmation before saving',
    (tester) async {
      await launch(tester);
      await tap(tester, 'Add transaction');
      await tap(tester, 'Expense');
      expect(find.byType(NumPad), findsNothing);
      await tap(tester, 'Cash');
      await amount(tester, '125');
      expect(find.byType(DateSelectorTile), findsNothing);
      await tester.enterText(find.byType(TextField).first, 'Lunch');
      await tap(tester, 'Select category');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Details'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'Lunch',
      );
      await tap(tester, 'Select category');
      await tap(tester, 'Food');
      await tap(tester, 'Next');
      expect(find.text('Confirm transaction'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(await providers.read(transactionProvider.future), isEmpty);
      await tap(tester, 'Confirm & save');
      final entries = await providers.read(transactionProvider.future);
      expect(entries.single.note, 'Lunch');
      expect(entries.single.amount, 125);
      expect(entries.single.categoryId, 'food');
      expect(entries.single.plannedPaymentId, isNull);
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
        expect(find.byType(NumPad), findsNothing);
        await tap(tester, 'Cash');
        await amount(tester, '125');
        await tap(tester, 'Select category');
        final before = tester.getTopLeft(find.byTooltip('Cancel'));
        await tester.ensureVisible(find.text('Category 15'));
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(find.byTooltip('Cancel')), before);
        await tap(tester, 'Category 15');
        expect(find.text('Details'), findsOneWidget);
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
    expect(find.byType(NumPad), findsNothing);
    await tap(tester, 'Cash');
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
      lessThanOrEqualTo(680),
    );
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
  testWidgets(
    'transfer confirms both accounts and records the fee atomically',
    (tester) async {
      await launch(tester);
      await tap(tester, 'Add transaction');
      await tap(tester, 'Transfer');
      expect(find.byType(NumPad), findsNothing);
      await tap(tester, 'Cash');
      await amount(tester, '500');
      await pickAccount(tester, 'Select receiving account', 'Bank');
      await tester.enterText(find.byType(TextField).last, '20');
      await tap(tester, 'Next');
      expect(find.text('Amount received'), findsOneWidget);
      expect(await providers.read(transactionProvider.future), isEmpty);
      await tap(tester, 'Confirm & save');
      final entries = await providers.read(transactionProvider.future);
      expect(entries, hasLength(2));
      final transfer = entries.firstWhere(
        (t) => t.type == TransactionType.transfer,
      );
      expect(transfer.amount, 480);
      expect(transfer.accountId, 'cash');
      expect(transfer.toAccountId, 'bank');
      expect(
        entries.firstWhere((t) => t.type == TransactionType.expense).amount,
        20,
      );
    },
  );
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
    expect(find.byType(NumPad), findsNothing);
    await tap(tester, 'Cash');
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
      expect(find.byType(NumPad), findsNothing);
      await tap(tester, 'Cash');
      await tap(tester, '1');
      await tap(tester, '2');
      await tap(tester, '5');
      final expression = tester
          .widget<NumPad>(find.byType(NumPad))
          .initialValue;
      await tap(tester, 'Cash');
      await tap(tester, 'Bank');
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
      expect(find.text('Details'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<NumPad>(find.byType(NumPad)).initialValue,
        expression,
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(NumPad), findsNothing);
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
    expect(find.byType(NumPad), findsNothing);
    await tap(tester, 'Cash');
    expect(find.textContaining('Available:'), findsOneWidget);
    await amount(tester, '6000');
    expect(find.text('Insufficient balance in Cash'), findsOneWidget);
    expect(find.text('Amount exceeds available balance'), findsOneWidget);
    expect(find.byType(NumPad), findsOneWidget);
    expect(await providers.read(transactionProvider.future), isEmpty);
    expect(windowCalls.where((c) => c.method == 'close'), isEmpty);
  });
}

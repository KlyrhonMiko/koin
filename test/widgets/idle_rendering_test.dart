import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/main_layout.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/features/transactions/widgets/voice_input_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeVoiceNotifier extends VoiceInputNotifier {
  @override
  Future<void> startListening() async {
    state = state.copyWith(isAvailable: true, isListening: true);
  }

  @override
  Future<void> stopListening() async {
    state = state.copyWith(isListening: false);
  }
}

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  ProviderContainer container() => ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      ledgerProvider.overrideWithValue(
        InMemoryLedgerAdapter(
          initial: [
            AppTransaction(
              id: 'coffee',
              note: 'Coffee',
              amount: 25,
              date: DateTime.now(),
              type: TransactionType.expense,
              categoryId: 'food',
              accountId: 'cash',
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
              initialBalance: 100,
              iconCodePoint: Icons.payments.codePoint,
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
              iconCodePoint: Icons.restaurant.codePoint,
              colorHex: '#008080',
              type: TransactionType.expense,
              budget: 10,
            ),
          ],
        ),
      ),
      categorySuggesterProvider.overrideWithValue(TestStubSuggesterAdapter()),
      voiceInputProvider.overrideWith(FakeVoiceNotifier.new),
    ],
  );

  Future<void> pumpScreen(
    WidgetTester tester,
    ProviderContainer providers,
    Widget screen, {
    bool dark = false,
    double width = 420,
    double height = 1600,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providers,
        child: MaterialApp(
          theme: AppTheme.getTheme(Colors.teal, dark),
          home: screen,
        ),
      ),
    );
  }

  for (final dark in [false, true]) {
    testWidgets(
      'main layout with an overspent budget stops rendering when idle (dark=$dark)',
      (tester) async {
        final providers = container();
        addTearDown(providers.dispose);
        providers.read(navigationProvider.notifier).setIndex(2);
        await pumpScreen(tester, providers, const MainLayout(), dark: dark);
        await tester.pumpAndSettle();
        expect(find.byType(FloatingActionButton), findsOneWidget);
        expect(find.text('Food'), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pump(const Duration(seconds: 3));
        expect(tester.binding.hasScheduledFrame, isFalse);
      },
    );
  }

  testWidgets(
    'main transaction form shows keypad immediately and account below amount',
    (tester) async {
      final providers = container();
      addTearDown(providers.dispose);
      await pumpScreen(
        tester,
        providers,
        const AddTransactionScreen(),
        width: 360,
        height: 760,
      );
      await tester.pumpAndSettle();
      expect(find.byType(NumPad), findsOneWidget);
      expect(
        tester
            .getTopLeft(
              find.text(providers.read(settingsProvider).currency.code),
            )
            .dy,
        lessThan(tester.getTopLeft(find.text('Select account')).dy),
      );
      await tester.tap(find.text('7'));
      await tester.pumpAndSettle();
      expect(tester.widget<NumPad>(find.byType(NumPad)).initialValue, '7');
      await tester.tap(find.text('Select account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      expect(find.byType(NumPad), findsOneWidget);
      expect(find.textContaining('Cash • '), findsOneWidget);
      expect(find.textContaining('Available:'), findsNothing);
      expect(tester.widget<NumPad>(find.byType(NumPad)).initialValue, '7');
      expect(
        tester.getTopLeft(find.textContaining('Cash • ')).dy,
        lessThan(tester.getTopLeft(find.byType(NumPad)).dy),
      );
      expect(tester.takeException(), isNull);
      final amountSize = tester.getRect(find.text('7').first).size;
      for (final type in ['Transfer', 'Income', 'Expense', 'Transfer']) {
        await tester.tap(find.text(type));
        for (var frame = 0; frame < 26; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.takeException(), isNull, reason: '$type frame $frame');
          final frameSize = tester.getRect(find.text('7').first).size;
          expect(frameSize.width, closeTo(amountSize.width, 0.1));
          expect(frameSize.height, closeTo(amountSize.height, 0.1));
        }
        expect(find.byType(NumPad), findsOneWidget);
        expect(tester.widget<NumPad>(find.byType(NumPad)).initialValue, '7');
      }
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await tester.tap(find.text('Expense'));
      await tester.pump();
      expect(find.text('Select category'), findsOneWidget);
      expect(find.text('Select destination'), findsNothing);
    },
  );

  testWidgets('transfer fee uses the keypad without opening the keyboard', (
    tester,
  ) async {
    final providers = container();
    addTearDown(providers.dispose);
    await pumpScreen(
      tester,
      providers,
      const AddTransactionScreen(initialType: TransactionType.transfer),
      width: 360,
      height: 900,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();

    final fee = find.byType(TextField);
    final keypadRect = tester.getRect(find.byType(NumPad));
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.getRect(find.byType(NumPad)), keypadRect);
    for (final key in ['0', '.', '5']) {
      await tester.tap(find.text(key).last);
      await tester.pumpAndSettle();
    }
    expect(tester.widget<TextField>(fee).controller!.text, '0.5');
    expect(find.text('7').first, findsOneWidget);

    await tester.tap(find.text('%'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fee).controller!.text, '0.5');
    expect(tester.testTextInput.isVisible, isFalse);

    // A tap on empty header space also returns input to the large amount.
    await tester.tapAt(const Offset(4, 200));
    await tester.pumpAndSettle();
    expect(tester.widget<NumPad>(find.byType(NumPad)).initialValue, '7');
    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();
    expect(tester.widget<NumPad>(find.byType(NumPad)).initialValue, '8');
    expect(tester.widget<TextField>(fee).controller!.text, '0.5');

    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    expect(tester.widget<NumPad>(find.byType(NumPad)).initialValue, '0.5');
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(fee).controller!.text, isEmpty);
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    expect(tester.widget<NumPad>(find.byType(NumPad)).initialValue, '8');
    expect(tester.takeException(), isNull);
  });

  testWidgets('transfer summary updates for fixed and percentage fees', (
    tester,
  ) async {
    final providers = container();
    addTearDown(providers.dispose);
    await pumpScreen(
      tester,
      providers,
      const AddTransactionScreen(initialType: TransactionType.transfer),
      width: 360,
      height: 900,
    );
    await tester.pumpAndSettle();
    final symbol = providers.read(settingsProvider).currency.symbol;
    expect(find.textContaining('Deducted'), findsNothing);
    for (final key in ['5', '0']) {
      await tester.tap(find.text(key).last);
      await tester.pumpAndSettle();
    }
    final amountRect = tester.getRect(find.text('50'));
    final feeRect = tester.getRect(find.byType(TextField));
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    for (final key in ['1', '0']) {
      await tester.tap(find.text(key).last);
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Deducted ${symbol}60 · Receives ${symbol}50'),
      findsOneWidget,
    );
    final summary = find.text('Deducted ${symbol}60 · Receives ${symbol}50');
    expect(tester.getTopLeft(summary).dy, greaterThan(amountRect.bottom));
    expect(tester.getBottomLeft(summary).dy, lessThan(feeRect.top));
    expect(tester.getRect(find.text('50')), amountRect);
    expect(tester.getRect(find.byType(TextField)), feeRect);
    await tester.tap(find.text('%'));
    await tester.pumpAndSettle();
    expect(
      find.text('Deducted ${symbol}55 · Receives ${symbol}50'),
      findsOneWidget,
    );
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(
      find.text('Deducted ${symbol}50 · Receives ${symbol}50'),
      findsOneWidget,
    );
    await tester.tap(find.text('Select account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(EditableText));
    await tester.pumpAndSettle();
    for (final key in ['3', '0']) {
      await tester.tap(find.text(key).last);
      await tester.pumpAndSettle();
    }
    expect(
      find.text('Deducted ${symbol}80 · Receives ${symbol}50'),
      findsOneWidget,
    );
    expect(find.text('Amount exceeds available balance'), findsOneWidget);
    expect(tester.getRect(find.text('50')), amountRect);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Expense'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Deducted'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('balance warning stays below the amount without shrinking it', (
    tester,
  ) async {
    final providers = container();
    addTearDown(providers.dispose);
    await pumpScreen(
      tester,
      providers,
      const AddTransactionScreen(),
      width: 360,
      height: 760,
    );
    await tester.pumpAndSettle();
    for (final key in ['8', '0']) {
      await tester.tap(find.text(key).last);
      await tester.pumpAndSettle();
    }
    final amountRect = tester.getRect(find.text('80'));
    await tester.tap(find.text('Select account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    final warning = find.text('Amount exceeds available balance');
    expect(warning, findsOneWidget);
    expect(tester.getRect(find.text('80')), amountRect);
    expect(tester.getTopLeft(warning).dy, greaterThan(amountRect.bottom));
    expect(
      tester.getBottomLeft(warning).dy,
      lessThan(tester.getTopLeft(find.byType(TextField)).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('note keyboard hands back to keypad without a layout bounce', (
    tester,
  ) async {
    final providers = container();
    addTearDown(providers.dispose);
    await pumpScreen(
      tester,
      providers,
      const AddTransactionScreen(),
      width: 360,
      height: 900,
    );
    tester.view.viewPadding = const FakeViewPadding(bottom: 24);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    await tester.tap(find.text('7'));
    await tester.pumpAndSettle();

    final note = find.byType(TextField).first;
    await tester.tap(note);
    await tester.enterText(note, 'Lunch');
    tester.view.viewInsets = const FakeViewPadding(bottom: 380);
    await tester.pumpAndSettle();
    final currency = find.text(providers.read(settingsProvider).currency.code);
    var previousY = tester.getTopLeft(currency).dy;

    for (final inset in [340.0, 300.0, 260.0, 180.0, 60.0, 0.0]) {
      tester.view.viewInsets = FakeViewPadding(bottom: inset);
      await tester.pump(const Duration(milliseconds: 16));
      final y = tester.getTopLeft(currency).dy;
      expect(y, greaterThanOrEqualTo(previousY - 0.1));
      previousY = y;
      expect(tester.takeException(), isNull);
    }

    // Once the keyboard is gone, the fields must already be in their final
    // position rather than sliding back up as the keypad grows.
    final restoredY = tester.getTopLeft(currency).dy;
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(currency).dy, closeTo(restoredY, 0.1));
    expect(find.byType(NumPad), findsOneWidget);
    expect(tester.widget<TextField>(note).controller!.text, 'Lunch');
    await tester.tap(find.text('8'));
    await tester.pumpAndSettle();
    expect(tester.widget<NumPad>(find.byType(NumPad)).initialValue, '78');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing shows availability with the original debit restored', (
    tester,
  ) async {
    final providers = container();
    addTearDown(providers.dispose);
    final transaction = (await providers.read(
      transactionProvider.future,
    )).single;
    await pumpScreen(
      tester,
      providers,
      AddTransactionScreen(editingTransaction: transaction),
      width: 360,
      height: 760,
    );
    await tester.pumpAndSettle();
    expect(find.byType(NumPad), findsOneWidget);
    expect(find.textContaining('Cash • '), findsOneWidget);
    expect(
      find.textContaining('Cash • ').evaluate().single.widget,
      isA<Text>().having((text) => text.data, 'available', endsWith('100')),
    );
    expect(find.text('Amount exceeds available balance'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('transaction form decorative animations settle', (tester) async {
    final providers = container();
    addTearDown(providers.dispose);
    await pumpScreen(
      tester,
      providers,
      const AddTransactionScreen(),
      width: 480,
    );
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('voice animations stop when listening ends', (tester) async {
    final providers = container();
    addTearDown(providers.dispose);
    await pumpScreen(
      tester,
      providers,
      const Scaffold(body: VoiceInputSheet()),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(providers.read(voiceInputProvider).isListening, isTrue);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await providers.read(voiceInputProvider.notifier).stopListening();
    await tester.pumpAndSettle();
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pump(const Duration(seconds: 3));
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

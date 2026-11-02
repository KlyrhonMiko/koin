import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/providers/effective_transaction_clock_provider.dart';
import 'package:koin/features/accounts/account_form_screen.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:koin/features/transactions/widgets/cashback_control.dart';
import 'package:koin/features/transactions/widgets/voice_input_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _SilentVoiceInput extends VoiceInputNotifier {
  @override
  VoiceInputState build() => VoiceInputState();
  @override
  Future<void> startListening() async {}
  @override
  Future<void> stopListening() async {}
}

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
      for (final entry in {
        'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
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
  final screenBoundaryKey = GlobalKey();
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_CASHBACK')) return;
    await tester.runAsync(() async {
      final boundary =
          key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('build/cashback-preview').create(recursive: true);
      await File('build/cashback-preview/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> setup(
    List<AppTransaction> initial, {
    Account? withAccount,
    List<Account>? withAccounts,
    DateTime? now,
  }) async {
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    providers = ProviderContainer(
      overrides: [
        voiceInputProvider.overrideWith(_SilentVoiceInput.new),
        if (now != null)
          effectiveTransactionClockProvider.overrideWithValue(now),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(
            initial: withAccounts ?? [withAccount ?? account],
          ),
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
          builder: (context, child) => RepaintBoundary(
            key: screenBoundaryKey,
            child: MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
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

  testWidgets('editor remembers cashback independently for each account', (
    tester,
  ) async {
    final other = account.copyWith(
      id: 'other',
      name: 'Other',
      defaultCashbackRule: CashbackRule.fixedFive,
    );
    await setup([], withAccounts: [account, other]);
    await launch(tester, const AddTransactionScreen());
    await tapVisible(tester, find.text('Select account'));
    await tapVisible(tester, find.text('MariBank').last);
    final shortcut = find.byKey(const ValueKey('cashback_button'));
    await tapVisible(tester, shortcut);
    await tapVisible(tester, find.text('1%'));
    await tapVisible(tester, find.text('Done'));
    expect(
      (await providers.read(accountRepositoryProvider).getAccounts())
          .singleWhere((a) => a.id == account.id)
          .defaultCashbackRule,
      CashbackRule.onePercent,
    );
    final sourcePicker = find.byWidgetPredicate(
      (widget) => widget is SelectionTile && widget.label == 'Account',
    );
    await tapVisible(tester, sourcePicker);
    await tapVisible(tester, find.text('Other').last);
    expect(
      find.descendant(of: shortcut, matching: find.text('₱5')),
      findsOneWidget,
    );
    await tapVisible(tester, sourcePicker);
    await tapVisible(tester, find.text('MariBank').last);
    expect(
      find.descendant(of: shortcut, matching: find.text('1%')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await launch(tester, const AddTransactionScreen());
    await tapVisible(tester, find.text('Select account'));
    await tapVisible(tester, find.text('MariBank').last);
    expect(
      find.descendant(of: shortcut, matching: find.text('1%')),
      findsOneWidget,
    );
    await tapVisible(tester, shortcut);
    await tapVisible(tester, find.text('None'));
    await tapVisible(tester, find.text('Done'));
    expect(
      providers
          .read(accountProvider)
          .value!
          .singleWhere((a) => a.id == account.id)
          .defaultCashbackRule,
      CashbackRule.none,
    );
    expect(providers.read(transactionProvider).value, isEmpty);
  });

  testWidgets(
    'editing keeps the recorded cashback rather than the account default',
    (tester) async {
      final source = purchase(rule: CashbackRule.onePercent);
      await setup(
        [source, source.cashbackCredit!],
        withAccount: account.copyWith(
          defaultCashbackRule: CashbackRule.fixedFive,
        ),
      );
      await launch(tester, AddTransactionScreen(editingTransaction: source));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('cashback_button')),
          matching: find.text('1%'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'voice changes from income restore the same account cashback default',
    (tester) async {
      final remembered = account.copyWith(
        defaultCashbackRule: CashbackRule.onePercent,
      );
      await setup([], withAccount: remembered);
      await launch(
        tester,
        const AddTransactionScreen(initialType: TransactionType.income),
      );
      await tapVisible(tester, find.text('Select account'));
      await tapVisible(tester, find.text('MariBank').last);
      await tapVisible(
        tester,
        find.byWidgetPredicate(
          (widget) =>
              widget is PressableScale &&
              widget.semanticLabel == 'Add transaction with voice',
        ),
      );
      Navigator.of(tester.element(find.byType(VoiceInputSheet))).pop(
        ParsedTransactionData(
          type: TransactionType.expense,
          amount: 100,
          account: remembered,
          category: category,
          note: 'Groceries',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('cashback_button')),
          matching: find.text('1%'),
        ),
        findsOneWidget,
      );
    },
  );

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
    'cashback credit opens its source; account separates received and pending cashback',
    (tester) async {
      final pending = purchase(rule: CashbackRule.fixedFive)
          .copyWith(date: DateTime.now(), cashbackPending: true);
      final received = purchase(rule: CashbackRule.onePercent)
          .copyWith(id: 'received', cashbackReceivedAt: () => DateTime.now());
      await setup([pending, received, received.cashbackCredit!]);
      await launch(tester, AccountFormScreen(account: account));
      await capture(tester, screenBoundaryKey, 'account-received-pending');
      await tester.ensureVisible(find.text('Received'));
      await tester.pumpAndSettle();
      expect(find.text('₱12.00'), findsOneWidget);
      expect(find.text('₱5.00'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
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

  testWidgets('delayed account saves cashback as pending from the editor', (
    tester,
  ) async {
    final source = purchase();
    await setup([source], withAccount: account.copyWith(cashbackDelayed: true));
    await launch(tester, AddTransactionScreen(editingTransaction: source));
    await tapVisible(tester, find.byKey(const ValueKey('cashback_button')));
    await tapVisible(tester, find.text('1%'));
    expect(
      find.text('Pending · Excluded from your balance and income.'),
      findsOneWidget,
    );
    expect(find.text('Mark received'), findsOneWidget);
    await tapVisible(tester, find.text('Done'));
    tester.widget<NumPad>(find.byType(NumPad)).onDone();
    await tester.pumpAndSettle();
    final entries = providers.read(transactionProvider).value!;
    expect(entries.single.cashbackPending, isTrue);
    expect(
      providers.read(dashboardStatsProvider).accountBalances[account.id],
      8800,
    );
    expect(providers.read(dashboardStatsProvider).allTimeIncome, 0);
  });

  testWidgets('mark received uses the chosen receipt date and waits for save', (
    tester,
  ) async {
    final source = purchase(rule: CashbackRule.onePercent)
        .copyWith(cashbackPending: true);
    await setup([source], withAccount: account.copyWith(cashbackDelayed: true));
    await launch(tester, AddTransactionScreen(editingTransaction: source));
    await tapVisible(tester, find.byKey(const ValueKey('cashback_button')));
    await tapVisible(
      tester,
      find.byKey(const ValueKey('cashback_receipt_date')),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    final picker = tester.widget<DatePickerDialog>(
      find.byType(DatePickerDialog),
    );
    expect(picker.firstDate, DateUtils.dateOnly(source.date));
    expect(picker.lastDate, DateUtils.dateOnly(DateTime.now()));
    final receipt = DateTime.now().subtract(const Duration(days: 1));
    if (receipt.month != DateTime.now().month) {
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
    }
    await tester.tap(
      find.descendant(
        of: find.byType(DatePickerDialog),
        matching: find.text('${receipt.day}'),
      ),
    );
    await tapVisible(tester, find.text('OK'));
    await tapVisible(tester, find.text('Mark received'));
    expect(
      providers.read(transactionProvider).value!.single.cashbackPending,
      isTrue,
    );
    expect(find.text('Mark received'), findsNothing);
    await tapVisible(tester, find.text('Done'));
    tester.widget<NumPad>(find.byType(NumPad)).onDone();
    await tester.pumpAndSettle();
    final entries = providers.read(transactionProvider).value!;
    expect(entries, hasLength(2));
    final credit = entries.singleWhere((tx) => tx.cashbackSourceId != null);
    expect(credit.date, DateUtils.dateOnly(receipt));
    expect(credit.amount, 12);
    expect(
      entries.singleWhere((tx) => tx.id == source.id).cashbackPending,
      isFalse,
    );
    expect(
      providers.read(dashboardStatsProvider).accountBalances[account.id],
      8812,
    );
  });

  testWidgets('received cashback can be marked pending again and saved', (
    tester,
  ) async {
    final source = purchase(rule: CashbackRule.onePercent).copyWith(
      cashbackReceivedAt: () =>
          DateTime.now().subtract(const Duration(days: 1)),
    );
    await setup([source, source.cashbackCredit!]);
    await launch(tester, AddTransactionScreen(editingTransaction: source));
    await tapVisible(tester, find.byKey(const ValueKey('cashback_button')));
    await tapVisible(tester, find.text('Mark pending'));
    expect(find.text('Mark received'), findsOneWidget);
    expect(providers.read(transactionProvider).value, hasLength(2));
    await tapVisible(tester, find.text('Done'));
    tester.widget<NumPad>(find.byType(NumPad)).onDone();
    await tester.pumpAndSettle();
    final entries = providers.read(transactionProvider).value!;
    expect(entries.single.cashbackPending, isTrue);
    expect(entries.single.cashbackReceivedAt, isNull);
    expect(
      providers.read(dashboardStatsProvider).accountBalances[account.id],
      8800,
    );
    expect(providers.read(dashboardStatsProvider).allTimeIncome, 0);
  });

  testWidgets('future pending cashback cannot be marked received', (
    tester,
  ) async {
    final source = purchase(rule: CashbackRule.onePercent).copyWith(
      cashbackPending: true,
      date: DateTime.now().add(const Duration(days: 2)),
    );
    await setup([source], now: DateTime.now());
    await launch(tester, AddTransactionScreen(editingTransaction: source));
    await tapVisible(tester, find.byKey(const ValueKey('cashback_button')));
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('cashback_mark_received')),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<TextButton>(
            find.byKey(const ValueKey('cashback_receipt_date')),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('zero cashback cannot be marked received', (tester) async {
    final source = purchase(rule: CashbackRule.onePercent)
        .copyWith(amount: 0.49, cashbackPending: true);
    await setup([source]);
    await launch(tester, AddTransactionScreen(editingTransaction: source));
    await tapVisible(tester, find.byKey(const ValueKey('cashback_button')));
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const ValueKey('cashback_mark_received')),
          )
          .onPressed,
      isNull,
    );
    expect(
      find.text('Cashback must be above zero to mark it received.'),
      findsOneWidget,
    );
  });

  for (final largeText in [false, true]) {
    testWidgets(
      'account cashback stays together in ${largeText ? 'dark large text' : 'light'}',
      (tester) async {
        final editedAccount = account.copyWith(
          cashbackDelayed: true,
          initialBalance: largeText ? 1000000000000 : account.initialBalance,
        );
        final pending = purchase(
          rule: largeText ? CashbackRule.onePercent : CashbackRule.fixedFive,
        ).copyWith(cashbackPending: true, amount: largeText ? 123456789 : 1200);
        final received = purchase(rule: CashbackRule.onePercent)
            .copyWith(id: 'received', amount: largeText ? 123456789 : 1200);
        await setup([
          pending,
          received,
          received.cashbackCredit!,
        ], withAccount: editedAccount);
        await launch(
          tester,
          AccountFormScreen(account: editedAccount),
          dark: largeText,
          size: Size(largeText ? 320 : 390, 1000),
          scale: largeText ? 2 : 1,
        );
        final section = find.byKey(const ValueKey('account_cashback_section'));
        await tester.ensureVisible(section);
        await tester.pumpAndSettle();
        for (final label in [
          'Cashback',
          'Received',
          'Pending',
          'Cashback timing',
          'Instant',
          'Delayed',
        ]) {
          expect(
            find.descendant(of: section, matching: find.text(label)),
            findsOneWidget,
          );
        }
        expect(
          find.descendant(of: section, matching: find.text('Account settings')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        await capture(
          tester,
          screenBoundaryKey,
          'account-group-${largeText ? 'dark-large' : 'light'}',
        );
      },
    );
  }

  testWidgets(
    'account timing saves without changing existing received cashback',
    (tester) async {
      final source = purchase(rule: CashbackRule.onePercent);
      await setup([source, source.cashbackCredit!]);
      await launch(tester, AccountFormScreen(account: account));
      await tapVisible(tester, find.text('Delayed'));
      await capture(tester, screenBoundaryKey, 'account-timing');
      await tapVisible(tester, find.text('Save Changes'));
      final updated = providers.read(accountProvider).value!.single;
      expect(updated.cashbackDelayed, isTrue);
      expect(
        providers.read(dashboardStatsProvider).accountBalances[account.id],
        8812,
      );
      await launch(tester, AddTransactionScreen(editingTransaction: source));
      await tapVisible(tester, find.byKey(const ValueKey('cashback_button')));
      expect(find.text('Mark received'), findsNothing);
      await tapVisible(tester, find.text('Done'));
      tester.widget<NumPad>(find.byType(NumPad)).onDone();
      await tester.pumpAndSettle();
      expect(providers.read(transactionProvider).value, hasLength(2));
      expect(
        providers.read(dashboardStatsProvider).accountBalances[account.id],
        8812,
      );
    },
  );

  for (final pending in [false, true]) {
    testWidgets(
      'transaction row shows ${pending ? 'pending' : 'received'} cashback',
      (tester) async {
        final source = purchase(rule: CashbackRule.onePercent)
            .copyWith(cashbackPending: pending);
        await setup([source]);
        await launch(
          tester,
          Scaffold(
            body: TransactionTile(
              transaction: source,
              currency: Currency.defaultCurrency,
            ),
          ),
        );
        expect(
          find.text('₱12.00 cashback ${pending ? 'pending' : 'received'}'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final dark in [false, true]) {
    for (final largeText in [false, true]) {
      for (final delayed in [false, true]) {
        testWidgets(
          '${delayed ? 'delayed' : 'instant'} cashback fields fit ${dark ? 'dark' : 'light'} at ${largeText ? 'large' : 'normal'} text',
          (tester) async {
            tester.view.physicalSize = Size(largeText ? 320 : 420, 1000);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            var rule = CashbackRule.onePercent;
            var pending = delayed;
            DateTime? receivedAt;
            final boundaryKey = GlobalKey();
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.getTheme(Colors.teal, dark),
                builder: (context, child) => RepaintBoundary(
                  key: boundaryKey,
                  child: MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      textScaler: TextScaler.linear(largeText ? 2 : 1),
                    ),
                    child: child!,
                  ),
                ),
                home: Scaffold(
                  body: SafeArea(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: StatefulBuilder(
                        builder: (context, setState) => CashbackControl(
                          amount: 1200,
                          currency: Currency.defaultCurrency,
                          rule: rule,
                          pending: pending,
                          defaultPending: delayed,
                          transactionDate: date,
                          receivedAt: receivedAt,
                          onReceived: (value) => setState(() {
                            pending = false;
                            receivedAt = value;
                          }),
                          onPending: () => setState(() {
                            pending = true;
                            receivedAt = null;
                          }),
                          onRuleChanged: (value) =>
                              setState(() => rule = value),
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
            final name =
                '${delayed ? 'delayed' : 'instant'}-${dark ? 'dark' : 'light'}-${largeText ? 'large' : 'normal'}';
            await capture(tester, boundaryKey, name);
            if (delayed) {
              await tapVisible(tester, find.text('Mark received'));
              expect(pending, isFalse);
              expect(receivedAt, isNotNull);
              expect(tester.takeException(), isNull);
              await capture(tester, boundaryKey, 'received-$name');
              await tapVisible(tester, find.text('Mark pending'));
              expect(pending, isTrue);
              expect(receivedAt, isNull);
              expect(find.text('Mark received'), findsOneWidget);
            }
            await tapVisible(tester, find.text('Done'));
            expect(
              find.byKey(const ValueKey('cashback_button')).hitTestable(),
              findsOneWidget,
            );
          },
        );
      }
    }
  }
}

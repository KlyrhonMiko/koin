import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/widgets/savings_log_sheet.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedFeedback extends TestStubSuggesterAdapter {
  late final completion = Completer<void>();

  @override
  Future<void> recordFeedback({
    required String text,
    required double amount,
    required TransactionType type,
    required String originAccountId,
    required String destinationId,
    bool isTransfer = false,
  }) => completion.future;
}

void main() {
  late ProviderContainer providers;
  late _DelayedFeedback suggester;
  final account = Account(
    id: 'cash',
    name: 'Cash',
    initialBalance: 100,
    iconCodePoint: KoinIcons.wallet.codePoint,
    colorHex: '#008080',
  );
  final goal = SavingsGoal(
    id: 'stash',
    name: 'Reserve',
    currentAmount: 0,
    isStash: true,
    linkedAccountId: 'cash',
    startDate: DateTime(2026),
  );
  final food = TransactionCategory(
    id: 'food',
    name: 'Food',
    type: TransactionType.expense,
    iconCodePoint: KoinIcons.forkKnife.codePoint,
    colorHex: '#008080',
  );
  setUp(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    final prefs = await SharedPreferences.getInstance();
    suggester = _DelayedFeedback();
    providers = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        categorySuggesterProvider.overrideWithValue(suggester),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(
            initial: [
              account,
              account.copyWith(id: 'bank', name: 'Bank', initialBalance: 0),
            ],
          ),
        ),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(initial: [food]),
        ),
        ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
        savingsRepositoryProvider.overrideWithValue(
          InMemorySavingsAdapter(initial: [goal]),
        ),
      ],
    );
  });
  tearDown(() => providers.dispose());

  Future<void> launch(WidgetTester tester, Widget screen) async {
    await providers.read(accountProvider.future);
    await providers.read(categoriesProvider.future);
    await providers.read(transactionProvider.future);
    await providers.read(savingsGoalsProvider.future);
    tester.view.physicalSize = const Size(420, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providers,
        child: MaterialApp(
          theme: AppTheme.getTheme(Colors.teal, false),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute<void>(builder: (_) => screen)),
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

  Future<void> fillExpense(WidgetTester tester, String amount) async {
    tester.widget<NumPad>(find.byType(NumPad)).onValueChanged(amount, amount);
    await tester.pump();
    await tester.tap(find.text('Select account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food'));
    await tester.pumpAndSettle();
  }

  Future<void> pumpSave(WidgetTester tester) async {
    for (var frame = 0; frame < 20; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  testWidgets(
    'saved expense stays free of balance warnings through dismissal',
    (tester) async {
      await launch(tester, const AddTransactionScreen());
      await fillExpense(tester, '60');
      tester.widget<NumPad>(find.byType(NumPad)).onDone();
      await pumpSave(tester);
      expect(providers.read(transactionProvider).value!.single.amount, 60);
      expect(find.byType(AddTransactionScreen), findsOneWidget);
      expect(find.text('Amount exceeds available balance'), findsNothing);
      expect(tester.widget<NumPad>(find.byType(NumPad)).enabled, isFalse);
      suggester.completion.complete();
      await tester.pump();
      expect(find.text('Amount exceeds available balance'), findsNothing);
      await tester.pumpAndSettle();
      expect(find.byType(AddTransactionScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final amount in ['0.20', '0.21']) {
    testWidgets('expense $amount checks rounded remaining cents', (
      tester,
    ) async {
      await providers.read(accountProvider.future);
      await providers
          .read(accountProvider.notifier)
          .updateAccount(account.copyWith(initialBalance: 0.3));
      await providers
          .read(transactionProvider.notifier)
          .addTransaction(
            AppTransaction(
              id: 'earlier',
              note: '',
              amount: 0.1,
              date: DateTime(2026),
              type: TransactionType.expense,
              categoryId: 'food',
              accountId: 'cash',
            ),
          );
      await launch(tester, const AddTransactionScreen());
      await fillExpense(tester, amount);
      final exceeds = amount == '0.21';
      expect(
        find.text('Amount exceeds available balance'),
        exceeds ? findsOneWidget : findsNothing,
      );
      tester.widget<NumPad>(find.byType(NumPad)).onDone();
      await pumpSave(tester);
      expect(
        providers.read(transactionProvider).value!.length,
        exceeds ? 1 : 2,
      );
      if (exceeds) {
        expect(find.text('Insufficient balance'), findsOneWidget);
        expect(find.text('Amount exceeds available balance'), findsOneWidget);
        expect(tester.widget<NumPad>(find.byType(NumPad)).enabled, isTrue);
      } else {
        suggester.completion.complete();
        await tester.pumpAndSettle();
        expect(find.byType(AddTransactionScreen), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('main transfer accepts the exact remaining cents', (
    tester,
  ) async {
    await providers.read(accountProvider.future);
    await providers
        .read(accountProvider.notifier)
        .updateAccount(account.copyWith(initialBalance: 0.3));
    await providers
        .read(transactionProvider.notifier)
        .addTransaction(
          AppTransaction(
            id: 'earlier',
            note: '',
            amount: 0.1,
            date: DateTime(2026),
            type: TransactionType.expense,
            categoryId: 'food',
            accountId: 'cash',
          ),
        );
    await launch(
      tester,
      const AddTransactionScreen(initialType: TransactionType.transfer),
    );
    tester.widget<NumPad>(find.byType(NumPad)).onValueChanged('0.20', '0.20');
    await tester.pump();
    await tester.tap(find.text('Select account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cash'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select destination'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank'));
    await tester.pumpAndSettle();
    expect(find.text('Amount exceeds available balance'), findsNothing);
    tester.widget<NumPad>(find.byType(NumPad)).onDone();
    await pumpSave(tester);
    await tester.pumpAndSettle();
    expect(providers.read(transactionProvider).value!.length, 2);
    expect(find.byType(AddTransactionScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved savings deposit freezes availability until dismissal', (
    tester,
  ) async {
    final completion = Completer<void>();
    await launch(
      tester,
      Scaffold(
        body: SavingsLogSheet(
          goal: goal,
          linkedAccount: account,
          initialAmount: 60,
          onSave: (amount) async {
            await providers
                .read(savingsGoalsProvider.notifier)
                .addLog(
                  SavingsLog(
                    id: 'deposit',
                    goalId: goal.id,
                    amount: amount,
                    date: DateTime.now(),
                  ),
                );
            await completion.future;
          },
        ),
      ),
    );
    final availableBefore = tester
        .widget<Text>(find.textContaining('Available for savings:'))
        .data;
    tester.widget<NumPad>(find.byType(NumPad)).onDone();
    await pumpSave(tester);
    expect(
      providers.read(savingsGoalsProvider).value!.single.currentAmount,
      60,
    );
    expect(find.textContaining('Insufficient available balance'), findsNothing);
    expect(find.text(availableBefore!), findsOneWidget);
    completion.complete();
    await tester.pump();
    expect(find.textContaining('Insufficient available balance'), findsNothing);
    expect(tester.widget<NumPad>(find.byType(NumPad)).enabled, isFalse);
    await tester.pumpAndSettle();
    expect(find.byType(SavingsLogSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed savings save restores live validation and retry', (
    tester,
  ) async {
    final completion = Completer<void>();
    await launch(
      tester,
      Scaffold(
        body: SavingsLogSheet(
          goal: goal,
          linkedAccount: account,
          initialAmount: 60,
          onSave: (_) => completion.future,
        ),
      ),
    );
    tester.widget<NumPad>(find.byType(NumPad)).onDone();
    await pumpSave(tester);
    await providers
        .read(accountProvider.notifier)
        .updateAccount(account.copyWith(initialBalance: 40));
    await tester.pumpAndSettle();
    expect(find.textContaining('Insufficient available balance'), findsNothing);
    completion.completeError(StateError('write failed'));
    await tester.pumpAndSettle();
    expect(find.text('Could not save savings. Try again'), findsOneWidget);
    expect(tester.widget<NumPad>(find.byType(NumPad)).enabled, isTrue);
    tester.widget<NumPad>(find.byType(NumPad)).onValueChanged('60', '60');
    await tester.pump();
    expect(
      find.textContaining('Insufficient available balance'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

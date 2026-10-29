import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/accounts/account_form_screen.dart';
import 'package:koin/features/budgets/budgets_screen.dart';
import 'package:koin/features/cashflow/cashflow_tab.dart';
import 'package:koin/features/categories/category_detail_screen.dart';
import 'package:koin/features/categories/category_manager_screen.dart';
import 'package:koin/features/debts/debt_details_screen.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';

class _RecoverableLedger extends InMemoryLedgerAdapter {
  bool fail = true;
  @override
  Future<List<AppTransaction>> getTransactions() async {
    if (fail) throw StateError('Read failed');
    return super.getTransactions();
  }
}

void main() {
  final cash = Account(
    id: 'cash',
    name: 'Cash',
    initialBalance: 50000,
    iconCodePoint: KoinIcons.wallet.codePoint,
    colorHex: '#00D09E',
  );
  final food = TransactionCategory(
    id: 'food',
    name: 'Food',
    budget: 10000,
    iconCodePoint: KoinIcons.forkKnife.codePoint,
    colorHex: '#00D09E',
    type: TransactionType.expense,
  );
  final taxi = food.copyWith(id: 'taxi', name: 'Trip taxi', position: 1);
  final flight = food.copyWith(id: 'flight', name: 'Trip flight', position: 2);
  final debt = Debt(
    id: 'debt',
    personName: 'Alex',
    amount: 12000,
    type: DebtType.iOwe,
    startDate: DateTime(2026, 1, 1),
  );

  Future<ProviderContainer> setup({
    Ledger? ledger,
    String currency = 'PHP',
  }) async {
    SharedPreferences.setMockInitialValues({'currency_code': currency});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ledgerProvider.overrideWithValue(ledger ?? InMemoryLedgerAdapter()),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(initial: [cash]),
        ),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(initial: [food, taxi, flight]),
        ),
        savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
        debtRepositoryProvider.overrideWithValue(
          InMemoryDebtAdapter(initial: [debt]),
        ),
        plannedPaymentRepositoryProvider.overrideWithValue(
          InMemoryPlannedPaymentAdapter(
            initial: [
              PlannedPayment(
                id: 'rent',
                title: 'Monthly household obligations',
                amount: 8000,
                type: TransactionType.expense,
                categoryId: 'food',
                accountId: 'cash',
                startDate: DateTime(2026, 1, 1),
                nextDate: DateTime.now(),
                frequency: PaymentFrequency.monthly,
                isAutoProcess: true,
              ),
            ],
          ),
        ),
        categorySuggesterProvider.overrideWithValue(TestStubSuggesterAdapter()),
      ],
    );
    addTearDown(c.dispose);
    await c.read(accountProvider.future);
    await c.read(categoriesProvider.future);
    return c;
  }

  Future<void> open(
    WidgetTester tester,
    ProviderContainer c,
    Widget page, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), false),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'budgets never show zero spending on a failed read and can recover',
    (tester) async {
      final ledger = _RecoverableLedger();
      final c = await setup(ledger: ledger);
      await open(tester, c, const BudgetsScreen());
      expect(find.text('Remaining'), findsNothing);
      expect(find.text('Could not load budget spending.'), findsOneWidget);
      ledger.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Remaining'), findsOneWidget);
    },
  );

  testWidgets('category search passes the visible IDs into reordering', (
    tester,
  ) async {
    final c = await setup();
    await open(tester, c, const CategoryManagerScreen());
    await tester.tap(find.byIcon(KoinIcons.magnifyingGlass));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Trip');
    await tester.pumpAndSettle();
    final list = tester.widget<ReorderableListView>(
      find.byType(ReorderableListView).first,
    );
    list.onReorderItem!(0, 1);
    await tester.pumpAndSettle();
    expect(c.read(categoriesProvider).value!.map((c) => c.id), [
      'food',
      'flight',
      'taxi',
    ]);
  });

  testWidgets(
    'JPY relabeling allows note edits without rounding historic money',
    (tester) async {
      final tx = AppTransaction(
        id: 'tx',
        amount: 100.5,
        date: DateTime.now(),
        accountId: 'cash',
        categoryId: 'food',
        type: TransactionType.expense,
        note: 'Lunch',
      );
      final c = await setup(
        ledger: InMemoryLedgerAdapter(initial: [tx]),
        currency: 'JPY',
      );
      await c.read(transactionProvider.future);
      await open(tester, c, AddTransactionScreen(editingTransaction: tx));
      await tester.enterText(find.byType(TextField).first, 'Updated note');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final updated = c.read(transactionProvider).value!.single;
      expect(updated.amount, 100.5);
      expect(updated.note, 'Updated note');
      expect(find.text('Enter a valid amount'), findsNothing);
    },
  );

  final screens = <String, Widget Function()>{
    'transaction': () => const AddTransactionScreen(),
    'cashflow': () => const CashflowScheduleTab(type: TransactionType.expense),
    'categories': () => const CategoryManagerScreen(),
    'category editor': () => CategoryDetailScreen(category: food),
    'debt actions': () => const DebtDetailsScreen(debtId: 'debt'),
  };
  for (final variant in ['large text', 'landscape']) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} remains usable in $variant', (tester) async {
        final c = await setup();
        await open(
          tester,
          c,
          entry.value(),
          size: variant == 'large text'
              ? const Size(320, 640)
              : const Size(640, 360),
          scale: variant == 'large text' ? 1.8 : 1,
        );
        expect(tester.takeException(), isNull);
        if (entry.key == 'transaction') {
          await tester.ensureVisible(find.text('Select account'));
          await tester.tap(find.text('Select account'));
          await tester.pumpAndSettle();
          expect(find.text('Cash'), findsOneWidget);
        }
      });
    }
  }

  testWidgets('expanded appearance controls retain semantic labels', (
    tester,
  ) async {
    final c = await setup();
    await open(tester, c, AccountFormScreen(account: cash));
    await tester.ensureVisible(find.text('Appearance'));
    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Templates'));
    final handle = tester.ensureSemantics();

    expect((await labeledTapTargetGuideline.evaluate(tester)).passed, isTrue);
    handle.dispose();
    expect(tester.takeException(), isNull);
  });
}

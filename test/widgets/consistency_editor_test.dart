import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/categories/category_detail_screen.dart';
import 'package:koin/features/transactions/add_transaction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _DelayedCategoryRepository extends InMemoryCategoryAdapter {
  _DelayedCategoryRepository(TransactionCategory category)
    : super(initial: [category]);
  final completion = Completer<void>();
  int writes = 0;
  @override
  Future<void> updateCategory(TransactionCategory category) async {
    writes++;
    await completion.future;
    await super.updateCategory(category);
  }
}

class _FailingLedger extends InMemoryLedgerAdapter {
  @override
  Future<AppTransaction> recordTransaction(AppTransaction transaction) async =>
      throw StateError('disk write failed');
}

void main() {
  testWidgets(
    'failed normal transaction restores released savings and retains draft',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final account = Account(
        id: 'cash',
        name: 'Cash',
        initialBalance: 200,
        iconCodePoint: KoinIcons.wallet.codePoint,
        colorHex: '#00D09E',
      );
      final savings = InMemorySavingsAdapter(
        initial: [
          SavingsGoal(
            id: 'stash',
            name: 'Reserve',
            currentAmount: 100,
            isStash: true,
            linkedAccountId: account.id,
            startDate: DateTime(2026),
          ),
        ],
      );
      final food = TransactionCategory(
        id: 'food',
        name: 'Food',
        iconCodePoint: KoinIcons.forkKnife.codePoint,
        colorHex: '#00D09E',
        type: TransactionType.expense,
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          accountRepositoryProvider.overrideWithValue(
            InMemoryAccountAdapter(initial: [account]),
          ),
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryAdapter(initial: [food]),
          ),
          savingsRepositoryProvider.overrideWithValue(savings),
          ledgerProvider.overrideWithValue(_FailingLedger()),
        ],
      );
      addTearDown(container.dispose);
      await container.read(accountProvider.future);
      await container.read(categoriesProvider.future);
      await container.read(transactionProvider.future);
      await container.read(savingsGoalsProvider.future);
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.getTheme(const Color(0xFF00D09E), true),
            home: const AddTransactionScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final digit in ['1', '5', '0']) {
        await tester.tap(
          find.descendant(of: find.byType(NumPad), matching: find.text(digit)),
        );
        await tester.pump();
      }
      await tester.ensureVisible(find.text('Select account'));
      await tester.tap(find.text('Select account'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cash'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Select category'));
      await tester.tap(find.text('Select category'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(find.text('Release & continue'), findsOneWidget);
      await tester.tap(find.text('Release & continue'));
      await tester.pumpAndSettle();
      expect(find.byType(AddTransactionScreen), findsOneWidget);
      expect((await savings.getSavingsGoals()).single.currentAmount, 100);
      expect(await savings.getSavingsLogs('stash'), isEmpty);
      expect(await container.read(ledgerProvider).getTransactions(), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  final category = TransactionCategory(
    id: 'food',
    name: 'Food',
    iconCodePoint: KoinIcons.forkKnife.codePoint,
    colorHex: '#00D09E',
    type: TransactionType.expense,
    budgetPercent: 25,
    isPercentBudget: true,
    position: 4,
  );

  Future<ProviderContainer> openEditor(
    WidgetTester tester,
    CategoryRepository repository,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        categoryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    await container.read(categoriesProvider.future);
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), false),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => CategoryDetailScreen(category: category),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Groceries');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save changes'));
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('renaming a category preserves percentage budget and order', (
    tester,
  ) async {
    final repository = InMemoryCategoryAdapter(initial: [category]);
    await openEditor(tester, repository);
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    final saved = (await repository.getCategories()).single;
    expect(saved.name, 'Groceries');
    expect(saved.budgetPercent, 25);
    expect(saved.isPercentBudget, isTrue);
    expect(saved.position, 4);
    expect(find.byType(CategoryDetailScreen), findsNothing);
  });

  testWidgets(
    'pending category save submits once and failed save retains draft',
    (tester) async {
      final repository = _DelayedCategoryRepository(category);
      final container = await openEditor(tester, repository);
      await tester.tap(find.text('Save changes'));
      await tester.pump();
      expect(
        tester
            .widget<KoinPrimaryButton>(find.byType(KoinPrimaryButton))
            .isLoading,
        isTrue,
      );
      expect(repository.writes, 1);
      repository.completion.completeError(StateError('disk write failed'));
      await tester.pumpAndSettle();
      expect(find.byType(CategoryDetailScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Groceries',
      );
      expect(find.text('Could not save category'), findsOneWidget);
      expect(container.read(categoriesProvider).value!.single.name, 'Food');
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter_test/flutter_test.dart';
import 'package:koin/koin.dart';

void main() {
  group('Architecture & Barrel Structure Tests', () {
    test('core.dart provides seamless access to all core domain models', () {
      final account = Account(
        id: 'acc_1',
        name: 'Main Wallet',
        iconCodePoint: 1234,
        colorHex: '#00D09E',
      );
      expect(account.id, 'acc_1');

      final category = TransactionCategory(
        id: 'cat_1',
        name: 'Dining',
        iconCodePoint: 5678,
        colorHex: '#FF6B6B',
        type: TransactionType.expense,
      );
      expect(category.type, TransactionType.expense);

      final tx = AppTransaction(
        id: 'tx_1',
        amount: 50.0,
        date: DateTime(2026, 10, 1),
        type: TransactionType.expense,
        categoryId: category.id,
        accountId: account.id,
      );
      expect(tx.amount, 50.0);
    });

    test(
      'core.dart provides seamless access to ledger and categorization seams',
      () {
        final ledger = InMemoryLedgerAdapter();
        expect(ledger, isA<Ledger>());

        final adapter = TestStubSuggesterAdapter(
          stubbedSuggestion: const CategorySuggestion(
            categoryId: 'cat_stub',
            type: TransactionType.expense,
            confidence: 0.9,
          ),
        );
        expect(adapter, isA<CategorySuggester>());

        expect(CashflowForecaster, isNotNull);
        expect(ForecastHorizon.values.length, 3);
      },
    );

    test(
      'features.dart provides unified access to all feature screens and layouts',
      () {
        expect(MainLayout, isNotNull);
        expect(DashboardScreen, isNotNull);
        expect(PortfolioScreen, isNotNull);
        expect(ActivityScreen, isNotNull);
        expect(BudgetsScreen, isNotNull);
        expect(AccountsScreen, isNotNull);
        expect(CategoryManagerScreen, isNotNull);
        expect(CustomReportsScreen, isNotNull);
        expect(SettingsScreen, isNotNull);
        expect(CashflowScheduleTab, isNotNull);
        expect(DebtsTab, isNotNull);
        expect(SavingsTab, isNotNull);
        expect(AccountsTab, isNotNull);
        expect(TransactionsListScreen, isNotNull);
        expect(AddRepaymentSheet, isNotNull);
        expect(SavingsLogSheet, isNotNull);
        expect(BudgetEditorSheet, isNotNull);
        expect(VoiceInputSheet, isNotNull);
      },
    );

    test('koin.dart root barrel exports both core and features layers', () {
      // Validates that koin.dart cleanly compiles and exports both layers
      expect(AppTheme, isNotNull);
      expect(SqliteLedgerAdapter, isNotNull);
      expect(MainLayout, isNotNull);
      expect(TransactionGroup, isNotNull);
      expect(TransactionTile, isNotNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  group('CategorySuggester Seam & Adapters', () {
    test(
      'SuggestionContext correctly calculates signed amount for expense and income',
      () {
        final expenseContext = SuggestionContext(
          text: 'Lunch at Cafe',
          amount: 25.50,
          type: TransactionType.expense,
          date: DateTime.now(),
          currentAccountId: 'acc_1',
        );
        expect(expenseContext.signedAmount, -25.50);

        final incomeContext = SuggestionContext(
          text: 'Freelance payment',
          amount: 500.0,
          type: TransactionType.income,
          date: DateTime.now(),
          currentAccountId: 'acc_1',
        );
        expect(incomeContext.signedAmount, 500.0);
      },
    );

    test(
      'TestStubSuggesterAdapter returns stubbed suggestions and records feedback',
      () async {
        const stub = CategorySuggestion(
          categoryId: 'cat_food',
          originAccountId: 'acc_cash',
          type: TransactionType.expense,
          confidence: 0.95,
          isExactMatch: true,
        );

        final stubAdapter = TestStubSuggesterAdapter(stubbedSuggestion: stub);

        final result = await stubAdapter.suggest(
          SuggestionContext(
            text: 'Burger King',
            amount: 15.0,
            type: TransactionType.expense,
            date: DateTime.now(),
            currentAccountId: 'acc_cash',
          ),
        );

        expect(result, isNotNull);
        expect(result!.categoryId, 'cat_food');
        expect(result.confidence, 0.95);
        expect(result.isExactMatch, isTrue);

        await stubAdapter.recordFeedback(
          text: 'Burger King',
          amount: 15.0,
          type: TransactionType.expense,
          originAccountId: 'acc_cash',
          destinationId: 'cat_food',
        );

        expect(stubAdapter.recordedFeedback.length, 1);
        expect(stubAdapter.recordedFeedback.first['destinationId'], 'cat_food');
      },
    );

    test(
      'DebouncedSuggesterCoordinator executes callback after debounce duration',
      () async {
        const stub = CategorySuggestion(
          categoryId: 'cat_groceries',
          type: TransactionType.expense,
          confidence: 0.88,
        );
        final stubAdapter = TestStubSuggesterAdapter(stubbedSuggestion: stub);
        final coordinator = DebouncedSuggesterCoordinator(
          suggester: stubAdapter,
          debounceDuration: const Duration(milliseconds: 10),
        );

        CategorySuggestion? captured;
        coordinator.run(
          context: SuggestionContext(
            text: 'Supermarket shopping',
            amount: 45.0,
            type: TransactionType.expense,
            date: DateTime.now(),
            currentAccountId: 'acc_card',
          ),
          onSuggested: (suggestion) {
            captured = suggestion;
          },
        );

        expect(captured, isNull);
        await Future.delayed(const Duration(milliseconds: 100));
        expect(captured, isNotNull);
        expect(captured!.categoryId, 'cat_groceries');
        coordinator.dispose();
      },
    );
  });
}

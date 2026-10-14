import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/categorization/voice_command_parser.dart';
import 'package:koin/core/models/models.dart';

TransactionCategory category(String name, TransactionType type) =>
    TransactionCategory(
      id: name,
      name: name,
      iconCodePoint: 0,
      colorHex: '#008080',
      type: type,
    );

void main() {
  final categories = [
    category('Food', TransactionType.expense),
    category('Car', TransactionType.expense),
    category('Personal', TransactionType.expense),
    category('Salary', TransactionType.income),
  ];
  for (final phrase in [
    'paid 100 for coffee',
    'spent 100 on food',
    'bought food for 100',
    'got groceries for 100',
  ]) {
    test('spending stays expense: $phrase', () {
      final parsed = VoiceCommandParser.parse(phrase, categories, []);
      expect(parsed.type, TransactionType.expense);
      expect(
        parsed.category == null || parsed.category!.type == parsed.type,
        isTrue,
      );
    });
  }
  for (final phrase in [
    'got paid 100 salary',
    'received 100 salary',
    'earned 100 salary',
    'they paid me 100 salary',
  ]) {
    test('receiving is income: $phrase', () {
      final parsed = VoiceCommandParser.parse(phrase, categories, []);
      expect(parsed.type, TransactionType.income);
      expect(parsed.category?.name, 'Salary');
    });
  }
  test('transfers take precedence over receiving keywords', () {
    final parsed = VoiceCommandParser.parse(
      'transferred 100 income to bank',
      categories,
      [],
    );
    expect(parsed.type, TransactionType.transfer);
    expect(parsed.category, isNull);
  });
  test(
    'category names require whole words, a compatible type, and no ambiguity',
    () {
      expect(
        VoiceCommandParser.parse('spent 100 skincare', categories, []).category,
        isNull,
      );
      expect(
        VoiceCommandParser.parse('paid 100 salary', categories, []).category,
        isNull,
      );
      expect(
        VoiceCommandParser.parse('spent 100 food car', categories, []).category,
        isNull,
      );
      expect(
        VoiceCommandParser.parse(
          'spent 100 FOOD',
          categories,
          [],
        ).category?.name,
        'Food',
      );
      expect(
        VoiceCommandParser.parse('spent 100 café', [
          category('Café', TransactionType.expense),
        ], []).category?.name,
        'Café',
      );
    },
  );
  test('keyword intent leaves category to the shared confidence policy', () {
    expect(
      VoiceCommandParser.parse('spent 100 coffee', categories, []).category,
      isNull,
    );
  });
  test('switching type can clear nullable parsed fields', () {
    final original = ParsedTransactionData(
      type: TransactionType.expense,
      category: categories.first,
      note: 'Food',
    );
    expect(original.copyWith(note: 'Lunch').category, original.category);
    expect(
      original.copyWith(type: TransactionType.income, category: null).category,
      isNull,
    );
  });
  test(
    'voice distinguishes named categories from inferred selections for feedback',
    () {
      final explicit = VoiceCommandParser.parse(
        'spent 100 food',
        categories,
        [],
      );
      final inferred = VoiceCommandParser.parse(
        'paid 100 coffee',
        categories,
        [],
      );
      expect(explicit.isCategoryExplicit, isTrue);
      expect(inferred.isCategoryExplicit, isFalse);
      expect(
        inferred.copyWith(category: categories.first).isCategoryExplicit,
        isFalse,
      );
      expect(
        inferred
            .copyWith(category: categories.first, isCategoryExplicit: true)
            .isCategoryExplicit,
        isTrue,
      );
    },
  );
}

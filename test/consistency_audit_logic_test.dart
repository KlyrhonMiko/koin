import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  group('Analysis calendar navigation', () {
    test('month-end dates visit February in both directions', () {
      for (final year in [2024, 2025, 2026]) {
        for (final day in [29, 30, 31]) {
          expect(
            AnalysisPeriod.month.nextPeriod(DateTime(year, 1, day)),
            DateTime(year, 2),
          );
          expect(
            AnalysisPeriod.month.previousPeriod(DateTime(year, 3, day)),
            DateTime(year, 2),
          );
        }
      }
    });

    test(
      'period navigation crosses years and round trips deterministically',
      () {
        expect(
          AnalysisPeriod.month.nextPeriod(DateTime(2026, 12, 31)),
          DateTime(2027, 1),
        );
        expect(
          AnalysisPeriod.month.previousPeriod(DateTime(2026, 1, 31)),
          DateTime(2025, 12),
        );
        final next = AnalysisPeriod.month.nextPeriod(DateTime(2026, 1, 31));
        expect(AnalysisPeriod.month.previousPeriod(next), DateTime(2026, 1));
        expect(
          AnalysisPeriod.year.nextPeriod(DateTime(2024, 2, 29)),
          DateTime(2025),
        );
        expect(
          AnalysisPeriod.year.previousPeriod(DateTime(2024, 2, 29)),
          DateTime(2023),
        );
      },
    );
  });

  test('account filters include transfer endpoints exactly once', () {
    final transfer = AppTransaction(
      id: 'transfer',
      amount: 50,
      date: DateTime(2026, 10, 12),
      type: TransactionType.transfer,
      categoryId: '',
      accountId: 'source',
      toAccountId: 'destination',
    );
    final ordinary = transfer.copyWith(
      id: 'expense',
      type: TransactionType.expense,
    );
    expect(
      const TransactionFilter(
        accountIds: {'destination'},
      ).apply([transfer, ordinary]),
      [transfer],
    );
    expect(
      const TransactionFilter(
        accountIds: {'source', 'destination'},
      ).apply([transfer]),
      [transfer],
    );
    expect(
      const TransactionFilter(accountIds: {'unrelated'}).matches(transfer),
      isFalse,
    );
    expect(
      const TransactionFilter(
        accountIds: {'destination'},
        minAmount: 60,
      ).matches(transfer),
      isFalse,
    );
    expect(
      const TransactionFilter(
        accountIds: {'destination'},
        type: TransactionType.expense,
      ).matches(transfer),
      isFalse,
    );
  });

  group('Currency input contract', () {
    final usd = Currency.supportedCurrencies.firstWhere((c) => c.code == 'USD');
    final jpy = Currency.supportedCurrencies.firstWhere((c) => c.code == 'JPY');

    test('valid grouped and signed inputs retain their numeric values', () {
      expect(usd.tryParseInput(' 1,234.56 '), 1234.56);
      expect(usd.tryParseInput('-1,234.56'), -1234.56);
      expect(usd.tryParseInput('.50'), 0.5);
      expect(usd.tryParseInput('1234.'), 1234);
      expect(usd.tryParseInput('1.2300'), 1.23);
      expect(jpy.tryParseInput('1,234.00'), 1234);
    });

    test(
      'invalid grouping, non-finite inputs and extra precision are rejected',
      () {
        for (final input in [
          '',
          '1,23',
          '12,34.56',
          '1,,234',
          'NaN',
          'Infinity',
          '1e3',
          '1.234',
          '1.2.3',
        ]) {
          expect(usd.tryParseInput(input), isNull, reason: input);
        }
        expect(jpy.tryParseInput('1234.5'), isNull);
        expect(usd.tryParseInput('9' * 400), isNull);
      },
    );
  });
}

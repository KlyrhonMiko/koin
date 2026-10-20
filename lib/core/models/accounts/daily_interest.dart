import 'dart:math' as math;

enum InterestPayoutFrequency {
  daily('Daily', 'day'),
  monthly('Monthly', 'month'),
  yearly('Yearly', 'year');

  const InterestPayoutFrequency(this.label, this.periodLabel);
  final String label;
  final String periodLabel;

  bool paysOn(DateTime date) => switch (this) {
    daily => true,
    monthly => DailyInterest.nextDay(date).month != date.month,
    yearly => DailyInterest.nextDay(date).year != date.year,
  };
}

/// Simple annual rate and a fixed 365-day basis; net interest compounds on payout.
abstract final class DailyInterest {
  static bool validRates(double annualRate, double taxRate) =>
      annualRate.isFinite &&
      annualRate > 0 &&
      annualRate <= 100 &&
      taxRate.isFinite &&
      taxRate >= 0 &&
      taxRate <= 100;

  static double estimate({
    required double balance,
    required double annualRate,
    double taxRate = 0,
    int decimalDigits = 2,
  }) {
    return round(
      rawDailyInterest(
        balance: balance,
        annualRate: annualRate,
        taxRate: taxRate,
      ),
      decimalDigits: decimalDigits,
    );
  }

  static double rawDailyInterest({
    required double balance,
    required double annualRate,
    double taxRate = 0,
  }) {
    if (!balance.isFinite || balance <= 0 || !validRates(annualRate, taxRate)) {
      return 0;
    }
    return balance * annualRate / 100 / 365 * (1 - taxRate / 100);
  }

  static double round(double amount, {int decimalDigits = 2}) {
    final factor = math.pow(10, decimalDigits);
    return (amount * factor).round() / factor;
  }

  static double estimatePayout({
    required double balance,
    required double annualRate,
    double taxRate = 0,
    required InterestPayoutFrequency frequency,
    required DateTime at,
    int decimalDigits = 2,
  }) {
    final days = switch (frequency) {
      InterestPayoutFrequency.daily => 1,
      InterestPayoutFrequency.monthly => DateTime(at.year, at.month + 1, 0).day,
      InterestPayoutFrequency.yearly => DateTime.utc(
        at.year + 1,
      ).difference(DateTime.utc(at.year)).inDays,
    };
    return round(
      rawDailyInterest(
            balance: balance,
            annualRate: annualRate,
            taxRate: taxRate,
          ) *
          days,
      decimalDigits: decimalDigits,
    );
  }

  static DateTime day(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static DateTime nextDay(DateTime value) =>
      DateTime(value.year, value.month, value.day + 1);

  static String transactionId(String accountId, DateTime date) =>
      'interest:$accountId:${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

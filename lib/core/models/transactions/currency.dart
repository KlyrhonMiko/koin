import 'package:intl/intl.dart';

class Currency {
  final String code;
  final String symbol;
  final String name;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  int get decimalDigits => NumberFormat.currency(name: code).decimalDigits ?? 2;
  NumberFormat get formatter => NumberFormat.currency(
    name: code,
    symbol: symbol,
    decimalDigits: decimalDigits,
  );
  NumberFormat get compactFormatter => NumberFormat.compactCurrency(
    name: code,
    symbol: symbol,
    decimalDigits: decimalDigits,
  );

  /// Parses the dot-decimal input used by the app's numeric keypad and editors.
  /// Grouped comma input is accepted only when groups contain three digits.
  /// Trailing fractional zeroes remain compatible with older editor values.
  double? tryParseInput(String text, {int? precision}) {
    final input = text.trim();
    if (!RegExp(
      r'^[+-]?(?:(?:\d+|\d{1,3}(?:,\d{3})+)(?:\.\d*)?|\.\d+)$',
    ).hasMatch(input)) {
      return null;
    }
    final normalized = input.replaceAll(',', '');
    final fraction = normalized.contains('.')
        ? normalized.split('.').last.replaceFirst(RegExp(r'0+$'), '')
        : '';
    if (fraction.length > (precision ?? decimalDigits)) return null;
    final value = double.tryParse(normalized);
    return value != null && value.isFinite ? value : null;
  }

  Map<String, dynamic> toMap() {
    return {'code': code, 'symbol': symbol, 'name': name};
  }

  factory Currency.fromMap(Map<String, dynamic> map) {
    return Currency(
      code: map['code'] ?? 'USD',
      symbol: map['symbol'] ?? '\$',
      name: map['name'] ?? 'US Dollar',
    );
  }

  static const List<Currency> supportedCurrencies = [
    Currency(code: 'USD', symbol: '\$', name: 'US Dollar'),
    Currency(code: 'EUR', symbol: '€', name: 'Euro'),
    Currency(code: 'GBP', symbol: '£', name: 'British Pound'),
    Currency(code: 'JPY', symbol: '¥', name: 'Japanese Yen'),
    Currency(code: 'CNY', symbol: '¥', name: 'Chinese Yuan'),
    Currency(code: 'INR', symbol: '₹', name: 'Indian Rupee'),
    Currency(code: 'IDR', symbol: 'Rp', name: 'Indonesian Rupiah'),
    Currency(code: 'MYR', symbol: 'RM', name: 'Malaysian Ringgit'),
    Currency(code: 'SGD', symbol: '\$', name: 'Singapore Dollar'),
    Currency(code: 'PHP', symbol: '₱', name: 'Philippine Peso'),
  ];
}

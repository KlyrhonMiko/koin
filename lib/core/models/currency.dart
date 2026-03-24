class Currency {
  final String code;
  final String symbol;
  final String name;

  const Currency({
    required this.code,
    required this.symbol,
    required this.name,
  });

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'symbol': symbol,
      'name': name,
    };
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

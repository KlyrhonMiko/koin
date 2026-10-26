import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app composition root binds this domain setting to the selected currency.
/// Pure repositories and their tests can use two decimal places independently
/// of device preferences, or override it explicitly for another currency.
final currencyPrecisionProvider = Provider<int>((ref) => 2);

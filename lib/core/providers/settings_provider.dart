import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/models/currency.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class SettingsState {
  final Currency currency;
  final Color themeColor;
  final bool isDarkMode;

  const SettingsState({
    required this.currency,
    required this.themeColor,
    required this.isDarkMode,
  });

  SettingsState copyWith({
    Currency? currency,
    Color? themeColor,
    bool? isDarkMode,
  }) {
    return SettingsState(
      currency: currency ?? this.currency,
      themeColor: themeColor ?? this.themeColor,
      isDarkMode: isDarkMode ?? this.isDarkMode,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _currencyCodeKey = 'currency_code';
  static const String _themeColorKey = 'theme_color';
  static const String _isDarkModeKey = 'is_dark_mode';

  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    
    final currencyCode = prefs.getString(_currencyCodeKey);
    final themeColorValue = prefs.getInt(_themeColorKey);
    final isDarkMode = prefs.getBool(_isDarkModeKey) ?? false;
    
    final currency = Currency.supportedCurrencies.firstWhere(
      (c) => c.code == currencyCode,
      orElse: () => Currency.supportedCurrencies.first,
    );

    final themeColor = themeColorValue != null 
        ? Color(themeColorValue) 
        : const Color(0xFF00D09E);
    
    return SettingsState(
      currency: currency,
      themeColor: themeColor,
      isDarkMode: isDarkMode,
    );
  }

  Future<void> setCurrency(Currency currency) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_currencyCodeKey, currency.code);
    ref.invalidateSelf();
  }

  Future<void> setThemeColor(Color color) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_themeColorKey, color.toARGB32());
    ref.invalidateSelf();
  }

  Future<void> setDarkMode(bool isDark) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_isDarkModeKey, isDark);
    ref.invalidateSelf();
  }

  Future<void> toggleDarkMode() async {
    await setDarkMode(!state.isDarkMode);
  }

  Future<void> resetSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_currencyCodeKey);
    await prefs.remove(_themeColorKey);
    await prefs.remove(_isDarkModeKey);
    ref.invalidateSelf();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

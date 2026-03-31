import 'dart:ui';
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
  final ThemeMode themeMode;
  final int analysisFilterIndex;

  const SettingsState({
    required this.currency,
    required this.themeColor,
    required this.themeMode,
    required this.analysisFilterIndex,
  });

  SettingsState copyWith({
    Currency? currency,
    Color? themeColor,
    ThemeMode? themeMode,
    int? analysisFilterIndex,
  }) {
    return SettingsState(
      currency: currency ?? this.currency,
      themeColor: themeColor ?? this.themeColor,
      themeMode: themeMode ?? this.themeMode,
      analysisFilterIndex: analysisFilterIndex ?? this.analysisFilterIndex,
    );
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _currencyCodeKey = 'currency_code';
  static const String _themeColorKey = 'theme_color';
  static const String _themeModeKey = 'theme_mode';
  static const String _analysisFilterIndexKey = 'analysis_filter_index';

  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    final currencyCode = prefs.getString(_currencyCodeKey);
    final themeColorValue = prefs.getInt(_themeColorKey);
    final themeModeIndex = prefs.getInt(_themeModeKey);
    final analysisFilterIndex = prefs.getInt(_analysisFilterIndexKey) ?? 0;

    final currency = Currency.supportedCurrencies.firstWhere(
      (c) => c.code == currencyCode,
      orElse: () => Currency.supportedCurrencies.first,
    );

    final themeColor = themeColorValue != null
        ? Color(themeColorValue)
        : const Color(0xFF00D09E);
        
    final themeMode = themeModeIndex != null
        ? ThemeMode.values[themeModeIndex]
        : ThemeMode.system;

    return SettingsState(
      currency: currency,
      themeColor: themeColor,
      themeMode: themeMode,
      analysisFilterIndex: analysisFilterIndex,
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

  Future<void> setThemeMode(ThemeMode mode) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_themeModeKey, mode.index);
    ref.invalidateSelf();
  }

  Future<void> setAnalysisFilterIndex(int index) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_analysisFilterIndexKey, index);
    ref.invalidateSelf();
  }

  Future<void> toggleDarkMode() async {
    final currentIsDark = state.themeMode == ThemeMode.dark || 
        (state.themeMode == ThemeMode.system && PlatformDispatcher.instance.platformBrightness == Brightness.dark);
    await setThemeMode(currentIsDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> resetSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_currencyCodeKey);
    await prefs.remove(_themeColorKey);
    await prefs.remove(_themeModeKey);
    await prefs.remove(_analysisFilterIndexKey);
    ref.invalidateSelf();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

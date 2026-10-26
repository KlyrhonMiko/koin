import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/utils/haptic_utils.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError();
});

class SettingsState {
  final Currency currency;
  final Color themeColor;
  final ThemeMode themeMode;
  final int analysisFilterIndex;
  final bool hapticsEnabled;
  final String? voiceLocale;
  final String? voiceLocaleName;
  final bool setupCompleted;
  final bool? _hideBalance;
  bool get hideBalance => _hideBalance ?? false;

  const SettingsState({
    required this.currency,
    required this.themeColor,
    required this.themeMode,
    required this.analysisFilterIndex,
    this._hideBalance,
    this.hapticsEnabled = true,
    this.voiceLocale,
    this.voiceLocaleName,
    this.setupCompleted = true,
  });

  SettingsState copyWith({
    Currency? currency,
    Color? themeColor,
    ThemeMode? themeMode,
    int? analysisFilterIndex,
    bool? hideBalance,
    bool? hapticsEnabled,
    String? voiceLocale,
    String? voiceLocaleName,
    bool clearVoiceLocale = false,
    bool? setupCompleted,
  }) {
    return SettingsState(
      currency: currency ?? this.currency,
      themeColor: themeColor ?? this.themeColor,
      themeMode: themeMode ?? this.themeMode,
      analysisFilterIndex: analysisFilterIndex ?? this.analysisFilterIndex,
      hideBalance: hideBalance ?? this.hideBalance,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      voiceLocale: clearVoiceLocale ? null : voiceLocale ?? this.voiceLocale,
      voiceLocaleName: clearVoiceLocale
          ? null
          : voiceLocaleName ?? this.voiceLocaleName,
      setupCompleted: setupCompleted ?? this.setupCompleted,
    );
  }
}

/// Portable effective preferences, shared by snapshots and change detection.
/// Missing legacy keys use app defaults rather than target-device settings.
abstract final class SettingsSnapshot {
  static Map<String, String> capture(SharedPreferences prefs) => {
    'settings_snapshot_version': '1',
    'currency_code':
        prefs.getString('currency_code') ?? Currency.defaultCurrency.code,
    'theme_color': (prefs.getInt('theme_color') ?? 0xFF00D09E).toString(),
    'theme_mode': (prefs.getInt('theme_mode') ?? ThemeMode.system.index)
        .toString(),
    'analysis_filter_index': (prefs.getInt('analysis_filter_index') ?? 0)
        .toString(),
    'hide_balance': (prefs.getBool('hide_balance') ?? false).toString(),
    'haptics_enabled': (prefs.getBool('haptics_enabled') ?? true).toString(),
    'voice_locale': prefs.getString('voice_locale') ?? '',
    'voice_locale_name': prefs.getString('voice_locale_name') ?? '',
    'setup_completed': (prefs.getBool('setup_completed') ?? true).toString(),
  };

  static Future<void> restore(
    SharedPreferences prefs,
    Map<String, String> data,
  ) async {
    final currency = data['currency_code'];
    await prefs.setString(
      'currency_code',
      Currency.supportedCurrencies.any((c) => c.code == currency)
          ? currency!
          // Backups without currency metadata predate the PHP default.
          : 'USD',
    );
    await prefs.setInt(
      'theme_color',
      int.tryParse(data['theme_color'] ?? '') ?? 0xFF00D09E,
    );
    final mode = int.tryParse(data['theme_mode'] ?? '');
    await prefs.setInt(
      'theme_mode',
      mode != null && mode >= 0 && mode < ThemeMode.values.length
          ? mode
          : ThemeMode.system.index,
    );
    final period = int.tryParse(data['analysis_filter_index'] ?? '');
    await prefs.setInt(
      'analysis_filter_index',
      period != null && period >= 0 && period <= 3 ? period : 0,
    );
    await prefs.setBool('hide_balance', data['hide_balance'] == 'true');
    await prefs.setBool('haptics_enabled', data['haptics_enabled'] != 'false');
    final voiceLocale = data['voice_locale'];
    if (voiceLocale == null || voiceLocale.isEmpty) {
      await prefs.remove('voice_locale');
      await prefs.remove('voice_locale_name');
    } else {
      await prefs.setString('voice_locale', voiceLocale);
      final name = data['voice_locale_name'];
      if (name == null || name.isEmpty) {
        await prefs.remove('voice_locale_name');
      } else {
        await prefs.setString('voice_locale_name', name);
      }
    }
    await prefs.setBool('setup_completed', data['setup_completed'] != 'false');
  }
}

class SettingsNotifier extends Notifier<SettingsState> {
  static const String _currencyCodeKey = 'currency_code';
  static const String _themeColorKey = 'theme_color';
  static const String _themeModeKey = 'theme_mode';
  static const String _analysisFilterIndexKey = 'analysis_filter_index';
  static const String _hideBalanceKey = 'hide_balance';
  static const String _hapticsEnabledKey = 'haptics_enabled';

  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    final currencyCode = prefs.getString(_currencyCodeKey);
    final themeColorValue = prefs.getInt(_themeColorKey);
    final themeModeIndex = prefs.getInt(_themeModeKey);
    final analysisFilterIndex = prefs.getInt(_analysisFilterIndexKey) ?? 0;
    final hideBalance = prefs.getBool(_hideBalanceKey) ?? false;
    final hapticsEnabled = prefs.getBool(_hapticsEnabledKey) ?? true;
    HapticService.enabled = hapticsEnabled;

    final currency = Currency.supportedCurrencies.firstWhere(
      (c) => c.code == currencyCode,
      orElse: () => Currency.defaultCurrency,
    );

    final themeColor = themeColorValue != null
        ? Color(themeColorValue)
        : const Color(0xFF00D09E);

    final themeMode =
        themeModeIndex != null &&
            themeModeIndex >= 0 &&
            themeModeIndex < ThemeMode.values.length
        ? ThemeMode.values[themeModeIndex]
        : ThemeMode.system;

    return SettingsState(
      currency: currency,
      themeColor: themeColor,
      themeMode: themeMode,
      analysisFilterIndex: analysisFilterIndex,
      hideBalance: hideBalance,
      hapticsEnabled: hapticsEnabled,
      voiceLocale: prefs.getString('voice_locale'),
      voiceLocaleName: prefs.getString('voice_locale_name'),
      setupCompleted: prefs.getBool('setup_completed') ?? true,
    );
  }

  Future<void> setCurrency(Currency currency) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_currencyCodeKey, currency.code);
    ref.invalidateSelf();
  }

  Future<void> setVoiceLocale(String? locale, {String? name}) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null || locale.isEmpty) {
      await prefs.remove('voice_locale');
      await prefs.remove('voice_locale_name');
    } else {
      await prefs.setString('voice_locale', locale);
      if (name == null || name.isEmpty) {
        await prefs.remove('voice_locale_name');
      } else {
        await prefs.setString('voice_locale_name', name);
      }
    }
    ref.invalidateSelf();
  }

  Future<void> completeSetup() async {
    await ref.read(sharedPreferencesProvider).setBool('setup_completed', true);
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

  Future<void> setHideBalance(bool hide) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_hideBalanceKey, hide);
    ref.invalidateSelf();
  }

  Future<void> setHapticsEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_hapticsEnabledKey, enabled);
    HapticService.enabled = enabled;
    state = state.copyWith(hapticsEnabled: enabled);
    if (enabled) HapticService.selection();
  }

  Future<void> resetSettings() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove(_currencyCodeKey);
    await prefs.remove(_themeColorKey);
    await prefs.remove(_themeModeKey);
    await prefs.remove(_analysisFilterIndexKey);
    await prefs.remove(_hideBalanceKey);
    await prefs.remove(_hapticsEnabledKey);
    await prefs.remove('voice_locale');
    await prefs.remove('voice_locale_name');
    HapticService.enabled = true;
    ref.invalidateSelf();
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/providers/settings_provider.dart';
import 'package:koin/features/main_layout.dart';
import 'package:koin/core/categorization/categorization_engine.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Auto-run ML bootstrap in the background. 
  // It handles its own 'already run' check, so this is safe and fast to call on every boot.
  CategorizationEngine().bootstrapFromHistory();
  
  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    
    return MaterialApp(
      title: 'Koin',
      themeMode: settings.themeMode,
      theme: AppTheme.getTheme(settings.themeColor, false),
      darkTheme: AppTheme.getTheme(settings.themeColor, true),
      debugShowCheckedModeBanner: false,
      home: const MainLayout(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/features.dart';
import 'package:koin/core/widgets/app_startup.dart';
import 'package:koin/core/services/quick_transaction_service.dart';
import 'package:koin/core/maintenance/recovery_service.dart';
import 'package:koin/features/transactions/quick_entry_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppStartup(initialize: _initializeApp));
}

@pragma('vm:entry-point')
void quickEntry() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(QuickEntryStartup(initialize: () => _initializeApp(standalone: true)));
}

Future<Widget> _initializeApp({bool standalone = false}) async {
  // Complete initial history training before the UI can request suggestions.
  if (!standalone) await HybridMlSuggesterAdapter().bootstrap();

  final sharedPrefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
    child: standalone ? const QuickEntryApp() : const MyApp(),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  final _quickTransactions = QuickTransactionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _quickTransactions.initialize(_openQuickTransaction);
        ref.read(recoveryServiceProvider).start();
      }
    });
  }

  void _openQuickTransaction() async {
    if (mounted) await QuickTransactionService.openStandalone();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      // The standalone window has its own engine and provider container.
      ref.invalidate(transactionProvider);
      ref.invalidate(plannedPaymentProvider);
      ref.invalidate(accountProvider);
      ref.invalidate(categoriesProvider);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _quickTransactions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/features.dart';
import 'package:koin/core/widgets/app_startup.dart';
import 'package:koin/core/services/quick_transaction_service.dart';
import 'package:koin/core/maintenance/recovery_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(AppStartup(initialize: _initializeApp));
}

Future<Widget> _initializeApp() async {
  // Complete initial history training before the UI can request suggestions.
  await HybridMlSuggesterAdapter().bootstrap();

  final sharedPrefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(sharedPrefs)],
    child: const MyApp(),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _quickTransactions = QuickTransactionService();
  final _transactionObserver = _TransactionRouteObserver();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _quickTransactions.initialize(_openQuickTransaction);
        ref.read(recoveryServiceProvider).start();
      }
    });
  }

  void _openQuickTransaction() {
    if (!mounted) return;
    final navigator = _navigatorKey.currentState;
    if (navigator == null) return;
    final existing = _transactionObserver.transactionRoute;
    if (existing != null) {
      // Keep the current draft, even if a category picker is above it.
      navigator.popUntil((route) => identical(route, existing));
      return;
    }
    navigator.push(SlideUpRoute(page: const AddTransactionScreen()));
  }

  @override
  void dispose() {
    _quickTransactions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [_transactionObserver],
      title: 'Koin',
      themeMode: settings.themeMode,
      theme: AppTheme.getTheme(settings.themeColor, false),
      darkTheme: AppTheme.getTheme(settings.themeColor, true),
      debugShowCheckedModeBanner: false,
      home: const MainLayout(),
    );
  }
}

class _TransactionRouteObserver extends NavigatorObserver {
  final _routes = <Route<dynamic>>[];

  Route<dynamic>? get transactionRoute {
    for (final route in _routes.reversed) {
      if (route is SlideUpRoute && route.page is AddTransactionScreen) {
        return route;
      }
    }
    return null;
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.remove(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    if (index >= 0) {
      if (newRoute == null) {
        _routes.removeAt(index);
      } else {
        _routes[index] = newRoute;
      }
    }
  }
}

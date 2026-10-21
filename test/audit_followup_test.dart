import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/portfolio/portfolio_screen.dart';
import 'package:koin/features/dashboard/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/features/cashflow/add_edit_cashflow_screen.dart';
import 'package:koin/core/database_version.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FailingReorderAccounts extends InMemoryAccountAdapter {
  FailingReorderAccounts({super.initial});
  bool failLoad = false;
  Completer<void>? loading;
  bool failReorder = true;
  @override
  Future<List<Account>> getAccounts() async {
    await loading?.future;
    if (failLoad) throw StateError('Storage unavailable');
    return super.getAccounts();
  }

  @override
  Future<void> updateAccountPositions(List<Account> accounts) async {
    if (failReorder) throw StateError('Storage full');
    return super.updateAccountPositions(accounts);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final outfit = FontLoader('Outfit');
    for (final weight in [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
      'Black',
    ]) {
      outfit.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await outfit.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  void phoneView(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('audit-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await Directory('build/audit-fix-review').create(recursive: true);
      await File('build/audit-fix-review/$name.png')
          .writeAsBytes(bytes!.buffer.asUint8List());
    });
  }

  Widget previewShell(BuildContext context, Widget? child) =>
      RepaintBoundary(key: const Key('audit-preview'), child: child!);

  final helper = DatabaseHelper.instance;
  final ledger = SqliteLedgerAdapter();
  late Directory root;
  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    root = await Directory.systemTemp.createTemp('koin_exploration_');
    await databaseFactory.setDatabasesPath(root.path);
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (_) async => root.path,
        );
    await helper.insertAccount(
      Account(
        id: 'cash',
        name: 'Cash',
        initialBalance: 1000,
        iconCodePoint: 0,
        colorHex: '#00D09E',
      ),
    );
  });
  tearDown(() async {
    await helper.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await root.delete(recursive: true);
  });

  test(
    'deleting an older occurrence does not reopen a newer paid occurrence',
    () async {
      var payment = PlannedPayment(
        id: 'schedule',
        title: 'Rent',
        amount: 10,
        type: TransactionType.expense,
        categoryId: 'cat_others',
        accountId: 'cash',
        startDate: DateTime(2026, 1, 1),
        nextDate: DateTime(2026, 1, 1),
        frequency: PaymentFrequency.monthly,
      );
      await helper.insertPlannedPayment(payment);
      await ledger.recordPlannedPaymentOccurrence(
        payment: payment,
        amount: 10,
        accountId: 'cash',
        categoryId: 'cat_others',
        transactionId: 'jan',
        date: DateTime(2026, 1, 1),
      );
      payment = (await helper.getPlannedPayments()).single;
      await ledger.recordPlannedPaymentOccurrence(
        payment: payment,
        amount: 10,
        accountId: 'cash',
        categoryId: 'cat_others',
        transactionId: 'feb',
        date: DateTime(2026, 2, 1),
      );
      await ledger.voidTransaction('jan');
      expect(
        (await helper.getPlannedPayments()).single.nextDate,
        DateTime(2026, 3, 1),
      );
    },
  );

  test(
    'default currency backup replaces a different target currency',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final maintenance = container.read(appMaintenanceProvider);
      expect(container.read(settingsProvider).currency.code, 'USD');
      final bundle = (await maintenance.createBackup())!;
      final backup = File('${root.path}/default.db');
      await backup.writeAsBytes(bundle.bytes);
      await prefs.setString('currency_code', 'PHP');
      expect(await maintenance.restoreBackup(backup.path), isTrue);
      expect(container.read(settingsProvider).currency.code, 'USD');
    },
  );

  test('backup roundtrip restores privacy and haptics preferences', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hide_balance', true);
    await prefs.setBool('haptics_enabled', false);
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    final maintenance = container.read(appMaintenanceProvider);
    final bundle = (await maintenance.createBackup())!;
    final backup = File('${root.path}/privacy.db');
    await backup.writeAsBytes(bundle.bytes);
    await prefs.setBool('hide_balance', false);
    await prefs.setBool('haptics_enabled', true);
    expect(await maintenance.restoreBackup(backup.path), isTrue);
    expect(container.read(settingsProvider).hideBalance, true);
    expect(container.read(settingsProvider).hapticsEnabled, false);
  });

  for (final layout in [
    (width: 390.0, height: 844.0, dark: false, scale: 2.0),
    (width: 320.0, height: 568.0, dark: true, scale: 2.0),
    (width: 844.0, height: 390.0, dark: false, scale: 2.0),
    (width: 390.0, height: 844.0, dark: true, scale: 1.0),
  ]) {
    testWidgets('portfolio menu supports large text: $layout', (tester) async {
      final loader = FontLoader('Outfit');
      for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
        loader.addFont(
          rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'),
        );
      }
      await loader.load();
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          accountRepositoryProvider.overrideWithValue(InMemoryAccountAdapter()),
          ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryAdapter(),
          ),
          savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
          debtRepositoryProvider.overrideWithValue(InMemoryDebtAdapter()),
          plannedPaymentRepositoryProvider.overrideWithValue(
            InMemoryPlannedPaymentAdapter(),
          ),
        ],
      );
      addTearDown(container.dispose);
      tester.view.physicalSize = Size(layout.width, layout.height);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.getTheme(const Color(0xFF00D09E), layout.dark),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(layout.scale),
                disableAnimations: true,
              ),
              child: previewShell(context, child),
            ),
            home: const Scaffold(body: PortfolioScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Accounts'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture(
        tester,
        ['portfolio', layout.width, layout.dark, layout.scale].join('-'),
      );
      await tester.ensureVisible(find.text('Incomes'));
      await tester.tap(find.text('Incomes'));
      await tester.pumpAndSettle();
      expect(container.read(portfolioTabProvider), 4);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('division by zero cannot submit a valid money amount', (
    tester,
  ) async {
    String? submitted;
    var result = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NumPad(
            initialValue: '100/0',
            onValueChanged: (_, value) => result = value,
            onDone: () => submitted = result,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(submitted, isNull);
  });

  test(
    'latest tracked occurrence reopens, edited and legacy schedules do not',
    () async {
      final schedule = PlannedPayment(
        id: 'latest',
        title: 'Rent',
        amount: 10,
        type: TransactionType.expense,
        categoryId: 'cat_others',
        accountId: 'cash',
        startDate: DateTime(2026, 1, 31),
        nextDate: DateTime(2026, 1, 31),
        frequency: PaymentFrequency.monthly,
      );
      await helper.insertPlannedPayment(schedule);
      final tx = await ledger.recordPlannedPaymentOccurrence(
        payment: schedule,
        amount: 10,
        accountId: 'cash',
        categoryId: 'cat_others',
        date: DateTime(2026, 2, 4),
      );
      expect(
        (await helper.getPlannedPayments()).single.nextDate,
        DateTime(2026, 2, 28),
      );
      await ledger.voidTransaction(tx.id);
      expect(
        (await helper.getPlannedPayments()).single.nextDate,
        DateTime(2026, 1, 31),
      );
      expect(
        await (await helper.database).query('planned_payment_occurrences'),
        isEmpty,
      );
      final nextTx = await ledger.recordPlannedPaymentOccurrence(
        payment: schedule,
        amount: 10,
        accountId: 'cash',
        categoryId: 'cat_others',
      );
      var changed = (await helper.getPlannedPayments()).single.copyWith(
        frequency: PaymentFrequency.weekly,
      );
      await helper.updatePlannedPayment(changed);
      await ledger.voidTransaction(nextTx.id);
      expect(
        (await helper.getPlannedPayments()).single.nextDate,
        changed.nextDate,
      );
      await helper.insertTransaction(
        AppTransaction(
          id: 'legacy',
          amount: 10,
          date: DateTime(2026, 1, 31),
          type: TransactionType.expense,
          accountId: 'cash',
          categoryId: 'cat_others',
          plannedPaymentId: 'latest',
        ),
      );
      await ledger.voidTransaction('legacy');
      expect(
        (await helper.getPlannedPayments()).single.nextDate,
        changed.nextDate,
      );
    },
  );

  test(
    'version 44 migration adds occurrence tracking without changing history',
    () async {
      final db = await helper.database;
      await db.execute('DROP TRIGGER planned_occurrence_deleted');
      await db.execute('DROP TABLE planned_payment_occurrences');
      await db.setVersion(44);
      await helper.close();
      final upgraded = await helper.database;
      expect(await upgraded.getVersion(), databaseSchemaVersion);
      expect(await upgraded.query('planned_payment_occurrences'), isEmpty);
      expect((await helper.getAccounts()).any((a) => a.id == 'cash'), isTrue);
      await upgraded.insert('planned_payment_occurrences', {
        'transactionId': 'cleanup',
        'paymentId': 'p',
        'dueDate': '2026-01-01',
        'nextDate': '2026-02-01',
        'scheduleKey': 'test',
      });
      await helper.insertTransaction(
        AppTransaction(
          id: 'cleanup',
          amount: 1,
          date: DateTime(2026),
          type: TransactionType.income,
          categoryId: 'cat_salary',
          accountId: 'cash',
        ),
      );
      await helper.deleteAllTransactions();
      expect(await upgraded.query('planned_payment_occurrences'), isEmpty);
    },
  );

  test(
    'legacy and malformed backup settings reset to safe effective defaults',
    () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('currency_code', 'PHP');
      await prefs.setInt('theme_mode', 999);
      await prefs.setBool('hide_balance', true);
      await SettingsSnapshot.restore(prefs, {
        'theme_mode': '-1',
        'analysis_filter_index': '500',
      });
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final restored = container.read(settingsProvider);
      expect(restored.currency.code, 'USD');
      expect(restored.themeMode, ThemeMode.system);
      expect(restored.analysisFilterIndex, 0);
      expect(restored.hideBalance, false);
      final before = SettingsSnapshot.capture(prefs);
      await prefs.setBool('hide_balance', true);
      expect(SettingsSnapshot.capture(prefs), isNot(before));
      await prefs.setString('backup_destination', 'device-specific');
      await SettingsSnapshot.restore(prefs, before);
      expect(prefs.getString('backup_destination'), 'device-specific');
    },
  );

  test(
    'failed reorder restores prior positions and successful retry persists',
    () async {
      final accounts = FailingReorderAccounts(
        initial: [
          for (var i = 0; i < 3; i++)
            Account(
              id: 'a$i',
              name: 'Account $i',
              position: i,
              iconCodePoint: 0,
              colorHex: '#00D09E',
            ),
        ],
      );
      final container = ProviderContainer(
        overrides: [accountRepositoryProvider.overrideWithValue(accounts)],
      );
      addTearDown(container.dispose);
      final initial = await container.read(accountProvider.future);
      await expectLater(
        container.read(accountProvider.notifier).reorderAccounts(0, 2),
        throwsStateError,
      );
      expect(container.read(accountProvider).value, initial);
      accounts.failReorder = false;
      await container.read(accountProvider.notifier).reorderAccounts(0, 2);
      expect((await accounts.getAccounts()).map((a) => a.id), [
        'a1',
        'a2',
        'a0',
      ]);
    },
  );

  testWidgets(
    'calculator rejects incomplete input then recovers after correction',
    (tester) async {
      var expression = '100';
      var result = '100';
      var submissions = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NumPad(
              initialValue: expression,
              onValueChanged: (expr, value) {
                expression = expr;
                result = value;
              },
              onDone: () => submissions++,
            ),
          ),
        ),
      );
      for (final key in ['÷', '0', 'Save']) {
        await tester.tap(find.text(key));
        await tester.pumpAndSettle();
      }
      expect(submissions, 0);
      expect(expression, '100/0');
      expect(result, '');
      expect(find.text('Cannot divide by zero'), findsOneWidget);
      await tester.tap(find.byIcon(KoinIcons.backspace));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(submissions, 0);
      expect(find.text('Complete the calculation'), findsOneWidget);
      await tester.tap(find.text('2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(submissions, 1);
      expect(result, '50');
      KoinSnackBar.dismiss(tester.element(find.byType(NumPad)));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('dashboard shows loading and retry instead of a false zero', (
    tester,
  ) async {
    phoneView(tester);
    final prefs = await SharedPreferences.getInstance();
    final accounts = FailingReorderAccounts()
      ..loading = Completer<void>()
      ..failLoad = true;
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accountRepositoryProvider.overrideWithValue(accounts),
        ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
        categoryRepositoryProvider.overrideWithValue(InMemoryCategoryAdapter()),
        savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
        debtRepositoryProvider.overrideWithValue(InMemoryDebtAdapter()),
        plannedPaymentRepositoryProvider.overrideWithValue(
          InMemoryPlannedPaymentAdapter(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), false),
          builder: previewShell,
          home: const Scaffold(body: DashboardScreen()),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Total Balance'), findsNothing);
    accounts.loading!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Could not load your balances.'), findsOneWidget);
    expect(find.text('Total Balance'), findsNothing);
    await capture(tester, 'dashboard-error');
    accounts.failLoad = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Total Balance'), findsOneWidget);
    expect(find.text('Could not load your balances.'), findsNothing);
  });

  testWidgets(
    'flexible schedule disables automatic processing and explains it',
    (tester) async {
      phoneView(tester);
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          accountRepositoryProvider.overrideWithValue(InMemoryAccountAdapter()),
          categoryRepositoryProvider.overrideWithValue(
            InMemoryCategoryAdapter(),
          ),
          plannedPaymentRepositoryProvider.overrideWithValue(
            InMemoryPlannedPaymentAdapter(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.getTheme(const Color(0xFF00D09E), false),
            builder: previewShell,
            home: const AddEditCashflowScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      var toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.onChanged, isNull);
      expect(toggle.value, false);
      expect(
        find.text('Choose a repeating schedule to enable automatic entries.'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      await capture(tester, 'flexible-schedule');
      await tester.ensureVisible(find.text('Flexible'));
      await tester.tap(find.text('Flexible'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();
      toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.onChanged, isNotNull);
      expect(
        find.text('Records due entries while Koin is open or when you return.'),
        findsOneWidget,
      );
    },
  );

  test('large history search debounces and grouping is reused across reads', () async {
    final history = List.generate(
      20000,
      (i) => AppTransaction(
        id: 'history_$i',
        note: i.isEven ? 'Coffee' : 'Salary',
        amount: 1,
        date: DateTime(2026, 1, 1).add(Duration(minutes: i)),
        type: i.isEven ? TransactionType.expense : TransactionType.income,
        accountId: 'cash',
        categoryId: i.isEven ? 'food' : 'salary',
      ),
    );
    final container = ProviderContainer(
      overrides: [
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(initial: history),
        ),
        categoryRepositoryProvider.overrideWithValue(InMemoryCategoryAdapter()),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(transactionRowsProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(transactionProvider.future);
    await container.read(categoriesProvider.future);
    final watch = Stopwatch()..start();
    final rows = container.read(transactionRowsProvider).value!;
    watch.stop();
    debugPrint(
      '20,000 entries grouping: ${watch.elapsedMilliseconds} ms; ${rows.length} rows',
    );
    expect(
      identical(rows, container.read(transactionRowsProvider).value),
      true,
    );
    final filter = container.read(transactionFilterProvider.notifier);
    filter.setQuery('co');
    filter.setQuery('coffee');
    expect(container.read(transactionFilterProvider).query, 'coffee');
    expect(container.read(effectiveTransactionFilterProvider).query, '');
    expect(
      identical(rows, container.read(transactionRowsProvider).value),
      true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 240));
    expect(
      container.read(filteredTransactionsProvider).value,
      hasLength(10000),
    );
    filter.updateFilter(
      container
          .read(transactionFilterProvider)
          .copyWith(type: TransactionType.income),
    );
    expect(container.read(filteredTransactionsProvider).value, isEmpty);
    filter.clearFilters();
    expect(
      container.read(filteredTransactionsProvider).value,
      hasLength(20000),
    );
  });
}

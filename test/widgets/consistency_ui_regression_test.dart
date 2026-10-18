import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/main_layout.dart';
import 'package:koin/features/accounts/accounts_tab.dart';
import 'package:koin/features/cashflow/add_edit_cashflow_screen.dart';
import 'package:koin/features/cashflow/cashflow_tab.dart';
import 'package:koin/features/settings/settings_screen.dart';
import 'package:koin/core/maintenance/recovery_service.dart';
import 'package:koin/core/maintenance/recovery_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FailingAccounts extends InMemoryAccountAdapter {
  bool fail = true;
  @override
  Future<List<Account>> getAccounts() async {
    if (fail) throw StateError('private technical exception');
    return super.getAccounts();
  }
}

class _DelayedMaintenance extends InMemoryMaintenanceAdapter {
  int writes = 0;
  var completion = Completer<void>();
  @override
  Future<void> clearTransactions() async {
    writes++;
    await completion.future;
  }
}

class _TestRecovery extends RecoveryService {
  _TestRecovery(SharedPreferences preferences)
    : super(
        maintenance: InMemoryMaintenanceAdapter(),
        preferences: preferences,
        changeToken: () async => '',
        store: () async => RecoveryStore(Directory('unused')),
      );
  @override
  Future<void> runMaintenance(Future<void> Function() action) => action();
}

void main() {
  setUpAll(() async {
    if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
    final outfit = FontLoader('Outfit');
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      outfit.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await outfit.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  Future<ProviderContainer> providers({
    String code = 'USD',
    PlannedPaymentRepository? payments,
    AccountRepository? accounts,
    DebtRepository? debts,
    AppMaintenanceService? maintenance,
    RecoveryService? recovery,
  }) async {
    SharedPreferences.setMockInitialValues({
      'analysis_filter_index': 1,
      'currency_code': code,
    });
    final prefs = await SharedPreferences.getInstance();
    return ProviderContainer(
      overrides: [
        if (maintenance != null)
          appMaintenanceProvider.overrideWithValue(maintenance),
        if (recovery != null)
          recoveryServiceProvider.overrideWithValue(recovery),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(
            initial: [
              AppTransaction(
                id: 'expense',
                amount: 20,
                date: DateTime.now(),
                type: TransactionType.expense,
                categoryId: 'food',
                accountId: 'cash',
              ),
            ],
          ),
        ),
        accountRepositoryProvider.overrideWithValue(
          accounts ??
              InMemoryAccountAdapter(
                initial: [
                  Account(
                    id: 'cash',
                    name: 'Cash',
                    initialBalance: 5000,
                    iconCodePoint: Icons.wallet.codePoint,
                    colorHex: '#00D09E',
                  ),
                ],
              ),
        ),
        categoryRepositoryProvider.overrideWithValue(
          InMemoryCategoryAdapter(
            initial: [
              TransactionCategory(
                id: 'food',
                name: 'Food',
                iconCodePoint: Icons.restaurant.codePoint,
                colorHex: '#00D09E',
                type: TransactionType.expense,
                budget: 500,
              ),
              TransactionCategory(
                id: 'salary',
                name: 'Salary',
                iconCodePoint: Icons.work.codePoint,
                colorHex: '#00D09E',
                type: TransactionType.income,
              ),
            ],
          ),
        ),
        savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
        debtRepositoryProvider.overrideWithValue(
          debts ?? InMemoryDebtAdapter(),
        ),
        plannedPaymentRepositoryProvider.overrideWithValue(
          payments ?? InMemoryPlannedPaymentAdapter(),
        ),
        categorySuggesterProvider.overrideWithValue(TestStubSuggesterAdapter()),
        forecastProvider.overrideWith(
          (ref, index) async => ForecastData(
            forecastedInflow: 0,
            forecastedOutflow: 0,
            currentBaseline: 5000,
            predictedNetBalance: 5000,
            isWarning: false,
          ),
        ),
      ],
    );
  }

  Future<void> launch(
    WidgetTester tester,
    Widget page,
    ProviderContainer container, {
    bool reduce = false,
    double width = 390,
    bool dark = false,
    double scale = 1,
    Color accent = const Color(0xFF00D09E),
  }) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.getTheme(accent, dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              disableAnimations: reduce,
              textScaler: TextScaler.linear(scale),
            ),
            child: RepaintBoundary(key: const Key('ui-preview'), child: child!),
          ),
          home: page,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('dashboard balance is left aligned with compact text spacing', (
    tester,
  ) async {
    final container = await providers();
    addTearDown(container.dispose);
    await launch(tester, const MainLayout(), container, reduce: true);
    final card = find.byType(KoinSummaryCard).first;
    final amount = find
        .descendant(of: card, matching: find.byType(AnimatedCounter))
        .first;
    final summary = find.descendant(of: card, matching: find.byType(Text)).last;
    final balanceToggle = find.byTooltip('Hide total balance');
    expect(
      tester.getCenter(find.text('Total Balance')).dy,
      closeTo(tester.getCenter(balanceToggle).dy, 1),
    );
    expect(
      tester.getTopLeft(summary).dy - tester.getBottomLeft(amount).dy,
      closeTo(16, 1),
    );
    expect(
      tester.getTopLeft(amount).dx,
      closeTo(tester.getTopLeft(find.text('Total Balance')).dx, 1),
    );
    expect(tester.getSize(balanceToggle), const Size(48, 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed async swipe remains usable and retries once', (
    tester,
  ) async {
    var completion = Completer<void>();
    var writes = 0;
    var exists = true;
    late StateSetter redraw;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              redraw = setState;
              return exists
                  ? SwipeToDeleteTile(
                      key: const Key('row'),
                      confirmDismiss: (_) async => true,
                      onDelete: () async {
                        writes++;
                        await completion.future;
                        redraw(() => exists = false);
                      },
                      child: const SizedBox(
                        height: 80,
                        width: double.infinity,
                        child: Text('Entry'),
                      ),
                    )
                  : const Text('Deleted');
            },
          ),
        ),
      ),
    );
    await tester.drag(find.byType(SwipeToDeleteTile), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(writes, 1);
    final pendingSwipe = tester.widget<Dismissible>(find.byType(Dismissible));
    expect(
      await pendingSwipe.confirmDismiss!(DismissDirection.endToStart),
      isFalse,
    );
    expect(writes, 1);
    completion.completeError(StateError('write failed'));
    await tester.pumpAndSettle();
    expect(find.text('Entry'), findsOneWidget);
    expect(find.text('Could not delete this item'), findsOneWidget);
    expect(tester.takeException(), isNull);
    completion = Completer<void>();
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SwipeToDeleteTile), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(writes, 2);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.text('Deleted'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'keyboard activation has one ordinary haptic; cancellation has none',
    (tester) async {
      final haptics = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            haptics.add(call.arguments as String);
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PressableScale(
              semanticLabel: 'Action',
              onTap: () {
                HapticService.light();
                taps++;
              },
              child: const SizedBox(
                width: 100,
                height: 60,
                child: Text('Action'),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PressableScale)),
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(haptics, isEmpty);
      await tester.tap(find.byType(PressableScale));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(haptics, hasLength(1));
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(taps, 2);
      expect(haptics, hasLength(2));
    },
  );

  testWidgets(
    'main tabs retain historical periods and expose selected labels at 320 dp',
    (tester) async {
      final container = await providers();
      addTearDown(container.dispose);
      await launch(
        tester,
        const MainLayout(),
        container,
        width: 320,
        reduce: true,
      );
      final semantics = tester.ensureSemantics();
      await tester.tap(find.byTooltip('Budgets'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
      await tester.pumpAndSettle();
      final now = DateTime.now();
      final previous = DateFormat('MMMM yyyy')
          .format(DateTime(now.year, now.month - 1));
      expect(find.text(previous), findsOneWidget);
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Budgets'));
      await tester.pumpAndSettle();
      expect(find.text(previous), findsOneWidget);
      expect(
        tester
            .getSemantics(find.bySemanticsLabel('Budgets'))
            .flagsCollection
            .isSelected,
        ui.Tristate.isTrue,
      );
      expect(
        tester.getSize(find.byTooltip('Budgets')).height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(find.byTooltip('Activity'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
      await tester.pumpAndSettle();
      expect(find.text(previous), findsOneWidget);
      await tester.tap(find.byTooltip('Home'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Activity'));
      await tester.pumpAndSettle();
      expect(find.text(previous), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

  testWidgets(
    'privacy explanations are tooltip-only and preserve inclusion behavior',
    (tester) async {
      final container = await providers();
      addTearDown(container.dispose);
      final account = (await container.read(accountProvider.future)).single;
      await launch(
        tester,
        Scaffold(
          body: AccountItem(
            account: account,
            balance: 5000,
            currencySymbol: r'$',
            onTap: () {},
            onPrivateToggle: () => container
                .read(accountProvider.notifier)
                .updateAccount(account.copyWith(excludeFromTotal: true)),
          ),
        ),
        container,
      );
      expect(find.text('Hide balance and exclude from totals'), findsNothing);
      expect(
        find.byTooltip('Hide balance and exclude from totals'),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byTooltip('Hide balance and exclude from totals'))
            .height,
        48,
      );
      await tester.tap(find.byTooltip('Hide balance and exclude from totals'));
      await tester.pumpAndSettle();
      expect(
        container.read(accountProvider).requireValue.single.excludeFromTotal,
        isTrue,
      );
    },
  );

  testWidgets(
    'new incomes have no end-date prompt; expenses offer an optional date',
    (tester) async {
      final container = await providers();
      addTearDown(container.dispose);
      await launch(
        tester,
        const AddEditCashflowScreen(initialType: TransactionType.income),
        container,
      );
      expect(find.text('Ends on'), findsNothing);
      expect(find.text('Add end date'), findsNothing);
      await launch(
        tester,
        const AddEditCashflowScreen(initialType: TransactionType.expense),
        container,
      );
      expect(find.text('Ends on'), findsNothing);
      expect(find.text('Add end date'), findsOneWidget);
      await tester.tap(find.text('Add end date'));
      await tester.pumpAndSettle();
      expect(find.text('Ends on'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove end date'));
      await tester.pumpAndSettle();
      expect(find.text('Ends on'), findsNothing);
    },
  );

  testWidgets(
    'existing income end dates can be removed and invalid ranges cannot save',
    (tester) async {
      final now = DateTime.now();
      final income = PlannedPayment(
        id: 'income',
        title: 'Salary',
        amount: 500,
        type: TransactionType.income,
        categoryId: 'salary',
        accountId: 'cash',
        startDate: now,
        nextDate: now,
        endDate: now.subtract(const Duration(days: 1)),
        frequency: PaymentFrequency.monthly,
      );
      final repository = InMemoryPlannedPaymentAdapter(initial: [income]);
      final container = await providers(payments: repository);
      addTearDown(container.dispose);
      await launch(tester, AddEditCashflowScreen(payment: income), container);
      expect(find.text('Ends on'), findsOneWidget);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Check the end date'), findsOneWidget);
      expect(
        (await repository.getPlannedPayments()).single.endDate,
        income.endDate,
      );
      await tester.tap(find.byTooltip('Remove end date'));
      await tester.pumpAndSettle();
      expect(find.text('Ends on'), findsNothing);
      expect(find.text('Add end date'), findsNothing);
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect((await repository.getPlannedPayments()).single.endDate, isNull);
    },
  );

  testWidgets('expired and future flexible schedules disable payment actions', (
    tester,
  ) async {
    final now = DateTime.now();
    PlannedPayment payment(String id, {DateTime? start, DateTime? end}) =>
        PlannedPayment(
          id: id,
          title: id,
          amount: 1234.5,
          type: TransactionType.income,
          categoryId: '',
          accountId: 'cash',
          startDate: start ?? now.subtract(const Duration(days: 30)),
          nextDate: now,
          endDate: end,
          frequency: PaymentFrequency.flexible,
        );
    final repository = InMemoryPlannedPaymentAdapter(
      initial: [
        payment('future', start: now.add(const Duration(days: 7))),
        payment('expired', end: now.subtract(const Duration(days: 1))),
        payment('active'),
      ],
    );
    final container = await providers(code: 'JPY', payments: repository);
    addTearDown(container.dispose);
    await launch(
      tester,
      const Scaffold(body: RecurringIncomesTab()),
      container,
      reduce: true,
    );
    for (final title in ['future', 'expired']) {
      final card = find.ancestor(
        of: find.text(title),
        matching: find.byType(PressableScale),
      );
      final action = find.descendant(of: card, matching: find.byType(InkWell));
      expect(tester.widget<InkWell>(action).onTap, isNull);
    }
    expect(find.textContaining('Available from'), findsOneWidget);
    expect(find.textContaining('Ended '), findsOneWidget);
    expect(find.text('Available anytime'), findsOneWidget);
    expect(find.text('+¥1,235'), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed list provider has friendly feedback and a working retry',
    (tester) async {
      final repository = _FailingAccounts();
      final container = await providers(accounts: repository);
      addTearDown(container.dispose);
      await launch(
        tester,
        const Scaffold(
          body: AccountsTab(
            animationSessionKey: 'retry',
            showEntranceAnimations: false,
          ),
        ),
        container,
      );
      expect(find.byType(KoinErrorState), findsOneWidget);
      expect(find.textContaining('private technical exception'), findsNothing);
      repository.fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(KoinErrorState), findsNothing);
      expect(container.read(accountProvider).requireValue, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('rapid main-tab changes keep the page fully visible', (
    tester,
  ) async {
    final container = await providers();
    addTearDown(container.dispose);
    await launch(tester, const MainLayout(), container);
    for (final index in [1, 2, 3, 0, 1]) {
      container.read(navigationProvider.notifier).setIndex(index);
      await tester.pump();
      final scaffold = tester.widget<Scaffold>(
        find
            .descendant(
              of: find.byType(MainLayout),
              matching: find.byType(Scaffold),
            )
            .first,
      );
      expect(scaffold.body, isA<IndexedStack>());
      expect((scaffold.body! as IndexedStack).index, index);
      await tester.pump(const Duration(milliseconds: 30));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion interrupts active widget and list entrances', (
    tester,
  ) async {
    var reduced = false;
    late StateSetter redraw;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            redraw = setState;
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: Builder(
                builder: (context) => Column(
                  children: [
                    const Text('Widget')
                        .koinAnimate(context)
                        .fade(duration: const Duration(seconds: 2))
                        .slideY(begin: 0.2),
                    ...[const Text('List one'), const Text('List two')]
                        .koinAnimate(
                          context,
                          interval: const Duration(seconds: 1),
                        )
                        .fade(duration: const Duration(seconds: 2)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widgetList<Animate>(find.byType(Animate)).every((a) => a.autoPlay),
      isTrue,
    );
    redraw(() => reduced = true);
    await tester.pump();
    for (final animation in tester.widgetList<Animate>(find.byType(Animate))) {
      expect(animation.autoPlay, isFalse);
      expect(animation.value, 1);
    }
    for (final fade in tester.widgetList<FadeTransition>(
      find.byType(FadeTransition),
    )) {
      expect(fade.opacity.value, 1);
    }
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    // Drain flutter_animate's previously scheduled list-delay timer after
    // verifying that reduced motion immediately finished every entrance.
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    for (final fade in tester.widgetList<FadeTransition>(
      find.byType(FadeTransition),
    )) {
      expect(fade.opacity.value, 1);
    }
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('review actual screens in both themes with preserved fills', (
    tester,
  ) async {
    Future<void> capture(String name) async {
      if (!const bool.fromEnvironment('UI_PREVIEWS')) return;
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('ui-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        await Directory('build/consistency-review').create(recursive: true);
        await File('build/consistency-review/$name.png')
            .writeAsBytes(data!.buffer.asUint8List());
      });
    }

    for (final dark in [false, true]) {
      final container = await providers();
      addTearDown(container.dispose);
      await launch(
        tester,
        const MainLayout(),
        container,
        dark: dark,
        reduce: true,
      );
      await capture('dashboard-${dark ? 'dark' : 'light'}');
      await tester.tap(find.byTooltip('Activity'));
      await tester.pumpAndSettle();
      await capture('analysis-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);
      await launch(
        tester,
        const AddEditCashflowScreen(initialType: TransactionType.income),
        container,
        dark: dark,
        reduce: true,
      );
      expect(find.text('Add end date'), findsNothing);
      await capture('income-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);

      final portfolio = await providers(
        debts: InMemoryDebtAdapter(
          initial: [
            Debt(
              id: 'credit',
              personName: 'SPayLater',
              amount: 1992,
              type: DebtType.iOwe,
              startDate: DateTime(2026),
              currentAmount: 1992,
            ),
            Debt(
              id: 'iou',
              personName: 'Nicole',
              amount: 1775,
              type: DebtType.iOwe,
              startDate: DateTime(2026),
              currentAmount: 0,
            ),
          ],
        ),
      );
      addTearDown(portfolio.dispose);
      portfolio.read(navigationProvider.notifier).setIndex(3);
      portfolio.read(portfolioTabProvider.notifier).setIndex(2);
      await launch(
        tester,
        const MainLayout(),
        portfolio,
        dark: dark,
        reduce: true,
      );
      // Finish the Portfolio's one-time entrance-session timer before disposal.
      await tester.pump(const Duration(milliseconds: 1200));
      await tester.pumpAndSettle();
      await capture('debts-${dark ? 'dark' : 'light'}');
      expect(tester.takeException(), isNull);
    }
    final container = await providers();
    addTearDown(container.dispose);
    await launch(
      tester,
      const MainLayout(),
      container,
      width: 320,
      scale: 1.4,
      accent: const Color(0xFFEAB308),
      reduce: true,
    );
    await capture('dashboard-yellow-large-text');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Settings delete-all is guarded while pending and can retry a failure',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final recovery = _TestRecovery(await SharedPreferences.getInstance());
      addTearDown(recovery.dispose);
      final maintenance = _DelayedMaintenance();
      final container = await providers(
        maintenance: maintenance,
        recovery: recovery,
      );
      addTearDown(container.dispose);
      await launch(tester, const SettingsScreen(), container, reduce: true);
      await tester.ensureVisible(find.text('Delete All Records'));
      await tester.tap(find.text('Delete All Records'));
      // The maintenance guard intentionally keeps progress active while the
      // confirmation and write are pending; settling would wait forever.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(maintenance.writes, 1);
      final tile = tester.widget<KoinSettingTile>(
        find.ancestor(
          of: find.text('Delete All Records'),
          matching: find.byType(KoinSettingTile),
        ),
      );
      tile.onTap!();
      expect(maintenance.writes, 1);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      maintenance.completion.completeError(StateError('write failed'));
      await tester.pumpAndSettle();
      expect(find.text('Could not finish this action'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      maintenance.completion = Completer<void>();
      await tester.tap(find.text('Delete All Records'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Delete'));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      expect(maintenance.writes, 2);
      maintenance.completion.complete();
      await tester.pumpAndSettle();
      expect(find.text('All transactions deleted'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'guarded destructive actions suppress duplicates and allow retry after failure',
    (tester) async {
      final guard = KoinAsyncActionGuard();
      var writes = 0;
      var completion = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => guard.run(context, () async {
                  writes++;
                  await completion.future;
                }),
                child: const Text('Delete'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete'));
      await tester.tap(find.text('Delete'));
      expect(writes, 1);
      completion.completeError(StateError('maintenance failed'));
      await tester.pumpAndSettle();
      expect(find.text('Could not finish this action'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      completion = Completer<void>();
      await tester.tap(find.text('Delete'));
      expect(writes, 2);
      completion.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

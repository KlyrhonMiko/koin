import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:csv/csv.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:koin/features/main_layout.dart';
import 'package:koin/features/budgets/budgets_screen.dart';
import 'package:koin/features/transactions/transactions_list_screen.dart';
import 'package:koin/features/reports/custom_reports_screen.dart';
import 'package:koin/main.dart';
import 'package:koin/core/maintenance/recovery_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/accounts/account_form_screen.dart';
import 'package:koin/features/analysis/analysis_screen.dart';
import 'package:koin/features/analysis/widgets/forecast_summary.dart';
import 'package:koin/features/dashboard/upcoming_screen.dart';
import 'package:koin/features/reports/report_service.dart';

class FailedSchedules extends InMemoryPlannedPaymentAdapter {
  bool fail = true;
  @override
  Future<List<PlannedPayment>> getPlannedPayments() async {
    if (fail) throw StateError('Read failed');
    return [];
  }
}

class PendingSchedules extends InMemoryPlannedPaymentAdapter {
  final ready = Completer<List<PlannedPayment>>();
  @override
  Future<List<PlannedPayment>> getPlannedPayments() => ready.future;
}

class NoopRecovery implements RecoveryService {
  @override
  void start() {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class NoopPayments extends AutomaticPaymentsNotifier {
  @override
  void start() {}
  @override
  void stop() {}
}

class NoopInterest extends DailyInterestNotifier {
  @override
  void start() {}
  @override
  void stop() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final cash = Account(
    id: 'cash',
    name: 'Cash',
    initialBalance: 0.1,
    iconCodePoint: KoinIcons.wallet.codePoint,
    colorHex: '#008080',
  );
  final income = AppTransaction(
    id: 'income',
    amount: 0.2,
    date: DateTime.now(),
    accountId: 'cash',
    categoryId: 'salary',
    type: TransactionType.income,
  );
  const forecast = ForecastData(
    forecastedInflow: 2000,
    forecastedOutflow: 1000,
    currentBaseline: 234.56,
    predictedNetBalance: 1234.56,
    isWarning: false,
    lowerNetBalance: 1000,
    upperNetBalance: 1500,
    historyMonths: 12,
  );

  Future<ProviderContainer> setup({
    bool hidden = false,
    bool failedSchedules = false,
    SavingsRepository? savings,
    PlannedPaymentRepository? schedules,
    List<AppTransaction>? transactions,
    DateTime Function()? clock,
    List<Account>? accounts,
  }) async {
    SharedPreferences.setMockInitialValues({
      'hide_balance': hidden,
      'analysis_filter_index': 1,
    });
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        recoveryServiceProvider.overrideWithValue(NoopRecovery()),
        automaticPaymentsProvider.overrideWith(NoopPayments.new),
        dailyInterestProvider.overrideWith(NoopInterest.new),
        sharedPreferencesProvider.overrideWithValue(prefs),
        ledgerProvider.overrideWithValue(
          InMemoryLedgerAdapter(initial: transactions ?? [income]),
        ),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(initial: accounts ?? [cash]),
        ),
        categoryRepositoryProvider.overrideWithValue(InMemoryCategoryAdapter()),
        savingsRepositoryProvider.overrideWithValue(
          savings ?? InMemorySavingsAdapter(),
        ),
        debtRepositoryProvider.overrideWithValue(InMemoryDebtAdapter()),
        plannedPaymentRepositoryProvider.overrideWithValue(
          schedules ??
              (failedSchedules
                  ? FailedSchedules()
                  : InMemoryPlannedPaymentAdapter()),
        ),
        if (clock != null) calendarClockProvider.overrideWithValue(clock),
        categorySuggesterProvider.overrideWithValue(TestStubSuggesterAdapter()),
        forecastProvider(1).overrideWith((ref) async => forecast),
      ],
    );
    addTearDown(c.dispose);
    await c.read(accountProvider.future);
    await c.read(transactionProvider.future);
    await c.read(categoriesProvider.future);
    return c;
  }

  Future<void> open(
    WidgetTester tester,
    ProviderContainer c,
    Widget page, {
    Size size = const Size(390, 844),
    double scale = 1,
    bool dark = false,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00D09E), dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: RepaintBoundary(
              key: const ValueKey('exploration-preview'),
              child: child!,
            ),
          ),
          home: page,
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('EXPLORATION_PREVIEWS')) return;
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('exploration-preview')),
    );
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      await Directory('build/exploration-previews').create(recursive: true);
      await File('build/exploration-previews/$name.png')
          .writeAsBytes(data!.buffer.asUint8List());
    });
  }

  setUpAll(() async {
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
    for (final entry in {
      'PhosphorRegular': 'Phosphor.ttf',
      'PhosphorFill': 'Phosphor-Fill.ttf',
    }.entries) {
      await (FontLoader('packages/phosphor_icons/${entry.key}')
            ..addFont(rootBundle.load('packages/phosphor_icons/lib/fonts/${entry.value}')))
          .load();
    }
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  testWidgets(
    'account editor rounds computed cents and saves unrelated changes',
    (tester) async {
      final c = await setup();
      await open(
        tester,
        c,
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AccountFormScreen(account: cash),
                ),
              ),
              child: const Text('Open account'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open account'));
      await tester.pumpAndSettle();
      final field = tester
          .widgetList<TextField>(find.byType(TextField))
          .firstWhere((f) => f.controller!.text == '0.30');
      expect(field.controller!.text, '0.30');
      final name = find.byWidgetPredicate(
        (w) => w is TextField && w.controller!.text == 'Cash',
      );
      await tester.enterText(name, 'Renamed cash');
      expect(
        c.read(settingsProvider).currency.tryParseInput(field.controller!.text),
        0.30,
      );
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Check account details'), findsNothing);
      expect(find.text('Open account'), findsOneWidget);
      expect(find.text('Discard account changes?'), findsNothing);
      expect(
        (await c.read(accountRepositoryProvider).getAccounts()).single.name,
        'Renamed cash',
      );
      expect(
        (await c.read(accountRepositoryProvider).getAccounts())
            .single
            .initialBalance,
        0.1,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('income-only history keeps forecast available', (tester) async {
    final c = await setup();
    await open(tester, c, const AnalysisScreen());
    expect(find.text('No expenses found'), findsOneWidget);
    expect(find.byType(ForecastSummary), findsOneWidget);
    await capture(tester, 'analysis-income-only-light');
    expect(
      (await c.read(forecastProvider(1).future)).predictedNetBalance,
      1234.56,
    );
  });

  testWidgets(
    'summary privacy also masks forecast details and balance ranges',
    (tester) async {
      final c = await setup(hidden: true);
      await open(tester, c, const AnalysisScreen(), dark: true);
      expect(c.read(settingsProvider).hideBalance, isTrue);
      expect(find.text(r'$1,234.56'), findsNothing);
      expect(find.text('Summary amounts hidden'), findsOneWidget);
      await tester.tap(find.text('Details'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('How this is estimated'));
      await tester.pumpAndSettle();
      for (final amount in [
        r'$1,234.56',
        r'$234.56',
        r'$2,000.00',
        r'$1,000.00',
        r'$1,500.00',
      ]) {
        expect(find.textContaining(amount), findsNothing);
      }
      await capture(tester, 'forecast-hidden-details-dark');
    },
  );

  testWidgets('failed schedules show a retry instead of an empty timeline', (
    tester,
  ) async {
    final c = await setup(failedSchedules: true);
    try {
      await c.read(plannedPaymentProvider.future);
    } catch (_) {}
    await c.read(debtsProvider.future);
    await open(tester, c, const UpcomingScreen());
    expect(c.read(plannedPaymentProvider).hasError, isTrue);
    expect(find.text('Nothing upcoming'), findsNothing);
    expect(find.byType(KoinErrorState), findsOneWidget);
    await capture(tester, 'upcoming-error-light');
    (c.read(plannedPaymentRepositoryProvider) as FailedSchedules).fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing upcoming'), findsOneWidget);
  });

  testWidgets(
    'resume refreshes external savings balances and already-loaded logs',
    (tester) async {
      final goal = SavingsGoal(
        id: 'goal',
        name: 'Emergency',
        currentAmount: 0.2,
        startDate: DateTime.now(),
        isStash: true,
        linkedAccountId: 'cash',
      );
      final repository = InMemorySavingsAdapter(initial: [goal]);
      final c = await setup(savings: repository);
      await c.read(savingsGoalsProvider.future);
      await c.read(savingsLogsProvider(goal.id).future);
      await open(tester, c, const MyApp());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await repository.insertSavingsLog(
        SavingsLog(
          id: 'release',
          goalId: goal.id,
          amount: -0.1,
          date: DateTime.now(),
          note: 'External release',
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect((await repository.getSavingsGoals()).single.currentAmount, 0.1);
      expect(
        (await c.read(savingsGoalsProvider.future)).single.currentAmount,
        0.1,
      );
      expect(
        (await c.read(savingsLogsProvider(goal.id).future)).single.note,
        'External release',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('report selectors retain touch size in compact windows', (
    tester,
  ) async {
    final c = await setup();
    await open(tester, c, const CustomReportsScreen());
    tester.view.physicalSize = const Size(300, 844);
    await tester.pumpAndSettle();
    final height = tester
        .getSize(find.byType(KoinSelectableOption).first)
        .height;
    expect(height, greaterThanOrEqualTo(48));
    expect(tester.takeException(), isNull);
    await capture(tester, 'reports-compact-light');
  });

  testWidgets('day totals use readable light-theme foregrounds', (
    tester,
  ) async {
    final c = await setup();
    await open(tester, c, const Scaffold(body: TransactionsListScreen()));
    final total = tester
        .widgetList<Text>(find.text(r'+$0.20'))
        .firstWhere((w) => w.style?.fontSize == KoinTypography.caption);
    final contrast = AppTheme.contrast(
      total.style!.color!,
      const Color(0xFFF8F9FA),
    );
    expect(contrast, greaterThanOrEqualTo(4.5));
  });

  testWidgets('empty history keeps forecast and period navigation available', (
    tester,
  ) async {
    final c = await setup(transactions: []);
    await open(tester, c, const AnalysisScreen());
    expect(find.byType(ForecastSummary), findsOneWidget);
    expect(find.byType(KoinPeriodNavigation), findsOneWidget);
    expect(find.text('No expenses found'), findsOneWidget);
  });

  testWidgets('upcoming loading does not claim the timeline is empty', (
    tester,
  ) async {
    final schedules = PendingSchedules();
    final c = await setup(schedules: schedules);
    await open(tester, c, const UpcomingScreen(), settle: false);
    await tester.pump();
    expect(find.text('Nothing upcoming'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    schedules.ready.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Nothing upcoming'), findsOneWidget);
  });

  for (final page in [const BudgetsScreen(), const AnalysisScreen()]) {
    testWidgets(
      '$page follows month rollover while preserving historical browsing',
      (tester) async {
        var now = DateTime(2026, 10, 31, 23, 59);
        final c = await setup(clock: () => now);
        await c
            .read(categoryRepositoryProvider)
            .insertCategory(
              TransactionCategory(
                id: 'food',
                name: 'Food',
                type: TransactionType.expense,
                iconCodePoint: KoinIcons.forkKnife.codePoint,
                colorHex: '#008080',
                budget: 100,
              ),
            );
        c.invalidate(categoriesProvider);
        await open(tester, c, page);
        expect(
          tester
              .widget<KoinPeriodNavigation>(find.byType(KoinPeriodNavigation))
              .label,
          'October 2026',
        );
        final calendar = c.read(calendarDayProvider.notifier);
        calendar.start();
        now = DateTime(2026, 11, 1, 0, 1);
        await tester.pump(const Duration(minutes: 2));
        await tester.pumpAndSettle();
        calendar.suspend();
        expect(
          tester
              .widget<KoinPeriodNavigation>(find.byType(KoinPeriodNavigation))
              .label,
          'November 2026',
        );
        await tester.tap(find.byTooltip('Previous month'));
        await tester.pumpAndSettle();
        now = DateTime(2026, 12, 1);
        calendar.refresh();
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<KoinPeriodNavigation>(find.byType(KoinPeriodNavigation))
              .label,
          'October 2026',
        );
      },
    );
  }

  testWidgets(
    'calendar refresh updates balance when a dated entry becomes effective',
    (tester) async {
      var now = DateTime(2026, 10, 31, 23, 59);
      final c = await setup(
        clock: () => now,
        transactions: [income.copyWith(date: DateTime(2026, 11, 1))],
      );
      expect(
        c.read(dashboardStatsProvider).currentBalance,
        closeTo(0.1, 0.00001),
      );
      now = DateTime(2026, 11, 1, 0, 1);
      c.read(calendarDayProvider.notifier).refresh();
      expect(
        c.read(dashboardStatsProvider).currentBalance,
        closeTo(0.3, 0.00001),
      );
    },
  );

  for (final variant in [
    (name: 'phone-light', size: const Size(390, 844), scale: 1.0, dark: false),
    (
      name: 'phone-dark-large',
      size: const Size(320, 844),
      scale: 2.0,
      dark: true,
    ),
    (name: 'tablet-dark', size: const Size(900, 1000), scale: 1.0, dark: true),
  ]) {
    testWidgets('navigation presentation and destinations on ${variant.name}', (
      tester,
    ) async {
      final c = await setup();
      await open(
        tester,
        c,
        const MainLayout(),
        size: variant.size,
        scale: variant.scale,
        dark: variant.dark,
      );
      expect(
        find.text('Home'),
        variant.size.width >= 840 ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(NavigationRail),
        variant.size.width >= 840 ? findsOneWidget : findsNothing,
      );
      await capture(tester, 'navigation-${variant.name}');
      if (variant.size.width < 840) {
        await tester.tap(find.byTooltip('Budgets'));
      } else {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text('Budgets'),
          ),
        );
      }
      await tester.pumpAndSettle();
      expect(c.read(navigationProvider), 2);
      expect(
        find.text('Budgets'),
        variant.size.width >= 840 ? findsOneWidget : findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('report long names remain selectable at large text size', (
    tester,
  ) async {
    const name = 'Savings account for family emergency expenses';
    final c = await setup(accounts: [cash.copyWith(name: name)]);
    await open(
      tester,
      c,
      const CustomReportsScreen(),
      size: const Size(320, 844),
      scale: 2,
      dark: true,
    );
    final option = find.byWidgetPredicate(
      (w) => w is KoinSelectableOption && w.label == name,
    );
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(tester.widget<KoinSelectableOption>(option).selected, isTrue);
    expect(find.byTooltip(name), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, 'reports-large-dark');
  });

  test(
    'CSV neutralizes formula prefixes in text while preserving numeric amounts',
    () async {
      for (final note in [
        '=1+1',
        '+SUM(A1)',
        '-10',
        '@SUM(A1)',
        '  =1+1',
        '\tformula',
        '\rformula',
        '\nformula',
      ]) {
        final bytes = await ReportService.generateCSV(
          transactions: [income.copyWith(note: note)],
          categories: [],
          accounts: [cash.copyWith(name: '=Account')],
          currencyCode: 'USD',
        );
        final rows = csv.decode(utf8.decode(bytes));
        expect(rows[1][1], '0.2');
        expect(rows[1][4], "'=Account");
        expect(rows[1][6], "'$note");
      }
      final bytes = await ReportService.generateCSV(
        transactions: [income.copyWith(note: 'Coffee, paid "cash"')],
        categories: [],
        accounts: [cash],
        currencyCode: 'USD',
      );
      expect(csv.decode(utf8.decode(bytes))[1][6], 'Coffee, paid "cash"');
    },
  );
}

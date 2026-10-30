import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/core/providers/effective_transaction_clock_provider.dart';
import 'package:koin/features/accounts/accounts_tab.dart';
import 'package:koin/features/cashflow/cashflow.dart';
import 'package:koin/features/dashboard/dashboard_screen.dart';
import 'package:koin/features/main_layout.dart';
import 'package:koin/features/reports/custom_reports_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Transactions extends TransactionNotifier {
  _Transactions(this.entries);
  final List<AppTransaction> entries;
  @override
  Future<List<AppTransaction>> build() async => entries;
}

final _now = DateTime(2026, 11, 1, 12);
final _accounts = [
  for (final name in ['MariBank', 'GoTyme'])
    Account(
      id: name,
      name: name,
      initialBalance: 10000,
      iconCodePoint: KoinIcons.wallet.codePoint,
      colorHex: '#00D09E',
    ),
];

AppTransaction _tx(
  String id,
  DateTime date, {
  double amount = 50,
  TransactionType type = TransactionType.expense,
}) => AppTransaction(
  id: id,
  note: id,
  amount: amount,
  date: date,
  type: type,
  categoryId: 'food',
  accountId: 'MariBank',
);

Future<ProviderContainer> _launch(
  WidgetTester tester, {
  List<AppTransaction> transactions = const [],
  List<Account>? accounts,
  List<PlannedPayment> payments = const [],
  DateTime? now,
  double width = 375,
  double scale = 1,
  bool dark = true,
  bool reduced = true,
  Widget home = const Scaffold(body: DashboardScreen()),
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
  AnimationTracker.clear();
  final prefs = await SharedPreferences.getInstance();
  final at = now ?? _now;
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      calendarClockProvider.overrideWithValue(() => at),
      effectiveTransactionClockProvider.overrideWithValue(at),
      ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
      transactionProvider.overrideWith(() => _Transactions(transactions)),
      accountRepositoryProvider.overrideWithValue(
        InMemoryAccountAdapter(initial: accounts ?? _accounts),
      ),
      categoryRepositoryProvider.overrideWithValue(InMemoryCategoryAdapter()),
      savingsRepositoryProvider.overrideWithValue(InMemorySavingsAdapter()),
      debtRepositoryProvider.overrideWithValue(InMemoryDebtAdapter()),
      plannedPaymentRepositoryProvider.overrideWithValue(
        InMemoryPlannedPaymentAdapter(initial: payments),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.getTheme(const Color(0xFF00D09E), dark),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduced,
          ),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(() async {
    final fonts = FontLoader(KoinTypography.fontFamily);
    for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
      fonts.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await fonts.load();
    final icons = FontLoader('packages/phosphor_icons/PhosphorRegular')
      ..addFont(
        rootBundle.load('packages/phosphor_icons/lib/fonts/Phosphor.ttf'),
      );
    await icons.load();
  });

  testWidgets(
    'weekly bars include previous-month spending and exclude future entries',
    (tester) async {
      final providers = await _launch(
        tester,
        transactions: [
          _tx('tomorrow', _now.add(const Duration(days: 1)), amount: 100),
          _tx('later today', _now.add(const Duration(hours: 1)), amount: 75),
          _tx('last month', DateTime(2026, 10, 31, 12)),
        ],
      );
      expect(providers.read(dashboardStatsProvider).totalExpense, 0);
      final chart = tester.widget<BarChart>(find.byType(BarChart));
      expect(
        chart.data.barGroups.fold<double>(
          0,
          (total, group) => total + group.barRods.single.toY,
        ),
        50,
      );
      expect(find.text('No spending this week'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'income-only and older spending have a compact weekly empty state',
    (tester) async {
      await _launch(
        tester,
        transactions: [
          _tx(
            'income',
            _now.subtract(const Duration(hours: 1)),
            type: TransactionType.income,
          ),
          _tx('old expense', _now.subtract(const Duration(days: 15))),
        ],
      );
      expect(find.text('No spending this week'), findsOneWidget);
      expect(find.byType(BarChart), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('future records cannot displace completed recent activity', (
    tester,
  ) async {
    await _launch(
      tester,
      transactions: [
        for (var i = 0; i < 12; i++)
          _tx('future $i', _now.add(Duration(days: i + 1))),
        _tx('completed record', _now.subtract(const Duration(hours: 1))),
      ],
    );
    expect(find.text('completed record'), findsOneWidget);
    expect(find.textContaining('future '), findsNothing);
    expect(find.text('THIS WEEK'), findsNothing);
  });

  testWidgets('recent This Week uses calendar week boundaries', (tester) async {
    await _launch(
      tester,
      now: DateTime(2026, 11, 4, 12),
      transactions: [_tx('previous Sunday', DateTime(2026, 11, 1, 12))],
    );
    expect(find.text('THIS WEEK'), findsNothing);
    expect(find.text('NOV 1, 2026'), findsOneWidget);
  });

  testWidgets('no-account dashboard keeps a single section gap', (
    tester,
  ) async {
    await _launch(tester, accounts: []);
    final actions = find.byType(KoinQuickAction);
    final upcoming = find.ancestor(
      of: find.text('Upcoming'),
      matching: find.byType(KoinSectionHeader),
    );
    final gap =
        tester.getRect(upcoming).top - tester.getRect(actions.first).bottom;
    expect(gap, closeTo(12, 0.1));
    expect(find.text('Accounts'), findsNothing);
  });

  for (final dark in [false, true]) {
    for (final scale in [1.0, 1.3, 1.5, 2.0]) {
      testWidgets('bank names remain readable at scale=$scale dark=$dark', (
        tester,
      ) async {
        await _launch(
          tester,
          scale: scale,
          dark: dark,
          home: const Scaffold(
            body: AccountsTab(
              animationSessionKey: 'audit',
              showEntranceAnimations: false,
            ),
          ),
        );
        for (final name in ['MariBank', 'GoTyme']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(name),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: name.length),
            ),
            hasLength(1),
          );
        }
        final cards = find.byType(AccountItem);
        if (scale >= 1.3) {
          expect(
            tester.getTopLeft(cards.at(1)).dy,
            greaterThan(tester.getTopLeft(cards.first).dy),
          );
        } else {
          expect(
            tester.getTopLeft(cards.at(1)).dy,
            tester.getTopLeft(cards.first).dy,
          );
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('heading shortcuts announce buttons and activate with keyboard', (
    tester,
  ) async {
    var activations = 0;
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KoinSectionHeader(
            title: 'Recent transactions',
            actionLabel: 'View All',
            onActionTap: () => activations++,
          ),
        ),
      ),
    );
    final action = find.byType(PressableScale);
    expect(tester.getSemantics(action).flagsCollection.isButton, isTrue);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(activations, 1);
    semantics.dispose();
  });

  testWidgets(
    'report default and 30-day preset select identical inclusive dates',
    (tester) async {
      await _launch(
        tester,
        now: DateTime.now(),
        home: const CustomReportsScreen(),
      );
      final before = tester
          .widget<DateRangeSelector>(find.byType(DateRangeSelector))
          .initialDateRange!;
      expect(DateRangeSelector.inclusiveDays(before), 30);
      expect(before.start.hour, 0);
      expect(before.end.hour, 0);
      await tester.tap(find.text('30d').last);
      await tester.pumpAndSettle();
      final after = tester
          .widget<DateRangeSelector>(find.byType(DateRangeSelector))
          .initialDateRange!;
      expect(after, before);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'inclusive calendar ranges work across month, year and leap-day boundaries',
    () {
      for (final at in [
        DateTime(2026, 1, 1, 23),
        DateTime(2024, 2, 29, 12),
        DateTime(2026, 11, 1),
      ]) {
        for (final days in [1, 7, 30, 90]) {
          final range = DateRangeSelector.lastDaysRange(days, now: at);
          expect(DateRangeSelector.inclusiveDays(range), days);
          expect(range.start.hour, 0);
          expect(range.end, DateTime(at.year, at.month, at.day));
        }
      }
    },
  );

  for (final width in [375.0, 1000.0]) {
    testWidgets('end clearance follows actual navigation at width=$width', (
      tester,
    ) async {
      await _launch(tester, width: width, home: const MainLayout());
      final scroll = tester.widget<SingleChildScrollView>(
        find
            .descendant(
              of: find.byType(DashboardScreen),
              matching: find.byType(SingleChildScrollView),
            )
            .first,
      );
      final padding = scroll.padding!.resolve(TextDirection.ltr);
      if (width < 840) {
        expect(padding.bottom, greaterThan(76));
      } else {
        expect(find.byType(NavigationRail), findsOneWidget);
        expect(padding.bottom, lessThan(40));
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('income card keeps details compact above its inset action', (
    tester,
  ) async {
    final payment = PlannedPayment(
      id: 'income',
      title: 'Allowance',
      amount: 200,
      type: TransactionType.income,
      categoryId: 'salary',
      accountId: 'MariBank',
      startDate: DateTime.now().subtract(const Duration(days: 1)),
      nextDate: DateTime.now().subtract(const Duration(days: 1)),
      frequency: PaymentFrequency.flexible,
    );
    final providers = await _launch(
      tester,
      payments: [payment],
      home: const Scaffold(body: RecurringIncomesTab()),
    );
    expect(find.text('FLEXIBLE'), findsNothing);
    expect(find.text('Availability'), findsNothing);
    expect(find.text('Available anytime'), findsOneWidget);
    final amount = tester.getRect(find.text('+₱200.00'));
    final title = tester.getRect(find.text('Allowance'));
    final availability = tester.getRect(find.text('Available anytime'));
    expect(amount.left, closeTo(title.left, 0.1));
    expect(amount.top - title.bottom, closeTo(4, 0.1));
    expect(availability.left, greaterThan(amount.right));
    expect(availability.center.dy, closeTo(amount.center.dy, 1));
    final titleStyle = tester.widget<Text>(find.text('Allowance')).style!;
    final availabilityStyle = tester
        .widget<Text>(find.text('Available anytime'))
        .style!;
    expect(availabilityStyle.fontSize, lessThan(titleStyle.fontSize!));
    expect(
      availabilityStyle.fontWeight!.value,
      lessThan(titleStyle.fontWeight!.value),
    );
    final semantics = tester.ensureSemantics();
    final action = find.byKey(const ValueKey('cashflow-action-income'));
    expect(availability.right, closeTo(tester.getRect(action).right, 0.1));
    final cardWidth = tester
        .getSize(find.byKey(const Key('cashflow_income')).first)
        .width;
    expect(tester.getSize(action).width, greaterThan(cardWidth * 0.8));
    expect(tester.getSize(action).width, lessThan(cardWidth));
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    expect(tester.getSemantics(action).flagsCollection.isButton, isTrue);
    semantics.dispose();
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(PaymentConfirmationSheet), findsOneWidget);
    Navigator.of(tester.element(find.byType(PaymentConfirmationSheet))).pop();
    await tester.pumpAndSettle();
    expect(await providers.read(transactionProvider.future), isEmpty);
    expect(
      providers.read(plannedPaymentProvider).value!.single.nextDate,
      payment.nextDate,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('cashflow cards keep long names and actions readable', (
    tester,
  ) async {
    for (final width in [320.0, 375.0, 768.0]) {
      for (final scale in [1.0, 1.3, 1.5, 2.0]) {
        for (final dark in [false, true]) {
          final now = DateTime.now();
          final payments = [
            PlannedPayment(
              id: 'salary',
              title: 'Monthly freelance retainer',
              amount: 125000.50,
              type: TransactionType.income,
              categoryId: 'salary',
              accountId: 'MariBank',
              startDate: now.subtract(const Duration(days: 30)),
              nextDate: now.subtract(const Duration(days: 1)),
              frequency: PaymentFrequency.monthly,
              isAutoProcess: true,
            ),
            PlannedPayment(
              id: 'allowance',
              title: 'Allowance',
              amount: 200,
              type: TransactionType.income,
              categoryId: 'salary',
              accountId: 'MariBank',
              startDate: now.subtract(const Duration(days: 1)),
              nextDate: now,
              frequency: PaymentFrequency.flexible,
            ),
          ];
          await _launch(
            tester,
            width: width,
            scale: scale,
            dark: dark,
            payments: payments,
            home: RepaintBoundary(
              key: const Key('income-preview'),
              child: const Scaffold(body: RecurringIncomesTab()),
            ),
          );
          if (const bool.fromEnvironment('UI_PREVIEWS')) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(
              find.byKey(const Key('income-preview')),
            );
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final data = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              image.dispose();
              const stage = String.fromEnvironment(
                'PREVIEW_STAGE',
                defaultValue: 'after',
              );
              final directory = Directory('build/income-review/$stage');
              await directory.create(recursive: true);
              await File('${directory.path}/$width-$scale-$dark.png')
                  .writeAsBytes(data!.buffer.asUint8List());
            });
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '$width px, $scale text scale, dark=$dark',
          );
          expect(find.text('Monthly freelance retainer'), findsOneWidget);
          if (scale == 1) {
            final title = tester.renderObject<RenderParagraph>(
              find.text('Monthly freelance retainer'),
            );
            expect(
              title
                  .getBoxesForSelection(
                    const TextSelection(baseOffset: 0, extentOffset: 26),
                  )
                  .length,
              lessThanOrEqualTo(2),
            );
          }
          for (final payment in payments) {
            final action = find.byKey(
              ValueKey('cashflow-action-${payment.id}'),
            );
            expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
            final amount = tester.getRect(
              find.text(
                '+${Currency.defaultCurrency.formatter.format(payment.amount)}',
              ),
            );
            final availability = tester.getRect(
              find.text(payment.availabilityLabel()),
            );
            final title = tester.getRect(find.text(payment.title));
            expect(amount.left, closeTo(title.left, 0.1));
            expect(availability.left, greaterThanOrEqualTo(title.left - 0.1));
            expect(availability.overlaps(amount), isFalse);
          }
        }
      }
    }
  });
}

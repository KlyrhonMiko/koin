import 'dart:io';
import 'dart:ui' as ui;

import 'package:fl_chart/fl_chart.dart';
import 'package:fl_chart/src/chart/bar_chart/bar_chart_renderer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/models/models.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/cards/spending_trend_chart.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader(KoinTypography.fontFamily)
      ..addFont(rootBundle.load('assets/fonts/outfit/Outfit-Regular.ttf'));
    await loader.load();
  });
  final boundaryKey = GlobalKey();
  const currency = Currency(code: 'PHP', symbol: '₱', name: 'Philippine Peso');
  final base = DateTime(2026, 10, 15);

  List<AppTransaction> expenses(double amount) => [
    AppTransaction(
      id: 'monday',
      amount: 100,
      date: DateTime(2026, 10, 12),
      type: TransactionType.expense,
      categoryId: 'food',
      accountId: 'cash',
    ),
    AppTransaction(
      id: 'tuesday',
      amount: amount,
      date: DateTime(2026, 10, 13),
      type: TransactionType.expense,
      categoryId: 'food',
      accountId: 'cash',
    ),
  ];

  Future<void> launch(
    WidgetTester tester,
    double amount, {
    bool reduced = false,
    double width = 390,
    double scale = 1,
    int filterIndex = 0,
    DateTime? baseDate,
    List<AppTransaction>? transactions,
    ValueChanged<DateTimeRange>? onPeriodSelected,
  }) async {
    tester.view.physicalSize = Size(width, 500);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(const Color(0xFF00C9A0), true),
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 500),
            disableAnimations: reduced,
            textScaler: TextScaler.linear(scale),
          ),
          child: Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: RepaintBoundary(
                  key: boundaryKey,
                  child: SpendingTrendChart(
                    expenses: transactions ?? expenses(amount),
                    currency: currency,
                    filterIndex: filterIndex,
                    baseDate: baseDate ?? base,
                    onPeriodSelected: onPeriodSelected,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double drawnAmount(WidgetTester tester) => tester
      .widget<BarChartLeaf>(find.byType(BarChartLeaf))
      .data
      .barGroups[1]
      .barRods
      .single
      .toY;

  setUp(() {});
  tearDown(() {});

  testWidgets(
    'updates settle quickly and interrupted changes continue from the visible bars',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await launch(tester, 200);
      expect(drawnAmount(tester), 200);
      await launch(tester, 400);
      await tester.pump(const Duration(milliseconds: 120));
      final halfway = drawnAmount(tester);
      expect(halfway, greaterThan(300));
      expect(halfway, lessThan(400));
      await launch(tester, 100);
      expect(drawnAmount(tester), closeTo(halfway, 0.01));
      await tester.pump(const Duration(milliseconds: 240));
      expect(drawnAmount(tester), 100);
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'taps select the exact day or month while scrubbing stays on the graph',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final filter in [0, 1, 2]) {
        final selected = <DateTimeRange>[];
        await launch(
          tester,
          200,
          filterIndex: filter,
          onPeriodSelected: selected.add,
        );
        await tester.pumpAndSettle();
        final chart = tester.widget<BarChart>(find.byType(BarChart)).data;
        final plot = tester.getRect(find.byType(BarChartLeaf));
        final index = filter == 0
            ? 1
            : filter == 1
            ? 12
            : 9;
        final point = Offset(
          plot.left + (index + .5) * plot.width / chart.barGroups.length,
          plot.bottom - 5,
        );
        final gesture = await tester.startGesture(point);
        await tester.pump(const Duration(milliseconds: 150));
        expect(selected, isEmpty);
        await gesture.moveBy(const Offset(0, -30));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(selected, isEmpty);
        await tester.tapAt(point);
        await tester.pumpAndSettle();
        expect(selected, hasLength(1));
        expect(selected.single.start, DateTime(2026, 10, filter == 2 ? 1 : 13));
        expect(
          selected.single.end.add(const Duration(microseconds: 1)),
          filter == 2 ? DateTime(2026, 11) : DateTime(2026, 10, 14),
        );
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('reduced motion shows final spending immediately', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await launch(tester, 200, reduced: true);
    await launch(tester, 400, reduced: true);
    await tester.pump();
    expect(drawnAmount(tester), 400);
    expect(
      tester.widget<BarChart>(find.byType(BarChart)).duration,
      Duration.zero,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'monthly dates stay readable and small amounts stay proportional',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final (year, month, days, width, scale) in [
        (2025, 2, 28, 320.0, 1.0),
        (2024, 2, 29, 320.0, 2.0),
        (2026, 4, 30, 390.0, 1.0),
        (2026, 10, 31, 390.0, 2.0),
      ]) {
        await launch(
          tester,
          100,
          width: width,
          scale: scale,
          filterIndex: 1,
          baseDate: DateTime(year, month),
          transactions: [
            for (final (day, amount) in [(1, 1.0), (days, 100.0)])
              AppTransaction(
                id: '$day',
                amount: amount,
                date: DateTime(year, month, day),
                type: TransactionType.expense,
                categoryId: 'food',
                accountId: 'cash',
              ),
          ],
        );
        await tester.pumpAndSettle();
        final chart = tester.widget<BarChart>(find.byType(BarChart)).data;
        expect(chart.barGroups, hasLength(days));
        expect(chart.barGroups[14].barRods.single.toY, 0);
        expect(chart.barGroups.first.barRods.single.toY, 1);
        expect(chart.barGroups.last.barRods.single.toY, 100);
        expect(chart.maxY, inInclusiveRange(100, 125));
        final rod = chart.barGroups.first.barRods.single;
        final minimumHeight =
            rod.borderRadius!.topLeft.y + rod.borderRadius!.bottomLeft.y;
        final actualHeight =
            tester.getSize(find.byType(BarChartLeaf)).height / chart.maxY;
        expect(minimumHeight, lessThanOrEqualTo(actualHeight));
        final labels = [1, 7, 14, 21, days];
        for (var i = 0; i < labels.length - 1; i++) {
          final current = tester.getRect(find.text('${labels[i]}'));
          final next = tester.getRect(find.text('${labels[i + 1]}'));
          expect(current.right, lessThan(next.left));
        }
        expect(find.text('3'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('month and year use the top of the plot', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final filter in [1, 2]) {
      for (final peak in [3.15, 1992.0, 6240.0, 987654.32]) {
        await launch(
          tester,
          peak,
          filterIndex: filter,
          transactions: [
            AppTransaction(
              id: 'first',
              amount: peak / 2,
              date: DateTime(2026, filter == 1 ? 10 : 1, 1),
              type: TransactionType.expense,
              categoryId: 'food',
              accountId: 'cash',
            ),
            AppTransaction(
              id: 'last',
              amount: peak,
              date: DateTime(2026, filter == 1 ? 10 : 12, 31),
              type: TransactionType.expense,
              categoryId: 'food',
              accountId: 'cash',
            ),
          ],
        );
        await tester.pumpAndSettle();
        final data = tester.widget<BarChart>(find.byType(BarChart)).data;
        expect(data.barGroups.last.barRods.single.toY, peak);
        final plot = tester.getRect(find.byType(BarChartLeaf));
        final topOfPeak = plot.top + plot.height * (1 - peak / data.maxY);
        final card = tester.getRect(find.byType(SpendingTrendChart));
        expect(topOfPeak - card.top, lessThan(40));
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('week, month, and year buckets agree across a month boundary', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final transactions = [
      for (final (day, amount) in [
        (DateTime(2026, 10, 31), 100.0),
        (DateTime(2026, 11, 1), 200.0),
        (DateTime(2026, 11, 1), 50.0),
      ])
        AppTransaction(
          id: '$day-$amount',
          amount: amount,
          date: day,
          type: TransactionType.expense,
          categoryId: 'food',
          accountId: 'cash',
        ),
    ];
    for (final filter in [0, 1, 2]) {
      await launch(
        tester,
        100,
        filterIndex: filter,
        baseDate: DateTime(2026, 11, 1),
        transactions: transactions,
      );
      await tester.pumpAndSettle();
      final bars = tester
          .widget<BarChart>(find.byType(BarChart))
          .data
          .barGroups;
      if (filter == 0) {
        expect(bars, hasLength(7));
        expect(bars[5].barRods.single.toY, 100);
        expect(bars[6].barRods.single.toY, 250);
      } else if (filter == 1) {
        expect(bars, hasLength(30));
        expect(bars.first.barRods.single.toY, 250);
        expect(
          bars.skip(1).every((bar) => bar.barRods.single.toY == 0),
          isTrue,
        );
      } else {
        expect(bars, hasLength(12));
        expect(bars[9].barRods.single.toY, 100);
        expect(bars[10].barRods.single.toY, 250);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'original graph layout stays intact at narrow and large text sizes',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final width in [390.0, 320.0]) {
        for (final scale in [1.0, 2.0]) {
          await launch(tester, 200, width: width, scale: scale);
          await tester.pumpAndSettle();
          final chart = tester.widget<BarChart>(find.byType(BarChart));
          expect(chart.data.barGroups, hasLength(7));
          expect(
            chart.data.barGroups.first.barRods.single.backDrawRodData.show,
            isTrue,
          );
          expect(find.text('Daily totals'), findsNothing);
          expect(find.text('PHP'), findsNothing);
          expect(tester.takeException(), isNull);
          if (Platform.environment['KOIN_CAPTURE_CHART'] == '1') {
            final boundary =
                boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final png = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              image.dispose();
              await Directory('build/chart-review').create(recursive: true);
              await File('build/chart-review/original-$width-$scale.png')
                  .writeAsBytes(png!.buffer.asUint8List());
            });
          }
        }
      }
    },
  );
}

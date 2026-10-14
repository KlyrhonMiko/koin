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
                    expenses: expenses(amount),
                    currency: currency,
                    filterIndex: 0,
                    baseDate: base,
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

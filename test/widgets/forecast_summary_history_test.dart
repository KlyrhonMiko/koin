import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/analysis/widgets/forecast_summary.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
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
    final font = File('C:/Windows/Fonts/segoeui.ttf');
    if (font.existsSync()) {
      final fallback = FontLoader('KoinTest')
        ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
      await fallback.load();
    }
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'limited forecast explains history and savings at scale $scale',
      (tester) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme(const Color(0xFF00D09E), true),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: RepaintBoundary(key: boundaryKey, child: child!),
            ),
            home: Scaffold(
              body: SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: ForecastSummary(
                    currency: const Currency(
                      code: 'PHP',
                      symbol: '₱',
                      name: 'Philippine Peso',
                    ),
                    horizon: ForecastHorizon.monthly,
                    forecast: const ForecastData(
                      forecastedInflow: 4500,
                      forecastedOutflow: 3500,
                      currentBaseline: 1000,
                      predictedNetBalance: 2000,
                      isWarning: false,
                      historyMonths: 1,
                      historyDays: 21,
                      savingsOutflow: 1500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Next month · Rough estimate'), findsOneWidget);
        expect(find.text('Based on 21 days · Limited history'), findsOneWidget);
        expect(tester.takeException(), isNull);

        Future<void> capture(String name) async {
          final boundary =
              boundaryKey.currentContext!.findRenderObject()
                  as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            image.dispose();
            await Directory('build/forecast-review').create(recursive: true);
            await File('build/forecast-review/$name.png')
                .writeAsBytes(data!.buffer.asUint8List());
          });
        }

        await capture('summary-$scale');
        await tester.tap(find.text('Details'));
        await tester.pumpAndSettle();
        expect(find.text('Includes savings contributions'), findsOneWidget);
        await capture('details-$scale');
        await tester.ensureVisible(find.text('How this is estimated'));
        await tester.tap(find.text('How this is estimated'));
        await tester.pumpAndSettle();
        expect(find.textContaining('21 complete days'), findsOneWidget);
        expect(
          find.textContaining('Large one-off transactions'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Done'));
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();
        expect(find.text('Forecast details'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

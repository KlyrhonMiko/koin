import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/portfolio/portfolio_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final dark in [true, false]) {
    for (final width in [390.0, 320.0]) {
      testWidgets('portfolio fits width=$width, dark=$dark', (tester) async {
        SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
        final prefs = await SharedPreferences.getInstance();
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final capture = Platform.environment['KOIN_CAPTURE_PORTFOLIO'];
        // Use the shipped font so text measurements match the real app.
        await tester.runAsync(() async {
          final loader = FontLoader(KoinTypography.fontFamily);
          for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
            loader.addFont(
              rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'),
            );
          }
          await loader.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
          final fallbackPath =
              Platform.environment['KOIN_PREVIEW_FALLBACK_FONT'];
          if (fallbackPath != null) {
            final fallback = FontLoader('Roboto')
              ..addFont(
                File(
                  fallbackPath,
                ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
              );
            await fallback.load();
          }
        });
        final account = Account(
          id: 'cash',
          name: 'Cash',
          initialBalance: 300,
          iconCodePoint: KoinIcons.money.codePoint,
          colorHex: '#00D09E',
        );
        final providers = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            accountRepositoryProvider.overrideWithValue(
              InMemoryAccountAdapter(initial: [account]),
            ),
            dashboardStatsProvider.overrideWithValue(
              DashboardStats(
                totalIncome: 0,
                totalExpense: 0,
                currentBalance: 300,
                accounts: [account],
                accountBalances: {'cash': 300},
                categorySpending: {},
              ),
            ),
            savingsRepositoryProvider.overrideWithValue(
              InMemorySavingsAdapter(
                initial: [
                  SavingsGoal(
                    id: 'stash',
                    name: 'Savings',
                    currentAmount: 500,
                    startDate: DateTime(2026),
                    isStash: true,
                  ),
                ],
              ),
            ),
            debtRepositoryProvider.overrideWithValue(
              InMemoryDebtAdapter(
                initial: [
                  Debt(
                    id: 'paid',
                    personName: 'SPayLater',
                    amount: 1992,
                    currentAmount: 1992,
                    type: DebtType.iOwe,
                    startDate: DateTime(2026),
                  ),
                  Debt(
                    id: 'debt',
                    personName: 'Nicole',
                    amount: 1775,
                    type: DebtType.iOwe,
                    startDate: DateTime(2026),
                  ),
                ],
              ),
            ),
          ],
        );
        addTearDown(providers.dispose);
        final boundary = GlobalKey();
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: providers,
            child: MaterialApp(
              theme: AppTheme.getTheme(const Color(0xFF00D09E), dark).copyWith(
                textTheme: AppTheme.getTheme(
                  const Color(0xFF00D09E),
                  dark,
                ).textTheme.apply(fontFamilyFallback: ['Roboto']),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.4 : 1),
                ),
                child: child!,
              ),
              home: RepaintBoundary(
                key: boundary,
                child: const Scaffold(body: PortfolioScreen()),
              ),
            ),
          ),
        );
        for (var tab = 0; tab < 3; tab++) {
          providers.read(portfolioTabProvider.notifier).setIndex(tab);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            find.text(['Accounts', 'Savings', 'Credit & IOUs'][tab]).first,
            findsOneWidget,
          );
          if (capture != null && dark) {
            await tester.runAsync(() async {
              final render =
                  boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary;
              final image = await render.toImage(pixelRatio: 2);
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await Directory(capture).create(recursive: true);
              await File(
                '$capture/portfolio_${width.toInt()}_$tab.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/debts_tab.dart';
import 'package:koin/features/savings/savings_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
  });

  for (final savings in [true, false]) {
    for (final largeText in [false, true]) {
      testWidgets(
        'portfolio summary privacy: savings=$savings, largeText=$largeText',
        (tester) async {
          tester.view.physicalSize = Size(largeText ? 320 : 390, 1000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              accountRepositoryProvider.overrideWithValue(
                InMemoryAccountAdapter(),
              ),
              dashboardStatsProvider.overrideWithValue(
                DashboardStats.calculate(accounts: [], transactions: []),
              ),
              savingsRepositoryProvider.overrideWithValue(
                InMemorySavingsAdapter(
                  initial: [
                    SavingsGoal(
                      id: 'goal',
                      name: 'Travel',
                      currentAmount: 1500,
                      targetAmount: 5000,
                      startDate: DateTime(2026),
                    ),
                  ],
                ),
              ),
              debtRepositoryProvider.overrideWithValue(
                InMemoryDebtAdapter(
                  initial: [
                    Debt(
                      id: 'debt',
                      personName: 'Nicole',
                      amount: 1992,
                      currentAmount: 217,
                      type: DebtType.iOwe,
                      startDate: DateTime(2026),
                    ),
                  ],
                ),
              ),
            ],
          );
          addTearDown(container.dispose);
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.getTheme(Colors.teal, !largeText),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(largeText ? 1.6 : 1),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: Scaffold(
                  body: savings
                      ? const SavingsTab(showEntranceAnimations: false)
                      : const DebtsTab(showEntranceAnimations: false),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final hero = find.byType(KoinSummaryCard);
          final counter = find.descendant(
            of: hero,
            matching: find.byType(AnimatedCounter),
          );
          expect(counter, findsOneWidget);
          expect(
            find.descendant(of: hero, matching: find.text('·  PHP')),
            findsOneWidget,
          );
          if (!savings) {
            expect(find.byIcon(KoinIcons.clockCounterClockwise), findsNothing);
          }
          final label = savings ? 'total saved' : 'net balance';
          await tester.tap(find.byTooltip('Hide $label'));
          await tester.pumpAndSettle();
          expect(container.read(settingsProvider).hideBalance, isTrue);
          expect(prefs.getBool('hide_balance'), isTrue);
          expect(counter, findsNothing);
          expect(
            find.descendant(of: hero, matching: find.text('****')),
            findsOneWidget,
          );
          if (!savings) {
            expect(
              find.textContaining('Repayment total hidden'),
              findsOneWidget,
            );
          }
          await tester.tap(find.byTooltip('Show $label'));
          await tester.pumpAndSettle();
          expect(container.read(settingsProvider).hideBalance, isFalse);
          expect(counter, findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

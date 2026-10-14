import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/dashboard/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    GoogleFonts.config.allowRuntimeFetching = false;
    AnimationTracker.clear();
    SharedPreferences.setMockInitialValues({'currency_code': 'USD'});
  });

  for (final dark in [false, true]) {
    testWidgets(
      'dashboard balance toggle masks all cards and persists ($dark)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 1600);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prefs = await SharedPreferences.getInstance();
        final accounts = List.generate(
          4,
          (i) => Account(
            id: 'account_$i',
            name: 'Account ${i + 1}',
            initialBalance: (i + 1) * 110.0,
            iconCodePoint: Icons.wallet.codePoint,
            colorHex: '#00D09E',
            excludeFromTotal: i == 3,
          ),
        );
        ProviderContainer createContainer() => ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            ledgerProvider.overrideWithValue(InMemoryLedgerAdapter()),
            accountRepositoryProvider.overrideWithValue(
              InMemoryAccountAdapter(initial: accounts),
            ),
            categoryRepositoryProvider.overrideWithValue(
              InMemoryCategoryAdapter(),
            ),
            savingsRepositoryProvider.overrideWithValue(
              InMemorySavingsAdapter(),
            ),
            debtRepositoryProvider.overrideWithValue(InMemoryDebtAdapter()),
            plannedPaymentRepositoryProvider.overrideWithValue(
              InMemoryPlannedPaymentAdapter(),
            ),
          ],
        );
        final providers = createContainer();
        addTearDown(providers.dispose);
        Future<void> showDashboard(ProviderContainer container) async {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AppTheme.getTheme(Colors.teal, dark),
                home: const Scaffold(body: DashboardScreen()),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await showDashboard(providers);
        final currency = providers.read(settingsProvider).currency;
        for (final account in accounts.take(3)) {
          expect(
            find.text(currency.formatter.format(account.initialBalance)),
            findsOneWidget,
          );
        }
        final masks = find.text('****');
        expect(masks, findsOneWidget);
        Finder cardFor(Account account) => find
            .ancestor(
              of: find.text(account.name),
              matching: find.byType(PressableScale),
            )
            .first;
        final cardSizes = {
          for (final account in accounts)
            account.id: tester.getSize(cardFor(account)),
        };
        final toggle = find.byKey(
          const ValueKey('dashboard_balance_visibility'),
        );
        expect(tester.getSize(toggle), const Size(56, 56));
        expect(find.byTooltip('Hide balances'), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Show balances'), findsOneWidget);
        expect(masks, findsNWidgets(5));
        for (final account in accounts) {
          expect(tester.getSize(cardFor(account)), cardSizes[account.id]);
          expect(find.text(account.name), findsOneWidget);
          expect(
            find.text(currency.formatter.format(account.initialBalance)),
            findsNothing,
          );
        }
        expect(prefs.getBool('hide_balance'), isTrue);

        // A new settings instance restores the saved preference.
        final restored = createContainer();
        addTearDown(restored.dispose);
        expect(restored.read(settingsProvider).hideBalance, isTrue);
        await showDashboard(restored);
        expect(masks, findsNWidgets(5));

        // The existing hero eye controls the same setting.
        await tester.tap(find.byTooltip('Show balances'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Hide balances'), findsOneWidget);
        expect(masks, findsOneWidget);
        for (final account in accounts) {
          expect(tester.getSize(cardFor(account)), cardSizes[account.id]);
        }
        expect(prefs.getBool('hide_balance'), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

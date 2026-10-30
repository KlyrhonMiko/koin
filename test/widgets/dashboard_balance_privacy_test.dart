import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/dashboard/dashboard_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AnimationTracker.clear();
    SharedPreferences.setMockInitialValues({'currency_code': 'USD'});
  });

  for (final dark in [false, true]) {
    testWidgets(
      'dashboard total and account privacy are independent and persist ($dark)',
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
            name: i == 1
                ? 'MariBank Credit Account for monthly household bills'
                : 'Account ${i + 1}',
            initialBalance: i == 2 ? 100000 : (i + 1) * 110.0,
            iconCodePoint: KoinIcons.wallet.codePoint,
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
        expect(find.byType(AccountItem), findsNWidgets(4));
        expect(
          tester
              .widgetList<AccountItem>(find.byType(AccountItem))
              .every((card) => card.compact),
          isTrue,
        );
        final currency = providers.read(settingsProvider).currency;
        for (final account in accounts.take(3)) {
          expect(
            find.byTooltip(currency.formatter.format(account.initialBalance)),
            findsOneWidget,
          );
        }
        expect(
          tester
              .renderObject<RenderParagraph>(find.text(accounts[1].name))
              .didExceedMaxLines,
          isTrue,
        );
        expect(
          find.text(currency.formatter.format(100000)),
          findsOneWidget,
        );
        final masks = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data == '****' || widget.data == '••••••'),
        );
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
        expect(tester.getSize(toggle), const Size(48, 48));
        expect(find.byTooltip('Hide total balance'), findsOneWidget);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        expect(find.byTooltip('Show total balance'), findsOneWidget);
        expect(masks, findsNWidgets(2));
        for (final account in accounts) {
          expect(tester.getSize(cardFor(account)), cardSizes[account.id]);
          expect(find.text(account.name), findsOneWidget);
          expect(
            find.byTooltip(currency.formatter.format(account.initialBalance)),
            account.excludeFromTotal ? findsNothing : findsOneWidget,
          );
        }
        // A card eye updates only that account while the hero stays hidden.
        final firstEye = find.descendant(
          of: cardFor(accounts.first),
          matching: find.byTooltip('Hide balance and exclude from totals'),
        );
        await tester.tap(firstEye);
        await tester.pumpAndSettle();
        expect(
          providers.read(accountProvider).value!.first.excludeFromTotal,
          isTrue,
        );
        expect(providers.read(settingsProvider).hideBalance, isTrue);
        expect(masks, findsNWidgets(3));
        expect(
          find.byTooltip(currency.formatter.format(accounts[1].initialBalance)),
          findsOneWidget,
        );
        await tester.tap(
          find.descendant(
            of: cardFor(accounts.first),
            matching: find.byTooltip('Show balance and include in totals'),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          providers.read(accountProvider).value!.first.excludeFromTotal,
          isFalse,
        );
        expect(masks, findsNWidgets(2));
        expect(prefs.getBool('hide_balance'), isTrue);

        // A new settings instance restores the saved preference.
        final restored = createContainer();
        addTearDown(restored.dispose);
        expect(restored.read(settingsProvider).hideBalance, isTrue);
        await showDashboard(restored);
        expect(masks, findsNWidgets(2));

        // The existing hero eye controls the same setting.
        await tester.tap(find.byTooltip('Show total balance'));
        await tester.pumpAndSettle();
        expect(find.byTooltip('Hide total balance'), findsOneWidget);
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

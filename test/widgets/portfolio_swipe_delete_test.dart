import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/portfolio/portfolio_screen.dart';
import 'package:koin/features/accounts/accounts_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  testWidgets('account balance follows each savings dashboard inclusion', (
    tester,
  ) async {
    final account = Account(
      id: 'mari',
      name: 'MariBank',
      initialBalance: 263,
      iconCodePoint: Icons.account_balance.codePoint,
      colorHex: '#008080',
    );
    final goal = SavingsGoal(
      id: 'goal',
      name: 'End of Year',
      startDate: DateTime(2026),
      linkedAccountId: account.id,
      currentAmount: 200,
      includeInDashboardBalance: false,
    );
    final providers = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        accountRepositoryProvider.overrideWithValue(
          InMemoryAccountAdapter(initial: [account]),
        ),
        savingsRepositoryProvider.overrideWithValue(
          InMemorySavingsAdapter(initial: [goal]),
        ),
        dashboardStatsProvider.overrideWithValue(
          DashboardStats(
            totalIncome: 0,
            totalExpense: 0,
            currentBalance: 263,
            accounts: [account],
            accountBalances: {account.id: 263},
            categorySpending: {},
          ),
        ),
      ],
    );
    addTearDown(providers.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providers,
        child: MaterialApp(
          home: Scaffold(
            body: AccountsTab(
              animationSessionKey: 'test',
              showEntranceAnimations: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<AccountItem>(find.byType(AccountItem)).balance, 63);
    expect(find.textContaining('in savings'), findsNothing);
    expect(find.textContaining('Reserved'), findsNothing);
    await providers
        .read(savingsGoalsProvider.notifier)
        .updateGoal(goal.copyWith(includeInDashboardBalance: true));
    await tester.pumpAndSettle();
    expect(tester.widget<AccountItem>(find.byType(AccountItem)).balance, 263);
    final symbol = providers.read(settingsProvider).currency.symbol;
    expect(find.text('${symbol}200 in savings'), findsOneWidget);
    await providers
        .read(accountProvider.notifier)
        .updateAccount(account.copyWith(excludeFromTotal: true));
    await tester.pumpAndSettle();
    expect(find.textContaining('in savings'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final goals in [true, false]) {
    testWidgets(
      '${goals ? 'Goals' : 'Credit'} swipe cancels or deletes only the selected item',
      (tester) async {
        final savings = InMemorySavingsAdapter(
          initial: [
            for (final id in ['first', 'second'])
              SavingsGoal(
                id: id,
                name: id,
                targetAmount: 1000,
                startDate: DateTime(2026, 1),
              ),
          ],
        );
        final debts = InMemoryDebtAdapter(
          initial: [
            for (final id in ['first', 'second'])
              Debt(
                id: id,
                personName: id,
                amount: 100,
                type: DebtType.iOwe,
                startDate: DateTime(2026, 1),
              ),
          ],
        );
        final providers = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            savingsRepositoryProvider.overrideWithValue(savings),
            debtRepositoryProvider.overrideWithValue(debts),
            dashboardStatsProvider.overrideWithValue(DashboardStats.empty()),
            accountRepositoryProvider.overrideWithValue(
              InMemoryAccountAdapter(),
            ),
          ],
        );
        addTearDown(providers.dispose);
        providers.read(portfolioTabProvider.notifier).setIndex(goals ? 1 : 2);
        tester.view.physicalSize = const Size(420, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: providers,
            child: MaterialApp(
              theme: AppTheme.getTheme(Colors.teal, false),
              home: const Scaffold(body: PortfolioScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final swipe = find.byWidgetPredicate(
          (widget) =>
              widget is SwipeToDeleteTile &&
              widget.key == Key('dismiss_${goals ? 'goal' : 'debt'}_first'),
        );
        final tile = tester.widget<SwipeToDeleteTile>(swipe);
        expect(tile.fillRoundedCorners, isTrue);
        expect(tile.direction, DismissDirection.endToStart);

        final touch = await tester.startGesture(tester.getCenter(swipe));
        await tester.pump();
        expect(
          tester.widget<TabBarView>(find.byType(TabBarView)).physics,
          isA<NeverScrollableScrollPhysics>(),
        );
        await touch.cancel();
        await tester.pumpAndSettle();
        expect(
          tester.widget<TabBarView>(find.byType(TabBarView)).physics,
          isNull,
        );

        Future<void> openConfirmation() async {
          await tester.drag(swipe, const Offset(-600, 0));
          await tester.pumpAndSettle();
          expect(
            find.text(goals ? 'Delete Goal?' : 'Delete Credit/IOU?'),
            findsOneWidget,
          );
          expect(providers.read(portfolioTabProvider), goals ? 1 : 2);
        }

        await openConfirmation();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.text('first'), findsOneWidget);
        expect(
          goals
              ? (await savings.getSavingsGoals()).length
              : (await debts.getDebts()).length,
          2,
        );

        await openConfirmation();
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        expect(find.text('first'), findsNothing);
        expect(find.text('second'), findsOneWidget);
        expect(
          goals
              ? (await savings.getSavingsGoals()).single.id
              : (await debts.getDebts()).single.id,
          'second',
        );
        expect(tester.takeException(), isNull);

        // Swipes starting below the cards still navigate between sections.
        await tester.dragFrom(
          const Offset(210, 920),
          Offset(goals ? -350 : 350, 0),
        );
        await tester.pumpAndSettle();
        expect(providers.read(portfolioTabProvider), goals ? 2 : 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

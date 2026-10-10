import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/savings/add_savings_goal_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({'currency_code': 'PHP'});
    prefs = await SharedPreferences.getInstance();
  });

  Future<InMemorySavingsAdapter> openForm(
    WidgetTester tester, {
    bool dark = true,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool disableAnimations = false,
    SavingsGoal? goal,
    List<Account> accounts = const [],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    final savings = InMemorySavingsAdapter(initial: [?goal]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          savingsRepositoryProvider.overrideWithValue(savings),
          accountRepositoryProvider.overrideWithValue(
            InMemoryAccountAdapter(initial: accounts),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.getTheme(const Color(0xFF00C9A0), dark),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: disableAnimations,
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => AddSavingsGoalScreen(goal: goal),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    return savings;
  }

  testWidgets('linked stash dashboard option persists independently', (
    tester,
  ) async {
    final account = Account(
      id: 'mari',
      name: 'MariBank',
      iconCodePoint: Icons.wallet.codePoint,
      colorHex: '#00C9A0',
    );
    final goal = SavingsGoal(
      id: 'goal',
      name: 'End of Year',
      startDate: DateTime(2026),
      currentAmount: 250,
      isStash: true,
      linkedAccountId: account.id,
    );
    final repository = await openForm(tester, goal: goal, accounts: [account]);
    final toggle = find.byKey(const ValueKey('include_in_dashboard'));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, true);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update Stash'));
    await tester.pumpAndSettle();
    final saved = (await repository.getSavingsGoals()).single;
    expect(saved.includeInDashboardBalance, false);
    expect(saved.currentAmount, 250);
    await openForm(tester, goal: saved, accounts: [account]);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(toggle).value, false);
  });

  testWidgets('Goal validates required fields and saves the form values', (
    tester,
  ) async {
    final savings = await openForm(tester);
    await tester.tap(find.text('Create Goal'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name for your goal'), findsOneWidget);
    expect(await savings.getSavingsGoals(), isEmpty);
    await tester.enterText(
      find.byKey(const Key('goal_name')),
      'Emergency fund',
    );
    await tester.ensureVisible(find.byKey(const Key('goal_amount')));
    await tester.enterText(find.byKey(const Key('goal_amount')), '6000');
    await tester.pumpAndSettle();
    expect(find.textContaining('a day over'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('goal_notes')));
    await tester.enterText(
      find.byKey(const Key('goal_notes')),
      'For a rainy day',
    );
    await tester.tap(find.text('Create Goal'));
    await tester.pumpAndSettle();
    final saved = (await savings.getSavingsGoals()).single;
    expect(saved.name, 'Emergency fund');
    expect(saved.targetAmount, 6000);
    expect(saved.notes, 'For a rainy day');
    expect(saved.isStash, isFalse);
    expect(saved.endDate, isNotNull);
    expect(find.text('Open editor'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Stash removes the deadline and saves without an amount', (
    tester,
  ) async {
    final savings = await openForm(tester, dark: false);
    await tester.enterText(find.byKey(const Key('goal_name')), 'Spare change');
    await tester.tap(find.text('Stash'));
    await tester.pumpAndSettle();
    expect(find.text('Target date'), findsNothing);
    expect(find.text('Target amount (optional)'), findsOneWidget);
    await tester.tap(find.text('Create Stash'));
    await tester.pumpAndSettle();
    final saved = (await savings.getSavingsGoals()).single;
    expect(saved.isStash, isTrue);
    expect(saved.targetAmount, isNull);
    expect(saved.endDate, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reveals retain outgoing fields and settle after rapid toggles', (
    tester,
  ) async {
    await openForm(tester, size: const Size(390, 1100));
    await tester.enterText(find.byKey(const Key('goal_amount')), '6000');
    await tester.pumpAndSettle();
    expect(find.text('Target date'), findsOneWidget);
    expect(find.textContaining('a day over'), findsOneWidget);

    await tester.tap(find.text('Stash'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    // Removed fields are still painted during their exit transition.
    expect(find.text('Target date'), findsOneWidget);
    expect(find.textContaining('a day over'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Target date'), findsNothing);
    expect(find.textContaining('a day over'), findsNothing);

    await tester.tap(find.text('Goal'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Stash'));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tap(find.text('Goal'));
    await tester.pumpAndSettle();
    expect(find.text('Target date'), findsOneWidget);
    expect(find.text('Start date'), findsOneWidget);
    expect(find.textContaining('a day over'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('goal_amount')))
          .controller!
          .text,
      '6000',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Reduced motion switches fields without retaining exit content', (
    tester,
  ) async {
    await openForm(tester, disableAnimations: true);
    await tester.tap(find.text('Stash'));
    await tester.pump();
    expect(find.text('Target date'), findsNothing);
    await tester.tap(find.text('Goal'));
    await tester.pump();
    expect(find.text('Target date'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Narrow form supports large text and scrolling with the keyboard',
    (tester) async {
      final goal = SavingsGoal(
        id: 'existing',
        name: 'Travel',
        currentAmount: 150,
        startDate: DateTime(2026, 10, 10),
        isStash: true,
      );
      final savings = await openForm(
        tester,
        size: const Size(320, 640),
        textScale: 1.3,
        goal: goal,
      );
      final amountField = find.byKey(const Key('goal_amount'));
      expect(
        tester.widget<TextFormField>(amountField).controller!.text,
        isEmpty,
      );
      await tester.tap(find.text('Goal'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(amountField);
      await tester.enterText(amountField, '1200');
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('goal_notes')));
      await tester.enterText(
        find.byKey(const Key('goal_notes')),
        'Summer trip',
      );
      await tester.pumpAndSettle();
      final button = tester.getRect(find.text('Update Goal'));
      expect(button.bottom, lessThan(640 - 280));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Update Goal'));
      await tester.pumpAndSettle();
      final saved = (await savings.getSavingsGoals()).single;
      expect(saved.id, goal.id);
      expect(saved.currentAmount, 150);
      expect(saved.targetAmount, 1200);
      expect(saved.notes, 'Summer trip');
      expect(saved.isStash, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/debt_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('purchase swipe cancels or deletes and recalculates credit', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final items = [
      for (final id in ['first', 'second'])
        DebtItem(
          id: id,
          debtId: 'credit',
          name: id,
          amount: id == 'first' ? 100 : 200,
          totalInstallments: 2,
          firstPaymentDate: DateTime(2026, 10, 1),
        ),
    ];
    final repository = InMemoryDebtAdapter(
      initial: [
        Debt(
          id: 'credit',
          personName: 'Credit card',
          amount: 300,
          currentAmount: 50,
          type: DebtType.iOwe,
          startDate: DateTime(2026, 10, 1),
          items: items,
        ),
      ],
    );
    final providers = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        debtRepositoryProvider.overrideWithValue(repository),
        categoryRepositoryProvider.overrideWithValue(InMemoryCategoryAdapter()),
      ],
    );
    addTearDown(providers.dispose);
    tester.view.physicalSize = const Size(440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: providers,
        child: MaterialApp(
          theme: AppTheme.getTheme(Colors.teal, false),
          home: const DebtDetailsScreen(debtId: 'credit'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Finder swipeFor(String id) => find.byWidgetPredicate(
      (widget) =>
          widget is SwipeToDeleteTile &&
          widget.key == Key('dismiss_purchase_$id'),
    );
    Future<void> swipe(String id) async {
      final tile = swipeFor(id);
      await tester.ensureVisible(tile);
      await tester.pumpAndSettle();
      expect(tester.widget<SwipeToDeleteTile>(tile).fillRoundedCorners, isTrue);
      await tester.drag(tile, const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Delete Purchase?'), findsOneWidget);
    }

    await swipe('first');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('first'), findsOneWidget);
    expect((await repository.getDebts()).single.amount, 300);

    await swipe('first');
    await tester.tap(
      find.descendant(
        of: find.byType(ConfirmationSheet),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('first'), findsNothing);
    expect(find.text('second'), findsOneWidget);
    var credit = (await repository.getDebts()).single;
    expect(credit.items.single.id, 'second');
    expect(credit.amount, 200);
    expect(credit.currentAmount, 50);
    expect(tester.takeException(), isNull);

    // The remaining tile retains its own dismiss state after a sibling is removed.
    await swipe('second');
    await tester.tap(
      find.descendant(
        of: find.byType(ConfirmationSheet),
        matching: find.text('Delete'),
      ),
    );
    await tester.pumpAndSettle();
    credit = (await repository.getDebts()).single;
    expect(credit.items, isEmpty);
    expect(credit.amount, 0);
    expect(credit.currentAmount, 50);
    expect(find.text('Add Purchase / Sub-Plan'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

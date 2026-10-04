import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/debt_details_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeHistoryDebtAdapter extends InMemoryDebtAdapter {
  final List<DebtRepayment> history;
  FakeHistoryDebtAdapter(Debt debt, this.history) : super(initial: [debt]);
  @override
  Future<List<DebtRepayment>> getDebtRepayments(String id) async =>
      List.of(history);
}

class FakeHistoryLedger extends InMemoryLedgerAdapter {
  final FakeHistoryDebtAdapter debts;
  final bool failDeletion;
  FakeHistoryLedger(this.debts, this.failDeletion);
  @override
  Future<void> voidDebtRepayment(DebtRepayment repayment) async {
    if (failDeletion) throw StateError('Unable to save deletion');
    debts.history.removeWhere((entry) => entry.id == repayment.id);
  }
}

void main() {
  for (final dark in [false, true]) {
    for (final failDeletion in [false, true]) {
      testWidgets('last payment transition dark=$dark failure=$failDeletion', (
        tester,
      ) async {
        GoogleFonts.config.allowRuntimeFetching = false;
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final repository = FakeHistoryDebtAdapter(
          Debt(
            id: 'credit',
            personName: 'Credit',
            amount: 100,
            type: DebtType.iOwe,
            startDate: DateTime(2026, 1),
          ),
          [
            DebtRepayment(
              id: 'payment',
              debtId: 'credit',
              amount: 25,
              date: DateTime(2026, 10, 1),
            ),
          ],
        );
        final providers = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            debtRepositoryProvider.overrideWithValue(repository),
            ledgerProvider.overrideWithValue(
              FakeHistoryLedger(repository, failDeletion),
            ),
            categoryRepositoryProvider.overrideWithValue(
              InMemoryCategoryAdapter(),
            ),
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
              theme: AppTheme.getTheme(Colors.teal, dark),
              home: const DebtDetailsScreen(debtId: 'credit'),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final payment = find.byWidgetPredicate(
          (widget) =>
              widget is SwipeToDeleteTile && widget.key == const Key('payment'),
        );
        await tester.ensureVisible(payment);
        await tester.pumpAndSettle();
        expect(find.text('Credit Activity'), findsOneWidget);
        await tester.drag(payment, const Offset(-600, 0));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Delete Payment'));
        await tester.pumpAndSettle();
        expect(find.text('Credit Activity'), findsOneWidget);
        if (failDeletion) {
          expect(payment, findsOneWidget);
          expect(find.text('No payments yet'), findsNothing);
          expect(find.text('Could not delete payment'), findsOneWidget);
        } else {
          expect(find.text('No payments yet'), findsOneWidget);
          expect(payment, findsNothing);
          expect(find.text('0'), findsWidgets);
        }
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
        if (failDeletion) {
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
        }
      });
    }
  }
}

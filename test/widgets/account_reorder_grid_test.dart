import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/features/accounts/account_reorder_grid.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('previews, cancels and commits a drag (reduced: $reduced)', (
      tester,
    ) async {
      final order = ValueNotifier(['a', 'b', 'c', 'd', 'e']);
      addTearDown(order.dispose);
      var commits = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ValueListenableBuilder(
                  valueListenable: order,
                  builder: (context, ids, _) => AccountReorderGrid(
                    columns: 2,
                    cardWidth: 150,
                    cardHeight: 100,
                    items: [
                      for (final id in ids)
                        (
                          id: id,
                          child: ColoredBox(
                            color: Colors.teal,
                            child: Center(child: Text(id)),
                          ),
                        ),
                    ],
                    addButton: const Text('Add account'),
                    onReorder: (id, index) {
                      commits++;
                      final next = [...order.value]..remove(id);
                      next.insert(index, id);
                      order.value = next;
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Finder slot(String id) => find.byKey(ValueKey('account_slot_$id'));
      final start = tester.getCenter(slot('a'));
      final destination = tester.getCenter(slot('d'));
      final originalB = tester.getTopLeft(slot('b'));
      final addPosition = tester.getTopLeft(find.text('Add account'));

      Future<TestGesture> preview() async {
        final drag = await tester.startGesture(start);
        await tester.pump(const Duration(milliseconds: 600));
        await drag.moveTo(destination);
        await tester.pump();
        if (!reduced) {
          // The neighboring card travels through an intermediate position.
          await tester.pump(const Duration(milliseconds: 100));
          final mid = tester.getTopLeft(slot('b'));
          expect(mid.dx, lessThan(originalB.dx));
          expect(mid.dx, greaterThan(start.dx - 75));
        }
        await tester.pumpAndSettle();
        expect(tester.getCenter(slot('a')), destination);
        expect(
          find.byKey(const ValueKey('account_drop_placeholder')),
          findsOneWidget,
        );
        expect(tester.getTopLeft(find.text('Add account')), addPosition);
        expect(order.value, ['a', 'b', 'c', 'd', 'e']);
        expect(commits, 0);
        return drag;
      }

      // Leaving the grid restores the order without saving a hover preview.
      final canceled = await preview();
      await canceled.moveTo(const Offset(700, 500));
      await tester.pump();
      await canceled.up();
      await tester.pumpAndSettle();
      expect(order.value, ['a', 'b', 'c', 'd', 'e']);
      expect(tester.getCenter(slot('a')), start);
      expect(commits, 0);
      expect(
        find.byKey(const ValueKey('account_drop_placeholder')),
        findsNothing,
      );

      final accepted = await preview();
      await accepted.up();
      await tester.pumpAndSettle();
      expect(order.value, ['b', 'c', 'd', 'a', 'e']);
      expect(commits, 1);
      expect(tester.getCenter(slot('a')), destination);
      expect(
        find.byKey(const ValueKey('account_drop_placeholder')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
}

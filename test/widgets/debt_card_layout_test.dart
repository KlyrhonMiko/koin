import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/debts_tab.dart';

void main() {

  for (final width in [360.0, 390.0]) {
    for (final settled in [false, true]) {
      testWidgets(
        'debt status stays beside amount at $width, settled=$settled',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final format = NumberFormat.simpleCurrency(name: 'PHP');
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.getTheme(Colors.teal, true),
              home: Scaffold(
                body: ListView(
                  padding: const EdgeInsets.all(KoinSpacing.screenInset),
                  children: [
                    DebtCard(
                      debt: Debt(
                        id: 'layout',
                        personName: settled ? 'SPayLater' : 'Nicole',
                        amount: 1992,
                        currentAmount: settled ? 1992 : 217,
                        type: DebtType.iOwe,
                        startDate: DateTime(2026),
                      ),
                      currencyFormat: format,
                      showEntranceAnimations: false,
                    ),
                  ],
                ),
              ),
            ),
          );
          final amount = tester.getRect(find.text(format.format(1992)));
          final status = tester.getRect(
            find.text(settled ? 'Paid off' : '${format.format(1775)} left'),
          );
          expect(status.left, greaterThanOrEqualTo(amount.right));
          expect(tester.getSize(find.byType(DebtCard)).height, lessThan(100));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

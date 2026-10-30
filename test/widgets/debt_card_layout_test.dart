import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:koin/core/core.dart';
import 'package:koin/features/debts/debts_tab.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final fonts = FontLoader(KoinTypography.fontFamily);
    for (final weight in ['Regular', 'Medium', 'SemiBold']) {
      fonts.addFont(rootBundle.load('assets/fonts/outfit/Outfit-$weight.ttf'));
    }
    await fonts.load();
  });

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.5, 2.0]) {
      for (final settled in [false, true]) {
        testWidgets(
          'remaining balance leads at $width, scale=$scale, settled=$settled',
          (tester) async {
            tester.view.physicalSize = Size(width, 800);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final format = NumberFormat.simpleCurrency(name: 'PHP');
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.getTheme(Colors.teal, width == 390),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: ListView(
                    padding: const EdgeInsets.all(KoinSpacing.screenInset),
                    children: [
                      DebtCard(
                        debt: Debt(
                          id: 'layout',
                          personName: settled
                              ? 'SPayLater'
                              : 'Nicole with a long account name',
                          amount: 1992,
                          currentAmount: settled ? 1992 : 217,
                          type: DebtType.iOwe,
                          startDate: DateTime(2026),
                          dueDate: DateTime.now().add(const Duration(days: 10)),
                        ),
                        currencyFormat: format,
                        showEntranceAnimations: false,
                      ),
                    ],
                  ),
                ),
              ),
            );
            final amountFinder = find.text(
              settled ? format.format(1992) : '${format.format(1775)} left',
              findRichText: true,
            );
            final amount = tester.getRect(amountFinder);
            final name = tester.getRect(
              find.text(
                settled ? 'SPayLater' : 'Nicole with a long account name',
              ),
            );
            expect(amount.top, greaterThanOrEqualTo(name.bottom));
            expect(amount.left, closeTo(name.left, 0.1));
            final amountText = tester.widget<Text>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is Text &&
                    widget.textSpan?.toPlainText() ==
                        (settled
                            ? format.format(1992)
                            : '${format.format(1775)} left'),
              ),
            );
            expect(amountText.style!.fontSize, KoinTypography.itemAmount);
            final title = tester.widget<Text>(
              find.text(
                settled ? 'SPayLater' : 'Nicole with a long account name',
              ),
            );
            expect(title.style!.fontSize, KoinTypography.body);
            expect(title.style!.fontWeight, KoinTypography.titleWeight);
            if (settled) {
              expect(find.text('Paid off'), findsOneWidget);
              final status = tester.getRect(find.text('Paid off'));
              expect(status.left, greaterThanOrEqualTo(name.right));
              expect(status.center.dy, closeTo(name.center.dy, 1));
              expect(status.bottom, lessThanOrEqualTo(amount.top));
              if (scale == 1) {
                expect(
                  tester.getSize(find.byType(DebtCard)).height,
                  lessThan(90),
                );
              }
              expect(find.byType(IconButton), findsNothing);
            } else {
              expect(find.text('of ${format.format(1992)}'), findsOneWidget);
              final action = tester.getRect(find.byType(IconButton));
              expect(action.left, greaterThanOrEqualTo(amount.right));
              expect(action.width, greaterThanOrEqualTo(48 - 0.01));
              expect(action.height, greaterThanOrEqualTo(48 - 0.01));
              expect(tester.widget<Icon>(find.byIcon(KoinIcons.plus)).size, 18);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

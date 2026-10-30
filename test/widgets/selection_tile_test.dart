import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  group('SelectionTile Widget Tests', () {
    testWidgets('renders placeholder when no selection provided', (
      tester,
    ) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(Colors.blue, false),
          home: Scaffold(
            body: SelectionTile(
              fallbackIcon: KoinIcons.squaresFour,
              label: 'Category',
              selectedName: null,
              selectedColor: null,
              selectedIconCodePoint: null,
              placeholder: 'Select Category',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Category'), findsOneWidget);
      expect(find.text('Select Category'), findsOneWidget);

      await tester.tap(find.byType(SelectionTile));
      expect(tapped, isTrue);
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('waits for a visible keyboard before opening the picker', (
      tester,
    ) async {
      var tapped = false;
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(Colors.blue, false),
          home: Scaffold(
            body: SelectionTile(
              fallbackIcon: KoinIcons.squaresFour,
              label: 'Category',
              selectedName: null,
              selectedColor: null,
              selectedIconCodePoint: null,
              placeholder: 'Select Category',
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byType(SelectionTile));
      expect(tapped, isFalse);
      await tester.pump(const Duration(milliseconds: 149));
      expect(tapped, isFalse);
      await tester.pump(const Duration(milliseconds: 1));
      expect(tapped, isTrue);
      await tester.pumpAndSettle();
    });

    testWidgets(
      'renders selectedName and custom icon when selection is provided',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.getTheme(Colors.blue, false),
            home: Scaffold(
              body: SelectionTile(
                asCard: false,
                fallbackIcon: KoinIcons.squaresFour,
                label: 'Account',
                selectedName: 'Savings Wallet',
                selectedColor: Colors.green,
                selectedIconCodePoint: KoinIcons.piggyBank.codePoint,
                placeholder: 'Select Account',
                onTap: () {},
              ),
            ),
          ),
        );

        expect(find.text('Account'), findsOneWidget);
        expect(find.text('Savings Wallet'), findsOneWidget);
        expect(find.text('Select Account'), findsNothing);
      },
    );
  });
}

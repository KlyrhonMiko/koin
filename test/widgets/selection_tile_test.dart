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
              fallbackIcon: Icons.category,
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
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
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
                fallbackIcon: Icons.category,
                label: 'Account',
                selectedName: 'Savings Wallet',
                selectedColor: Colors.green,
                selectedIconCodePoint: Icons.savings.codePoint,
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

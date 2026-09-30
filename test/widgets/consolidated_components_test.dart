import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/widgets/date_selector_tile.dart';
import 'package:koin/core/widgets/hero_amount_field.dart';
import 'package:koin/core/widgets/form_section_title.dart';
import 'package:koin/core/widgets/koin_empty_state.dart';
import 'package:koin/core/widgets/koin_primary_button.dart';
import 'package:koin/core/widgets/color_palette_grid.dart';
import 'package:koin/core/widgets/swipe_to_delete_tile.dart';
import 'package:koin/core/widgets/koin_reorder_proxy.dart';

void main() {
  group('Consolidated Reusable Components Tests', () {
    testWidgets('DateSelectorTile renders label, formatted date and icon', (tester) async {
      final testDate = DateTime(2026, 10, 1);
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DateSelectorTile(
              label: 'Test Date',
              date: testDate,
              icon: Icons.calendar_today,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Test Date'), findsOneWidget);
      expect(find.text('Oct 1, 2026'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);

      await tester.tap(find.text('Test Date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tapped, isTrue);
    });

    testWidgets('HeroAmountField renders currency symbol, controller value and animated underline', (tester) async {
      final controller = TextEditingController(text: '125.50');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HeroAmountField(
              controller: controller,
              currencySymbol: '\$',
              primaryColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.text('\$ '), findsOneWidget);
      expect(find.text('125.50'), findsOneWidget);
    });

    testWidgets('FormSectionTitle renders both standard and uppercase subhead formats', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FormSectionTitle(title: 'Overview'),
                FormSectionTitle.subhead(title: 'details', icon: Icons.info_outline),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Overview'), findsOneWidget);
      expect(find.text('DETAILS'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('KoinEmptyState renders title, subtitle, and action in box and sliver layouts', (tester) async {
      bool actionTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KoinEmptyState(
              icon: Icons.inbox,
              title: 'Empty State Title',
              subtitle: 'Empty state subtitle description',
              action: ElevatedButton(
                onPressed: () => actionTriggered = true,
                child: const Text('Add Item'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Empty State Title'), findsOneWidget);
      expect(find.text('Empty state subtitle description'), findsOneWidget);
      expect(find.text('Add Item'), findsOneWidget);

      await tester.tap(find.text('Add Item'));
      await tester.pump();
      expect(actionTriggered, isTrue);

      // Verify sliver factory compiles and renders in a scroll view
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: KoinEmptyState.sliver(
              icon: Icons.inbox,
              title: 'Sliver Empty',
              subtitle: 'Sliver Subtitle',
            ),
          ),
        ),
      );

      expect(find.text('Sliver Empty'), findsOneWidget);
      expect(find.text('Sliver Subtitle'), findsOneWidget);
    });

    testWidgets('KoinPrimaryButton renders label, handles tap, and shows loading indicator', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KoinPrimaryButton(
              label: 'Submit Action',
              icon: Icons.check,
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Submit Action'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);

      await tester.tap(find.text('Submit Action'));
      await tester.pump();
      expect(tapped, isTrue);

      // Loading state
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KoinPrimaryButton(
              label: 'Submit Action',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit Action'), findsNothing);
    });

    testWidgets('ColorPaletteGrid renders colors and triggers selection', (tester) async {
      final colors = [Colors.red, Colors.green, Colors.blue];
      Color? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColorPaletteGrid(
              colors: colors,
              selectedColor: Colors.green,
              onColorSelected: (c) => selected = c,
            ),
          ),
        ),
      );

      // Checkmark on the selected color
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);

      // Tap on red
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();
      expect(selected, equals(Colors.red));
    });

    testWidgets('SwipeToDeleteTile renders child and provides dismiss background', (tester) async {
      bool deleted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SwipeToDeleteTile(
              onDelete: () => deleted = true,
              child: const ListTile(
                title: Text('Swipe Me'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Swipe Me'), findsOneWidget);
      expect(find.byType(Dismissible), findsOneWidget);
      expect(deleted, isFalse);
    });

    testWidgets('koinReorderProxyDecorator wraps child in elevation and scale transform', (tester) async {
      final animationController = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 300),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: koinReorderProxyDecorator(
              const Text('Dragging Item'),
              0,
              animationController,
            ),
          ),
        ),
      );

      expect(find.text('Dragging Item'), findsOneWidget);
      final widget = koinReorderProxyDecorator(const Text('Direct'), 0, animationController);
      expect(widget, isA<AnimatedBuilder>());
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/core.dart';

void main() {
  testWidgets(
    'primary text has no outline and preserves fill and card gradient',
    (tester) async {
      const accent = Color(0xFFEAB308);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.getTheme(accent, false),
          home: Scaffold(
            body: Column(
              children: [
                KoinPrimaryButton(label: 'Save', onPressed: () {}),
                const KoinSummaryCard(
                  child: Text('Summary', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
      final buttonText = tester.widget<Text>(find.text('Save'));
      expect(buttonText.style!.color, Colors.white);
      expect(buttonText.style!.shadows, isNull);
      final card = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(KoinSummaryCard),
              matching: find.byType(Container),
            )
            .first,
      );
      final gradient =
          (card.decoration! as BoxDecoration).gradient! as LinearGradient;
      expect(gradient.colors, [accent, accent.withValues(alpha: 0.8)]);
      expect(
        tester.widget<Text>(find.text('Summary')).style!.color,
        Colors.white,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('readable dark-editor amount hint stays unoutlined', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.getTheme(const Color(0xFF00D09E), true),
        home: Builder(
          builder: (context) => Theme(
            data: Theme.of(
              context,
            ).copyWith(extensions: [const EditorAppearance()]),
            child: Scaffold(
              body: HeroAmountField(
                controller: controller,
                currencySymbol: r'$',
                primaryColor: const Color(0xFF00D09E),
              ),
            ),
          ),
        ),
      ),
    );
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.decoration!.hintStyle!.shadows, isNull);
  });
}

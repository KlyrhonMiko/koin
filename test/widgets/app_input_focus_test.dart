import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/widgets/inputs/app_input_focus.dart';

void main() {
  Future<void> launch(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AppInputFocus(child: child!),
        home: Scaffold(body: child),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('touch outside clears text focus and still activates buttons', (
    tester,
  ) async {
    final first = FocusNode();
    final second = FocusNode();
    addTearDown(first.dispose);
    addTearDown(second.dispose);
    var taps = 0;
    await launch(
      tester,
      Column(
        children: [
          TextField(focusNode: first),
          TextFormField(focusNode: second),
          TextButton(onPressed: () => taps++, child: const Text('Apply')),
          const SizedBox(key: Key('outside'), width: 200, height: 100),
        ],
      ),
    );
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    expect(first.hasFocus, isTrue);
    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    expect(first.hasFocus, isFalse);
    expect(second.hasFocus, isTrue);
    await tester.tapAt(tester.getCenter(find.byKey(const Key('outside'))));
    await tester.pump();
    expect(second.hasFocus, isFalse);
    await tester.tap(find.byType(TextField).first);
    await tester.pump();
    await tester.tap(find.text('Apply'));
    await tester.pump();
    expect(first.hasFocus, isFalse);
    expect(taps, 1);
  });

  testWidgets(
    'keyboard closing clears the active field after its resize animation',
    (tester) async {
      addTearDown(tester.view.resetViewInsets);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await launch(tester, TextField(focusNode: focus));
      await tester.tap(find.byType(TextField));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      tester.view.viewInsets = const FakeViewPadding(bottom: 100);
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isFalse);
      // The field remains usable after dismissal.
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Still editable');
      expect(focus.hasFocus, isTrue);
    },
  );

  for (final sheet in [false, true]) {
    testWidgets(
      'outside focus behavior reaches ${sheet ? 'sheets' : 'dialogs'}',
      (tester) async {
        final focus = FocusNode();
        addTearDown(focus.dispose);
        Widget content(BuildContext context) => Material(
          child: SizedBox(
            height: 220,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(focusNode: focus),
                TextButton(
                  onPressed: () {},
                  child: const Text('Outside field'),
                ),
              ],
            ),
          ),
        );
        await launch(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () {
                if (sheet) {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: content,
                  );
                } else {
                  showDialog<void>(
                    context: context,
                    builder: (context) => Dialog(child: content(context)),
                  );
                }
              },
              child: const Text('Open'),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(TextField));
        await tester.pump();
        expect(focus.hasFocus, isTrue);
        await tester.tap(find.text('Outside field'));
        await tester.pump();
        expect(focus.hasFocus, isFalse);
      },
    );
  }

  testWidgets('field accessory tap regions retain focus', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await launch(
      tester,
      Column(
        children: [
          TextField(focusNode: focus),
          TextFieldTapRegion(
            child: TextButton(
              onPressed: () {},
              child: const Text('Field accessory'),
            ),
          ),
        ],
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
    await tester.tap(find.text('Field accessory'));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
  });
}

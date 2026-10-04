import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/widgets/inputs/numpad.dart';

void main() {
  Future<void> mountPad(
    WidgetTester tester, {
    String initialValue = '',
    required void Function(String, String) onValueChanged,
    VoidCallback? onDone,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => NumPad(
                  compact: true,
                  initialValue: initialValue,
                  onValueChanged: onValueChanged,
                  onDone: onDone ?? () {},
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('replaces a prefilled payment with a new amount in a sheet', (
    tester,
  ) async {
    var expression = '15.99';
    var result = expression;
    await mountPad(
      tester,
      initialValue: expression,
      onValueChanged: (expr, value) {
        expression = expr;
        result = value;
      },
    );
    for (final key in ['2', '5', '.', '5', '0', '9']) {
      await tester.tap(find.text(key));
      await tester.pumpAndSettle();
    }
    expect(expression, '25.50');
    expect(result, '25.50');
  });

  testWidgets('backspace edits the prefilled amount', (tester) async {
    var result = '';
    await mountPad(
      tester,
      initialValue: '15.99',
      onValueChanged: (_, value) => result = value,
    );
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(result, '15.95');
  });

  testWidgets('enters and clears an amount in an empty sheet', (tester) async {
    var result = '';
    await mountPad(tester, onValueChanged: (_, value) => result = value);
    for (final key in ['1', '2', '.', '3', '4']) {
      await tester.tap(find.text(key));
      await tester.pumpAndSettle();
    }
    expect(result, '12.34');
    await tester.tap(find.text('C'));
    await tester.pumpAndSettle();
    expect(result, '0');
    await tester.tap(find.text('.'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5'));
    await tester.pumpAndSettle();
    expect(result, '0.5');
  });

  testWidgets('follows external resets without resetting on parent echoes', (
    tester,
  ) async {
    var expression = '15.99';
    late StateSetter updateParent;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              updateParent = setState;
              return NumPad(
                initialValue: expression,
                onValueChanged: (expr, _) => setState(() => expression = expr),
                onDone: () {},
              );
            },
          ),
        ),
      ),
    );
    for (final key in ['2', '5']) {
      await tester.tap(find.text(key));
      await tester.pumpAndSettle();
    }
    expect(expression, '25');
    updateParent(() => expression = '');
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();
    expect(expression, '3');
  });

  testWidgets('Save publishes the evaluated value before submitting', (
    tester,
  ) async {
    var expression = '15.99';
    var result = expression;
    String? submittedExpression;
    String? submittedResult;
    await mountPad(
      tester,
      initialValue: expression,
      onValueChanged: (expr, value) {
        expression = expr;
        result = value;
      },
      onDone: () {
        submittedExpression = expression;
        submittedResult = result;
      },
    );
    for (final key in ['+', '2', 'Save']) {
      await tester.tap(find.text(key));
      await tester.pumpAndSettle();
    }
    expect(submittedExpression, '17.99');
    expect(submittedResult, '17.99');
  });
}

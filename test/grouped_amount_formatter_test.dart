import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koin/core/widgets/inputs/grouped_amount_formatter.dart';

void main() {
  const formatter = GroupedAmountFormatter();
  TextEditingValue value(String text, [int? offset]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: offset ?? text.length),
  );

  test('groups signed balances without rounding or losing decimal input', () {
    for (final (input, expected) in [
      ('100000000', '100,000,000'),
      ('-1234567.80', '-1,234,567.80'),
      ('1234.', '1,234.'),
      ('1234.00', '1,234.00'),
      ('', ''),
      ('-', '-'),
      ('.5', '.5'),
    ]) {
      final result = formatter.formatEditUpdate(value(''), value(input));
      expect(result.text, expected);
      expect(result.selection.baseOffset, expected.length);
    }
  });

  test('keeps the caret at a middle insertion after regrouping', () {
    final result = formatter.formatEditUpdate(
      value('12,345', 2),
      value('129,345', 3),
    );
    expect(result.text, '129,345');
    expect(result.selection.baseOffset, 4);
  });

  test('backspace at a comma deletes the preceding digit', () {
    final result = formatter.formatEditUpdate(
      value('1,234', 2),
      value('1234', 1),
    );
    expect(result.text, '234');
    expect(result.selection.baseOffset, 0);
  });

  test('supports forward deletion and replacing a selected amount', () {
    expect(
      formatter.formatEditUpdate(value('1,234', 2), value('1,34', 2)).text,
      '134',
    );
    final old = value(
      '12,345',
    ).copyWith(selection: const TextSelection(baseOffset: 0, extentOffset: 6));
    expect(formatter.formatEditUpdate(old, value('9876')).text, '9,876');
  });

  test('rejects non-numeric input and leaves composition alone', () {
    final old = value('123');
    expect(formatter.formatEditUpdate(old, value('123x')), old);
    final composing = value('1234')
        .copyWith(composing: const TextRange(start: 0, end: 4));
    expect(formatter.formatEditUpdate(old, composing), composing);
  });
}

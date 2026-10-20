import 'package:flutter/services.dart';

/// Groups the integer part without rounding decimals or jumping the caret.
class GroupedAmountFormatter extends TextInputFormatter {
  const GroupedAmountFormatter();

  static String formatText(String text) {
    final raw = text.replaceAll(',', '');
    final parts = raw.split('.');
    final grouped = parts.first.replaceAllMapped(
      RegExp(r'\d(?=(\d{3})+(?!\d))'),
      (match) => '${match[0]},',
    );
    return parts.length > 1 ? '$grouped.${parts[1]}' : grouped;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed) return newValue;
    var text = newValue.text;
    var selection = newValue.selection;
    // Backspace over a grouping separator should remove the preceding digit.
    if (oldValue.selection.isCollapsed &&
        selection.isCollapsed &&
        oldValue.selection.baseOffset > 1 &&
        selection.baseOffset == oldValue.selection.baseOffset - 1 &&
        oldValue.text.length == text.length + 1 &&
        oldValue.text[selection.baseOffset] == ',' &&
        text.replaceAll(',', '') == oldValue.text.replaceAll(',', '')) {
      final index = selection.baseOffset - 1;
      text = text.replaceRange(index, index + 1, '');
      selection = TextSelection.collapsed(offset: index);
    }
    final raw = text.replaceAll(',', '');
    if (!RegExp(r'^[+-]?\d*(?:\.\d*)?$').hasMatch(raw)) return oldValue;
    final formatted = formatText(text);
    int mapOffset(int offset) {
      if (offset < 0) return formatted.length;
      final count = text
          .substring(0, offset.clamp(0, text.length))
          .replaceAll(',', '')
          .length;
      var seen = 0;
      var result = 0;
      while (result < formatted.length && seen < count) {
        if (formatted[result] != ',') seen++;
        result++;
      }
      if (result < formatted.length && formatted[result] == ',') result++;
      return result;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection(
        baseOffset: mapOffset(selection.baseOffset),
        extentOffset: mapOffset(selection.extentOffset),
        affinity: selection.affinity,
        isDirectional: selection.isDirectional,
      ),
    );
  }
}

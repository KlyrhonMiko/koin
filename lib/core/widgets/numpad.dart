import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

enum NumPadAction {
  digit,
  operator,
  decimal,
  backspace,
  clear,
  equals,
  done,
}

class NumPad extends StatefulWidget {
  final Function(String expression, String result) onValueChanged;
  final VoidCallback onDone;
  final String initialValue;
  final bool compact;
  final bool inline;

  const NumPad({
    super.key,
    required this.onValueChanged,
    required this.onDone,
    this.initialValue = '',
    this.compact = false,
    this.inline = false,
  });

  @override
  State<NumPad> createState() => _NumPadState();
}

class _NumPadState extends State<NumPad> {
  String _expression = '';
  String _result = '0';

  @override
  void initState() {
    super.initState();
    _expression = widget.initialValue;
    _calculate();
  }

  void _onPress(String value, NumPadAction action) {
    if (action != NumPadAction.done) {
      HapticService.light();
    }
    setState(() {
      if (action == NumPadAction.digit) {
        final lastPart = _expression.split(RegExp(r'[+\-*/]')).last;
        if (lastPart.contains('.')) {
          final decimalPart = lastPart.split('.').last;
          if (decimalPart.length >= 2) return;
        }

        if (_expression == '0') {
          _expression = value;
        } else {
          _expression += value;
        }
      } else if (action == NumPadAction.decimal) {
        final lastPart = _expression.split(RegExp(r'[+\-*/]')).last;
        if (!lastPart.contains('.')) {
          if (lastPart.isEmpty) {
            _expression += '0.';
          } else {
            _expression += '.';
          }
        }
      } else if (action == NumPadAction.operator) {
        if (_expression.isNotEmpty) {
          final lastChar = _expression[_expression.length - 1];
          if (RegExp(r'[+\-*/]').hasMatch(lastChar)) {
            _expression = _expression.substring(0, _expression.length - 1) + value;
          } else {
            _expression += value;
          }
        }
      } else if (action == NumPadAction.backspace) {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
      } else if (action == NumPadAction.clear) {
        _expression = '';
      } else if (action == NumPadAction.equals) {
        _calculate();
        if (_expression.isNotEmpty) {
          _expression = _result;
        }
      } else if (action == NumPadAction.done) {
        _expression = _result;
        widget.onDone();
      }

      _calculate();
      widget.onValueChanged(_expression, _result);
    });
  }

  void _calculate() {
    if (_expression.isEmpty) {
      _result = '0';
      return;
    }

    try {
      final hasOperators = _expression.contains(RegExp(r'[+\-*/]'));
      if (!hasOperators) {
        _result = _expression;
        return;
      }

      final tokens = RegExp(r'(\d+\.?\d*)|([+\-*/])').allMatches(_expression).map((m) => m.group(0)!).toList();

      if (tokens.isEmpty) {
        _result = '0';
        return;
      }

      double currentResult = 0;
      if (tokens.isNotEmpty) {
        currentResult = double.tryParse(tokens[0]) ?? 0;
      }

      for (int i = 1; i < tokens.length; i += 2) {
        if (i + 1 >= tokens.length) break;
        final op = tokens[i];
        final nextVal = double.tryParse(tokens[i + 1]) ?? 0;

        if (op == '+') currentResult += nextVal;
        if (op == '-') currentResult -= nextVal;
        if (op == '*') currentResult *= nextVal;
        if (op == '/') {
          if (nextVal != 0) {
            currentResult /= nextVal;
          }
        }
      }

      if (currentResult == currentResult.toInt()) {
        _result = currentResult.toInt().toString();
      } else {
        _result = currentResult.toStringAsFixed(2);
        if (_result.endsWith('0')) {
          _result = _result.replaceAll(RegExp(r'\.?0+$'), '');
        }
      }
    } catch (e) {
      // Keep last valid result
    }
  }

  Widget _buildDigitKey(BuildContext context, String text, {int flex = 1}) {
    final c = widget.compact;
    final keyPad = c ? 3.0 : 4.0;
    final keyRadius = c ? 14.0 : 16.0;
    final keyHeight = c ? 51.0 : 56.0;
    final fontSize = c ? 20.5 : 22.0;

    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.all(keyPad),
        child: Material(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(keyRadius),
          child: InkWell(
            onTap: () => _onPress(text, text == '.' ? NumPadAction.decimal : NumPadAction.digit),
            borderRadius: BorderRadius.circular(keyRadius),
            splashColor: AppTheme.primaryColor(context).withValues(alpha: 0.08),
            highlightColor: AppTheme.primaryColor(context).withValues(alpha: 0.04),
            child: Container(
              height: keyHeight,
              alignment: Alignment.center,
              child: Text(
                text,
                style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textColor(context),
                  letterSpacing: -0.3,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOperatorKey(BuildContext context, String value, String display) {
    final c = widget.compact;
    final keyPad = c ? 3.0 : 4.0;
    final keyRadius = c ? 14.0 : 16.0;
    final keyHeight = c ? 51.0 : 56.0;
    final primaryColor = AppTheme.primaryColor(context);

    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(keyPad),
        child: Material(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(keyRadius),
          child: InkWell(
            onTap: () => _onPress(value, NumPadAction.operator),
            borderRadius: BorderRadius.circular(keyRadius),
            splashColor: primaryColor.withValues(alpha: 0.15),
            highlightColor: primaryColor.withValues(alpha: 0.08),
            child: Container(
              height: keyHeight,
              alignment: Alignment.center,
              child: Text(
                display,
                style: TextStyle(
                  fontSize: c ? 23.0 : 24.0,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionKey(BuildContext context, {
    required NumPadAction action,
    IconData? icon,
    String? text,
    Color? color,
    Color? bgColor,
    int flex = 1,
  }) {
    final c = widget.compact;
    final keyPad = c ? 3.0 : 4.0;
    final keyRadius = c ? 14.0 : 16.0;
    final keyHeight = c ? 51.0 : 56.0;
    final effectiveColor = color ?? AppTheme.textLightColor(context);

    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.all(keyPad),
        child: Material(
          color: bgColor ?? AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(keyRadius),
          child: InkWell(
            onTap: () => _onPress(text ?? '', action),
            borderRadius: BorderRadius.circular(keyRadius),
            splashColor: effectiveColor.withValues(alpha: 0.12),
            highlightColor: effectiveColor.withValues(alpha: 0.06),
            child: Container(
              height: keyHeight,
              alignment: Alignment.center,
              child: icon != null
                  ? Icon(icon, color: effectiveColor, size: c ? 21.0 : 22.0)
                  : Text(
                      text ?? '',
                      style: TextStyle(
                        fontSize: c ? 17.0 : 18.0,
                        fontWeight: FontWeight.w700,
                        color: effectiveColor,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEqualsKey(BuildContext context) {
    final c = widget.compact;
    final keyPad = c ? 3.0 : 4.0;
    final keyRadius = c ? 14.0 : 16.0;
    final keyHeight = c ? 51.0 : 56.0;
    final primaryColor = AppTheme.primaryColor(context);

    return Expanded(
      child: Padding(
        padding: EdgeInsets.all(keyPad),
        child: Material(
          color: primaryColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(keyRadius),
          child: InkWell(
            onTap: () => _onPress('=', NumPadAction.equals),
            borderRadius: BorderRadius.circular(keyRadius),
            splashColor: primaryColor.withValues(alpha: 0.15),
            highlightColor: primaryColor.withValues(alpha: 0.08),
            child: Container(
              height: keyHeight,
              alignment: Alignment.center,
              child: Text(
                '=',
                style: TextStyle(
                  fontSize: c ? 23.0 : 24.0,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDoneKey(BuildContext context, {int flex = 3}) {
    final c = widget.compact;
    final keyPad = c ? 3.0 : 4.0;
    final keyRadius = c ? 14.0 : 16.0;
    final keyHeight = c ? 51.0 : 56.0;

    return Expanded(
      flex: flex,
      child: Padding(
        padding: EdgeInsets.all(keyPad),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(keyRadius),
          child: InkWell(
            onTap: () {
              HapticService.success();
              _onPress('Done', NumPadAction.done);
            },
            borderRadius: BorderRadius.circular(keyRadius),
            splashColor: Colors.white.withValues(alpha: 0.2),
            child: Container(
              height: keyHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient(context),
                borderRadius: BorderRadius.circular(keyRadius),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    'Save',
                    style: TextStyle(
                      fontSize: c ? 15.5 : 16.0,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.compact;
    return Container(
      padding: EdgeInsets.fromLTRB(10, c ? 10 : 12, 10, widget.inline ? (c ? 10 : 12) : (c ? 8 : 12)),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLightColor(context),
        borderRadius: widget.inline 
            ? BorderRadius.circular(c ? 24 : 28)
            : BorderRadius.vertical(top: Radius.circular(c ? 24 : 28)),
        boxShadow: widget.inline ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row 1: 7 8 9 ÷
            Row(
              children: [
                _buildDigitKey(context, '7'),
                _buildDigitKey(context, '8'),
                _buildDigitKey(context, '9'),
                _buildOperatorKey(context, '/', '÷'),
              ],
            ),
            // Row 2: 4 5 6 ×
            Row(
              children: [
                _buildDigitKey(context, '4'),
                _buildDigitKey(context, '5'),
                _buildDigitKey(context, '6'),
                _buildOperatorKey(context, '*', '×'),
              ],
            ),
            // Row 3: 1 2 3 −
            Row(
              children: [
                _buildDigitKey(context, '1'),
                _buildDigitKey(context, '2'),
                _buildDigitKey(context, '3'),
                _buildOperatorKey(context, '-', '−'),
              ],
            ),
            // Row 4: . 0 C +
            Row(
              children: [
                _buildDigitKey(context, '.'),
                _buildDigitKey(context, '0'),
                _buildActionKey(context,
                  action: NumPadAction.clear,
                  text: 'C',
                  color: const Color(0xFFFF6B6B),
                  bgColor: const Color(0xFFFF6B6B).withValues(alpha: 0.08),
                ),
                _buildOperatorKey(context, '+', '+'),
              ],
            ),
            // Row 5: ⌫ = [  Save  ]
            Row(
              children: [
                _buildActionKey(context,
                  action: NumPadAction.backspace,
                  icon: Icons.backspace_outlined,
                  color: AppTheme.textLightColor(context),
                  bgColor: AppTheme.surfaceLightColor(context),
                ),
                _buildEqualsKey(context),
                _buildDoneKey(context, flex: 2),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

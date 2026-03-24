import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

enum NumPadAction {
  digit,
  operator,
  decimal,
  backspace,
  clear,
  done,
}

class NumPad extends StatefulWidget {
  final Function(String expression, String result) onValueChanged;
  final VoidCallback onDone;
  final String initialValue;

  const NumPad({
    super.key,
    required this.onValueChanged,
    required this.onDone,
    this.initialValue = '',
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
    setState(() {
      if (action == NumPadAction.digit) {
        _expression += value;
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

  Widget _buildButton(BuildContext context, String text, NumPadAction action, {Color? color, Color? textColor, IconData? icon, int flex = 1, String? displayText}) {
    final isOperator = action == NumPadAction.operator;
    final isDone = action == NumPadAction.done;

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Material(
          color: color ?? AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _onPress(text, action),
            borderRadius: BorderRadius.circular(14),
            splashColor: (textColor ?? AppTheme.textColor(context)).withValues(alpha: 0.1),
            child: Container(
              height: 56,
              alignment: Alignment.center,
              decoration: isDone
                  ? BoxDecoration(
                      gradient: AppTheme.primaryGradient(context),
                      borderRadius: BorderRadius.circular(14),
                    )
                  : null,
              child: icon != null
                  ? Icon(icon, color: textColor ?? AppTheme.textColor(context), size: 22)
                  : Text(
                      displayText ?? text,
                      style: TextStyle(
                        fontSize: isOperator ? 24 : 20,
                        fontWeight: FontWeight.w700,
                        color: isDone ? Colors.white : (textColor ?? AppTheme.textColor(context)),
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLightColor(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: AppTheme.dividerColor(context), width: 1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppTheme.dividerColor(context),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            children: [
              _buildButton(context, '7', NumPadAction.digit),
              _buildButton(context, '8', NumPadAction.digit),
              _buildButton(context, '9', NumPadAction.digit),
              _buildButton(context, '/', NumPadAction.operator, color: AppTheme.primaryColor(context).withValues(alpha: 0.08), textColor: AppTheme.primaryColor(context), displayText: '÷'),
            ],
          ),
          Row(
            children: [
              _buildButton(context, '4', NumPadAction.digit),
              _buildButton(context, '5', NumPadAction.digit),
              _buildButton(context, '6', NumPadAction.digit),
              _buildButton(context, '*', NumPadAction.operator, color: AppTheme.primaryColor(context).withValues(alpha: 0.08), textColor: AppTheme.primaryColor(context), displayText: '×'),
            ],
          ),
          Row(
            children: [
              _buildButton(context, '1', NumPadAction.digit),
              _buildButton(context, '2', NumPadAction.digit),
              _buildButton(context, '3', NumPadAction.digit),
              _buildButton(context, '-', NumPadAction.operator, color: AppTheme.primaryColor(context).withValues(alpha: 0.08), textColor: AppTheme.primaryColor(context), displayText: '−'),
            ],
          ),
          Row(
            children: [
              _buildButton(context, '.', NumPadAction.decimal),
              _buildButton(context, '0', NumPadAction.digit),
              _buildButton(context, 'C', NumPadAction.clear, textColor: const Color(0xFFFF6B6B)),
              _buildButton(context, '+', NumPadAction.operator, color: AppTheme.primaryColor(context).withValues(alpha: 0.08), textColor: AppTheme.primaryColor(context)),
            ],
          ),
          Row(
            children: [
              _buildButton(context, '', NumPadAction.backspace, icon: Icons.backspace_outlined, textColor: AppTheme.textLightColor(context), flex: 1),
              _buildButton(context, 'Done', NumPadAction.done,
                color: Colors.transparent,
                textColor: Colors.white,
                flex: 3,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

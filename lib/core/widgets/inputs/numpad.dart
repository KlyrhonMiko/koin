import 'package:koin/core/icons.dart';
import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/utils/snackbar_utils.dart';

enum NumPadAction { digit, operator, decimal, backspace, clear, equals, done }

class NumPad extends StatefulWidget {
  final Function(String expression, String result) onValueChanged;
  final VoidCallback onDone;
  final String initialValue;
  final bool compact;
  final bool inline;
  final String doneLabel;
  final int decimalDigits;
  final bool enabled;

  const NumPad({
    super.key,
    required this.onValueChanged,
    required this.onDone,
    this.initialValue = '',
    this.compact = false,
    this.inline = false,
    this.doneLabel = 'Save',
    this.decimalDigits = 2,
    this.enabled = true,
  });

  @override
  State<NumPad> createState() => _NumPadState();
}

class _NumPadState extends State<NumPad> {
  String _expression = '';
  String _result = '0';
  bool _replaceOnNextDigit = false;
  String? _calculationError;

  @override
  void initState() {
    super.initState();
    _expression = widget.initialValue;
    _replaceOnNextDigit = _expression.isNotEmpty;
    _calculate();
  }

  @override
  void didUpdateWidget(covariant NumPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Parents echo our expression on each key press, but can also reset it
    // externally (for example, when switching budget modes).
    if (widget.initialValue != oldWidget.initialValue &&
        widget.initialValue != _expression) {
      _expression = widget.initialValue;
      _replaceOnNextDigit = _expression.isNotEmpty;
      _calculate();
    }
  }

  void _onPress(String value, NumPadAction action) {
    if (!widget.enabled) return;
    if (action == NumPadAction.done || action == NumPadAction.equals) {
      _calculate();
      if (_calculationError != null) {
        HapticService.error();
        KoinSnackBar.error(context, _calculationError!);
        return;
      }
    }
    HapticService.light();
    setState(() {
      if (_replaceOnNextDigit &&
          (action == NumPadAction.digit || action == NumPadAction.decimal)) {
        _expression = '';
      }
      _replaceOnNextDigit = false;
      if (action == NumPadAction.digit) {
        final lastPart = _expression.split(RegExp(r'[+\-*/]')).last;
        if (lastPart.contains('.')) {
          final decimalPart = lastPart.split('.').last;
          if (decimalPart.length >= widget.decimalDigits) return;
        }

        if (_expression == '0') {
          _expression = value;
        } else {
          _expression += value;
        }
      } else if (action == NumPadAction.decimal) {
        if (widget.decimalDigits == 0) return;
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
            _expression =
                _expression.substring(0, _expression.length - 1) + value;
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
      }

      _calculate();
    });
    widget.onValueChanged(_expression, _result);
    if (action == NumPadAction.done) {
      widget.onDone();
    }
  }

  void _calculate() {
    _calculationError = null;
    _result = '';
    if (_expression.isEmpty) {
      _result = '0';
      return;
    }
    // Preserve the existing left-to-right calculator behavior. Every token must
    // be valid: an incomplete expression must never reuse the last amount.
    if (!RegExp(r'^-?\d+(?:\.\d*)?(?:[+\-*/]\d+(?:\.\d*)?)*$')
        .hasMatch(_expression)) {
      _calculationError = 'Complete the calculation';
      return;
    }
    try {
      final tokens = RegExp(r'\d+\.?\d*|[+\-*/]')
          .allMatches(_expression)
          .map((m) => m.group(0)!)
          .toList();
      final negative = tokens.first == '-';
      if (negative) tokens.removeAt(0);
      var amount = double.parse(tokens.first) * (negative ? -1 : 1);
      for (var i = 1; i < tokens.length; i += 2) {
        final value = double.parse(tokens[i + 1]);
        switch (tokens[i]) {
          case '+':
            amount += value;
          case '-':
            amount -= value;
          case '*':
            amount *= value;
          case '/':
            if (value == 0) {
              _calculationError = 'Cannot divide by zero';
              return;
            }
            amount /= value;
        }
      }
      if (!amount.isFinite) {
        _calculationError = 'This amount is too large';
        return;
      }
      if (tokens.length == 1) {
        _result = _expression;
      } else {
        _result = amount.toStringAsFixed(widget.decimalDigits);
        if (_result.contains('.')) {
          _result = _result.replaceFirst(RegExp(r'\.?0+$'), '');
        }
      }
    } on FormatException {
      _calculationError = 'Check the calculation';
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
      child: _AnimatedKeyWrapper(
        label: text == '.' ? 'Decimal point' : text,
        onTap: () => _onPress(
          text,
          text == '.' ? NumPadAction.decimal : NumPadAction.digit,
        ),
        child: Padding(
          padding: EdgeInsets.all(keyPad),
          child: Material(
            color: AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(keyRadius),
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
      child: _AnimatedKeyWrapper(
        label: switch (value) {
          '+' => 'Add',
          '-' => 'Subtract',
          '*' => 'Multiply',
          '/' => 'Divide',
          _ => display,
        },
        onTap: () => _onPress(value, NumPadAction.operator),
        child: Padding(
          padding: EdgeInsets.all(keyPad),
          child: Material(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(keyRadius),
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

  Widget _buildActionKey(
    BuildContext context, {
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
      child: _AnimatedKeyWrapper(
        label: action == NumPadAction.backspace
            ? 'Delete last digit'
            : 'Clear amount',
        onTap: () => _onPress(text ?? '', action),
        child: Padding(
          padding: EdgeInsets.all(keyPad),
          child: Material(
            color: bgColor ?? AppTheme.surfaceColor(context),
            borderRadius: BorderRadius.circular(keyRadius),
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
      child: _AnimatedKeyWrapper(
        label: 'Equals. Calculations run from left to right',
        onTap: () => _onPress('=', NumPadAction.equals),
        child: Padding(
          padding: EdgeInsets.all(keyPad),
          child: Material(
            color: primaryColor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(keyRadius),
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
    final showIcon =
        widget.doneLabel.length <= 8 &&
        MediaQuery.textScalerOf(context).scale(16) <= 21;

    return Expanded(
      flex: flex,
      child: _AnimatedKeyWrapper(
        label: widget.doneLabel,
        onTap: () {
          _onPress('Done', NumPadAction.done);
        },
        child: Padding(
          padding: EdgeInsets.all(keyPad),
          child: Container(
            constraints: BoxConstraints(minHeight: keyHeight),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient(context),
              borderRadius: BorderRadius.circular(keyRadius),
              boxShadow: [
                AppTheme.boxShadow(
                  context,
                  color: AppTheme.primaryColor(context).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (showIcon)
                  Icon(
                    KoinIcons.check,
                    color: AppTheme.gradientForeground(
                      context,
                      AppTheme.primaryGradient(context),
                    ),
                    size: 20,
                  ),
                if (showIcon) const SizedBox(width: 6),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      widget.doneLabel,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(
                        fontSize: c ? 15.5 : 16.0,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.gradientForeground(
                          context,
                          AppTheme.primaryGradient(context),
                        ),
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ],
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
      padding: EdgeInsets.fromLTRB(
        10,
        c ? 10 : 12,
        10,
        widget.inline ? (c ? 10 : 12) : (c ? 8 : 12),
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLightColor(context),
        borderRadius: widget.inline
            ? BorderRadius.circular(c ? 24 : 28)
            : BorderRadius.vertical(top: Radius.circular(KoinShape.sheet)),
        boxShadow: widget.inline
            ? null
            : [
                AppTheme.boxShadow(
                  context,
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
            if (_expression.contains(RegExp(r'[+*/-]')))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'Calculates from left to right',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
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
                _buildActionKey(
                  context,
                  action: NumPadAction.clear,
                  text: 'C',
                  color: AppTheme.errorContentColor(context),
                  bgColor: AppTheme.errorContentColor(context)
                      .withValues(alpha: 0.08),
                ),
                _buildOperatorKey(context, '+', '+'),
              ],
            ),
            // Row 5: ⌫ = [  Save  ]
            Row(
              children: [
                _buildActionKey(
                  context,
                  action: NumPadAction.backspace,
                  icon: KoinIcons.backspace,
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

/// Subtle press feedback with explicit accessible button labels.
class _AnimatedKeyWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String label;

  const _AnimatedKeyWrapper({
    required this.child,
    required this.onTap,
    required this.label,
  });

  @override
  State<_AnimatedKeyWrapper> createState() => _AnimatedKeyWrapperState();
}

class _AnimatedKeyWrapperState extends State<_AnimatedKeyWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 120),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!MediaQuery.disableAnimationsOf(context)) _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      onTap: widget.onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _onTapDown,
        onTapUp: _onTapUp,
        onTapCancel: _onTapCancel,
        child: MediaQuery.disableAnimationsOf(context)
            ? widget.child
            : ScaleTransition(scale: _scaleAnimation, child: widget.child),
      ),
    );
  }
}

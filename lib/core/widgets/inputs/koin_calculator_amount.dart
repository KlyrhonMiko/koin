import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Read-only amount driven by the shared numpad, separate from text input.
class KoinCalculatorAmount extends StatelessWidget {
  const KoinCalculatorAmount({
    super.key,
    required this.symbol,
    required this.expression,
    required this.color,
    this.result,
    this.amountColor,
  });

  final String symbol;
  final String expression;
  final String? result;
  final Color color;
  final Color? amountColor;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$symbol ',
              style: TextStyle(
                fontSize: KoinTypography.screenTitle,
                fontWeight: KoinTypography.labelWeight,
                color: color,
              ),
            ),
            Text(
              expression.isEmpty ? '0' : expression,
              style: KoinTypography.inputAmountStyle.copyWith(
                color: amountColor ?? color,
              ),
            ),
          ],
        ),
      ),
      if (result != null &&
          result!.isNotEmpty &&
          expression.contains(RegExp(r'[+\-*/]')))
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '= $symbol$result',
            style: TextStyle(
              fontSize: KoinTypography.compact,
              fontWeight: KoinTypography.labelWeight,
              color: AppTheme.textLightColor(context).withValues(alpha: 0.6),
            ),
          ),
        ),
    ],
  );
}

import 'package:flutter/material.dart';
import 'package:koin/core/models/models.dart';

/// Keeps portfolio balances and editor previews readable at the same card size.
class AccountCardAmount extends StatelessWidget {
  const AccountCardAmount({
    super.key,
    required this.value,
    required this.currency,
    required this.style,
    this.detail,
  });

  final double value;
  final Currency currency;
  final TextStyle style;
  final String? detail;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final fullAmount = currency.formatter.format(value);
      final description = detail == null ? fullAmount : '$fullAmount\n$detail';
      final measure = TextPainter(
        text: TextSpan(
          text: fullAmount,
          style: DefaultTextStyle.of(context).style.merge(style),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 1,
      )..layout();
      final compact = measure.width > constraints.maxWidth;
      measure.dispose();
      return Tooltip(
        message: description,
        excludeFromSemantics: true,
        child: Semantics(
          label: description,
          excludeSemantics: true,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              compact ? currency.compactFormatter.format(value) : fullAmount,
              style: style,
            ),
          ),
        ),
      );
    },
  );
}

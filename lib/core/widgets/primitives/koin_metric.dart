import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Quiet label/value/detail stack used for savings metrics and rate estimates.
class KoinMetric extends StatelessWidget {
  const KoinMetric({
    super.key,
    required this.label,
    required this.value,
    this.detail,
    this.labelStyle,
  });
  final String label;
  final String value;
  final String? detail;
  final TextStyle? labelStyle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style:
            labelStyle ??
            TextStyle(
              color: AppTheme.textLightColor(context),
              fontSize: KoinTypography.caption,
              fontWeight: KoinTypography.labelWeight,
              letterSpacing: KoinTypography.itemTracking,
            ),
      ),
      const SizedBox(height: 6),
      Text(
        value,
        style: TextStyle(
          color: AppTheme.textColor(context),
          fontSize: KoinTypography.itemAmount,
          fontWeight: KoinTypography.titleWeight,
          letterSpacing: KoinTypography.itemTracking,
        ),
      ),
      if (detail != null) ...[
        const SizedBox(height: 4),
        Text(
          detail!,
          style: TextStyle(
            color: AppTheme.textLightColor(context),
            fontSize: KoinTypography.small,
          ),
        ),
      ],
    ],
  );
}

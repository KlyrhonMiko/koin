import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Shared visual rules for Accounts, Savings, and Credit & IOUs.
abstract final class PortfolioCardStyle {
  static const radius = 24.0;
  static const iconSize = 48.0;
  static const iconRadius = 16.0;
  static const padding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);

  static BoxDecoration decoration(BuildContext context) => BoxDecoration(
    color: AppTheme.surfaceColor(context),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: AppTheme.dividerColor(context).withValues(alpha: 0.6),
    ),
  );

  static TextStyle label(BuildContext context, {bool colored = false}) =>
      TextStyle(
        color: colored
            ? Colors.white.withValues(alpha: 0.85)
            : AppTheme.textLightColor(context),
        fontSize: KoinTypography.caption,
        fontWeight: KoinTypography.labelWeight,
        letterSpacing: KoinTypography.itemTracking,
      );

  static TextStyle amount(BuildContext context, {bool colored = false}) =>
      TextStyle(
        color: colored ? Colors.white : AppTheme.textColor(context),
        fontSize: KoinTypography.itemAmount,
        fontWeight: KoinTypography.titleWeight,
        letterSpacing: KoinTypography.itemTracking,
      );

  static final summaryLabel = TextStyle(
    color: Colors.white.withValues(alpha: 0.8),
    fontSize: KoinTypography.caption,
    fontWeight: KoinTypography.labelWeight,
    letterSpacing: 0.5,
  );

  static const summaryAmount = TextStyle(
    color: Colors.white,
    fontSize: KoinTypography.summaryAmount,
    fontWeight: KoinTypography.headingWeight,
    letterSpacing: KoinTypography.amountTracking,
    height: KoinTypography.amountHeight,
  );
}

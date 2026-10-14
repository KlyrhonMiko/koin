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

  static TextStyle label(
    BuildContext context, {
    bool colored = false,
    Color? foreground,
  }) => TextStyle(
    color:
        foreground ??
        (colored
            ? Colors.white.withValues(alpha: 0.85)
            : AppTheme.textLightColor(context)),
    fontSize: KoinTypography.caption,
    fontWeight: KoinTypography.labelWeight,
    letterSpacing: KoinTypography.itemTracking,
  );

  static TextStyle amount(
    BuildContext context, {
    bool colored = false,
    Color? foreground,
  }) => TextStyle(
    color: foreground ?? (colored ? Colors.white : AppTheme.textColor(context)),
    fontSize: KoinTypography.itemAmount,
    fontWeight: KoinTypography.titleWeight,
    letterSpacing: KoinTypography.itemTracking,
  );

  static const summaryLabel = KoinTypography.summaryLabelStyle;
  static const summaryAmount = KoinTypography.summaryAmountStyle;
}

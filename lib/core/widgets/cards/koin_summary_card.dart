import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/widgets/cards/card_background_shapes.dart';

enum SummaryShapeStyle {
  dashboard,
  savings,
  debts,
  debtDetails,
  budgets,
  analysis,
  defaultStyle,
}

/// Hero summary surface with a primary gradient and translucent account-style shapes.
class KoinSummaryCard extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  final Color? glowColor;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final SummaryShapeStyle shapeStyle;

  const KoinSummaryCard({
    super.key,
    required this.child,
    this.gradient,
    this.glowColor,
    this.borderRadius = 32,
    this.padding = const EdgeInsets.all(KoinSpacing.summaryInset),
    this.margin,
    this.shapeStyle = SummaryShapeStyle.defaultStyle,
  });

  // Reuse the account card patterns with a modest visibility boost for heroes.
  int get _shapeType => switch (shapeStyle) {
    SummaryShapeStyle.dashboard => 0,
    SummaryShapeStyle.savings => 1,
    SummaryShapeStyle.debts => 2,
    SummaryShapeStyle.debtDetails => 5,
    SummaryShapeStyle.budgets => 4,
    SummaryShapeStyle.analysis => 7,
    SummaryShapeStyle.defaultStyle => 2,
  };

  Widget _buildCornerAccent(bool isDark) {
    final useTile =
        shapeStyle == SummaryShapeStyle.savings ||
        shapeStyle == SummaryShapeStyle.analysis;

    return Positioned(
      left: -36,
      top: useTile ? -34 : null,
      bottom: useTile ? null : -38,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: useTile ? -0.3 : 0,
          child: Container(
            width: 116,
            height: 116,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: isDark ? 0.035 : 0.10),
              shape: useTile ? BoxShape.rectangle : BoxShape.circle,
              borderRadius: useTile ? BorderRadius.circular(32) : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveGradient = gradient ?? AppTheme.primaryGradient(context);
    final effectiveGlow = glowColor ?? AppTheme.primaryColor(context);

    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: effectiveGradient,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.12)
                : effectiveGlow.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CardBackgroundShapes(
                shapeType: _shapeType,
                opacityMultiplier: isDark ? 0.4 : 1.4,
              ),
            ),
          ),
          // The eclipse pattern already decorates opposite corners.
          if (shapeStyle != SummaryShapeStyle.debtDetails)
            _buildCornerAccent(isDark),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

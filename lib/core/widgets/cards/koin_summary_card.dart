import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

enum SummaryShapeStyle {
  dashboard,
  savings,
  debts,
  debtDetails,
  budgets,
  analysis,
  defaultStyle,
}

/// Consolidated hero summary surface card.
/// Encapsulates 32px rounded corners, primary gradient/lighting, glow elevation,
/// and layered translucent depth bubbles.
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
    this.padding = const EdgeInsets.all(28),
    this.margin,
    this.shapeStyle = SummaryShapeStyle.defaultStyle,
  });

  List<Widget> _buildShapes() {
    switch (shapeStyle) {
      case SummaryShapeStyle.dashboard:
        return [
          Positioned(
            top: -40,
            right: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
        ];
      case SummaryShapeStyle.savings:
        return [
          Positioned(
            top: -50,
            right: -30,
            child: Transform.rotate(
              angle: -0.2,
              child: Container(
                width: 150,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -30,
            child: Transform.rotate(
              angle: 0.3,
              child: Container(
                width: 140,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
        ];
      case SummaryShapeStyle.debts:
        return [
          Positioned(
            left: -50,
            top: -20,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          Positioned(
            right: -20,
            top: -50,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(40),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
        ];
      case SummaryShapeStyle.debtDetails:
        return [
          Positioned(
            right: -30,
            bottom: 0,
            child: Container(
              width: 120,
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(60),
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            left: 20,
            top: -40,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
        ];
      case SummaryShapeStyle.budgets:
        return [
          Positioned(
            right: 40,
            top: -20,
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          Positioned(
            right: -20,
            bottom: -10,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.12)),
            ),
          ),
        ];
      case SummaryShapeStyle.analysis:
        return [
          Positioned(
            right: -30,
            bottom: -50,
            child: Transform.rotate(
              angle: 0.5,
              child: Container(
                width: 140,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            left: -20,
            top: -20,
            child: Transform.rotate(
              angle: -0.3,
              child: Container(
                width: 80,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
        ];
      case SummaryShapeStyle.defaultStyle:
        return [
          Positioned(
            left: -20,
            bottom: -40,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.07)),
            ),
          ),
          Positioned(
            right: -10,
            top: -10,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ?? AppTheme.primaryGradient(context);
    final effectiveGlow = glowColor ?? AppTheme.primaryColor(context);

    return Container(
      margin: margin,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: effectiveGradient,
        boxShadow: [
          BoxShadow(
            color: effectiveGlow.withValues(alpha: 0.25),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ..._buildShapes(),
          child,
        ],
      ),
    );
  }
}

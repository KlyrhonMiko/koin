import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

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

  const KoinSummaryCard({
    super.key,
    required this.child,
    this.gradient,
    this.glowColor,
    this.borderRadius = 32,
    this.padding = const EdgeInsets.all(28),
    this.margin,
  });

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
          // Decorative top-right depth bubble
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
          // Decorative bottom-left depth bubble
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
          child,
        ],
      ),
    );
  }
}

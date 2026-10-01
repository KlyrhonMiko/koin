import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

/// Consolidated, deep primary gradient action button.
/// Encapsulates full-width layout, primary gradient styling, glow elevation,
/// loading spinner, icon layout, and tactile haptic feedback.
class KoinPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final bool enabled;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final LinearGradient? gradient;
  final Color? glowColor;
  final double? width;

  const KoinPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.enabled = true,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
    this.gradient,
    this.glowColor,
    this.width = double.infinity,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveGlow = glowColor ?? AppTheme.primaryColor(context);
    final effectiveGradient = gradient ?? AppTheme.primaryGradient(context);
    final isInteractive = enabled && !isLoading && onPressed != null;

    Widget button = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: isInteractive
            ? effectiveGradient
            : LinearGradient(
                colors: [
                  AppTheme.textLightColor(context).withValues(alpha: 0.3),
                  AppTheme.textLightColor(context).withValues(alpha: 0.2),
                ],
              ),
        boxShadow: isInteractive
            ? [
                BoxShadow(
                  color: effectiveGlow.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: ElevatedButton(
        onPressed: isInteractive
            ? () {
                HapticService.medium();
                onPressed!();
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: width == null ? MainAxisSize.min : MainAxisSize.max,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: Colors.white, size: 20),
                    const Gap(8),
                  ],
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
      ),
    );

    if (width != null) {
      return SizedBox(width: width, child: button);
    }
    return button;
  }
}

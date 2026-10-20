import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/motion_policy.dart';

/// Determinate progress with one track shape and reduced-motion behavior.
class KoinProgressBar extends StatelessWidget {
  const KoinProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.backgroundColor,
    this.initialValue = 0,
    this.duration = KoinMotion.entrance,
    this.curve = Curves.easeOutCubic,
    this.height = 4,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double value;
  final Color color;
  final Color? backgroundColor;

  /// Starting fill on first mount. Updates still tween from the current fill.
  final double initialValue;
  final Duration duration;
  final Curve curve;
  final double height;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(
      begin: initialValue.clamp(0.0, 1.0),
      end: value.clamp(0.0, 1.0),
    ),
    duration: KoinMotion.duration(context, duration),
    curve: curve,
    builder: (context, progress, _) => LinearProgressIndicator(
      value: progress,
      minHeight: height,
      borderRadius: BorderRadius.circular(2),
      backgroundColor: backgroundColor ?? AppTheme.surfaceLightColor(context),
      color: color,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
    ),
  );
}

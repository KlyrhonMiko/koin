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
    this.duration = const Duration(milliseconds: 600),
    this.curve = Curves.easeOutCubic,
    this.height = 4,
    this.semanticsLabel,
    this.semanticsValue,
  });

  final double value;
  final Color color;
  final Color? backgroundColor;
  final Duration duration;
  final Curve curve;
  final double height;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween<double>(begin: 0, end: value.clamp(0.0, 1.0)),
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

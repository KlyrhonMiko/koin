import 'package:flutter/material.dart';

/// Displays a formatted amount immediately, without counting or rolling digits.
///
/// The existing name and motion parameters are retained for compatibility with
/// callers. Financial values always render in full, including on first display
/// and subsequent updates.
class AnimatedCounter extends StatelessWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool animateFromZero;
  final String? lastValueToken;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = Duration.zero,
    this.curve = Curves.easeOutCubic,
    this.maxLines,
    this.overflow,
    this.animateFromZero = false,
    this.lastValueToken,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      formatter(value),
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}

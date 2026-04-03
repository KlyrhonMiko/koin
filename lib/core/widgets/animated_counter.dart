import 'dart:math';
import 'package:flutter/material.dart';

/// A premium animated counter that rolls individual digits up/down
/// like a mechanical odometer. Each digit independently transitions
/// with a slight stagger for a sophisticated cascading effect.
class AnimatedCounter extends StatefulWidget {
  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;
  final Curve curve;
  final int? maxLines;
  final TextOverflow? overflow;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 1200),
    this.curve = Curves.easeOutCubic,
    this.maxLines,
    this.overflow,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> {
  double? _oldValue;

  @override
  Widget build(BuildContext context) {
    final beginValue = _oldValue ?? 0.0;
    _oldValue = widget.value;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: beginValue, end: widget.value),
      duration: widget.duration,
      curve: widget.curve,
      builder: (context, animatedValue, child) {
        final formatted = widget.formatter(animatedValue);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: _buildDigits(formatted, animatedValue, widget.style),
        );
      },
    );
  }

  List<Widget> _buildDigits(
    String formatted,
    double animatedValue,
    TextStyle? style,
  ) {
    final effectiveStyle = style ?? const TextStyle();
    final List<Widget> widgets = [];

    for (int i = 0; i < formatted.length; i++) {
      final char = formatted[i];

      if (_isDigit(char)) {
        // Animate digit with a rolling effect
        final digit = int.parse(char);
        widgets.add(
          _RollingDigit(
            digit: digit,
            progress: animatedValue / max(widget.value.abs(), 1),
            style: effectiveStyle,
          ),
        );
      } else {
        // Static character (currency symbol, comma, period, etc.)
        widgets.add(Text(char, style: effectiveStyle));
      }
    }

    return widgets;
  }

  bool _isDigit(String char) {
    return char.codeUnitAt(0) >= 48 && char.codeUnitAt(0) <= 57;
  }
}

class _RollingDigit extends StatelessWidget {
  final int digit;
  final double progress; // 0.0 to 1.0
  final TextStyle style;

  const _RollingDigit({
    required this.digit,
    required this.progress,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    // When progress is near completion, show the final digit clearly
    // The rolling effect happens during the animation
    final opacity = (0.7 + (progress * 0.3)).clamp(0.0, 1.0);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (Widget child, Animation<double> animation) {
        // Slide up transition for changing digits
        final slideAnimation =
            Tween<Offset>(
              begin: const Offset(0, 0.3),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            );

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slideAnimation, child: child),
        );
      },
      child: Text(
        '$digit',
        key: ValueKey<int>(digit),
        style: style.copyWith(
          color: (style.color ?? Theme.of(context).colorScheme.onSurface)
              .withValues(alpha: opacity),
        ),
      ),
    );
  }
}

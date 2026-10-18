import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Navigation chrome only. Features own date arithmetic and bounds.
class KoinPeriodNavigation extends StatelessWidget {
  const KoinPeriodNavigation({
    super.key,
    required this.label,
    required this.onPrevious,
    required this.onNext,
    required this.previousTooltip,
    required this.nextTooltip,
    this.onReset,
  });
  final String label;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onReset;
  final String previousTooltip;
  final String nextTooltip;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: TextStyle(
        color: AppTheme.textColor(context),
        fontSize: KoinTypography.caption,
        fontWeight: KoinTypography.titleWeight,
        letterSpacing: 0.3,
      ),
    );
    return Row(
      children: [
        IconButton(
          tooltip: previousTooltip,
          onPressed: onPrevious,
          icon: Icon(
            Icons.chevron_left_rounded,
            color: AppTheme.textLightColor(context),
            size: 20,
          ),
        ),
        Expanded(
          child: onReset == null
              ? FittedBox(fit: BoxFit.scaleDown, child: text)
              : TextButton(onPressed: onReset, child: text),
        ),
        IconButton(
          tooltip: nextTooltip,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded, size: 20),
        ),
      ],
    );
  }
}

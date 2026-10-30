import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

import 'pressable_scale.dart';

/// A circular action with a caption. Callers own navigation and haptics.
class KoinQuickAction extends StatelessWidget {
  const KoinQuickAction({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
    this.tooltip,
    this.size = 54,
    this.labelGap = 8,
    this.elevated = false,
    this.tonal = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double labelGap;
  final bool elevated;
  final bool tonal;

  @override
  Widget build(BuildContext context) {
    final button = tonal
        ? IconButton.filledTonal(
            tooltip: tooltip,
            onPressed: onPressed,
            style: IconButton.styleFrom(
              overlayColor: AppTheme.primaryColor(context),
              fixedSize: Size.square(size),
              backgroundColor: AppTheme.surfaceColor(context),
              foregroundColor: color,
              disabledForegroundColor: AppTheme.textLightColor(context)
                  .withValues(alpha: 0.4),
              shape: const CircleBorder(),
            ),
            icon: Icon(icon, size: 22),
          )
        : Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor(context),
              shape: BoxShape.circle,
              boxShadow: elevated
                  ? [
                      AppTheme.boxShadow(
                        context,
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Icon(icon, color: color, size: 22),
          );
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        button,
        SizedBox(height: labelGap),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: KoinTypography.small,
            fontWeight: KoinTypography.labelWeight,
            color: AppTheme.textLightColor(context),
          ),
        ),
      ],
    );
    if (tonal) return content;
    if (onPressed == null) {
      return Semantics(
        button: true,
        enabled: false,
        child: Opacity(opacity: 0.4, child: content),
      );
    }
    final action = PressableScale(
      enableHaptic: false,
      onTap: onPressed!,
      child: content,
    );
    return tooltip == null ? action : Tooltip(message: tooltip!, child: action);
  }
}

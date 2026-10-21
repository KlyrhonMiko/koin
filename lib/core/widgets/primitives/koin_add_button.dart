import 'package:koin/core/icons.dart';
import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

import 'pressable_scale.dart';

/// The outlined add action used at the end of portfolio lists.
class KoinAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool iconOnly;
  final double borderRadius;
  final bool stacked;

  const KoinAddButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.iconOnly = false,
    this.borderRadius = 24,
    this.stacked = false,
  });

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onPressed,
    semanticLabel: iconOnly ? label : null,
    child: Container(
      width: double.infinity,
      padding: EdgeInsets.all(stacked ? 16 : 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.6),
        ),
      ),
      child: stacked
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  KoinIcons.plus,
                  color: AppTheme.textLightColor(context),
                  size: 24,
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textLightColor(context),
                      fontWeight: KoinTypography.labelWeight,
                      fontSize: KoinTypography.compact,
                    ),
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  KoinIcons.plus,
                  color: AppTheme.textLightColor(context),
                  size: 20,
                ),
                if (!iconOnly) const SizedBox(width: 10),
                if (!iconOnly)
                  Flexible(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AppTheme.textLightColor(context),
                        fontWeight: KoinTypography.labelWeight,
                        fontSize: KoinTypography.compact,
                      ),
                    ),
                  ),
              ],
            ),
    ),
  );
}

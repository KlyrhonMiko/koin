import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'package:koin/core/widgets/pressable_scale.dart';

class KoinBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const KoinBackButton({super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        HapticService.light();
        if (onPressed != null) {
          onPressed!();
        } else {
          Navigator.maybePop(context);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: AppTheme.dividerColor(context).withValues(alpha: 0.5),
          ),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 15,
          color: color ?? AppTheme.textColor(context),
        ),
      ),
    );
  }
}

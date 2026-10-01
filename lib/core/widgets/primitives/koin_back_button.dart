import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';
import 'pressable_scale.dart';

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
        padding: const EdgeInsets.all(8),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: color ?? AppTheme.textColor(context),
        ),
      ),
    );
  }
}

import 'package:koin/core/icons.dart';
import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'pressable_scale.dart';

class KoinBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? color;

  const KoinBackButton({super.key, this.onPressed, this.color});

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      semanticLabel: 'Back',
      onTap: () {
        if (onPressed != null) {
          onPressed!();
        } else {
          Navigator.maybePop(context);
        }
      },
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Icon(
          KoinIcons.arrowLeft,
          size: 24,
          color: color ?? AppTheme.textColor(context),
        ),
      ),
    );
  }
}

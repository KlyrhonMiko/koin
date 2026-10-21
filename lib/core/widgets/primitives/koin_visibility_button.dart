import 'package:koin/core/icons.dart';
import 'package:flutter/material.dart';
import 'package:koin/core/utils/haptic_utils.dart';

/// Visibility presentation only: summary and account preferences stay separate.
class KoinVisibilityButton extends StatelessWidget {
  const KoinVisibilityButton({
    super.key,
    required this.hidden,
    required this.subject,
    required this.onPressed,
    this.color = Colors.white,
    this.iconSize = 22,
    this.haptic = true,
  });

  final bool hidden;
  final String subject;
  final VoidCallback onPressed;
  final Color color;
  final double iconSize;
  final bool haptic;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: '${hidden ? 'Show' : 'Hide'} $subject',
    onPressed: () {
      if (haptic) HapticService.selection();
      onPressed();
    },
    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    iconSize: iconSize,
    color: color.withValues(alpha: hidden ? 0.6 : 0.9),
    icon: Icon(
      hidden ? KoinIcons.eyeSlash : KoinIcons.eye,
    ),
  );
}

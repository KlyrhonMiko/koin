import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'pressable_scale.dart';

/// The outlined add action used at the end of portfolio lists.
class KoinAddButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const KoinAddButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) => PressableScale(
    onTap: onPressed,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.dividerColor(context).withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.add_rounded,
            color: AppTheme.textLightColor(context),
            size: 20,
          ),
          const SizedBox(width: 10),
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

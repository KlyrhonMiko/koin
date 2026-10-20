import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

/// Borderless search input for a header or a search/filter capsule.
class KoinSearchField extends StatelessWidget {
  const KoinSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
    this.inline = false,
    this.autofocus = false,
  });
  final String hintText;
  final ValueChanged<String> onChanged;
  final bool inline;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final size = inline ? KoinTypography.itemTitle : KoinTypography.compact;
    return TextField(
      autofocus: autofocus,
      onChanged: onChanged,
      style: TextStyle(
        color: AppTheme.textColor(context),
        fontSize: size,
        fontWeight: inline
            ? KoinTypography.supportingWeight
            : KoinTypography.labelWeight,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: AppTheme.textLightColor(context)
              .withValues(alpha: inline ? 1 : 0.4),
          fontSize: size,
          fontWeight: KoinTypography.supportingWeight,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: inline
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

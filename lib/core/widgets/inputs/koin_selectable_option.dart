import 'package:koin/core/icons.dart';
import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/motion_policy.dart';

/// Shared multi-select presentation for report grids and filter chips.
/// The owning feature retains the selection set and haptic policy.
class KoinSelectableOption extends StatelessWidget {
  const KoinSelectableOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accentColor,
    this.leading,
    this.compact = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accentColor;
  final Widget? leading;
  final bool compact;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(compact ? 12 : 16),
          child: AnimatedContainer(
            duration: KoinMotion.duration(
              context,
              Duration(milliseconds: compact ? 250 : 200),
            ),
            curve: Curves.easeOutCubic,
            constraints: const BoxConstraints(minHeight: 48),
            padding: EdgeInsets.symmetric(
              horizontal: 14,
              vertical: compact ? 9 : 0,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? accentColor.withValues(alpha: compact ? 0.12 : 0.1)
                  : compact
                  ? AppTheme.surfaceLightColor(context)
                  : AppTheme.surfaceColor(context),
              borderRadius: BorderRadius.circular(compact ? 12 : 16),
              border: Border.all(
                width: selected ? 1.5 : 1,
                color: selected
                    ? accentColor.withValues(alpha: compact ? 0.4 : 1)
                    : AppTheme.dividerColor(context)
                          .withValues(alpha: compact ? 0.3 : 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
              children: [
                if (compact && selected) ...[
                  Icon(
                    KoinIcons.checkCircle,
                    size: 15,
                    color: accentColor,
                  ),
                  const SizedBox(width: 6),
                ] else if (leading != null) ...[
                  leading!,
                  SizedBox(width: compact ? 6 : 10),
                ],
                Flexible(
                  fit: compact ? FlexFit.loose : FlexFit.tight,
                  child: Text(
                    label,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: compact && selected
                          ? accentColor
                          : AppTheme.textColor(context),
                      fontSize: compact
                          ? KoinTypography.small
                          : KoinTypography.caption,
                      fontWeight: selected
                          ? KoinTypography.titleWeight
                          : KoinTypography.labelWeight,
                    ),
                  ),
                ),
                if (!compact && selected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    KoinIcons.checkCircle,
                    size: 14,
                    color: accentColor,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

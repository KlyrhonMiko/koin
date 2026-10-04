import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

/// Card container for grouped lists and settings with 20px rounded corners,
/// surface background, subtle border, and optional auto-injected dividers.
class KoinGroupedCard extends StatelessWidget {
  final List<Widget> children;
  final bool autoDivide;
  final double dividerIndent;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? borderColor;

  const KoinGroupedCard({
    super.key,
    required this.children,
    this.autoDivide = true,
    this.dividerIndent = 64.0,
    this.margin,
    this.borderRadius = 20.0,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    List<Widget> contentChildren;
    if (autoDivide && children.length > 1) {
      contentChildren = [];
      for (int i = 0; i < children.length; i++) {
        contentChildren.add(children[i]);
        if (i < children.length - 1) {
          contentChildren.add(
            Divider(
              height: 1,
              indent: dividerIndent,
              color: AppTheme.hasEditorAppearance(context)
                  ? AppTheme.dividerColor(context).withValues(alpha: 0.45)
                  : AppTheme.dividerColor(context),
            ),
          );
        }
      }
    } else {
      contentChildren = children;
    }

    final card = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color:
              borderColor ??
              (AppTheme.hasEditorAppearance(context)
                  ? AppTheme.fieldBorderColor(context)
                  : AppTheme.dividerColor(context)),
        ),
      ),
      child: Material(
        color: backgroundColor ?? AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(borderRadius),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: contentChildren,
        ),
      ),
    );

    if (margin != null) {
      return Padding(padding: margin!, child: card);
    }
    return card;
  }
}

/// Standardized interactive tile for settings, preferences, and action lists.
class KoinSettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final EdgeInsetsGeometry? contentPadding;

  const KoinSettingTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
    this.iconColor,
    this.iconBackgroundColor,
    this.contentPadding,
  });

  Widget _buildLeading(BuildContext context) {
    if (leading != null) return leading!;
    if (icon == null) return const SizedBox.shrink();

    final effectiveColor =
        iconColor ??
        (isDestructive
            ? Colors.red
            : AppTheme.hasEditorAppearance(context)
            ? AppTheme.textLightColor(context)
            : AppTheme.primaryColor(context));
    final effectiveBg =
        iconBackgroundColor ??
        (AppTheme.hasEditorAppearance(context) && !isDestructive
            ? AppTheme.surfaceLightColor(context)
            : effectiveColor.withValues(alpha: 0.1));

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: effectiveBg,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(icon, color: effectiveColor, size: 20),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget? effectiveTrailing = trailing;
    if (effectiveTrailing == null && onTap != null) {
      effectiveTrailing = Icon(
        Icons.chevron_right_rounded,
        color: AppTheme.textLightColor(context),
        size: 20,
      );
    }

    return ListTile(
      onTap: onTap != null
          ? () {
              HapticService.light();
              onTap!();
            }
          : null,
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(
            horizontal: KoinSpacing.screenInset,
            vertical: 4,
          ),
      leading: icon != null || leading != null ? _buildLeading(context) : null,
      title: Text(
        title,
        style: TextStyle(
          fontWeight: KoinTypography.labelWeight,
          fontSize: KoinTypography.body,
          color: isDestructive ? Colors.red : null,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: AppTheme.textLightColor(context),
                fontSize: KoinTypography.small,
                fontWeight: KoinTypography.supportingWeight,
              ),
            )
          : null,
      trailing: effectiveTrailing,
    );
  }
}

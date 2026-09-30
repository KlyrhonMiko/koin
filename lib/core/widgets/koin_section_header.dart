import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/theme.dart';
import 'package:koin/core/utils/haptic_utils.dart';

/// Standardized section header with title, optional subtitle, and interactive action button.
class KoinSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;

  const KoinSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onActionTap,
    this.trailing,
    this.padding,
  });

  Widget _buildTitleColumn(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppTheme.textColor(context),
            letterSpacing: -0.4,
          ),
        ),
        if (subtitle != null) ...[
          const Gap(3),
          Text(
            subtitle!,
            style: TextStyle(
              fontSize: 13,
              color: AppTheme.textLightColor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildAction(BuildContext context) {
    if (trailing != null) return trailing;
    if (actionLabel != null && onActionTap != null) {
      return GestureDetector(
        onTap: () {
          HapticService.light();
          onActionTap!();
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                actionLabel!,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textLightColor(context),
                ),
              ),
              const Gap(4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 10,
                color: AppTheme.textLightColor(context),
              ),
            ],
          ),
        ),
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final action = _buildAction(context);

    Widget content;
    if (action != null) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: _buildTitleColumn(context)),
          action,
        ],
      );
    } else {
      content = _buildTitleColumn(context);
    }

    if (padding != null) {
      return Padding(padding: padding!, child: content);
    }
    return content;
  }
}

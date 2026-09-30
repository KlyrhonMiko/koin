import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:koin/core/theme.dart';

/// Standard top header for tab views and feature home screens.
/// Features an uppercase tracked category tag, large prominent screen title,
/// and an optional trailing actions slot.
class KoinScreenHeader extends StatelessWidget {
  final String title;
  final String? tag;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const KoinScreenHeader({
    super.key,
    required this.title,
    this.tag,
    this.trailing,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectivePadding =
        padding ??
        EdgeInsets.only(
          top: MediaQuery.paddingOf(context).top + 14,
          bottom: 12,
          left: 20,
          right: 20,
        );

    final titleColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (tag != null) ...[
          Text(
            tag!.toUpperCase(),
            style: TextStyle(
              color: AppTheme.textLightColor(context).withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const Gap(4),
        ],
        Text(
          title,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: AppTheme.textColor(context),
          ),
        ),
      ],
    );

    Widget content;
    if (trailing != null) {
      content = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: titleColumn),
          trailing!,
        ],
      );
    } else {
      content = titleColumn;
    }

    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: effectivePadding,
      child: content,
    );
  }
}

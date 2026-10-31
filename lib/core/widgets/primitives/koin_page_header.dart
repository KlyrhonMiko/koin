import 'package:flutter/material.dart';
import 'package:koin/core/theme.dart';

import 'koin_back_button.dart';

/// Back navigation and a flexible title, with optional supporting text/actions.
class KoinPageHeader extends StatelessWidget {
  const KoinPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding = EdgeInsets.zero,
  });
  final String title;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      children: [
        const KoinBackButton(),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ?subtitle,
              Text(
                title,
                maxLines: MediaQuery.textScalerOf(context).scale(16) > 22
                    ? 2
                    : 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: KoinTypography.screenTitle,
                  fontWeight: KoinTypography.headingWeight,
                  letterSpacing: KoinTypography.headingTracking,
                  color: AppTheme.textColor(context),
                ),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Keeps secondary routes aligned with the main app's readable viewport.
class KoinContentWidth extends StatelessWidget {
  const KoinContentWidth({super.key, required this.child, this.maxWidth = 760});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

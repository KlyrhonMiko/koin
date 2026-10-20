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
                maxLines: 1,
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
